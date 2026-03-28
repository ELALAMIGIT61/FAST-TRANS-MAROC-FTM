#!/bin/bash

mkdir -p frontend/src/services
cat > frontend/src/services/locationService.ts << 'ENDOFFILE'
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
ENDOFFILE

cat > frontend/src/services/missionService.ts << 'ENDOFFILE'
import { supabase } from '../lib/supabaseClient';

export type VehicleCategory = 'vul' | 'n2_medium' | 'n2_large';
export type MissionType = 'transport' | 'ecommerce_parcel';
export type MissionStatus =
  | 'pending'
  | 'accepted'
  | 'in_progress'
  | 'completed'
  | 'cancelled_client'
  | 'cancelled_driver';

export interface CreateMissionData {
  mission_type?: MissionType;
  vehicle_category: VehicleCategory;
  pickup_lat: number;
  pickup_lng: number;
  pickup_address: string;
  pickup_city: string;
  dropoff_lat: number;
  dropoff_lng: number;
  dropoff_address: string;
  dropoff_city: string;
  description?: string;
  needs_loading_help?: boolean;
  negotiated_price?: number;
  client_notes?: string;
}

export interface Mission {
  id: string;
  mission_number: string;
  client_id: string | null;
  driver_id: string | null;
  mission_type: MissionType;
  vehicle_category: VehicleCategory;
  pickup_address: string;
  pickup_city: string;
  dropoff_address: string;
  dropoff_city: string;
  estimated_distance_km: number | null;
  description: string | null;
  needs_loading_help: boolean;
  negotiated_price: number | null;
  commission_amount: number | null;
  payment_method: string;
  status: MissionStatus;
  scheduled_pickup_time: string | null;
  actual_pickup_time: string | null;
  actual_dropoff_time: string | null;
  client_notes: string | null;
  driver_notes: string | null;
  client_rating: number | null;
  driver_rating: number | null;
  client_review: string | null;
  created_at: string;
  updated_at: string;
  completed_at: string | null;
}

export interface NearbyDriver {
  id: string;
  full_name: string;
  phone_number: string;
  vehicle_category: VehicleCategory;
  vehicle_brand: string;
  vehicle_model: string;
  license_plate: string;
  rating_average: number;
  total_missions: number;
  distance_km: number;
  last_location_update: string;
}

export async function createMission(
  clientProfileId: string,
  missionData: CreateMissionData
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  console.log('[FTM-DEBUG] Mission - Creating mission', {
    clientId: clientProfileId,
    vehicleCategory: missionData.vehicle_category,
    pickupCity: missionData.pickup_city,
    dropoffCity: missionData.dropoff_city,
    needsLoading: missionData.needs_loading_help,
    missionType: missionData.mission_type,
  });

  const { data, error } = await supabase
    .from('missions')
    .insert({
      client_id: clientProfileId,
      mission_type: missionData.mission_type ?? 'transport',
      vehicle_category: missionData.vehicle_category,
      pickup_location: `POINT(${missionData.pickup_lng} ${missionData.pickup_lat})`,
      pickup_address: missionData.pickup_address,
      pickup_city: missionData.pickup_city,
      dropoff_location: `POINT(${missionData.dropoff_lng} ${missionData.dropoff_lat})`,
      dropoff_address: missionData.dropoff_address,
      dropoff_city: missionData.dropoff_city,
      description: missionData.description ?? null,
      needs_loading_help: missionData.needs_loading_help ?? false,
      negotiated_price: missionData.negotiated_price ?? null,
      client_notes: missionData.client_notes ?? null,
      payment_method: 'cash',
      status: 'pending',
    })
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Creation error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Mission - Created successfully', {
    missionId: data.id,
    missionNumber: data.mission_number,
    commission: data.commission_amount,
    distanceKm: data.estimated_distance_km,
    status: data.status,
  });

  return { success: true, mission: data as Mission };
}

export async function findNearbyDrivers(
  clientLat: number,
  clientLng: number,
  vehicleCategory: VehicleCategory,
  radiusKm = 15
): Promise<{ success?: boolean; drivers?: NearbyDriver[]; error?: string }> {
  console.log('[FTM-DEBUG] GPS - Searching nearby drivers', {
    clientLat,
    clientLng,
    vehicleCategory,
    radiusKm,
  });

  const radiusMeters = radiusKm * 1000;
  const clientPoint = `POINT(${clientLng} ${clientLat})`;

  const { data, error } = await supabase.rpc('find_nearby_drivers', {
    client_point: clientPoint,
    radius_meters: radiusMeters,
    p_vehicle_category: vehicleCategory,
  });

  if (error) {
    console.log('[FTM-DEBUG] GPS - Find nearby drivers error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] GPS - Nearby drivers found', {
    count: data?.length ?? 0,
    vehicleCategory,
    radiusKm,
    drivers: (data as NearbyDriver[])?.map((d) => ({
      driverId: d.id,
      name: d.full_name,
      distanceKm: d.distance_km,
      rating: d.rating_average,
    })),
  });

  return { success: true, drivers: (data as NearbyDriver[]) ?? [] };
}

export async function acceptMission(
  missionId: string,
  driverId: string
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  console.log('[FTM-DEBUG] Mission - Driver accepting mission', { missionId, driverId });

  const { data, error } = await supabase
    .from('missions')
    .update({
      driver_id: driverId,
      status: 'accepted',
    })
    .eq('id', missionId)
    .eq('status', 'pending')
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Accept error', { error: error.message });
    return { error: error.message };
  }

  if (!data) {
    console.log('[FTM-DEBUG] Mission - Accept failed: mission already taken', { missionId });
    return { error: 'Cette mission a déjà été acceptée par un autre chauffeur.' };
  }

  console.log('[FTM-DEBUG] Mission - Accepted successfully', {
    missionId: data.id,
    missionNumber: data.mission_number,
    driverId: data.driver_id,
    status: data.status,
  });

  return { success: true, mission: data as Mission };
}

export async function startMission(
  missionId: string,
  driverId: string
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  console.log('[FTM-DEBUG] Mission - Starting mission', { missionId, driverId });

  const { data, error } = await supabase
    .from('missions')
    .update({
      status: 'in_progress',
      actual_pickup_time: new Date().toISOString(),
    })
    .eq('id', missionId)
    .eq('driver_id', driverId)
    .eq('status', 'accepted')
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Start error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Mission - Started', {
    missionId,
    pickupTime: data.actual_pickup_time,
  });

  return { success: true, mission: data as Mission };
}

