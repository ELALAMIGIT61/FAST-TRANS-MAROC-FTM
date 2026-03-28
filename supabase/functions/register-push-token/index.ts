import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/*
 * Edge Function : register-push-token
 * Rôle : enregistre ou met à jour le token FCM/APNs d'un device
 *
 * Table attendue dans Supabase :
 *   CREATE TABLE push_tokens (
 *     id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
 *     profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
 *     token      TEXT NOT NULL,
 *     platform   VARCHAR(10) NOT NULL, -- 'android' | 'ios'
 *     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
 *     updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
 *     UNIQUE(profile_id, token)
 *   );
 */

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

serve(async (req) => {
  try {
    const { profile_id, token, platform } = await req.json();

    if (!profile_id || !token || !platform) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: profile_id, token, platform' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log('[FTM-DEBUG] Push - Registering device token', {
      profile_id,
      platform,
      tokenPreview: token.substring(0, 20) + '...',
    });

    // Upsert : insert ou update si le token existe déjà
    const { error } = await supabase
      .from('push_tokens')
      .upsert(
        {
          profile_id,
          token,
          platform,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'profile_id,token' }
      );

    if (error) {
      console.error('[FTM-DEBUG] Push - Token registration error', error.message);
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log('[FTM-DEBUG] Push - Token registered successfully', {
      profile_id,
      platform,
    });

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('[FTM-DEBUG] Push - register-push-token exception', msg);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
