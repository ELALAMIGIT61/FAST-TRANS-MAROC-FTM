import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/*
 * Edge Function : send-push-notification
 * Rôle : récupère les tokens FCM/APNs du profil et envoie la notification push
 *        via l'API Expo Push Notifications (compatible FCM + APNs)
 */

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

serve(async (req) => {
  try {
    const {
      profile_id,
      notification_id,
      type,
      title,
      body,
      data = {},
      channel_id = 'ftm_default',
    } = await req.json();

    if (!profile_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: profile_id, title, body' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Récupérer les tokens du profil
    const { data: tokens, error: tokensError } = await supabase
      .from('push_tokens')
      .select('token, platform')
      .eq('profile_id', profile_id);

    if (tokensError) {
      console.error('[FTM-DEBUG] Push - Fetch tokens error', tokensError.message);
      return new Response(
        JSON.stringify({ error: tokensError.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    if (!tokens || tokens.length === 0) {
      console.log('[FTM-DEBUG] Push - No tokens for profile', { profile_id });
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: 'No push tokens registered' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Préparer les messages pour l'API Expo Push
    const messages = tokens.map((t: { token: string; platform: string }) => ({
      to:         t.token,
      title,
      body,
      data:       { ...data, type, notification_id, channel_id },
      sound:      'default',
      channelId:  channel_id,
      priority:   type.includes('mission') ? 'high' : 'normal',
    }));

    // Envoyer via Expo Push API
    const expoPushResp = await fetch('https://exp.host/--/api/v2/push/send', {
      method:  'POST',
      headers: {
        'Content-Type':  'application/json',
        'Accept':        'application/json',
        'Accept-Encoding': 'gzip, deflate',
      },
      body: JSON.stringify(messages),
    });

    const expoPushData = await expoPushResp.json();

    const sentCount = messages.length;
    console.log('[FTM-DEBUG] Push - Dispatched successfully', {
      notification_id, profile_id, type, sentCount,
    });

    return new Response(
      JSON.stringify({ success: true, sent: sentCount, expoPushData }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('[FTM-DEBUG] Push - send-push-notification exception', msg);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