export async function completeMission(
  missionId: string,
  driverId: string,
  driverNotes?: string
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  console.log('[FTM-DEBUG] Mission - Completing mission', { missionId, driverId });

  const { data, error } = await supabase
    .from('missions')
    .update({
      status: 'completed',
      actual_dropoff_time: new Date().toISOString(),
      completed_at: new Date().toISOString(),
      driver_notes: driverNotes ?? null,
    })
    .eq('id', missionId)
    .eq('driver_id', driverId)
    .eq('status', 'in_progress')
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Complete error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Mission - Completed successfully', {
    missionId: data.id,
    missionNumber: data.mission_number,
    commission: data.commission_amount,
    dropoffTime: data.actual_dropoff_time,
  });

  return { success: true, mission: data as Mission };
}

export async function cancelMission(
  missionId: string,
  _userId: string,
  cancelledBy: 'client' | 'driver'
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  const newStatus: MissionStatus =
    cancelledBy === 'client' ? 'cancelled_client' : 'cancelled_driver';

  console.log('[FTM-DEBUG] Mission - Cancelling mission', {
    missionId,
    cancelledBy,
    newStatus,
  });

  const { data, error } = await supabase
    .from('missions')
    .update({ status: newStatus })
    .eq('id', missionId)
    .in('status', ['pending', 'accepted'])
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Cancel error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Mission - Cancelled', {
    missionId,
    status: data.status,
  });

  return { success: true, mission: data as Mission };
}

export async function submitClientRating(
  missionId: string,
  rating: number,
  review?: string
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  console.log('[FTM-DEBUG] Mission - Submitting client rating', {
    missionId,
    rating,
    hasReview: !!review,
  });

  const { data, error } = await supabase
    .from('missions')
    .update({
      client_rating: rating,
      client_review: review ?? null,
    })
    .eq('id', missionId)
    .eq('status', 'completed')
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Rating error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Mission - Rating submitted', {
    missionId,
    rating,
  });

  return { success: true, mission: data as Mission };
}
ENDOFFILE

cat > frontend/src/services/realtimeService.ts << 'ENDOFFILE'
import { supabase } from '../lib/supabaseClient';
import type { RealtimeChannel } from '@supabase/supabase-js';

export function subscribeToMissionUpdates(
  missionId: string,
  onUpdate: (mission: Record<string, unknown>) => void
): RealtimeChannel {
  console.log('[FTM-DEBUG] Realtime - Subscribing to mission updates', { missionId });

  const channel = supabase
    .channel(`mission-${missionId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'missions',
        filter: `id=eq.${missionId}`,
      },
      (payload) => {
        console.log('[FTM-DEBUG] Realtime - Mission update received', {
          missionId,
          oldStatus: (payload.old as Record<string, unknown>).status,
          newStatus: (payload.new as Record<string, unknown>).status,
          driverId: (payload.new as Record<string, unknown>).driver_id,
        });
        onUpdate(payload.new as Record<string, unknown>);
      }
    )
    .subscribe((status) => {
      console.log('[FTM-DEBUG] Realtime - Mission subscription status', { missionId, status });
    });

  return channel;
}

export function subscribeToNewMissions(
  vehicleCategory: string,
  _driverLocation: { lat: number; lng: number } | null,
  onNewMission: (mission: Record<string, unknown>) => void
): RealtimeChannel {
  console.log('[FTM-DEBUG] Realtime - Subscribing to new missions', { vehicleCategory });

  const channel = supabase
    .channel(`new-missions-${vehicleCategory}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'missions',
        filter: `vehicle_category=eq.${vehicleCategory}`,
      },
      (payload) => {
        const mission = payload.new as Record<string, unknown>;
        console.log('[FTM-DEBUG] Realtime - New mission received', {
          missionId: mission.id,
          missionNumber: mission.mission_number,
          pickupCity: mission.pickup_city,
          dropoffCity: mission.dropoff_city,
          commission: mission.commission_amount,
        });
        onNewMission(mission);
      }
    )
    .subscribe();

  return channel;
}

