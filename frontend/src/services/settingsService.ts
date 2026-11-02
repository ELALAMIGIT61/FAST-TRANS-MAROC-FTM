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

// ─── A1 (migrations 073 et 074) : montants et solde, lisibles par tous ─────────
// Les reglages ne sont lisibles que par l'admin ; ces deux fonctions du serveur
// donnent seulement ce que l'application doit afficher.

export type CommissionAmounts = Record<string, number>;

// Montants affiches tant que le serveur n'a pas repondu (valeurs de depart)
export const DEFAULT_COMMISSION_AMOUNTS: CommissionAmounts = { vul: 25, n2_medium: 40, n2_large: 50 };

export async function getCommissionAmounts(): Promise<{ amounts?: CommissionAmounts; error?: string }> {
  const { data, error } = await supabase.rpc('get_commission_amounts');
  if (error) {
    console.log('[FTM-DEBUG] Settings - Commission amounts error', { error: error.message });
    return { error: error.message };
  }
  const amounts: CommissionAmounts = {};
  for (const row of (data ?? []) as { vehicle_category: string; amount: number }[]) {
    amounts[row.vehicle_category] = Number(row.amount);
  }
  return { amounts };
}

export interface MyWalletStatus {
  balance: number;
  engaged: number;
  available: number;
  minimum: number;
  commission: number;
  vehicle_category: string;
  balance_ok: boolean;
}

export async function getMyWalletStatus(): Promise<{ status?: MyWalletStatus | null; error?: string }> {
  const { data, error } = await supabase.rpc('get_my_wallet_status');
  if (error) {
    console.log('[FTM-DEBUG] Wallet - Status error', { error: error.message });
    return { error: error.message };
  }
  const row = Array.isArray(data) ? data[0] : null;
  if (!row) return { status: null };
  return {
    status: {
      balance: Number(row.balance),
      engaged: Number(row.engaged),
      available: Number(row.available),
      minimum: Number(row.minimum),
      commission: Number(row.commission),
      vehicle_category: String(row.vehicle_category),
      balance_ok: row.balance_ok === true,
    },
  };
}

/** Retire le code technique place en tete des messages du serveur (« solde_insuffisant: … »). */
export function cleanServerMessage(message: string): string {
  const m = message.match(/^[a-z_]+:\s*([\s\S]*)$/);
  const text = m ? m[1] : message;
  return text.charAt(0).toUpperCase() + text.slice(1);
}
