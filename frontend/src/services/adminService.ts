import { supabase } from '../lib/supabaseClient';
import { notifyDocumentVerified, notifyDocumentRejected } from './notificationTemplates';

type DocumentType = 'driver_license' | 'vehicle_registration' | 'insurance' | 'technical_inspection';

const columnMap: Record<DocumentType, string> = {
  driver_license: 'driver_license_verified',
  vehicle_registration: 'vehicle_registration_verified',
  insurance: 'insurance_verified',
  technical_inspection: 'technical_inspection_verified',
};

export async function getPendingDrivers() {
  console.log('[FTM-DEBUG] Admin - Fetching pending drivers');

  const { data, error } = await supabase
    .from('drivers')
    .select(`
      id,
      profile_id,
      vehicle_category,
      vehicle_brand,
      vehicle_model,
      license_plate,
      driver_license_number,
      driver_license_expiry,
      driver_license_verified,
      driver_license_url,
      vehicle_registration_number,
      vehicle_registration_verified,
      vehicle_registration_url,
      insurance_number,
      insurance_expiry,
      insurance_verified,
      insurance_url,
      technical_inspection_expiry,
      technical_inspection_verified,
      technical_inspection_url,
      is_verified,
      created_at,
      profiles (
        id,
        full_name,
        phone_number,
        language_preference,
        is_active,
        created_at
      )
    `)
    .or(
      'driver_license_verified.eq.pending,' +
      'vehicle_registration_verified.eq.pending,' +
      'insurance_verified.eq.pending,' +
      'technical_inspection_verified.eq.pending'
    )
    .order('created_at', { ascending: true });

  if (error) {
    console.log('[FTM-DEBUG] Admin - Fetch pending drivers error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Admin - Pending drivers fetched', { count: data?.length || 0 });
  return { success: true, drivers: data || [] };
}

export async function verifyDocument(driverId: string, documentType: DocumentType, profileId: string) {
  const column = columnMap[documentType];
  if (!column) {
    console.log('[FTM-DEBUG] Admin - Unknown document type', { documentType });
    return { error: 'Type de document inconnu.' };
  }

  console.log('[FTM-DEBUG] Admin - Verifying document', { driverId, documentType, column, profileId });

  const { error } = await supabase
    .from('drivers')
    .update({ [column]: 'verified' })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Admin - Verify document error', { error: error.message, driverId, documentType });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Admin - Document verified', { driverId, documentType });

  const { data: driver } = await supabase
    .from('drivers')
    .select('is_verified')
    .eq('id', driverId)
    .single();

  await notifyDocumentVerified(profileId, documentType);

  if (driver?.is_verified) {
    console.log('[FTM-DEBUG] Admin - Driver fully verified!', { driverId });
    await supabase.from('notifications').insert({
      profile_id: profileId,
      type: 'driver_fully_verified',
      title: '🎉 Dossier complet validé !',
      body: 'Tous vos documents ont été approuvés. Activez votre disponibilité pour recevoir des missions.',
      data: { screen: 'DriverHomeStack' },
    });
    console.log('[FTM-DEBUG] Admin - Full verification notification sent', { profileId });
  }

  return { success: true, isFullyVerified: driver?.is_verified };
}

export async function rejectDocument(driverId: string, documentType: DocumentType, profileId: string, reason: string) {
  const column = columnMap[documentType];

  console.log('[FTM-DEBUG] Admin - Rejecting document', { driverId, documentType, reason, profileId });

  const { error } = await supabase
    .from('drivers')
    .update({ [column]: 'rejected' })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Admin - Reject document error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Admin - Document rejected', { driverId, documentType, reason });

  await notifyDocumentRejected(profileId, documentType, reason);

  return { success: true };
}

