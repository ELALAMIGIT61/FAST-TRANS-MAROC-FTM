import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/*
 * Volet 5, lot D-bis (13/10/2026) :
 *  - l'appelant doit être un utilisateur connecté, client de la mission du colis ;
 *  - seul le numéro de suivi est lu dans la requête : destinataire, téléphone
 *    et villes sont lus dans la fiche du colis et de sa mission ;
 *  - un seul SMS par colis : l'envoi est réservé en renseignant
 *    tracking_sms_sent_at (migration 050) ; la réservation est annulée si
 *    l'envoi échoue ou si aucun fournisseur SMS n'est configuré.
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface SendTrackingSmsPayload {
  tracking_number: string;
}

function reply(status: number, payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // Réservation de l'envoi (un seul SMS par colis), annulée en cas d'échec
  let releaseClaim: (() => Promise<void>) | null = null;

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. Identifier l'appelant
    const authHeader = req.headers.get('Authorization') ?? '';
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: userData } = await userClient.auth.getUser();
    const user = userData?.user;
    if (!user) {
      return reply(401, { error: 'Utilisateur non connecte' });
    }

    const payload: SendTrackingSmsPayload = await req.json();
    const tracking_number = String(payload?.tracking_number ?? '').trim().toUpperCase();

    if (!tracking_number) {
      return reply(400, { error: 'tracking_number is required' });
    }

    // 2. Lire le colis et sa mission ; verifier que l'appelant en est le client
    const { data: parcel, error: parcelError } = await supabaseClient
      .from('ecommerce_parcels')
      .select('tracking_number, recipient_name, recipient_phone, created_at, missions ( client_id, pickup_city, dropoff_city )')
      .eq('tracking_number', tracking_number)
      .maybeSingle();

    if (parcelError) {
      console.log('[FTM-DEBUG] send-tracking-sms - Parcel fetch error', { error: parcelError.message });
      return reply(500, { error: 'Internal server error' });
    }

    const mission = (parcel?.missions ?? null) as { client_id: string | null; pickup_city: string; dropoff_city: string } | null;
    let isOwner = false;
    if (parcel && mission?.client_id) {
      const { data: owner } = await supabaseClient
        .from('profiles')
        .select('id')
        .eq('id', mission.client_id)
        .eq('user_id', user.id)
        .maybeSingle();
      isOwner = !!owner;
    }
    if (!parcel || !mission || !isOwner) {
      console.log('[FTM-DEBUG] send-tracking-sms - Refused (unknown parcel or not owner)', { tracking_number });
      return reply(403, { error: 'Colis introuvable ou non autorise' });
    }

    // 3. Réserver l'envoi : réussit seulement si aucun SMS n'est déjà parti
    const { data: claimed, error: claimError } = await supabaseClient
      .from('ecommerce_parcels')
      .update({ tracking_sms_sent_at: new Date().toISOString() })
      .eq('tracking_number', tracking_number)
      .is('tracking_sms_sent_at', null)
      .select('tracking_number');

    if (claimError) {
      console.log('[FTM-DEBUG] send-tracking-sms - Claim error', { error: claimError.message });
      return reply(500, { error: 'Internal server error' });
    }
    if (!claimed || claimed.length === 0) {
      console.log('[FTM-DEBUG] send-tracking-sms - Refused (SMS already sent)', { tracking_number });
      return reply(409, { error: 'SMS deja envoye pour ce colis' });
    }
    releaseClaim = async () => {
      await supabaseClient
        .from('ecommerce_parcels')
        .update({ tracking_sms_sent_at: null })
        .eq('tracking_number', tracking_number);
    };

    const recipient_phone = String(parcel.recipient_phone);
    const recipient_name = String(parcel.recipient_name);
    const pickup_city = mission.pickup_city;
    const dropoff_city = mission.dropoff_city;

    // Normaliser le numéro marocain
    let phone = recipient_phone.replace(/\s+/g, '');
    if (phone.startsWith('0')) {
      phone = '+212' + phone.slice(1);
    } else if (!phone.startsWith('+')) {
      phone = '+212' + phone;
    }

    const smsApiKey = Deno.env.get('SMS_API_KEY') ?? '';
    const smsApiUrl = Deno.env.get('SMS_API_URL') ?? '';

    const message =
      `Bonjour ${recipient_name}, votre colis FTM est en route !\n` +
      `De : ${pickup_city} → ${dropoff_city}\n` +
      `N° de suivi : ${tracking_number}\n` +
      `Suivez votre colis sur l'app Fast Trans Maroc.`;

    console.log('[FTM-DEBUG] send-tracking-sms - Sending SMS', {
      tracking_number,
      phone,
      recipient_name,
    });

    if (!smsApiKey || !smsApiUrl) {
      console.log('[FTM-DEBUG] send-tracking-sms - SMS API not configured, skipping send');
      await releaseClaim();
      return new Response(
        JSON.stringify({ success: true, message: 'SMS skipped (API not configured)', tracking_number }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const smsResponse = await fetch(smsApiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${smsApiKey}`,
      },
      body: JSON.stringify({
        to: phone,
        message,
        from: 'FastTrans',
      }),
    });

    if (!smsResponse.ok) {
      const errText = await smsResponse.text();
      console.log('[FTM-DEBUG] send-tracking-sms - SMS API error', { status: smsResponse.status, errText });
      await releaseClaim();
      return new Response(
        JSON.stringify({ error: 'SMS delivery failed', details: errText }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Logguer dans notifications (optionnel)
    await supabaseClient.from('notifications').insert({
      profile_id: null,
      type: 'sms_tracking_sent',
      title: 'SMS de suivi envoyé',
      body: `SMS envoyé à ${phone} pour colis ${tracking_number}`,
      data: { tracking_number, phone },
    }).maybeSingle();

    console.log('[FTM-DEBUG] send-tracking-sms - SMS sent successfully', { tracking_number, phone });

    return new Response(
      JSON.stringify({ success: true, tracking_number, phone }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[FTM-DEBUG] send-tracking-sms - Unexpected error', error);
    if (releaseClaim) {
      try { await releaseClaim(); } catch (_e) { /* best effort */ }
    }
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
