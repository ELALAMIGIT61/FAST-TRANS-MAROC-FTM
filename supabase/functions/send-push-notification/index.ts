import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/*
 * Edge Function : send-push-notification
 * Rôle : envoie sur les téléphones du destinataire une notification DÉJÀ
 *        enregistrée dans la table notifications, via l'API Expo Push
 *        (compatible FCM + APNs).
 *
 * Volet 5, lot D-bis (13/10/2026) :
 *  - l'appelant doit être un utilisateur connecté, ou un service interne
 *    (clé de service, ex. check-document-reminders) ;
 *  - le titre, le texte et le destinataire sont lus dans la notification
 *    enregistrée (notification_id), jamais dans la requête ;
 *  - un utilisateur ne peut déclencher l'envoi que s'il a le droit de notifier
 *    ce destinataire (fonction SQL can_notify_profile) et que la notification
 *    a moins de 10 minutes ;
 *  - réponse CORS pour l'application web.
 */

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const MAX_AGE_MS = 10 * 60 * 1000;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

function reply(status: number, payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Identifier l'appelant
    const authHeader = req.headers.get('Authorization') ?? '';
    const isService = authHeader === `Bearer ${SERVICE_ROLE_KEY}`;
    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    if (!isService) {
      const { data: userData } = await userClient.auth.getUser();
      if (!userData?.user) {
        return reply(401, { error: 'Utilisateur non connecte' });
      }
    }

    // 2. Charger la notification enregistrée
    const { notification_id, channel_id = 'ftm_default' } = await req.json();
    if (!notification_id) {
      return reply(400, { error: 'Missing required field: notification_id' });
    }

    const { data: notif, error: notifError } = await supabase
      .from('notifications')
      .select('id, profile_id, type, title, body, data, created_at')
      .eq('id', notification_id)
      .maybeSingle();

    if (notifError) {
      console.error('[FTM-DEBUG] Push - Fetch notification error', notifError.message);
      return reply(500, { error: notifError.message });
    }
    if (!notif) {
      return reply(404, { error: 'Notification introuvable' });
    }

    // 3. Un utilisateur ne peut envoyer qu'une notification récente qu'il a le droit d'adresser
    if (!isService) {
      const ageMs = Date.now() - new Date(notif.created_at).getTime();
      if (ageMs > MAX_AGE_MS) {
        return reply(403, { error: 'Notification trop ancienne' });
      }
      const { data: allowed, error: allowedError } = await userClient.rpc('can_notify_profile', {
        p_target: notif.profile_id,
      });
      if (allowedError || allowed !== true) {
        console.log('[FTM-DEBUG] Push - Refused (no relation)', { notification_id });
        return reply(403, { error: 'Envoi non autorise pour ce destinataire' });
      }
    }

    // 4. Récupérer les tokens du destinataire
    const { data: tokens, error: tokensError } = await supabase
      .from('push_tokens')
      .select('token, platform')
      .eq('profile_id', notif.profile_id);

    if (tokensError) {
      console.error('[FTM-DEBUG] Push - Fetch tokens error', tokensError.message);
      return reply(500, { error: tokensError.message });
    }

    if (!tokens || tokens.length === 0) {
      console.log('[FTM-DEBUG] Push - No tokens for profile', { profile_id: notif.profile_id });
      return reply(200, { success: true, sent: 0, message: 'No push tokens registered' });
    }

    // 5. Préparer et envoyer les messages via l'API Expo Push
    const type = String(notif.type ?? '');
    const messages = tokens.map((t: { token: string; platform: string }) => ({
      to:        t.token,
      title:     notif.title,
      body:      notif.body,
      data:      { ...(notif.data ?? {}), type, notification_id: notif.id, channel_id },
      sound:     'default',
      channelId: channel_id,
      priority:  type.includes('mission') ? 'high' : 'normal',
    }));

    const expoPushResp = await fetch('https://exp.host/--/api/v2/push/send', {
      method:  'POST',
      headers: {
        'Content-Type':    'application/json',
        'Accept':          'application/json',
        'Accept-Encoding': 'gzip, deflate',
      },
      body: JSON.stringify(messages),
    });

    const expoPushData = await expoPushResp.json();

    const sentCount = messages.length;
    console.log('[FTM-DEBUG] Push - Dispatched successfully', {
      notification_id: notif.id, profile_id: notif.profile_id, type, sentCount,
    });

    return reply(200, { success: true, sent: sentCount, expoPushData });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('[FTM-DEBUG] Push - send-push-notification exception', msg);
    return reply(500, { error: msg });
  }
});
