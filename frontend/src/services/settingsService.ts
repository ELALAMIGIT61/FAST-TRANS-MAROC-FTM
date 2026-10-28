// /frontend/src/services/settingsService.ts
// FTM A1 (ecran Reglages admin) — lecture et modification du tableau de
// reglages app_settings (migrations 064, 065, 066). Seul l'admin peut lire
// et modifier ces valeurs (regles de securite du serveur) ; aucune migration
// n'est necessaire pour changer une valeur.

import { supabase } from '../lib/supabaseClient';

export interface AppSetting {
  key: string;
  value: number;
  description: string | null;
  updated_at: string;
}

export async function getAppSettings(): Promise<{ settings?: AppSetting[]; error?: string }> {
  const { data, error } = await supabase
    .from('app_settings')
    .select('key, value, description, updated_at')
    .order('key', { ascending: true });
  if (error) {
    console.log('[FTM-DEBUG] Settings - Load error', { error: error.message });
    return { error: error.message };
  }
  return {
    settings: ((data ?? []) as AppSetting[]).map((s) => ({ ...s, value: Number(s.value) })),
  };
}

export async function updateAppSetting(
  key: string,
  value: number
): Promise<{ setting?: AppSetting; error?: string }> {
  console.log('[FTM-DEBUG] Settings - Update', { key, value });
  const { data, error } = await supabase
    .from('app_settings')
    .update({ value, updated_at: new Date().toISOString() })
    .eq('key', key)
    .select('key, value, description, updated_at');
  if (error) {
    console.log('[FTM-DEBUG] Settings - Update error', { key, error: error.message });
    return { error: error.message };
  }
  // Une seule ligne doit avoir ete modifiee ; zero = droits insuffisants.
  if (!data || data.length !== 1) {
    return { error: "La modification n'a pas été enregistrée (droits insuffisants ?)." };
  }
  const row = data[0] as AppSetting;
  return { setting: { ...row, value: Number(row.value) } };
}
