// Lot 5 (C3, validé par le porteur le 13/11/2026) : adresses enregistrées du
// client (« Mes adresses »). Partie serveur : migration 078. Une adresse n'est
// créée qu'à partir d'une mission terminée, à la demande du client ; le point
// précis (lat/lng) n'existe que si le serveur a pu l'apprendre de la position
// du chauffeur. Le client peut renommer ou supprimer une adresse.
import { supabase } from '../lib/supabaseClient';

export interface SavedAddress {
  id: string;
  label: string | null;
  address: string;
  city: string;
  landmark: string | null;
  lat: number | null;
  lng: number | null;
  last_used_at: string;
}

export const SAVED_ADDRESS_LABEL_MAX = 40;

export async function listSavedAddresses(
  clientProfileId: string
): Promise<{ addresses: SavedAddress[]; error?: string }> {
  const { data, error } = await supabase
    .from('client_saved_addresses')
    .select('id, label, address, city, landmark, lat, lng, last_used_at')
    .eq('client_id', clientProfileId)
    .order('last_used_at', { ascending: false });
  if (error) {
    console.log('[FTM-DEBUG] Addresses - List error', { error: error.message });
    return { addresses: [], error: error.message };
  }
  return { addresses: (data as SavedAddress[]) ?? [] };
}

export async function saveMissionAddress(
  missionId: string,
  which: 'pickup' | 'dropoff',
  label?: string
): Promise<{ id?: string; error?: string }> {
  const name = label?.trim() ? label.trim() : null;
  const { data, error } = await supabase.rpc('save_mission_address', {
    p_mission_id: missionId,
    p_which: which,
    p_label: name,
  });
  if (error) {
    console.log('[FTM-DEBUG] Addresses - Save error', { missionId, which, error: error.message });
    return { error: error.message };
  }
  return { id: data as string };
}

export async function renameSavedAddress(id: string, label: string): Promise<{ error?: string }> {
  const name = label.trim() ? label.trim() : null;
  const { error } = await supabase.from('client_saved_addresses').update({ label: name }).eq('id', id);
  if (error) {
    console.log('[FTM-DEBUG] Addresses - Rename error', { id, error: error.message });
    return { error: error.message };
  }
  return {};
}

export async function deleteSavedAddress(id: string): Promise<{ error?: string }> {
  const { error } = await supabase.from('client_saved_addresses').delete().eq('id', id);
  if (error) {
    console.log('[FTM-DEBUG] Addresses - Delete error', { id, error: error.message });
    return { error: error.message };
  }
  return {};
}

// Note la date de dernier usage (sans bloquer la création de la mission)
export async function markSavedAddressUsed(id: string): Promise<void> {
  const { error } = await supabase.rpc('use_saved_address', { p_id: id });
  if (error) console.log('[FTM-DEBUG] Addresses - Mark used error', { id, error: error.message });
}

export function savedAddressTitle(a: SavedAddress): string {
  return a.label ? `${a.label} — ${a.address}` : a.address;
}
