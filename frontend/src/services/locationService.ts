import * as Location from 'expo-location';
import { supabase } from '../lib/supabaseClient';

export async function requestLocationPermissions(): Promise<{
  granted: boolean;
  backgroundGranted?: boolean;
  error?: string;
  warning?: string;
}> {
  console.log('[FTM-DEBUG] GPS - Requesting location permissions');

  const { status: fgStatus } = await Location.requestForegroundPermissionsAsync();

  if (fgStatus !== 'granted') {
    console.log('[FTM-DEBUG] GPS - Foreground permission denied', { status: fgStatus });
    return {
      granted: false,
      error: 'Permission de localisation refusée. Activez-la dans les réglages.',
    };
  }

  console.log('[FTM-DEBUG] GPS - Foreground permission granted');

  // A1 (correction 10) : sans declaration de la position en arriere-plan dans
  // app.json, Android refuse la demande par une erreur (et non par un refus).
  // On la traite comme un refus : le suivi continue pendant l'utilisation.
  let bgStatus: string = 'denied';
  try {
    const bg = await Location.requestBackgroundPermissionsAsync();
    bgStatus = bg.status;
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] GPS - Background permission unavailable', { err: message });
  }

  if (bgStatus !== 'granted') {
    console.log('[FTM-DEBUG] GPS - Background permission denied', { status: bgStatus });
    return {
      granted: true,
      backgroundGranted: false,
      warning: "Tracking arrière-plan non autorisé. Gardez l'app ouverte pendant les missions.",
    };
  }

  console.log('[FTM-DEBUG] GPS - Background permission granted (full tracking active)');
  return { granted: true, backgroundGranted: true };
}

const TRACKING_CONFIG: Location.LocationOptions = {
  accuracy: Location.Accuracy.High,
  timeInterval: 15000,
  distanceInterval: 50,
};

let locationSubscription: Location.LocationSubscription | null = null;

// A1 (correction 25) : le serveur n'envoie une mission qu'aux chauffeurs dont la
// position date de moins de 5 minutes, or le suivi n'envoie la position qu'apres
// un deplacement de 50 m : un chauffeur disponible mais immobile devenait
// invisible. Tant que le suivi est actif, la position est renvoyee toutes les
// 2 minutes, meme sans deplacement.
const HEARTBEAT_MS = 2 * 60 * 1000;
let heartbeatTimer: ReturnType<typeof setInterval> | null = null;
let lastCoords: { latitude: number; longitude: number } | null = null;

export async function startBackgroundTracking(driverId: string): Promise<{ success?: boolean; error?: string }> {
  console.log('[FTM-DEBUG] GPS - Starting background tracking', { driverId });

  // A1 (correction 10) : une erreur inattendue renvoie un message au lieu de
  // tout arreter en silence.
  let perms: Awaited<ReturnType<typeof requestLocationPermissions>>;
  try {
    perms = await requestLocationPermissions();
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] GPS - Permission request error', { err: message });
    return { error: "Impossible d'activer la localisation. Réessayez." };
  }
  if (!perms.granted) {
    console.log('[FTM-DEBUG] GPS - Cannot start tracking: permissions denied');
    return { error: perms.error };
  }

  await stopBackgroundTracking();

  try {
    locationSubscription = await Location.watchPositionAsync(
      TRACKING_CONFIG,
      async (location) => {
        const { latitude, longitude, accuracy } = location.coords;

        console.log('[FTM-DEBUG] GPS - Position update', {
          driverId,
          lat: latitude,
          lng: longitude,
          accuracy: Math.round(accuracy ?? 0) + 'm',
          timestamp: new Date(location.timestamp).toISOString(),
        });

        lastCoords = { latitude, longitude };
        await updateDriverLocation(driverId, latitude, longitude);
      }
    );

    heartbeatTimer = setInterval(async () => {
      let coords = lastCoords;
      try {
        const current = await Location.getCurrentPositionAsync({
          accuracy: Location.Accuracy.Balanced,
        });
        coords = { latitude: current.coords.latitude, longitude: current.coords.longitude };
        lastCoords = coords;
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        console.log('[FTM-DEBUG] GPS - Heartbeat position error, last known used', { err: message });
      }
      if (!coords) return;
      console.log('[FTM-DEBUG] GPS - Heartbeat', { driverId });
      await updateDriverLocation(driverId, coords.latitude, coords.longitude);
    }, HEARTBEAT_MS);

    console.log('[FTM-DEBUG] GPS - Background tracking started successfully', {
      driverId,
      interval: '15s',
      distance: '50m',
    });

    return { success: true };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] GPS - Start tracking error', { err: message });
    return { error: message };
  }
}

export async function stopBackgroundTracking(): Promise<void> {
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
  lastCoords = null;
  if (locationSubscription) {
    locationSubscription.remove();
    locationSubscription = null;
    console.log('[FTM-DEBUG] GPS - Background tracking stopped');
  }
}

async function updateDriverLocation(driverId: string, latitude: number, longitude: number): Promise<void> {
  const { error } = await supabase
    .from('drivers')
    .update({
      current_location: `POINT(${longitude} ${latitude})`,
      last_location_update: new Date().toISOString(),
    })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] GPS - Location update error', {
      driverId,
      error: error.message,
    });
  }
}

export async function getClientCurrentLocation(): Promise<{
  success?: boolean;
  latitude?: number;
  longitude?: number;
  error?: string;
}> {
  console.log('[FTM-DEBUG] GPS - Getting client current location');

  const { status } = await Location.requestForegroundPermissionsAsync();
  if (status !== 'granted') {
    console.log('[FTM-DEBUG] GPS - Client location permission denied');
    return { error: 'Activez la localisation pour trouver des chauffeurs proches.' };
  }

  try {
    // Session 3.4 : haute precision (GPS) pour le point de depart d'une mission ;
    // la precision « equilibree » se contentait souvent du quartier.
    const location = await Location.getCurrentPositionAsync({
      accuracy: Location.Accuracy.High,
    });

    const { latitude, longitude } = location.coords;

    console.log('[FTM-DEBUG] GPS - Client location obtained', {
      lat: latitude,
      lng: longitude,
    });

    return { success: true, latitude, longitude };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] GPS - Get location error', { err: message });
    return { error: "Impossible d'obtenir votre position. Réessayez." };
  }
}

export async function reverseGeocode(
  latitude: number,
  longitude: number
): Promise<{ address: string; city: string }> {
  console.log('[FTM-DEBUG] GPS - Reverse geocoding', { latitude, longitude });

  try {
    const result = await Location.reverseGeocodeAsync({ latitude, longitude });

    if (result && result.length > 0) {
      const place = result[0];
      const address = [
        place.streetNumber,
        place.street,
        place.district,
        place.city,
      ]
        .filter(Boolean)
        .join(', ');

      console.log('[FTM-DEBUG] GPS - Address resolved', { address, city: place.city });
      return { address, city: place.city ?? '' };
    }

    return { address: `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`, city: '' };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] GPS - Reverse geocode error', { err: message });
    return { address: `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`, city: '' };
  }
}
