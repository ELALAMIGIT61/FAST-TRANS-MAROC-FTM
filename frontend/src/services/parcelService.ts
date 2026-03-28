import { supabase } from '../lib/supabaseClient';
import { createMission } from './missionService';
import {
  recommendVehicleCategory,
  calculateVolume,
} from '../utils/parcelCalculations';

export interface ParcelData {
  sender_name: string;
  sender_phone: string;
  recipient_name: string;
  recipient_phone: string;
  length_cm: string | number;
  width_cm: string | number;
  height_cm: string | number;
  weight_kg: string | number;
  is_fragile?: boolean;
  content_description: string;
  vehicle_category?: string;
  pickup_lat?: number;
  pickup_lng?: number;
  pickup_address?: string;
  pickup_city?: string;
  dropoff_lat?: number;
  dropoff_lng?: number;
  dropoff_address?: string;
  dropoff_city?: string;
  negotiated_price?: string | null;
  client_notes?: string | null;
}

/**
 * CRÉER UNE MISSION E-COMMERCE AVEC SON COLIS
 * Flux en 2 étapes atomiques :
 *   1. INSERT dans missions (mission_type = 'ecommerce_parcel')
 *   2. INSERT dans ecommerce_parcels lié à la mission
 */
export async function createParcelMission(
  clientProfileId: string,
  parcelData: ParcelData
): Promise<{ success?: boolean; mission?: any; parcel?: any; trackingNumber?: string; error?: string }> {
  console.log('[FTM-DEBUG] Parcel - Creating parcel mission', {
    clientId: clientProfileId,
    senderName: parcelData.sender_name,
    recipientName: parcelData.recipient_name,
    recipientPhone: parcelData.recipient_phone,
    dimensions: `${parcelData.length_cm}×${parcelData.width_cm}×${parcelData.height_cm} cm`,
    weightKg: parcelData.weight_kg,
    volumeM3: calculateVolume(parcelData.length_cm, parcelData.width_cm, parcelData.height_cm),
    isFragile: parcelData.is_fragile,
    vehicleCategory: parcelData.vehicle_category,
    pickupCity: parcelData.pickup_city,
    dropoffCity: parcelData.dropoff_city,
  });

  // ── ÉTAPE 1 : Créer la mission parent ──────────────────────────────
  const missionResult = await createMission(clientProfileId, {
    mission_type: 'ecommerce_parcel',
    vehicle_category: parcelData.vehicle_category,
    pickup_lat: parcelData.pickup_lat,
    pickup_lng: parcelData.pickup_lng,
    pickup_address: parcelData.pickup_address,
    pickup_city: parcelData.pickup_city,
    dropoff_lat: parcelData.dropoff_lat,
    dropoff_lng: parcelData.dropoff_lng,
    dropoff_address: parcelData.dropoff_address,
    dropoff_city: parcelData.dropoff_city,
    description: `Colis e-commerce : ${parcelData.content_description}`,
    needs_loading_help: false,
    negotiated_price: parcelData.negotiated_price || null,
    client_notes: parcelData.client_notes || null,
  });

  if (missionResult.error) {
    console.log('[FTM-DEBUG] Parcel - Mission creation failed', {
      error: missionResult.error,
    });
    return { error: missionResult.error };
  }

  const mission = missionResult.mission;
  console.log('[FTM-DEBUG] Parcel - Parent mission created', {
    missionId: mission.id,
    missionNumber: mission.mission_number,
    commission: mission.commission_amount,
  });

  // ── ÉTAPE 2 : Créer le colis lié à la mission ──────────────────────
  const { data: parcel, error: parcelError } = await supabase
    .from('ecommerce_parcels')
    .insert({
      mission_id: mission.id,
      sender_name: parcelData.sender_name,
      sender_phone: parcelData.sender_phone,
      recipient_name: parcelData.recipient_name,
      recipient_phone: parcelData.recipient_phone,
      length_cm: parseFloat(String(parcelData.length_cm)),
      width_cm: parseFloat(String(parcelData.width_cm)),
      height_cm: parseFloat(String(parcelData.height_cm)),
      weight_kg: parseFloat(String(parcelData.weight_kg)),
      // volume_m3 : calculé automatiquement par PostgreSQL (GENERATED ALWAYS)
      content_description: parcelData.content_description,
      is_fragile: parcelData.is_fragile || false,
      // tracking_number : assigné automatiquement par trigger_set_tracking_number
    })
    .select()
    .single();

  if (parcelError) {
    console.log('[FTM-DEBUG] Parcel - Parcel insert error', {
      error: parcelError.message,
      missionId: mission.id,
    });
    // Rollback : annuler la mission créée à l'étape 1
    await supabase
      .from('missions')
      .update({ status: 'cancelled_client' })
      .eq('id', mission.id);

    console.log('[FTM-DEBUG] Parcel - Mission rolled back after parcel error', {
      missionId: mission.id,
    });
    return { error: 'Erreur lors de la création du colis. Réessayez.' };
  }

  console.log('[FTM-DEBUG] Parcel - Parcel created successfully', {
    parcelId: parcel.id,
    trackingNumber: parcel.tracking_number,
    volumeM3: parcel.volume_m3,
    missionId: mission.id,
  });

  // ── ÉTAPE 3 : Notifier le destinataire par SMS ─────────────────────
  await notifyRecipientBySMS(parcel, mission);

  return {
    success: true,
    mission,
    parcel,
    trackingNumber: parcel.tracking_number,
  };
}

