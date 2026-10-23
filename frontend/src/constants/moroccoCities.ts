// /frontend/src/constants/moroccoCities.ts
// FTM A1 (correction 15) — Villes du Maroc et coordonnees de leur centre.
//
// Sert de solution de secours gratuite quand l'adresse tapee par le client
// ne peut pas etre situee precisement (autorisation de position refusee ou
// adresse introuvable) : on prend alors le centre de la ville choisie.
// Coordonnees issues de GeoNames (geonames.org, licence CC BY 4.0),
// via le paquet all-the-cities 3.1.0.

export type MoroccoCity = { name: string; lat: number; lng: number };

export const MOROCCO_CITIES: MoroccoCity[] = [
  { name: "Agadir", lat: 30.4202, lng: -9.5982 },
  { name: "Al Hoceïma", lat: 35.2516, lng: -3.9372 },
  { name: "Asilah", lat: 35.4652, lng: -6.0342 },
  { name: "Azemmour", lat: 33.2895, lng: -8.3425 },
  { name: "Azrou", lat: 33.4344, lng: -5.2213 },
  { name: "Béni Mellal", lat: 32.3372, lng: -6.3498 },
  { name: "Berkane", lat: 34.9200, lng: -2.3200 },
  { name: "Berrechid", lat: 33.2655, lng: -7.5875 },
  { name: "Bouskoura", lat: 33.4498, lng: -7.6524 },
  { name: "Bouznika", lat: 33.7894, lng: -7.1597 },
  { name: "Casablanca", lat: 33.5883, lng: -7.6114 },
  { name: "Chefchaouen", lat: 35.1688, lng: -5.2636 },
  { name: "Dakhla", lat: 23.6848, lng: -15.9580 },
  { name: "El Jadida", lat: 33.2568, lng: -8.5088 },
  { name: "Errachidia", lat: 31.9314, lng: -4.4266 },
  { name: "Essaouira", lat: 31.5125, lng: -9.7700 },
  { name: "Fès", lat: 34.0331, lng: -5.0003 },
  { name: "Fnideq", lat: 35.8491, lng: -5.3575 },
  { name: "Fquih Ben Salah", lat: 32.5021, lng: -6.6877 },
  { name: "Guelmim", lat: 28.9870, lng: -10.0574 },
  { name: "Guercif", lat: 34.2257, lng: -3.3536 },
  { name: "Ifrane", lat: 33.5267, lng: -5.1102 },
  { name: "Inezgane", lat: 30.3554, lng: -9.5364 },
  { name: "Jerada", lat: 34.3100, lng: -2.1600 },
  { name: "Kasba Tadla", lat: 32.5977, lng: -6.2684 },
  { name: "Kénitra", lat: 34.2610, lng: -6.5802 },
  { name: "Khémisset", lat: 33.8240, lng: -6.0663 },
  { name: "Khénifra", lat: 32.9349, lng: -5.6617 },
  { name: "Khouribga", lat: 32.8811, lng: -6.9063 },
  { name: "Ksar El Kébir", lat: 35.0004, lng: -5.9038 },
  { name: "Laâyoune", lat: 27.1418, lng: -13.1880 },
  { name: "Larache", lat: 35.1932, lng: -6.1557 },
  { name: "M'diq", lat: 35.6831, lng: -5.3287 },
  { name: "Marrakech", lat: 31.6342, lng: -7.9999 },
  { name: "Martil", lat: 35.6166, lng: -5.2752 },
  { name: "Mechra Bel Ksiri", lat: 34.5737, lng: -5.9558 },
  { name: "Meknès", lat: 33.8935, lng: -5.5473 },
  { name: "Midelt", lat: 32.6852, lng: -4.7451 },
  { name: "Mohammedia", lat: 33.6861, lng: -7.3830 },
  { name: "Nador", lat: 35.1681, lng: -2.9335 },
  { name: "Ouarzazate", lat: 30.9189, lng: -6.8934 },
  { name: "Oued Zem", lat: 32.8627, lng: -6.5736 },
  { name: "Ouezzane", lat: 34.7958, lng: -5.5785 },
  { name: "Oujda", lat: 34.6814, lng: -1.9086 },
  { name: "Oulad Teïma", lat: 30.3947, lng: -9.2090 },
  { name: "Rabat", lat: 34.0132, lng: -6.8326 },
  { name: "Safi", lat: 32.2994, lng: -9.2372 },
  { name: "Salé", lat: 34.0531, lng: -6.7985 },
  { name: "Sefrou", lat: 33.8319, lng: -4.8280 },
  { name: "Settat", lat: 33.0010, lng: -7.6166 },
  { name: "Sidi Bennour", lat: 32.6524, lng: -8.4277 },
  { name: "Sidi Kacem", lat: 34.2215, lng: -5.7077 },
  { name: "Sidi Slimane", lat: 34.2648, lng: -5.9260 },
  { name: "Sidi Yahya El Gharb", lat: 34.3049, lng: -6.3040 },
  { name: "Skhirat", lat: 33.8527, lng: -7.0317 },
  { name: "Smara", lat: 26.7384, lng: -11.6719 },
  { name: "Souk El Arbaa", lat: 34.6866, lng: -6.0027 },
  { name: "Tan-Tan", lat: 28.4380, lng: -11.1032 },
  { name: "Tanger", lat: 35.7673, lng: -5.7998 },
  { name: "Taourirt", lat: 34.4073, lng: -2.8973 },
  { name: "Taroudant", lat: 30.4703, lng: -8.8770 },
  { name: "Taza", lat: 34.2100, lng: -4.0100 },
  { name: "Témara", lat: 33.9287, lng: -6.9066 },
  { name: "Tétouan", lat: 35.5784, lng: -5.3684 },
  { name: "Tiflet", lat: 33.8947, lng: -6.3065 },
  { name: "Tit Mellil", lat: 33.5581, lng: -7.4865 },
  { name: "Tiznit", lat: 29.6974, lng: -9.7316 },
  { name: "Youssoufia", lat: 32.2463, lng: -8.5294 },
  { name: "Zagora", lat: 30.3324, lng: -5.8384 },
];

