/**
 * CALCUL VOLUME CÔTÉ CLIENT (pour preview avant soumission)
 * La valeur réelle est recalculée par PostgreSQL (GENERATED ALWAYS)
 * Ici sert uniquement à l'affichage en temps réel dans le formulaire
 *
 * @returns {number} volume en m³, arrondi à 4 décimales
 */
export function calculateVolume(
  lengthCm: string | number,
  widthCm: string | number,
  heightCm: string | number
): number {
  const l = parseFloat(String(lengthCm)) || 0;
  const w = parseFloat(String(widthCm)) || 0;
  const h = parseFloat(String(heightCm)) || 0;
  if (l <= 0 || w <= 0 || h <= 0) return 0;
  return parseFloat(((l * w * h) / 1_000_000).toFixed(4));
}

/**
 * RECOMMANDER LA CATÉGORIE VÉHICULE selon le volume et poids du colis
 *
 * Logique métier FTM :
 *  - Colis ≤ 0.5 m³ et ≤ 50 kg  → VUL recommandé
 *  - Colis ≤ 2.0 m³ et ≤ 500 kg → N2 Medium recommandé
 *  - Colis > 2.0 m³ ou > 500 kg  → N2 Large recommandé
 */
export function recommendVehicleCategory(
  volumeM3: string | number,
  weightKg: string | number
): 'vul' | 'n2_medium' | 'n2_large' {
  const v = parseFloat(String(volumeM3)) || 0;
  const w = parseFloat(String(weightKg)) || 0;

  if (v <= 0.5 && w <= 50) return 'vul';
  if (v <= 2.0 && w <= 500) return 'n2_medium';
  return 'n2_large';
}

/**
 * FORMATER L'AFFICHAGE DU VOLUME
 * 0.0600 m³  → "60 litres (0.06 m³)"
 * 1.2000 m³  → "1 200 litres (1.20 m³)"
 */
export function formatVolume(volumeM3: number): string {
  const liters = (volumeM3 * 1000).toFixed(0);
  const m3 = volumeM3.toFixed(2);
  return `${parseInt(liters).toLocaleString('fr-MA')} litres (${m3} m³)`;
}

/**
 * VALIDER LES DIMENSIONS (limites raisonnables pour un colis)
 * Retourne un objet d'erreurs ou null si valide
 */
export function validateParcelDimensions(
  lengthCm: string | number,
  widthCm: string | number,
  heightCm: string | number,
  weightKg: string | number
): Record<string, string> | null {
  const errors: Record<string, string> = {};

  if (parseFloat(String(lengthCm)) > 300) errors.length = 'Longueur max : 300 cm';
  if (parseFloat(String(widthCm)) > 250) errors.width = 'Largeur max : 250 cm';
  if (parseFloat(String(heightCm)) > 250) errors.height = 'Hauteur max : 250 cm';
  if (parseFloat(String(weightKg)) > 5000) errors.weight = 'Poids max : 5 000 kg';

  if (parseFloat(String(lengthCm)) <= 0) errors.length = 'Longueur requise';
  if (parseFloat(String(widthCm)) <= 0) errors.width = 'Largeur requise';
  if (parseFloat(String(heightCm)) <= 0) errors.height = 'Hauteur requise';
  if (parseFloat(String(weightKg)) <= 0) errors.weight = 'Poids requis';

  return Object.keys(errors).length > 0 ? errors : null;
}

/**
 * FORMATER UN NUMÉRO DE TÉLÉPHONE MAROCAIN pour l'affichage
 * "+212612345678" → "06 12 34 56 78"
 */
export function formatPhoneDisplay(phone: string): string {
  const cleaned = phone.replace('+212', '0').replace(/\s/g, '');
  return cleaned.replace(/(\d{2})(?=\d)/g, '$1 ').trim();
}

/**
 * MASQUER UN NUMÉRO DE TÉLÉPHONE pour affichage public
 * "0612345678" → "06****78"
 */
export function maskPhone(phone: string): string {
  if (!phone || phone.length < 6) return '****';
  return phone.slice(0, 3) + '****' + phone.slice(-2);
}