export function subscribeToDriverLocation(
  driverId: string,
  onLocationUpdate: (driver: Record<string, unknown>) => void
): RealtimeChannel {
  console.log('[FTM-DEBUG] Realtime - Subscribing to driver location', { driverId });

  const channel = supabase
    .channel(`driver-location-${driverId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'drivers',
        filter: `id=eq.${driverId}`,
      },
      (payload) => {
        console.log('[FTM-DEBUG] Realtime - Driver location update', {
          driverId,
          lastUpdate: (payload.new as Record<string, unknown>).last_location_update,
        });
        onLocationUpdate(payload.new as Record<string, unknown>);
      }
    )
    .subscribe();

  return channel;
}

export async function unsubscribeChannel(channel: RealtimeChannel | null): Promise<void> {
  if (channel) {
    await supabase.removeChannel(channel);
    console.log('[FTM-DEBUG] Realtime - Channel unsubscribed');
  }
}
ENDOFFILE

mkdir -p frontend/src/screens/client
cat > frontend/src/screens/client/CreateMissionScreen.tsx << 'ENDOFFILE'
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Switch,
  ActivityIndicator,
  StyleSheet,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { COLORS, FONTS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { getClientCurrentLocation, reverseGeocode } from '../../services/locationService';
import { createMission, VehicleCategory } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type RootStackParamList = {
  CreateMission: { clientProfileId: string };
  MissionTracking: { mission: Record<string, unknown> };
};

type Props = NativeStackScreenProps<RootStackParamList, 'CreateMission'>;

const VEHICLE_OPTIONS: { key: VehicleCategory; label: string; commission: number; icon: string }[] = [
  { key: 'vul', label: 'VUL', commission: 25, icon: '🚐' },
  { key: 'n2_medium', label: 'N2 Moyen', commission: 40, icon: '🚛' },
  { key: 'n2_large', label: 'N2 Grand', commission: 50, icon: '🚚' },
];

export default function CreateMissionScreen({ route, navigation }: Props) {
  const { clientProfileId } = route.params;

  const [pickupCoords, setPickupCoords] = useState<{ lat: number; lng: number } | null>(null);
  const [pickupAddress, setPickupAddress] = useState('');
  const [pickupCity, setPickupCity] = useState('');
  const [dropoffAddress, setDropoffAddress] = useState('');
  const [dropoffCity, setDropoffCity] = useState('');
  const [dropoffCoords] = useState<{ lat: number; lng: number } | null>(null);
  const [vehicleCategory, setVehicleCategory] = useState<VehicleCategory | null>(null);
  const [needsLoading, setNeedsLoading] = useState(false);
  const [description, setDescription] = useState('');
  const [negotiatedPrice, setNegotiatedPrice] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isLocating, setIsLocating] = useState(false);

  const locateClient = useCallback(async () => {
    setIsLocating(true);
    const result = await getClientCurrentLocation();
    if (result.success && result.latitude && result.longitude) {
      setPickupCoords({ lat: result.latitude, lng: result.longitude });
      const geo = await reverseGeocode(result.latitude, result.longitude);
      setPickupAddress(geo.address);
      setPickupCity(geo.city);
    } else {
      Alert.alert('Localisation', result.error ?? 'Erreur inconnue');
    }
    setIsLocating(false);
  }, []);

  useEffect(() => {
    locateClient();
  }, [locateClient]);

  const selectedVehicle = VEHICLE_OPTIONS.find((v) => v.key === vehicleCategory);
  const canSubmit = !!pickupCoords && !!dropoffAddress && !!vehicleCategory && !isLoading;

  const handleSubmit = async () => {
    if (!canSubmit || !pickupCoords) return;
    setIsLoading(true);

    const result = await createMission(clientProfileId, {
      vehicle_category: vehicleCategory!,
      pickup_lat: pickupCoords.lat,
      pickup_lng: pickupCoords.lng,
      pickup_address: pickupAddress,
      pickup_city: pickupCity,
      dropoff_lat: dropoffCoords?.lat ?? pickupCoords.lat,
      dropoff_lng: dropoffCoords?.lng ?? pickupCoords.lng,
      dropoff_address: dropoffAddress,
      dropoff_city: dropoffCity,
      description: description || undefined,
      needs_loading_help: needsLoading,
      negotiated_price: negotiatedPrice ? parseFloat(negotiatedPrice) : undefined,
    });

    setIsLoading(false);

    if (result.error) {
      Alert.alert('Erreur', result.error);
    } else if (result.mission) {
      navigation.replace('MissionTracking', { mission: result.mission as unknown as Record<string, unknown> });
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.flex}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        <Text style={styles.title}>Nouvelle mission</Text>

        {/* DÉPART */}
        <Text style={styles.sectionLabel}>📍 DÉPART</Text>
        <TouchableOpacity style={styles.gpsButton} onPress={locateClient} disabled={isLocating}>
          {isLocating ? (
            <ActivityIndicator color={COLORS.primary} />
          ) : (
            <Text style={styles.gpsButtonText}>🎯 Ma position actuelle</Text>
          )}
        </TouchableOpacity>
        <TextInput
          style={styles.input}
          value={pickupAddress}
          onChangeText={setPickupAddress}
          placeholder="Adresse de départ"
          placeholderTextColor={COLORS.textSecondary}
        />

        {/* ARRIVÉE */}
        <Text style={styles.sectionLabel}>🏁 ARRIVÉE</Text>
        <TextInput
          style={styles.input}
          value={dropoffAddress}
          onChangeText={setDropoffAddress}
          placeholder="Adresse de livraison"
          placeholderTextColor={COLORS.textSecondary}
        />
        <TextInput
          style={styles.input}
          value={dropoffCity}
          onChangeText={setDropoffCity}
          placeholder="Ville d'arrivée"
          placeholderTextColor={COLORS.textSecondary}
        />

        {/* VÉHICULE */}
        <Text style={styles.sectionLabel}>VÉHICULE</Text>
        <View style={styles.vehicleRow}>
          {VEHICLE_OPTIONS.map((v) => (
            <TouchableOpacity
              key={v.key}
              style={[styles.vehicleCard, vehicleCategory === v.key && styles.vehicleCardActive]}
              onPress={() => setVehicleCategory(v.key)}
            >
              <Text style={styles.vehicleIcon}>{v.icon}</Text>
              <Text style={[styles.vehicleLabel, vehicleCategory === v.key && styles.vehicleLabelActive]}>
                {v.label}
              </Text>
              <Text style={[styles.vehicleCommission, vehicleCategory === v.key && styles.vehicleCommissionActive]}>
                {v.commission} DH
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* OPTIONS */}
        <Text style={styles.sectionLabel}>OPTIONS</Text>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>💪 Manutention nécessaire</Text>
          <Switch
            value={needsLoading}
            onValueChange={setNeedsLoading}
            trackColor={{ false: COLORS.border, true: COLORS.primary }}
            thumbColor={needsLoading ? '#fff' : '#f4f3f4'}
          />
        </View>
        <TextInput
          style={[styles.input, styles.textArea]}
          value={description}
          onChangeText={setDescription}
          placeholder="Description du chargement (optionnel)"
          placeholderTextColor={COLORS.textSecondary}
          multiline
          numberOfLines={3}
        />
        <TextInput
          style={styles.input}
          value={negotiatedPrice}
          onChangeText={setNegotiatedPrice}
          placeholder="Prix proposé en DH (optionnel)"
          placeholderTextColor={COLORS.textSecondary}
          keyboardType="numeric"
        />

        {/* RÉSUMÉ */}
        {selectedVehicle && (
          <View style={styles.summaryBox}>
            <Text style={styles.summaryText}>
              Commission : <Text style={styles.summaryHighlight}>{selectedVehicle.commission} DH</Text>
            </Text>
          </View>
        )}

        <TouchableOpacity
          style={[styles.submitButton, !canSubmit && styles.submitButtonDisabled]}
          onPress={handleSubmit}
          disabled={!canSubmit}
        >
          {isLoading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.submitButtonText}>Trouver un chauffeur</Text>
          )}
        </TouchableOpacity>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: COLORS.background },
  container: { flex: 1 },
  content: { padding: SPACING.md, paddingBottom: 40 },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: SPACING.lg,
  },
  sectionLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: COLORS.textSecondary,
    letterSpacing: 1,
    marginTop: SPACING.md,
    marginBottom: SPACING.sm,
  },
  gpsButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.sm,
    borderRadius: BORDER_RADIUS.md,
    backgroundColor: COLORS.primary + '15',
    marginBottom: SPACING.sm,
    minHeight: 44,
  },
  gpsButtonText: { color: COLORS.primary, fontWeight: '600', fontSize: 15 },
  input: {
    backgroundColor: COLORS.surface,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
    color: COLORS.text,
    fontSize: 15,
    marginBottom: SPACING.sm,
  },
  textArea: { minHeight: 80, textAlignVertical: 'top' },
  vehicleRow: { flexDirection: 'row', gap: SPACING.sm, marginBottom: SPACING.sm },
  vehicleCard: {
    flex: 1,
    alignItems: 'center',
    padding: SPACING.sm,
    borderRadius: BORDER_RADIUS.md,
    borderWidth: 2,
    borderColor: COLORS.border,
    backgroundColor: COLORS.surface,
  },
  vehicleCardActive: {
    borderColor: COLORS.primary,
    backgroundColor: COLORS.primary + '10',
  },
  vehicleIcon: { fontSize: 24, marginBottom: 4 },
  vehicleLabel: { fontSize: 12, fontWeight: '600', color: COLORS.textSecondary },
  vehicleLabelActive: { color: COLORS.primary },
  vehicleCommission: { fontSize: 13, fontWeight: '700', color: COLORS.text, marginTop: 2 },
  vehicleCommissionActive: { color: COLORS.primary },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: SPACING.sm,
    paddingVertical: SPACING.xs,
  },
  toggleLabel: { fontSize: 15, color: COLORS.text, flex: 1 },
  summaryBox: {
    backgroundColor: COLORS.primary + '10',
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
    marginVertical: SPACING.sm,
    alignItems: 'center',
  },
  summaryText: { fontSize: 15, color: COLORS.text },
  summaryHighlight: { fontWeight: '700', color: COLORS.primary },
  submitButton: {
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    marginTop: SPACING.md,
    minHeight: 52,
    justifyContent: 'center',
  },
  submitButtonDisabled: { opacity: 0.5 },
  submitButtonText: { color: '#fff', fontSize: 17, fontWeight: '700' },
});
ENDOFFILE

cat > frontend/src/screens/client/MissionTrackingScreen.tsx << 'ENDOFFILE'
import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Linking,
  Alert,
} from 'react-native';
import type { RealtimeChannel } from '@supabase/supabase-js';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import {
  subscribeToMissionUpdates,
  subscribeToDriverLocation,
  unsubscribeChannel,
} from '../../services/realtimeService';
import { cancelMission } from '../../services/missionService';
import type { Mission } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type RootStackParamList = {
  MissionTracking: { mission: Record<string, unknown> };
  Rating: { mission: Record<string, unknown> };
  CreateMission: { clientProfileId: string };
};

type Props = NativeStackScreenProps<RootStackParamList, 'MissionTracking'>;

export default function MissionTrackingScreen({ route, navigation }: Props) {
  const initialMission = route.params.mission as unknown as Mission;
  const [mission, setMission] = useState<Mission>(initialMission);
  const missionChannelRef = useRef<RealtimeChannel | null>(null);
  const locationChannelRef = useRef<RealtimeChannel | null>(null);

  const handleMissionUpdate = useCallback(
    (updated: Record<string, unknown>) => {
      const updatedMission = updated as unknown as Mission;
      setMission(updatedMission);

      if (updatedMission.status === 'completed') {
        setTimeout(() => {
          navigation.replace('Rating', { mission: updated });
        }, 2000);
      }
    },
    [navigation]
  );

  useEffect(() => {
    missionChannelRef.current = subscribeToMissionUpdates(
      mission.id,
      handleMissionUpdate
    );

    return () => {
      unsubscribeChannel(missionChannelRef.current);
      unsubscribeChannel(locationChannelRef.current);
    };
  }, [mission.id, handleMissionUpdate]);

  useEffect(() => {
    if (mission.driver_id && !locationChannelRef.current) {
      locationChannelRef.current = subscribeToDriverLocation(
        mission.driver_id,
        (driver) => {
          console.log('[FTM-DEBUG] Realtime - Driver location update received', driver);
        }
      );
    }
  }, [mission.driver_id]);

  const handleCancel = async () => {
    Alert.alert('Annuler la mission', 'Êtes-vous sûr de vouloir annuler ?', [
      { text: 'Non', style: 'cancel' },
      {
        text: 'Oui, annuler',
        style: 'destructive',
        onPress: async () => {
          const result = await cancelMission(mission.id, mission.client_id ?? '', 'client');
          if (result.error) Alert.alert('Erreur', result.error);
        },
      },
    ]);
  };

  const callDriver = () => {
    Linking.openURL(`tel:${(mission as unknown as Record<string, unknown>).driver_phone ?? ''}`);
  };

  const renderStatus = () => {
    switch (mission.status) {
      case 'pending':
        return (
          <View style={styles.statusContainer}>
            <ActivityIndicator size="large" color={COLORS.primary} />
            <Text style={styles.statusTitle}>Recherche d'un chauffeur...</Text>
            <Text style={styles.missionNumber}>N° {mission.mission_number}</Text>
            <View style={styles.addressCard}>
              <Text style={styles.addressLabel}>📍 Départ</Text>
              <Text style={styles.addressText}>{mission.pickup_address}</Text>
              <Text style={styles.addressLabel}>🏁 Arrivée</Text>
              <Text style={styles.addressText}>{mission.dropoff_address}</Text>
            </View>
            {mission.estimated_distance_km && (
              <Text style={styles.distanceText}>
                Distance estimée : ~{mission.estimated_distance_km} km
              </Text>
            )}
            <TouchableOpacity style={styles.cancelButton} onPress={handleCancel}>
              <Text style={styles.cancelButtonText}>Annuler</Text>
            </TouchableOpacity>
          </View>
        );

      case 'accepted':
        return (
          <View style={styles.statusContainer}>
            <Text style={styles.successIcon}>✅</Text>
            <Text style={styles.statusTitle}>Chauffeur trouvé !</Text>
            <View style={styles.driverCard}>
              <Text style={styles.driverName}>Chauffeur assigné</Text>
              <Text style={styles.driverInfo}>Mission N° {mission.mission_number}</Text>
            </View>
            <TouchableOpacity style={styles.callButton} onPress={callDriver}>
              <Text style={styles.callButtonText}>📞 Appeler le chauffeur</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.cancelButton} onPress={handleCancel}>
              <Text style={styles.cancelButtonText}>Annuler</Text>
            </TouchableOpacity>
          </View>
        );

      case 'in_progress':
        return (
          <View style={styles.statusContainer}>
            <Text style={styles.statusIcon}>🚚</Text>
            <Text style={styles.statusTitle}>Mission en cours</Text>
            <View style={styles.addressCard}>
              <Text style={styles.addressLabel}>🏁 Destination</Text>
              <Text style={styles.addressText}>{mission.dropoff_address}</Text>
            </View>
          </View>
        );

      case 'completed':
        return (
          <View style={styles.statusContainer}>
            <Text style={styles.successIcon}>✅</Text>
            <Text style={styles.statusTitle}>Mission terminée !</Text>
            <Text style={styles.subText}>Redirection vers l'évaluation...</Text>
          </View>
        );

      case 'cancelled_driver':
        return (
          <View style={styles.statusContainer}>
            <Text style={styles.errorIcon}>❌</Text>
            <Text style={styles.statusTitle}>Mission annulée par le chauffeur</Text>
            <TouchableOpacity
              style={styles.primaryButton}
              onPress={() => navigation.replace('CreateMission', { clientProfileId: mission.client_id ?? '' })}
            >
              <Text style={styles.primaryButtonText}>Créer une nouvelle mission</Text>
            </TouchableOpacity>
          </View>
        );

      default:
        return null;
    }
  };

  return <View style={styles.container}>{renderStatus()}</View>;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
    justifyContent: 'center',
    padding: SPACING.lg,
  },
  statusContainer: { alignItems: 'center', gap: SPACING.md },
  statusTitle: {
    fontSize: 22,
    fontWeight: '700',
    color: COLORS.text,
    textAlign: 'center',
  },
  missionNumber: { fontSize: 14, color: COLORS.textSecondary },
  statusIcon: { fontSize: 48 },
  successIcon: { fontSize: 48 },
  errorIcon: { fontSize: 48 },
  addressCard: {
    width: '100%',
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    gap: SPACING.xs,
  },
  addressLabel: { fontSize: 12, fontWeight: '700', color: COLORS.textSecondary, letterSpacing: 1 },
  addressText: { fontSize: 15, color: COLORS.text, marginBottom: SPACING.xs },
  distanceText: { fontSize: 14, color: COLORS.textSecondary },
  driverCard: {
    width: '100%',
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
    gap: SPACING.xs,
  },
  driverName: { fontSize: 18, fontWeight: '700', color: COLORS.text },
  driverInfo: { fontSize: 14, color: COLORS.textSecondary },
  callButton: {
    width: '100%',
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
  },
  callButtonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  cancelButton: {
    width: '100%',
    borderWidth: 1,
    borderColor: COLORS.alert ?? '#E53E3E',
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
  },
  cancelButtonText: { color: COLORS.alert ?? '#E53E3E', fontSize: 16, fontWeight: '600' },
  primaryButton: {
    width: '100%',
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    marginTop: SPACING.md,
  },
  primaryButtonText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  subText: { fontSize: 14, color: COLORS.textSecondary },
});
ENDOFFILE

cat > frontend/src/screens/client/RatingScreen.tsx << 'ENDOFFILE'
import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  TextInput,
  StyleSheet,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { submitClientRating } from '../../services/missionService';
import type { Mission } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type RootStackParamList = {
  Rating: { mission: Record<string, unknown> };
  ClientHome: undefined;
};

type Props = NativeStackScreenProps<RootStackParamList, 'Rating'>;

const STAR_COLORS: Record<number, string> = {
  1: '#E53E3E',
  2: '#E53E3E',
  3: '#D69E2E',
  4: '#38A169',
  5: '#38A169',
};

export default function RatingScreen({ route, navigation }: Props) {
  const mission = route.params.mission as unknown as Mission;
  const [rating, setRating] = useState(0);
  const [review, setReview] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async () => {
    if (rating === 0) {
      Alert.alert('Note requise', 'Veuillez sélectionner une note.');
      return;
    }
    setIsLoading(true);
    const result = await submitClientRating(mission.id, rating, review || undefined);
    setIsLoading(false);

    if (result.error) {
      Alert.alert('Erreur', result.error);
    } else {
      navigation.replace('ClientHome');
    }
  };

  const handleSkip = () => {
    navigation.replace('ClientHome');
  };

  const starColor = rating > 0 ? STAR_COLORS[rating] : COLORS.border;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Comment s'est passée{'\n'}votre mission ?</Text>

      <View style={styles.starsRow}>
        {[1, 2, 3, 4, 5].map((star) => (
          <TouchableOpacity key={star} onPress={() => setRating(star)}>
            <Text style={[styles.star, { color: star <= rating ? starColor : COLORS.border }]}>
              ★
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <TextInput
        style={styles.reviewInput}
        value={review}
        onChangeText={setReview}
        placeholder="Laissez un avis... (optionnel)"
        placeholderTextColor={COLORS.textSecondary}
        multiline
        numberOfLines={4}
        textAlignVertical="top"
      />

      <TouchableOpacity
        style={[styles.submitButton, rating === 0 && styles.submitButtonDisabled]}
        onPress={handleSubmit}
        disabled={isLoading || rating === 0}
      >
        {isLoading ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Text style={styles.submitButtonText}>Envoyer mon avis</Text>
        )}
      </TouchableOpacity>

      <TouchableOpacity onPress={handleSkip} style={styles.skipButton}>
        <Text style={styles.skipText}>Passer</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
    padding: SPACING.lg,
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.xl,
    lineHeight: 32,
  },
  starsRow: {
    flexDirection: 'row',
    gap: SPACING.sm,
    marginBottom: SPACING.xl,
  },
  star: { fontSize: 48 },
  reviewInput: {
    width: '100%',
    backgroundColor: COLORS.surface,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    color: COLORS.text,
    fontSize: 15,
    minHeight: 100,
    marginBottom: SPACING.lg,
  },
  submitButton: {
    width: '100%',
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    minHeight: 52,
    justifyContent: 'center',
  },
  submitButtonDisabled: { opacity: 0.5 },
  submitButtonText: { color: '#fff', fontSize: 17, fontWeight: '700' },
  skipButton: { marginTop: SPACING.md, padding: SPACING.sm },
  skipText: { color: COLORS.textSecondary, fontSize: 15 },
});
ENDOFFILE

mkdir -p frontend/src/screens/driver
cat > frontend/src/screens/driver/DriverHomeScreen.tsx << 'ENDOFFILE'
import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Switch,
  Alert,
} from 'react-native';
import type { RealtimeChannel } from '@supabase/supabase-js';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { startBackgroundTracking, stopBackgroundTracking } from '../../services/locationService';
import { subscribeToNewMissions, unsubscribeChannel } from '../../services/realtimeService';
import { supabase } from '../../lib/supabaseClient';
import NewMissionModal from './NewMissionModal';
import type { Mission, VehicleCategory } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type RootStackParamList = {
  DriverHome: { driverId: string; vehicleCategory: VehicleCategory };
  MissionActive: { mission: Record<string, unknown> };
};

type Props = NativeStackScreenProps<RootStackParamList, 'DriverHome'>;

export default function DriverHomeScreen({ route, navigation }: Props) {
  const { driverId, vehicleCategory } = route.params;
  const [isAvailable, setIsAvailable] = useState(false);
  const [walletBalance, setWalletBalance] = useState<number | null>(null);
  const [pendingMission, setPendingMission] = useState<Mission | null>(null);
  const missionChannelRef = useRef<RealtimeChannel | null>(null);

  useEffect(() => {
    const fetchWallet = async () => {
      const { data } = await supabase
        .from('wallets')
        .select('balance')
        .eq('driver_id', driverId)
        .single();
      if (data) setWalletBalance(data.balance as number);
    };
    fetchWallet();
  }, [driverId]);

  const handleToggleAvailability = useCallback(async () => {
    const newStatus = !isAvailable;

    if (newStatus) {
      const trackResult = await startBackgroundTracking(driverId);
      if (trackResult.error) {
        Alert.alert('GPS requis', trackResult.error);
        return;
      }
    } else {
      await stopBackgroundTracking();
      if (missionChannelRef.current) {
        await unsubscribeChannel(missionChannelRef.current);
        missionChannelRef.current = null;
      }
    }

    const { error } = await supabase
      .from('drivers')
      .update({ is_available: newStatus })
      .eq('id', driverId);

    if (error) {
      Alert.alert('Erreur', error.message);
      if (newStatus) await stopBackgroundTracking();
      return;
    }

    console.log('[FTM-DEBUG] Driver - Availability updated', { driverId, isAvailable: newStatus });
    setIsAvailable(newStatus);

    if (newStatus) {
      missionChannelRef.current = subscribeToNewMissions(
        vehicleCategory,
        null,
        (missionData) => {
          setPendingMission(missionData as unknown as Mission);
        }
      );
    }
  }, [isAvailable, driverId, vehicleCategory]);

  useEffect(() => {
    return () => {
      stopBackgroundTracking();
      unsubscribeChannel(missionChannelRef.current);
    };
  }, []);

  const walletColor =
    walletBalance !== null && walletBalance < 100
      ? (COLORS.alert ?? '#E53E3E')
      : (COLORS.success ?? '#38A169');

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View>
          <Text style={styles.greeting}>Bonjour, Chauffeur</Text>
          <Text style={styles.vehicleInfo}>{vehicleCategory.toUpperCase()}</Text>
        </View>
      </View>

      {walletBalance !== null && (
        <View style={[styles.walletCard, { borderColor: walletColor }]}>
          <Text style={styles.walletLabel}>💰 Wallet</Text>
          <Text style={[styles.walletAmount, { color: walletColor }]}>
            {walletBalance.toFixed(2)} DH
          </Text>
        </View>
      )}

      <View style={styles.toggleCard}>
        <Text style={styles.toggleCardTitle}>JE SUIS</Text>
        <View style={styles.toggleRow}>
          <Text style={[styles.toggleStatus, isAvailable ? styles.statusOn : styles.statusOff]}>
            {isAvailable ? '● DISPONIBLE' : '○ HORS SERVICE'}
          </Text>
          <Switch
            value={isAvailable}
            onValueChange={handleToggleAvailability}
            trackColor={{ false: COLORS.border, true: COLORS.success ?? '#38A169' }}
            thumbColor="#fff"
          />
        </View>
      </View>

      {pendingMission && (
        <NewMissionModal
          mission={pendingMission}
          driverId={driverId}
          onAccepted={(acceptedMission) => {
            setPendingMission(null);
            navigation.navigate('MissionActive', { mission: acceptedMission as unknown as Record<string, unknown> });
          }}
          onDismiss={() => setPendingMission(null)}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background, padding: SPACING.lg },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  greeting: { fontSize: 22, fontWeight: '700', color: COLORS.text },
  vehicleInfo: { fontSize: 14, color: COLORS.textSecondary, marginTop: 2 },
  walletCard: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderWidth: 1.5,
    marginBottom: SPACING.md,
  },
  walletLabel: { fontSize: 16, color: COLORS.text, fontWeight: '600' },
  walletAmount: { fontSize: 22, fontWeight: '700' },
  toggleCard: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.lg,
    alignItems: 'center',
    gap: SPACING.md,
    marginBottom: SPACING.lg,
  },
  toggleCardTitle: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 2,
    color: COLORS.textSecondary,
  },
  toggleRow: { flexDirection: 'row', alignItems: 'center', gap: SPACING.md },
  toggleStatus: { fontSize: 17, fontWeight: '700' },
  statusOn: { color: COLORS.success ?? '#38A169' },
  statusOff: { color: COLORS.textSecondary },
});
ENDOFFILE

cat > frontend/src/screens/driver/NewMissionModal.tsx << 'ENDOFFILE'
import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Modal,
  Animated,
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { acceptMission } from '../../services/missionService';
import type { Mission } from '../../services/missionService';

interface Props {
  mission: Mission;
  driverId: string;
  onAccepted: (mission: Mission) => void;
  onDismiss: () => void;
}

const COUNTDOWN_SECONDS = 30;

export default function NewMissionModal({ mission, driverId, onAccepted, onDismiss }: Props) {
  const [timeLeft, setTimeLeft] = useState(COUNTDOWN_SECONDS);
  const [isAccepting, setIsAccepting] = useState(false);
  const progressAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);

    Animated.timing(progressAnim, {
      toValue: 0,
      duration: COUNTDOWN_SECONDS * 1000,
      useNativeDriver: false,
    }).start();

    const interval = setInterval(() => {
      setTimeLeft((prev) => {
        if (prev <= 1) {
          clearInterval(interval);
          onDismiss();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, []);

  const handleAccept = async () => {
    setIsAccepting(true);
    const result = await acceptMission(mission.id, driverId);
    setIsAccepting(false);

    if (result.error) {
      onDismiss();
    } else if (result.mission) {
      onAccepted(result.mission);
    }
  };

  const progressWidth = progressAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ['0%', '100%'],
  });

  return (
    <Modal transparent animationType="slide" visible>
      <View style={styles.overlay}>
        <View style={styles.card}>
          <Text style={styles.badge}>🔔 NOUVELLE MISSION</Text>
          <Text style={styles.missionNumber}>N° {mission.mission_number}</Text>

          <View style={styles.addressSection}>
            <Text style={styles.addressLabel}>📍 Départ</Text>
            <Text style={styles.addressText}>{mission.pickup_address}</Text>
            <Text style={styles.addressLabel}>🏁 Arrivée</Text>
            <Text style={styles.addressText}>{mission.dropoff_address}</Text>
          </View>

          <View style={styles.infoRow}>
            <View style={styles.infoItem}>
              <Text style={styles.infoIcon}>📏</Text>
              <Text style={styles.infoValue}>
                {mission.estimated_distance_km ? `~${mission.estimated_distance_km} km` : 'N/A'}
              </Text>
            </View>
            <View style={styles.infoItem}>
              <Text style={styles.infoIcon}>💰</Text>
              <Text style={styles.infoValue}>
                {mission.commission_amount ? `${mission.commission_amount} DH` : 'N/A'}
              </Text>
            </View>
            <View style={styles.infoItem}>
              <Text style={styles.infoIcon}>💪</Text>
              <Text style={styles.infoValue}>{mission.needs_loading_help ? 'Oui' : 'Non'}</Text>
            </View>
          </View>

          <View style={styles.progressContainer}>
            <Animated.View
              style={[styles.progressBar, { width: progressWidth }]}
            />
          </View>
          <Text style={styles.countdown}>{timeLeft}s</Text>

          <View style={styles.actionRow}>
            <TouchableOpacity
              style={styles.refuseButton}
              onPress={onDismiss}
              disabled={isAccepting}
            >
              <Text style={styles.refuseButtonText}>❌ Refuser</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.acceptButton, isAccepting && styles.buttonDisabled]}
              onPress={handleAccept}
              disabled={isAccepting}
            >
              <Text style={styles.acceptButtonText}>✅ Accepter</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'flex-end',
  },
  card: {
    backgroundColor: COLORS.background,
    borderTopLeftRadius: BORDER_RADIUS.xl ?? 24,
    borderTopRightRadius: BORDER_RADIUS.xl ?? 24,
    padding: SPACING.lg,
    gap: SPACING.md,
  },
  badge: {
    fontSize: 18,
    fontWeight: '800',
    color: COLORS.text,
    textAlign: 'center',
    letterSpacing: 0.5,
  },
  missionNumber: {
    fontSize: 14,
    color: COLORS.textSecondary,
    textAlign: 'center',
  },
  addressSection: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    gap: SPACING.xs,
  },
  addressLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: COLORS.textSecondary,
    letterSpacing: 1,
  },
  addressText: { fontSize: 15, color: COLORS.text, marginBottom: SPACING.xs },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  infoItem: { alignItems: 'center', gap: 4 },
  infoIcon: { fontSize: 20 },
  infoValue: { fontSize: 14, fontWeight: '600', color: COLORS.text },
  progressContainer: {
    height: 6,
    backgroundColor: COLORS.border,
    borderRadius: 3,
    overflow: 'hidden',
  },
  progressBar: {
    height: '100%',
    backgroundColor: COLORS.alert ?? '#E53E3E',
    borderRadius: 3,
  },
  countdown: {
    textAlign: 'center',
    fontSize: 13,
    color: COLORS.textSecondary,
    marginTop: -SPACING.xs,
  },
  actionRow: { flexDirection: 'row', gap: SPACING.sm },
  acceptButton: {
    flex: 1,
    backgroundColor: COLORS.success ?? '#38A169',
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
  },
  acceptButtonText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  refuseButton: {
    flex: 1,
    backgroundColor: (COLORS.alert ?? '#E53E3E') + '15',
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.alert ?? '#E53E3E',
  },
  refuseButtonText: { color: COLORS.alert ?? '#E53E3E', fontSize: 16, fontWeight: '700' },
  buttonDisabled: { opacity: 0.5 },
});
ENDOFFILE

cat > frontend/src/screens/driver/MissionActiveScreen.tsx << 'ENDOFFILE'
import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Linking,
  Alert,
  Platform,
} from 'react-native';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { startMission, completeMission } from '../../services/missionService';
import type { Mission } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type RootStackParamList = {
  MissionActive: { mission: Record<string, unknown> };
  DriverHome: { driverId: string; vehicleCategory: string };
};

type Props = NativeStackScreenProps<RootStackParamList, 'MissionActive'>;

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return [h, m, s].map((v) => String(v).padStart(2, '0')).join(':');
}

export default function MissionActiveScreen({ route, navigation }: Props) {
  const initialMission = route.params.mission as unknown as Mission;
  const [mission, setMission] = useState<Mission>(initialMission);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    if (mission.status === 'in_progress' && mission.actual_pickup_time) {
      const start = new Date(mission.actual_pickup_time).getTime();
      timerRef.current = setInterval(() => {
        setElapsedSeconds(Math.floor((Date.now() - start) / 1000));
      }, 1000);
    }
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [mission.status, mission.actual_pickup_time]);

  const openMaps = (lat: number, lng: number) => {
    const url =
      Platform.OS === 'ios'
        ? `maps://?daddr=${lat},${lng}`
        : `https://maps.google.com/?daddr=${lat},${lng}`;
    Linking.openURL(url);
  };

  const handleStart = async () => {
    const result = await startMission(mission.id, mission.driver_id ?? '');
    if (result.error) {
      Alert.alert('Erreur', result.error);
    } else if (result.mission) {
      setMission(result.mission);
    }
  };

  const handleComplete = async () => {
    Alert.alert('Terminer la mission', 'Confirmer la livraison ?', [
      { text: 'Annuler', style: 'cancel' },
      {
        text: 'Confirmer',
        onPress: async () => {
          const result = await completeMission(mission.id, mission.driver_id ?? '');
          if (result.error) {
            Alert.alert('Erreur', result.error);
          } else {
            navigation.replace('DriverHome', {
              driverId: mission.driver_id ?? '',
              vehicleCategory: mission.vehicle_category,
            });
          }
        },
      },
    ]);
  };

  if (mission.status === 'accepted') {
    return (
      <View style={styles.container}>
        <Text style={styles.phaseTitle}>🚗 En route vers le client</Text>

        <View style={styles.addressCard}>
          <Text style={styles.addressLabel}>📍 Point de chargement</Text>
          <Text style={styles.addressText}>{mission.pickup_address}</Text>
          <Text style={styles.cityText}>{mission.pickup_city}</Text>
        </View>

        <TouchableOpacity
          style={styles.mapsButton}
          onPress={() => {
            /* pickup_location is a PostGIS geography — coordinates not directly available here */
            Alert.alert('Navigation', 'Ouvrez Google Maps avec les coordonnées du point de départ.');
          }}
        >
          <Text style={styles.mapsButtonText}>🗺 Ouvrir dans Maps</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.primaryButton} onPress={handleStart}>
          <Text style={styles.primaryButtonText}>J'arrive — Démarrer la mission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  if (mission.status === 'in_progress') {
    return (
      <View style={styles.container}>
        <Text style={styles.phaseTitle}>🚚 Mission en cours</Text>
        <Text style={styles.missionNumber}>N° {mission.mission_number}</Text>

        <View style={styles.addressCard}>
          <Text style={styles.addressLabel}>🏁 Destination</Text>
          <Text style={styles.addressText}>{mission.dropoff_address}</Text>
          <Text style={styles.cityText}>{mission.dropoff_city}</Text>
        </View>

        <TouchableOpacity
          style={styles.mapsButton}
          onPress={() => {
            Alert.alert('Navigation', 'Ouvrez Google Maps avec les coordonnées de destination.');
          }}
        >
          <Text style={styles.mapsButtonText}>🗺 Ouvrir dans Maps</Text>
        </TouchableOpacity>

        <View style={styles.timerBox}>
          <Text style={styles.timerLabel}>⏱ Durée</Text>
          <Text style={styles.timerValue}>{formatDuration(elapsedSeconds)}</Text>
        </View>

        <TouchableOpacity style={styles.successButton} onPress={handleComplete}>
          <Text style={styles.successButtonText}>Mission terminée ✓</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.phaseTitle}>Mission</Text>
      <Text style={styles.missionNumber}>Statut : {mission.status}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
    padding: SPACING.lg,
    justifyContent: 'center',
    gap: SPACING.md,
  },
  phaseTitle: { fontSize: 24, fontWeight: '700', color: COLORS.text, textAlign: 'center' },
  missionNumber: { fontSize: 14, color: COLORS.textSecondary, textAlign: 'center' },
  addressCard: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    gap: SPACING.xs,
  },
  addressLabel: { fontSize: 11, fontWeight: '700', color: COLORS.textSecondary, letterSpacing: 1 },
  addressText: { fontSize: 16, color: COLORS.text, fontWeight: '500' },
  cityText: { fontSize: 14, color: COLORS.textSecondary },
  mapsButton: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  mapsButtonText: { color: COLORS.primary, fontSize: 15, fontWeight: '600' },
  primaryButton: {
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    minHeight: 52,
    justifyContent: 'center',
  },
  primaryButtonText: { color: '#fff', fontSize: 17, fontWeight: '700' },
  timerBox: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
    gap: 4,
  },
  timerLabel: { fontSize: 12, color: COLORS.textSecondary, fontWeight: '600' },
  timerValue: { fontSize: 32, fontWeight: '700', color: COLORS.text, fontVariant: ['tabular-nums'] },
  successButton: {
    backgroundColor: COLORS.success ?? '#38A169',
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    minHeight: 52,
    justifyContent: 'center',
  },
  successButtonText: { color: '#fff', fontSize: 17, fontWeight: '700' },
});
ENDOFFILE

