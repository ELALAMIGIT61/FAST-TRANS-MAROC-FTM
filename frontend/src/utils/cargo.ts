// /frontend/src/utils/cargo.ts
// FTM A1 F6 (migration 068) — poids et volume du chargement.
// Charges utiles maximales habituelles par categorie (donnees techniques,
// validees par le porteur) : servent a informer le client et a l'avertir,
// sans jamais bloquer.

export const MAX_LOAD_KG: Record<string, number> = {
  vul: 1500,
  n2_medium: 4500,
  n2_large: 8000,
};

/** « 1,5 t » a partir de 1500 kg. */
export function formatTonnes(kg: number): string {
  return `${String(kg / 1000).replace('.', ',')} t`;
}

/** Lit un nombre saisi (virgule acceptee). Renvoie null si vide, NaN si invalide. */
export function parseQuantity(raw: string): number | null {
  const t = raw.replace(',', '.').trim();
  if (!t) return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : NaN;
}

/** « 800 kg · 6,5 m³ », ou null si rien n'est connu. */
export function formatCargo(weightKg: unknown, volumeM3: unknown): string | null {
  const parts: string[] = [];
  if (weightKg !== null && weightKg !== undefined && weightKg !== '') {
    parts.push(`${Number(weightKg).toLocaleString('fr-FR')} kg`);
  }
  if (volumeM3 !== null && volumeM3 !== undefined && volumeM3 !== '') {
    parts.push(`${String(Number(volumeM3)).replace('.', ',')} m³`);
  }
  return parts.length > 0 ? parts.join(' · ') : null;
}