/**
 * NOTIFIER LE DESTINATAIRE PAR SMS
 */
async function notifyRecipientBySMS(parcel: any, mission: any): Promise<void> {
  console.log('[FTM-DEBUG] Parcel - Sending SMS to recipient', {
    recipientPhone: parcel.recipient_phone,
    recipientName: parcel.recipient_name,
    trackingNumber: parcel.tracking_number,
    pickupCity: mission.pickup_city,
    dropoffCity: mission.dropoff_city,
  });

  try {
    const { error } = await supabase.functions.invoke('send-tracking-sms', {
      body: {
        to: parcel.recipient_phone,
        recipient_name: parcel.recipient_name,
        tracking_number: parcel.tracking_number,
        pickup_city: mission.pickup_city,
        dropoff_city: mission.dropoff_city,
      },
    });

    if (error) {
      console.log('[FTM-DEBUG] Parcel - SMS send error', { error: error.message });
    } else {
      console.log('[FTM-DEBUG] Parcel - SMS sent to recipient', {
        trackingNumber: parcel.tracking_number,
        phone: parcel.recipient_phone,
      });
    }
  } catch (err: any) {
    console.log('[FTM-DEBUG] Parcel - SMS exception', { err: err.message });
  }
}

/**
 * RÉCUPÉRER LES INFOS D'UN COLIS PAR TRACKING NUMBER
 * Accessible SANS authentification (destinataire non-utilisateur)
 */
export async function getParcelByTrackingNumber(
  trackingNumber: string
): Promise<{ success?: boolean; parcel?: any; error?: string }> {
  const normalized = trackingNumber.trim().toUpperCase();

  console.log('[FTM-DEBUG] Parcel - Fetching parcel by tracking number', {
    trackingNumber: normalized,
  });

  const { data, error } = await supabase
    .from('public_parcel_tracking')
    .select('*')
    .eq('tracking_number', normalized)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Parcel - Tracking fetch error', {
      trackingNumber: normalized,
      error: error.message,
      errorCode: error.code,
    });
    if (error.code === 'PGRST116') {
      return { error: 'Numéro de suivi introuvable. Vérifiez le format : FTM-TRACK-XXXXXXXX' };
    }
    return { error: 'Erreur lors de la recherche. Réessayez.' };
  }

  console.log('[FTM-DEBUG] Parcel - Parcel found', {
    trackingNumber: normalized,
    status: data.mission_status,
    pickupCity: data.pickup_city,
    dropoffCity: data.dropoff_city,
    driverName: data.driver_name,
  });

  return { success: true, parcel: data };
}

/**
 * RÉCUPÉRER TOUS LES COLIS D'UN CLIENT (historique expéditions)
 */
export async function getClientParcels(
  clientProfileId: string
): Promise<{ success?: boolean; parcels?: any[]; error?: any }> {
  console.log('[FTM-DEBUG] Parcel - Fetching client parcels', { clientProfileId });

  const { data, error } = await supabase
    .from('ecommerce_parcels')
    .select(`
      id,
      tracking_number,
      recipient_name,
      recipient_phone,
      content_description,
      is_fragile,
      weight_kg,
      volume_m3,
      length_cm,
      width_cm,
      height_cm,
      created_at,
      missions (
        id,
        mission_number,
        status,
        pickup_city,
        dropoff_city,
        estimated_distance_km,
        commission_amount,
        negotiated_price,
        actual_pickup_time,
        actual_dropoff_time,
        completed_at
      )
    `)
    .eq('missions.client_id', clientProfileId)
    .order('created_at', { ascending: false });

  if (error) {
    console.log('[FTM-DEBUG] Parcel - Fetch client parcels error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Parcel - Client parcels fetched', {
    clientProfileId,
    count: data?.length || 0,
  });

  return { success: true, parcels: data || [] };
}
