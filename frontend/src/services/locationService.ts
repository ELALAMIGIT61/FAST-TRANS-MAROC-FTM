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

  const { status: bgStatus } = await Location.requestBackgroundPermissionsAsync();

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

export async function startBackgroundTracking(driverId: string): Promise<{ success?: boolean; error?: string }> {
  console.log('[FTM-DEBUG] GPS - Starting background tracking', { driverId });

  const perms = await requestLocationPermissions();
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

        await updateDriverLocation(driverId, latitude, longitude);
      }
    );

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
    const location = await Location.getCurrentPositionAsync({
      accuracy: Location.Accuracy.Balanced,
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
