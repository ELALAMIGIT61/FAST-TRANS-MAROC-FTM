// /frontend/src/lib/supabaseClient.ts
// FTM — Initialisation du client Supabase
 
import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';
 
const SUPABASE_URL = process.env.EXPO_PUBLIC_SUPABASE_URL as string;
const SUPABASE_ANON_KEY = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY as string;
 
if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  throw new Error(
    '[FTM] Variables EXPO_PUBLIC_SUPABASE_URL et EXPO_PUBLIC_SUPABASE_ANON_KEY manquantes dans .env'
  );
}
 
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
});
 
console.log('[FTM-DEBUG] Supabase client initialized', {
  url: SUPABASE_URL,
  timestamp: new Date().toISOString(),
});
