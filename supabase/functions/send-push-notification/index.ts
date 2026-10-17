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
 *
 * Session 2.26 (16/10/2026) : sonnerie déclenchée par le serveur.
 *  - la base appelle désormais cette fonction pour chaque notification
 *    enregistrée (trigger notifications_push_dispatch, migration 057) ;
 *  - envoi unique : la colonne push_sent_at est cochée avant l'envoi ; un
 *    second appel pour la même notification est ignoré (pas de doublon) ;
 *  - le canal Android est choisi ici, d'après le type de la notification.
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

// Canaux Android (créés par l'application, pushNotificationService.ts)
const CHANNEL_BY_TYPE: Record<string, string> = {
  new_mission:        'ftm_missions',
  mission_accepted:   'ftm_missions',
  mission_started:    'ftm_missions',
  mission_completed:  'ftm_missions',
  mission_cancelled:  'ftm_missions',
  offer_update:       'ftm_missions',
  parcel_status:      'ftm_missions',
  voice_channel_opened: 'ftm_missions',
  wallet_low_balance: 'ftm_wallet',
  commission_insufficient_balance: 'ftm_wallet',
  document_expiry:    'ftm_documents',
  document_rejected:  'ftm_documents',
  document_verified:  'ftm_documents',
};

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

// Session 2.26 (correctif) : role inscrit dans un jeton JWT. La passerelle de
// Supabase verifie la signature du jeton avant d'appeler la fonction
// (verification JWT active par defaut) : un jeton falsifie n'arrive jamais ici.
function jwtRole(authHeader: string): string | null {
  try {
    const token = authHeader.replace(/^Bearer\s+/i, '');
    const part = token.split('.')[1];
    if (!part) return null;
    const b64 = part.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(part.length / 4) * 4, '=');
    const payload = JSON.parse(atob(b64));
    return typeof payload.role === 'string' ? payload.role : null;
  } catch {
    return null;
  }
}

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
    const isService = authHeader === `Bearer ${SERVICE_ROLE_KEY}`
      || jwtRole(authHeader) === 'service_role';
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
    const { notification_id } = await req.json();
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

    // 4. Envoi unique : réserver la notification (push_sent_at), sinon ignorer
    const { data: claimed, error: claimError } = await supabase
      .from('notifications')
      .update({ push_sent_at: new Date().toISOString() })
      .eq('id', notif.id)
      .is('push_sent_at', null)
      .select('id');

    if (claimError) {
      console.error('[FTM-DEBUG] Push - Claim error', claimError.message);
      return reply(500, { error: claimError.message });
    }
    if (!claimed || claimed.length === 0) {
      console.log('[FTM-DEBUG] Push - Already sent, skipped', { notification_id: notif.id });
      return reply(200, { success: true, sent: 0, message: 'Already sent' });
    }

    // 5. Récupérer les tokens du destinataire
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

    // 6. Préparer et envoyer les messages via l'API Expo Push
    const type = String(notif.type ?? '');
    const channelId = CHANNEL_BY_TYPE[type] ?? 'ftm_default';
    const messages = tokens.map((t: { token: string; platform: string }) => ({
      to:        t.token,
      title:     notif.title,
      body:      notif.body,
      data:      { ...(notif.data ?? {}), type, notification_id: notif.id, channel_id: channelId },
      sound:     'default',
      channelId: channelId,
      priority:  channelId === 'ftm_missions' ? 'high' : 'normal',
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