mkdir -p supabase/migrations
cat > supabase/migrations/20260221000000_add_rpc_nearby_drivers.sql << 'ENDOFFILE'
-- Migration: add_rpc_nearby_drivers
-- Adds the find_nearby_drivers() RPC function used by missionService.ts

CREATE OR REPLACE FUNCTION find_nearby_drivers(
    client_point       TEXT,
    radius_meters      INTEGER,
    p_vehicle_category vehicle_category
)
RETURNS TABLE (
    id                   UUID,
    full_name            TEXT,
    phone_number         VARCHAR,
    vehicle_category     vehicle_category,
    vehicle_brand        VARCHAR,
    vehicle_model        VARCHAR,
    license_plate        VARCHAR,
    rating_average       DECIMAL,
    total_missions       INTEGER,
    distance_km          DECIMAL,
    last_location_update TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ad.id,
        ad.full_name::TEXT,
        ad.phone_number,
        ad.vehicle_category,
        ad.vehicle_brand,
        ad.vehicle_model,
        ad.license_plate,
        ad.rating_average,
        ad.total_missions,
        ROUND((ST_Distance(
            ad.current_location,
            ST_GeographyFromText(client_point)
        ) / 1000)::NUMERIC, 2) AS distance_km,
        ad.last_location_update
    FROM available_drivers ad
    WHERE ST_DWithin(
        ad.current_location,
        ST_GeographyFromText(client_point),
        radius_meters
    )
    AND ad.vehicle_category = p_vehicle_category
    AND ad.last_location_update > NOW() - INTERVAL '5 minutes'
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
ENDOFFILE

echo "✅ Fichiers P3 créés"