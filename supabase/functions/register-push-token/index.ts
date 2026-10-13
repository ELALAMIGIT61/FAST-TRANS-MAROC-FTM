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
 *
 * Volet 5, lot D-bis (13/10/2026) :
 *  - l'appelant doit être un utilisateur connecté ;
 *  - le profil indiqué doit appartenir à cet utilisateur (sinon un tiers
 *    pourrait recevoir les notifications d'un autre compte) ;
 *  - réponse CORS pour l'application web.
 */

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

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
    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await userClient.auth.getUser();
    const user = userData?.user;
    if (!user) {
      return reply(401, { error: 'Utilisateur non connecte' });
    }

    const { profile_id, token, platform } = await req.json();

    if (!profile_id || !token || !platform) {
      return reply(400, { error: 'Missing required fields: profile_id, token, platform' });
    }

    // 2. Le profil doit appartenir à l'utilisateur connecté
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id')
      .eq('id', profile_id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (profileError) {
      console.error('[FTM-DEBUG] Push - Profile check error', profileError.message);
      return reply(500, { error: profileError.message });
    }
    if (!profile) {
      console.log('[FTM-DEBUG] Push - Token registration refused (not own profile)', { profile_id });
      return reply(403, { error: 'Ce profil n appartient pas a l utilisateur connecte' });
    }

    console.log('[FTM-DEBUG] Push - Registering device token', {
      profile_id,
      platform,
      tokenPreview: String(token).substring(0, 20) + '...',
    });

    // 3. Upsert : insert ou update si le token existe déjà
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
      return reply(500, { error: error.message });
    }

    console.log('[FTM-DEBUG] Push - Token registered successfully', {
      profile_id,
      platform,
    });

    return reply(200, { success: true });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('[FTM-DEBUG] Push - register-push-token exception', msg);
    return reply(500, { error: msg });
  }
});
