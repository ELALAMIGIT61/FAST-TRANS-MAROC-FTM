import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface SendTrackingSmsPayload {
  tracking_number: string;
  recipient_phone: string;
  recipient_name: string;
  pickup_city: string;
  dropoff_city: string;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const payload: SendTrackingSmsPayload = await req.json();
    const { tracking_number, recipient_phone, recipient_name, pickup_city, dropoff_city } = payload;

    if (!tracking_number || !recipient_phone) {
      return new Response(
        JSON.stringify({ error: 'tracking_number and recipient_phone are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

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
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
