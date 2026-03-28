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
