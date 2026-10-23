// /frontend/src/services/geocodingService.ts
// FTM A1 (correction 15) — Situer une adresse tapee par le client (gratuit).
//
// Regles validees par le porteur :
// - le GPS du client n'est utilise que s'il touche « Ma position actuelle » ;
// - une adresse tapee est situee a partir du texte (adresse + ville), jamais
//   a partir de la position du client ;
// - si l'adresse ne peut pas etre situee precisement, on propose au client
//   de la corriger ou de continuer avec le centre de la ville choisie.
//
// Sur Android, la recherche d'adresse du telephone exige l'autorisation de
// position (sans utiliser le GPS) : on la demande seulement au moment de
// l'envoi, avec une explication.

import * as Location from 'expo-location';
import { confirmAction } from '../utils/dialogs';
import { findCity, distanceKm } from '../constants/moroccoCities';

// Un resultat a plus de 50 km du centre de la ville choisie est rejete :
// la recherche a trouve une autre rue du meme nom ailleurs.
const MAX_KM_FROM_CITY = 50;

export type GeoPoint = { lat: number; lng: number };

/**
 * Verifie l'autorisation de position, et la demande avec une explication
 * si elle n'a pas encore ete donnee. Renvoie true si elle est accordee.
 */
export async function ensureGeocodingPermission(): Promise<boolean> {
  try {
    const current = await Location.getForegroundPermissionsAsync();
    if (current.granted) return true;
    if (!current.canAskAgain) return false;
    const ok = await confirmAction(
      'Situer vos adresses',
      "Pour situer les adresses que vous avez tapées, l'application a besoin de l'accès à la position. " +
        'Votre GPS ne sera pas utilisé : seules vos adresses sont recherchées.',
      { confirmLabel: 'Continuer', cancelLabel: 'Refuser' }
    );
    if (!ok) return false;
    const res = await Location.requestForegroundPermissionsAsync();
    return res.granted;
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Geocoding - Permission error', { err: message });
    return false;
  }
}

/**
 * Cherche les coordonnees d'une adresse dans une ville. Renvoie null si
 * l'adresse est introuvable ou trop loin de la ville choisie.
 */
export async function geocodeInCity(address: string, city: string): Promise<GeoPoint | null> {
  const center = findCity(city);
  const query = `${address}, ${city}, Maroc`;
  try {
    const results = await Location.geocodeAsync(query);
    for (const r of results ?? []) {
      const point = { lat: r.latitude, lng: r.longitude };
      if (!center || distanceKm(center, point) <= MAX_KM_FROM_CITY) {
        console.log('[FTM-DEBUG] Geocoding - Address found', { query, ...point });
        return point;
      }
    }
    console.log('[FTM-DEBUG] Geocoding - No usable result', { query, count: results?.length ?? 0 });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Geocoding - Error', { query, err: message });
  }
  return null;
}
