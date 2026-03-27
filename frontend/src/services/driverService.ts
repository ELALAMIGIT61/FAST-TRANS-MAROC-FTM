// /services/driverService.ts
// Fast Trans Maroc — P2

import { supabase } from '../lib/supabaseClient';

export type VehicleCategory = 'vul' | 'n2_medium' | 'n2_large';

export interface VehicleData {
  vehicle_category:    VehicleCategory;
  vehicle_brand:       string;
  vehicle_model:       string;
  license_plate:       string;
  vehicle_capacity_kg: number;
}

export interface LegalDocsData {
  driver_license_number:       string;
  driver_license_expiry:       string; // 'YYYY-MM-DD'
  vehicle_registration_number: string;
  insurance_number:            string;
  insurance_expiry:            string; // 'YYYY-MM-DD'
  technical_inspection_expiry: string; // 'YYYY-MM-DD'
}

/**
 * STEP 1 — Create driver row + wallet
 */
export async function createDriverProfile(
  profileId: string,
  vehicleData: VehicleData
): Promise<{ success?: boolean; driver?: Record<string, unknown>; error?: string }> {
  console.log('[FTM-DEBUG] Driver - Creating driver profile', {
    profileId,
    vehicleCategory: vehicleData.vehicle_category,
    licensePlate:    vehicleData.license_plate,
  });

  const { data, error } = await supabase
    .from('drivers')
    .insert({
      profile_id:          profileId,
      vehicle_category:    vehicleData.vehicle_category,
      vehicle_brand:       vehicleData.vehicle_brand,
      vehicle_model:       vehicleData.vehicle_model,
      license_plate:       vehicleData.license_plate.toUpperCase(),
      vehicle_capacity_kg: vehicleData.vehicle_capacity_kg,
      is_available:        false,
    })
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Driver - Create error', { error: error.message });
    if (error.code === '23505') {
      return { error: "Cette plaque d'immatriculation est déjà enregistrée." };
    }
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Driver - Profile created', {
    driverId: data.id,
    category: data.vehicle_category,
  });

  await createDriverWallet(data.id as string);

  return { success: true, driver: data as Record<string, unknown> };
}

async function createDriverWallet(driverId: string): Promise<void> {
  console.log('[FTM-DEBUG] Wallet - Creating wallet for driver', { driverId });

  const { error } = await supabase.from('wallet').insert({
    driver_id:         driverId,
    balance:           0,
    minimum_balance:   100.00,
    total_earned:      0,
    total_commissions: 0,
  });

  if (error) {
    console.log('[FTM-DEBUG] Wallet - Creation error', { error: error.message });
  } else {
    console.log('[FTM-DEBUG] Wallet - Created successfully', { driverId });
  }
}

/**
 * STEP 2 — Save legal document numbers & expiry dates
 */
export async function saveDriverDocuments(
  driverId: string,
  docsData: LegalDocsData
): Promise<{ success?: boolean; error?: string }> {
  console.log('[FTM-DEBUG] Driver - Saving legal documents', {
    driverId,
    docs: Object.keys(docsData),
  });

  const { error } = await supabase
    .from('drivers')
    .update({
      driver_license_number:       docsData.driver_license_number,
      driver_license_expiry:       docsData.driver_license_expiry,
      vehicle_registration_number: docsData.vehicle_registration_number,
      insurance_number:            docsData.insurance_number,
      insurance_expiry:            docsData.insurance_expiry,
      technical_inspection_expiry: docsData.technical_inspection_expiry,
    })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Driver - Save documents error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Driver - Legal documents saved', { driverId });
  await createDocumentReminders(driverId, docsData);
  return { success: true };
}

async function createDocumentReminders(
  driverId: string,
  docsData: LegalDocsData
): Promise<void> {
  console.log('[FTM-DEBUG] Reminders - Creating document reminders', { driverId });

  const candidates = [
    { document_type: 'driver_license',       expiry_date: docsData.driver_license_expiry },
    { document_type: 'insurance',            expiry_date: docsData.insurance_expiry },
    { document_type: 'technical_inspection', expiry_date: docsData.technical_inspection_expiry },
  ].filter(r => Boolean(r.expiry_date));

  const rows = candidates.map(r => ({
    driver_id:              driverId,
    document_type:          r.document_type,
    expiry_date:            r.expiry_date,
    reminder_30_days_sent:  false,
    reminder_15_days_sent:  false,
    reminder_7_days_sent:   false,
  }));

  const { error } = await supabase
    .from('document_reminders')
    .upsert(rows, { onConflict: 'driver_id,document_type' });

  if (error) {
    console.log('[FTM-DEBUG] Reminders - Creation error', { error: error.message });
  } else {
    console.log('[FTM-DEBUG] Reminders - Created', { count: rows.length, driverId });
  }
}

/**
 * Fetch full driver profile by profile_id
 */
export async function getDriverProfile(
  profileId: string
): Promise<{ success?: boolean; driver?: Record<string, unknown>; error?: unknown }> {
  console.log('[FTM-DEBUG] Driver - Fetching driver profile', { profileId });

  const { data, error } = await supabase
    .from('drivers')
    .select(`
      id, profile_id, vehicle_category, vehicle_brand, vehicle_model,
      license_plate, vehicle_capacity_kg,
      driver_license_number, driver_license_expiry, driver_license_verified, driver_license_url,
      vehicle_registration_number, vehicle_registration_verified, vehicle_registration_url,
      insurance_number, insurance_expiry, insurance_verified, insurance_url,
      technical_inspection_expiry, technical_inspection_verified, technical_inspection_url,
      is_verified, is_available, total_missions, rating_average
    `)
    .eq('profile_id', profileId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Driver - Fetch error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Driver - Profile fetched', {
    driverId:   data.id,
    isVerified: data.is_verified,
  });

  return { success: true, driver: data as Record<string, unknown> };
}

/**
 * Reset a single document verification status to 'pending' (for re-upload)
 */
export async function resetDocumentStatus(
  driverId: string,
  docType: string
): Promise<{ success?: boolean; error?: string }> {
  const verifiedColumnMap: Record<string, string> = {
    driver_license:       'driver_license_verified',
    vehicle_registration: 'vehicle_registration_verified',
    insurance:            'insurance_verified',
    technical_inspection: 'technical_inspection_verified',
  };

  const column = verifiedColumnMap[docType];
  if (!column) return { error: 'Type de document inconnu.' };

  const { error } = await supabase
    .from('drivers')
    .update({ [column]: 'pending' })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Document - Reset status error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Document - Status reset to pending', { driverId, docType });
  return { success: true };
}