export async function getAllDrivers(filter: string = 'all') {
  console.log('[FTM-DEBUG] Admin - Fetching all drivers', { filter });

  let query = supabase
    .from('drivers')
    .select(`
      id,
      vehicle_category,
      license_plate,
      is_verified,
      is_available,
      total_missions,
      rating_average,
      created_at,
      profiles ( id, full_name, phone_number, is_active ),
      wallet ( balance, minimum_balance, total_commissions )
    `)
    .order('created_at', { ascending: false });

  if (filter === 'verified') query = query.eq('is_verified', true);
  if (filter === 'pending') {
    query = query.or(
      'driver_license_verified.eq.pending,vehicle_registration_verified.eq.pending,' +
      'insurance_verified.eq.pending,technical_inspection_verified.eq.pending'
    );
  }

  const { data, error } = await query;

  if (error) {
    console.log('[FTM-DEBUG] Admin - Fetch all drivers error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Admin - All drivers fetched', { count: data?.length || 0, filter });
  return { success: true, drivers: data || [] };
}

export async function toggleUserActive(profileId: string, isActive: boolean) {
  console.log('[FTM-DEBUG] Admin - Toggling user active status', { profileId, newStatus: isActive });

  const { error } = await supabase
    .from('profiles')
    .update({ is_active: isActive })
    .eq('id', profileId);

  if (error) {
    console.log('[FTM-DEBUG] Admin - Toggle user error', { error: error.message });
    return { error: error.message };
  }

  if (!isActive) {
    await supabase
      .from('drivers')
      .update({ is_available: false })
      .eq('profile_id', profileId);
    console.log('[FTM-DEBUG] Admin - Driver availability reset on suspension', { profileId });
  }

  console.log('[FTM-DEBUG] Admin - User status updated', { profileId, isActive });
  return { success: true };
}

export async function getAdminMissions(filters: Record<string, string> = {}, page: number = 0) {
  const PAGE_SIZE = 25;
  const from = page * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

  console.log('[FTM-DEBUG] Admin - Fetching missions', { filters, page });

  let query = supabase
    .from('missions')
    .select(`
      id,
      mission_number,
      mission_type,
      vehicle_category,
      status,
      pickup_city,
      dropoff_city,
      estimated_distance_km,
      negotiated_price,
      commission_amount,
      needs_loading_help,
      created_at,
      completed_at,
      profiles!client_id ( full_name, phone_number ),
      drivers (
        license_plate,
        vehicle_brand,
        profiles ( full_name, phone_number )
      )
    `, { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, to);

  if (filters.status) query = query.eq('status', filters.status);
  if (filters.vehicleCategory) query = query.eq('vehicle_category', filters.vehicleCategory);
  if (filters.missionType) query = query.eq('mission_type', filters.missionType);
  if (filters.city) query = query.or(
    `pickup_city.ilike.%${filters.city}%,dropoff_city.ilike.%${filters.city}%`
  );
  if (filters.dateFrom) query = query.gte('created_at', filters.dateFrom);
  if (filters.dateTo) query = query.lte('created_at', filters.dateTo);

  const { data, error, count } = await query;

  if (error) {
    console.log('[FTM-DEBUG] Admin - Fetch missions error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Admin - Missions fetched', { count: data?.length, totalCount: count, page, filters });
  return { success: true, missions: data || [], totalCount: count };
}

export async function getAdminStats() {
  console.log('[FTM-DEBUG] Admin - Fetching global stats');

  const [
    { count: totalMissions },
    { count: completedMissions },
    { count: totalDrivers },
    { count: verifiedDrivers },
    { count: totalClients },
    { data: commissionData },
  ] = await Promise.all([
    supabase.from('missions').select('*', { count: 'exact', head: true }),
    supabase.from('missions').select('*', { count: 'exact', head: true }).eq('status', 'completed'),
    supabase.from('drivers').select('*', { count: 'exact', head: true }),
    supabase.from('drivers').select('*', { count: 'exact', head: true }).eq('is_verified', true),
    supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'client'),
    supabase.from('transactions').select('amount').eq('transaction_type', 'commission').eq('status', 'completed'),
  ]);

  const totalCommissions = commissionData?.reduce((sum: number, tx: { amount: string }) => sum + parseFloat(tx.amount), 0) || 0;

  const stats = {
    totalMissions,
    completedMissions,
    completionRate: totalMissions && totalMissions > 0
      ? ((((completedMissions ?? 0) / totalMissions) * 100).toFixed(1) + '%')
      : '0%',
    totalDrivers,
    verifiedDrivers,
    pendingDrivers: (totalDrivers ?? 0) - (verifiedDrivers ?? 0),
    totalClients,
    totalCommissionsDH: totalCommissions.toFixed(2),
  };

  console.log('[FTM-DEBUG] Admin - Global stats fetched', stats);
  return { success: true, stats };
}

export async function adminTopupDriverWallet(driverId: string, amount: number, agentRef: string) {
  console.log('[FTM-DEBUG] Admin - Topup driver wallet', { driverId, amount, agentRef });

  const { data: wallet, error } = await supabase
    .from('wallet')
    .select('id, balance')
    .eq('driver_id', driverId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Admin - Wallet fetch error', { error: error.message });
    return { error: error.message };
  }

  const { topupWallet } = await import('./walletService');
  const result = await topupWallet(wallet.id, amount, agentRef);

  if (result.success) {
    console.log('[FTM-DEBUG] Admin - Topup completed for driver', {
      driverId,
      walletId: wallet.id,
      amountAdded: amount,
      newBalance: result.balanceAfter,
    });
  }

  return result;
}