/** Minuscules, sans accents ni apostrophes, pour comparer et rechercher. */
export function normalizeCityName(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[’'`\-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

// Autres orthographes courantes (francaises, anglaises, abregees).
const ALIASES: Record<string, string> = {
  casa: 'Casablanca',
  fes: 'Fès',
  fez: 'Fès',
  marrakesh: 'Marrakech',
  tangier: 'Tanger',
  tangiers: 'Tanger',
  sale: 'Salé',
  kenitra: 'Kénitra',
  temara: 'Témara',
  tetouan: 'Tétouan',
  meknes: 'Meknès',
  'el jadid': 'El Jadida',
  'oujda angad': 'Oujda',
  ouarzazat: 'Ouarzazate',
  laayoune: 'Laâyoune',
  'beni mellal': 'Béni Mellal',
  'sidi qacem': 'Sidi Kacem',
  skhirate: 'Skhirat',
  fnidek: 'Fnideq',
  mdiq: "M'diq",
  chefchaouene: 'Chefchaouen',
};

/** Retrouve une ville de la liste a partir d'un nom (accents et casse ignores). */
export function findCity(name: string | null | undefined): MoroccoCity | null {
  if (!name) return null;
  const n = normalizeCityName(name);
  if (!n) return null;
  const direct = MOROCCO_CITIES.find((c) => normalizeCityName(c.name) === n);
  if (direct) return direct;
  const alias = ALIASES[n];
  return alias ? MOROCCO_CITIES.find((c) => c.name === alias) ?? null : null;
}

/** Distance a vol d'oiseau en km entre deux points. */
export function distanceKm(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number }
): number {
  const R = 6371;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((a.lat * Math.PI) / 180) * Math.cos((b.lat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}
