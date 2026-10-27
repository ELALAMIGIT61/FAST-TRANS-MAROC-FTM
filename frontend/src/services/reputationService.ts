// /frontend/src/services/reputationService.ts
// FTM A1 F5 (migration 067) — reputation des chauffeurs : moyennes par
// critere, missions realisees, annulations sur une periode reglable, et
// commentaires moderes par l'admin. Toutes les valeurs sont calculees par le
// serveur, qui ne renvoie que ce que l'utilisateur connecte a le droit de voir.

import { supabase } from '../lib/supabaseClient';

export interface DriverReputation {
  driver_id?: string;
  avg_punctuality: number | null;
  avg_care: number | null;
  avg_service: number | null;
  rated_missions: number;
  completed_missions: number;
  cancelled_missions: number;
  cancel_window_months: number;
}

export interface DriverReview {
  driver_id: string;
  review_date: string;
  review: string;
  rating_punctuality: number;
  rating_care: number;
  rating_service: number;
}

export interface ReviewToModerate {
  mission_id: string;
  mission_number: string;
  review_date: string;
  review: string;
  rating_punctuality: number;
  rating_care: number;
  rating_service: number;
  driver_name: string | null;
}

const toNumber = (v: unknown): number | null => (v === null || v === undefined ? null : Number(v));

function normalize(row: Record<string, unknown>): DriverReputation {
  return {
    driver_id: row.driver_id as string | undefined,
    avg_punctuality: toNumber(row.avg_punctuality),
    avg_care: toNumber(row.avg_care),
    avg_service: toNumber(row.avg_service),
    rated_missions: Number(row.rated_missions ?? 0),
    completed_missions: Number(row.completed_missions ?? 0),
    cancelled_missions: Number(row.cancelled_missions ?? 0),
    cancel_window_months: Number(row.cancel_window_months ?? 6),
  };
}

/** Client : reputation des chauffeurs ayant fait une offre sur sa mission. */
export async function getOfferDriverReputation(
  missionId: string
): Promise<{ reputations?: Record<string, DriverReputation>; error?: string }> {
  const { data, error } = await supabase.rpc('get_offer_driver_reputation', {
    p_mission_id: missionId,
  });
  if (error) {
    console.log('[FTM-DEBUG] Reputation - Offer drivers error', { error: error.message });
    return { error: error.message };
  }
  const map: Record<string, DriverReputation> = {};
  ((data ?? []) as Record<string, unknown>[]).forEach((row) => {
    const r = normalize(row);
    if (r.driver_id) map[r.driver_id] = r;
  });
  return { reputations: map };
}

/** Client : 3 derniers commentaires publies de chaque chauffeur (sans nom du client). */
export async function getOfferDriverReviews(
  missionId: string
): Promise<{ reviews?: Record<string, DriverReview[]>; error?: string }> {
  const { data, error } = await supabase.rpc('get_offer_driver_reviews', {
    p_mission_id: missionId,
  });
  if (error) {
    console.log('[FTM-DEBUG] Reputation - Offer reviews error', { error: error.message });
    return { error: error.message };
  }
  const map: Record<string, DriverReview[]> = {};
  ((data ?? []) as DriverReview[]).forEach((r) => {
    (map[r.driver_id] = map[r.driver_id] ?? []).push(r);
  });
  return { reviews: map };
}

/** Chauffeur connecte : sa propre reputation. */
export async function getMyDriverReputation(): Promise<{
  reputation?: DriverReputation | null;
  error?: string;
}> {
  const { data, error } = await supabase.rpc('get_my_driver_reputation');
  if (error) {
    console.log('[FTM-DEBUG] Reputation - Own reputation error', { error: error.message });
    return { error: error.message };
  }
  const row = ((data ?? []) as Record<string, unknown>[])[0];
  return { reputation: row ? normalize(row) : null };
}

/** Admin : commentaires en attente de moderation. */
export async function getReviewsToModerate(): Promise<{
  reviews?: ReviewToModerate[];
  error?: string;
}> {
  const { data, error } = await supabase.rpc('get_reviews_to_moderate');
  if (error) {
    console.log('[FTM-DEBUG] Reputation - Moderation list error', { error: error.message });
    return { error: error.message };
  }
  return { reviews: (data ?? []) as ReviewToModerate[] };
}

/** Admin : publier (true) ou refuser (false) un commentaire. */
export async function moderateReview(
  missionId: string,
  publish: boolean
): Promise<{ success?: boolean; error?: string }> {
  const { data, error } = await supabase.rpc('moderate_review', {
    p_mission_id: missionId,
    p_publish: publish,
  });
  if (error) {
    console.log('[FTM-DEBUG] Reputation - Moderation error', { error: error.message });
    return { error: error.message };
  }
  if (data !== true) return { error: 'Cet avis a déjà été traité.' };
  return { success: true };
}

/** Affichage d'une moyenne : « 4,6 » ou « — » si aucune note. */
export function formatAverage(value: number | null): string {
  return value === null ? '—' : value.toFixed(1).replace('.', ',');
}

export function formatCancellations(r: DriverReputation): string {
  const n = r.cancelled_missions;
  return `${n} annulée${n > 1 ? 's' : ''} (${r.cancel_window_months} derniers mois)`;
}
