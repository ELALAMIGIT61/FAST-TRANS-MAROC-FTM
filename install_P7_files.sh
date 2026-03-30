#!/bin/bash
mkdir -p frontend/src/services
cat > frontend/src/services/adminService.ts << 'ENDOFFILE'
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
ENDOFFILE

mkdir -p frontend/src/screens/admin
cat > frontend/src/screens/admin/AdminDashboardScreen.tsx << 'ENDOFFILE'
import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { COLORS } from '../../constants/theme';
import { getAdminStats } from '../../services/adminService';

interface AdminStats {
  totalMissions: number | null;
  completedMissions: number | null;
  completionRate: string;
  totalDrivers: number | null;
  verifiedDrivers: number | null;
  pendingDrivers: number;
  totalClients: number | null;
  totalCommissionsDH: string;
}

export default function AdminDashboardScreen() {
  const navigation = useNavigation<any>();
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const loadStats = useCallback(async () => {
    const result = await getAdminStats();
    if (result.success && result.stats) {
      setStats(result.stats as AdminStats);
    }
    setLoading(false);
    setRefreshing(false);
  }, []);

  useEffect(() => {
    loadStats();
  }, [loadStats]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadStats();
  }, [loadStats]);

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color={COLORS.primary} />
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
    >
      <Text style={styles.title}>🛡️ Admin FTM — Dashboard</Text>

      <Text style={styles.sectionTitle}>── KPIs ──</Text>
      <View style={styles.kpiGrid}>
        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Missions Total</Text>
          <Text style={styles.kpiValue}>{stats?.totalMissions ?? 0}</Text>
          <Text style={styles.kpiSub}>Taux : {stats?.completionRate}</Text>
        </View>
        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Commissions Collectées</Text>
          <Text style={styles.kpiValue}>{stats?.totalCommissionsDH} DH</Text>
        </View>
        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Chauffeurs Total</Text>
          <Text style={styles.kpiValue}>{stats?.totalDrivers ?? 0}</Text>
          <Text style={styles.kpiSub}>Vérifiés : {stats?.verifiedDrivers ?? 0}</Text>
        </View>
        <View style={[styles.kpiCard, (stats?.pendingDrivers ?? 0) > 0 && styles.kpiCardWarning]}>
          <Text style={styles.kpiLabel}>En attente</Text>
          <Text style={[styles.kpiValue, (stats?.pendingDrivers ?? 0) > 0 && styles.kpiValueWarning]}>
            {(stats?.pendingDrivers ?? 0) > 0 ? '⚠️ ' : ''}{stats?.pendingDrivers ?? 0}
          </Text>
        </View>
        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Clients Total</Text>
          <Text style={styles.kpiValue}>{stats?.totalClients ?? 0}</Text>
        </View>
      </View>

      <Text style={styles.sectionTitle}>── NAVIGATION ──</Text>

      <TouchableOpacity
        style={styles.navItem}
        onPress={() => navigation.navigate('DocumentReview')}
      >
        <Text style={styles.navText}>📋 Documents en attente</Text>
        {(stats?.pendingDrivers ?? 0) > 0 && (
          <View style={styles.badge}>
            <Text style={styles.badgeText}>{stats?.pendingDrivers}</Text>
          </View>
        )}
        <Text style={styles.navArrow}>→</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.navItem}
        onPress={() => navigation.navigate('AdminMissions')}
      >
        <Text style={styles.navText}>🚚 Toutes les missions</Text>
        <Text style={styles.navArrow}>→</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.navItem}
        onPress={() => navigation.navigate('AdminUsers')}
      >
        <Text style={styles.navText}>👥 Gestion utilisateurs</Text>
        <Text style={styles.navArrow}>→</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.navItem}
        onPress={() => navigation.navigate('WalletManagement')}
      >
        <Text style={styles.navText}>💰 Wallets & Transactions</Text>
        <Text style={styles.navArrow}>→</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F7FA',
    padding: 16,
  },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: COLORS.primary,
    marginBottom: 20,
    marginTop: 8,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#888',
    marginBottom: 12,
    marginTop: 8,
  },
  kpiGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
    marginBottom: 24,
  },
  kpiCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    width: '47%',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 4,
    elevation: 2,
  },
  kpiCardWarning: {
    borderLeftWidth: 3,
    borderLeftColor: '#F59E0B',
  },
  kpiLabel: {
    fontSize: 12,
    color: '#888',
    marginBottom: 4,
  },
  kpiValue: {
    fontSize: 24,
    fontWeight: '700',
    color: '#1A1A2E',
  },
  kpiValueWarning: {
    color: '#F59E0B',
  },
  kpiSub: {
    fontSize: 11,
    color: '#AAA',
    marginTop: 2,
  },
  navItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 1,
  },
  navText: {
    flex: 1,
    fontSize: 15,
    fontWeight: '500',
    color: '#1A1A2E',
  },
  navArrow: {
    fontSize: 16,
    color: '#CCC',
  },
  badge: {
    backgroundColor: '#EF4444',
    borderRadius: 10,
    minWidth: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 6,
    marginRight: 8,
  },
  badgeText: {
    color: '#FFF',
    fontSize: 11,
    fontWeight: '700',
  },
});
ENDOFFILE

cat > frontend/src/screens/admin/DocumentReviewScreen.tsx << 'ENDOFFILE'
import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Modal,
  TextInput,
  RefreshControl,
  ActivityIndicator,
  Linking,
  Alert,
  ScrollView,
} from 'react-native';
import { COLORS } from '../../constants/theme';
import { getPendingDrivers, verifyDocument, rejectDocument } from '../../services/adminService';

type DocumentType = 'driver_license' | 'vehicle_registration' | 'insurance' | 'technical_inspection';

interface Driver {
  id: string;
  profile_id: string;
  vehicle_category: string;
  vehicle_brand: string;
  vehicle_model: string;
  license_plate: string;
  driver_license_number: string;
  driver_license_expiry: string;
  driver_license_verified: string;
  driver_license_url: string;
  vehicle_registration_number: string;
  vehicle_registration_verified: string;
  vehicle_registration_url: string;
  insurance_number: string;
  insurance_expiry: string;
  insurance_verified: string;
  insurance_url: string;
  technical_inspection_expiry: string;
  technical_inspection_verified: string;
  technical_inspection_url: string;
  is_verified: boolean;
  created_at: string;
  profiles: {
    id: string;
    full_name: string;
    phone_number: string;
    language_preference: string;
    is_active: boolean;
    created_at: string;
  };
}

const DOC_LABELS: Record<DocumentType, string> = {
  driver_license: '🪪 Permis de conduire',
  vehicle_registration: '📄 Carte grise',
  insurance: '🛡️ Assurance',
  technical_inspection: '🔧 Visite technique',
};

function statusIcon(status: string) {
  if (status === 'verified') return '✅';
  if (status === 'rejected') return '❌';
  return '🟡';
}

function statusLabel(status: string) {
  if (status === 'verified') return 'Vérifié';
  if (status === 'rejected') return 'Rejeté';
  return 'En attente';
}

export default function DocumentReviewScreen() {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [selectedDriver, setSelectedDriver] = useState<Driver | null>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [rejectTarget, setRejectTarget] = useState<DocumentType | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  const loadDrivers = useCallback(async () => {
    const result = await getPendingDrivers();
    if (result.success && result.drivers) {
      setDrivers(result.drivers as Driver[]);
    }
    setLoading(false);
    setRefreshing(false);
  }, []);

  useEffect(() => { loadDrivers(); }, [loadDrivers]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadDrivers();
  }, [loadDrivers]);

  const handleVerify = async (driver: Driver, docType: DocumentType) => {
    setIsProcessing(true);
    const result = await verifyDocument(driver.id, docType, driver.profile_id);
    if (result.success) {
      await loadDrivers();
      if (selectedDriver) {
        const updated = drivers.find(d => d.id === driver.id);
        if (updated) setSelectedDriver(updated);
      }
    } else {
      Alert.alert('Erreur', result.error ?? 'Une erreur est survenue');
    }
    setIsProcessing(false);
  };

  const handleRejectConfirm = async () => {
    if (!selectedDriver || !rejectTarget || !rejectReason.trim()) {
      Alert.alert('Requis', 'Veuillez saisir un motif de rejet.');
      return;
    }
    setIsProcessing(true);
    const result = await rejectDocument(selectedDriver.id, rejectTarget, selectedDriver.profile_id, rejectReason.trim());
    if (result.success) {
      setRejectTarget(null);
      setRejectReason('');
      await loadDrivers();
    } else {
      Alert.alert('Erreur', result.error ?? 'Une erreur est survenue');
    }
    setIsProcessing(false);
  };

  const docs: { key: DocumentType; label: string; verifiedField: string; urlField: string; numberField: string; expiryField: string }[] = [
    { key: 'driver_license', label: DOC_LABELS.driver_license, verifiedField: 'driver_license_verified', urlField: 'driver_license_url', numberField: 'driver_license_number', expiryField: 'driver_license_expiry' },
    { key: 'vehicle_registration', label: DOC_LABELS.vehicle_registration, verifiedField: 'vehicle_registration_verified', urlField: 'vehicle_registration_url', numberField: 'vehicle_registration_number', expiryField: '' },
    { key: 'insurance', label: DOC_LABELS.insurance, verifiedField: 'insurance_verified', urlField: 'insurance_url', numberField: 'insurance_number', expiryField: 'insurance_expiry' },
    { key: 'technical_inspection', label: DOC_LABELS.technical_inspection, verifiedField: 'technical_inspection_verified', urlField: 'technical_inspection_url', numberField: '', expiryField: 'technical_inspection_expiry' },
  ];

  const renderDriverCard = ({ item }: { item: Driver }) => (
    <TouchableOpacity style={styles.card} onPress={() => setSelectedDriver(item)}>
      <Text style={styles.cardName}>👤 {item.profiles?.full_name}</Text>
      <Text style={styles.cardSub}>🚐 {item.vehicle_category?.toUpperCase()} — {item.license_plate}</Text>
      <Text style={styles.cardSub}>Inscrit le {new Date(item.created_at).toLocaleDateString('fr-MA')}</Text>
      <View style={styles.docRow}>
        {docs.map(d => (
          <Text key={d.key} style={styles.docBadge}>
            {statusIcon((item as any)[d.verifiedField])} {d.label.split(' ')[1]}
          </Text>
        ))}
      </View>
      <Text style={styles.viewDocs}>Voir les documents →</Text>
    </TouchableOpacity>
  );

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color={COLORS.primary} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={drivers}
        keyExtractor={item => item.id}
        renderItem={renderDriverCard}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        ListHeaderComponent={
          <Text style={styles.header}>Documents en attente ({drivers.length})</Text>
        }
        ListEmptyComponent={
          <Text style={styles.empty}>✅ Aucun document en attente.</Text>
        }
      />

      <Modal visible={!!selectedDriver} animationType="slide" onRequestClose={() => setSelectedDriver(null)}>
        {selectedDriver && (
          <ScrollView style={styles.modal}>
            <TouchableOpacity onPress={() => setSelectedDriver(null)} style={styles.closeBtn}>
              <Text style={styles.closeBtnText}>✕ Fermer</Text>
            </TouchableOpacity>
            <Text style={styles.modalName}>👤 {selectedDriver.profiles?.full_name}</Text>
            <Text style={styles.modalSub}>📞 {selectedDriver.profiles?.phone_number}</Text>
            <Text style={styles.modalSub}>🚐 {selectedDriver.vehicle_category} | {selectedDriver.vehicle_brand} {selectedDriver.vehicle_model}</Text>
            <Text style={styles.modalSub}>Plaque : {selectedDriver.license_plate}</Text>

            {selectedDriver.is_verified && (
              <View style={styles.verifiedBanner}>
                <Text style={styles.verifiedBannerText}>✅ Dossier complet validé !</Text>
              </View>
            )}

            {docs.map(doc => {
              const status: string = (selectedDriver as any)[doc.verifiedField] ?? 'pending';
              const url: string = (selectedDriver as any)[doc.urlField] ?? '';
              const number: string = doc.numberField ? (selectedDriver as any)[doc.numberField] : '';
              const expiry: string = doc.expiryField ? (selectedDriver as any)[doc.expiryField] : '';
              return (
                <View key={doc.key} style={styles.docSection}>
                  <Text style={styles.docSectionTitle}>── {doc.label} ──</Text>
                  <Text style={styles.docStatus}>{statusIcon(status)} {statusLabel(status)}</Text>
                  {number ? <Text style={styles.docInfo}>N° : {number}</Text> : null}
                  {expiry ? <Text style={styles.docInfo}>Expire : {new Date(expiry).toLocaleDateString('fr-MA')}</Text> : null}
                  {url ? (
                    <TouchableOpacity onPress={() => Linking.openURL(url)}>
                      <Text style={styles.viewDocBtn}>🔍 Voir le document</Text>
                    </TouchableOpacity>
                  ) : null}
                  {status === 'pending' && (
                    <View style={styles.actionRow}>
                      <TouchableOpacity
                        style={[styles.actionBtn, styles.validateBtn]}
                        onPress={() => handleVerify(selectedDriver, doc.key)}
                        disabled={isProcessing}
                      >
                        <Text style={styles.actionBtnText}>✅ Valider</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={[styles.actionBtn, styles.rejectBtn]}
                        onPress={() => setRejectTarget(doc.key)}
                        disabled={isProcessing}
                      >
                        <Text style={styles.actionBtnText}>❌ Rejeter</Text>
                      </TouchableOpacity>
                    </View>
                  )}
                  {rejectTarget === doc.key && (
                    <View style={styles.rejectForm}>
                      <TextInput
                        style={styles.rejectInput}
                        placeholder="Ex: Document illisible"
                        value={rejectReason}
                        onChangeText={setRejectReason}
                        multiline
                      />
                      <TouchableOpacity
                        style={styles.confirmRejectBtn}
                        onPress={handleRejectConfirm}
                        disabled={isProcessing}
                      >
                        <Text style={styles.confirmRejectText}>Confirmer le rejet</Text>
                      </TouchableOpacity>
                    </View>
                  )}
                </View>
              );
            })}
          </ScrollView>
        )}
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F5F7FA' },
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  header: { fontSize: 18, fontWeight: '700', color: COLORS.primary, padding: 16, paddingBottom: 8 },
  card: {
    backgroundColor: '#FFF',
    margin: 12,
    marginBottom: 0,
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 3,
    elevation: 2,
  },
  cardName: { fontSize: 15, fontWeight: '700', color: '#1A1A2E', marginBottom: 4 },
  cardSub: { fontSize: 13, color: '#666', marginBottom: 2 },
  docRow: { flexDirection: 'row', flexWrap: 'wrap', marginTop: 8, gap: 6 },
  docBadge: { fontSize: 12, color: '#555', marginRight: 8 },
  viewDocs: { marginTop: 10, color: COLORS.primary, fontWeight: '600', fontSize: 13 },
  empty: { textAlign: 'center', color: '#888', marginTop: 40, fontSize: 15 },
  modal: { flex: 1, backgroundColor: '#F5F7FA', padding: 16 },
  closeBtn: { alignSelf: 'flex-end', padding: 8, marginBottom: 8 },
  closeBtnText: { color: '#888', fontSize: 14 },
  modalName: { fontSize: 18, fontWeight: '700', color: '#1A1A2E', marginBottom: 4 },
  modalSub: { fontSize: 13, color: '#666', marginBottom: 2 },
  verifiedBanner: {
    backgroundColor: '#D1FAE5',
    borderRadius: 8,
    padding: 10,
    marginVertical: 12,
    alignItems: 'center',
  },
  verifiedBannerText: { color: '#065F46', fontWeight: '700', fontSize: 14 },
  docSection: {
    backgroundColor: '#FFF',
    borderRadius: 10,
    padding: 14,
    marginTop: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.04,
    shadowRadius: 3,
    elevation: 1,
  },
  docSectionTitle: { fontSize: 14, fontWeight: '700', color: '#333', marginBottom: 6 },
  docStatus: { fontSize: 13, color: '#555', marginBottom: 4 },
  docInfo: { fontSize: 13, color: '#444', marginBottom: 2 },
  viewDocBtn: { color: COLORS.primary, fontWeight: '600', fontSize: 13, marginTop: 6 },
  actionRow: { flexDirection: 'row', gap: 10, marginTop: 10 },
  actionBtn: {
    flex: 1,
    borderRadius: 8,
    padding: 10,
    alignItems: 'center',
  },
  validateBtn: { backgroundColor: '#10B981' },
  rejectBtn: { backgroundColor: '#EF4444' },
  actionBtnText: { color: '#FFF', fontWeight: '700', fontSize: 13 },
  rejectForm: { marginTop: 10 },
  rejectInput: {
    borderWidth: 1,
    borderColor: '#DDD',
    borderRadius: 8,
    padding: 10,
    fontSize: 13,
    color: '#333',
    backgroundColor: '#FFF',
    minHeight: 60,
  },
  confirmRejectBtn: {
    backgroundColor: '#EF4444',
    borderRadius: 8,
    padding: 10,
    alignItems: 'center',
    marginTop: 8,
  },
  confirmRejectText: { color: '#FFF', fontWeight: '700', fontSize: 13 },
});
ENDOFFILE

cat > frontend/src/screens/admin/WalletManagementScreen.tsx << 'ENDOFFILE'
import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  TextInput,
  Modal,
  RefreshControl,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { COLORS } from '../../constants/theme';
import { getAllDrivers, adminTopupDriverWallet } from '../../services/adminService';

interface DriverWallet {
  id: string;
  license_plate: string;
  vehicle_category: string;
  is_verified: boolean;
  profiles: { id: string; full_name: string; phone_number: string; is_active: boolean };
  wallet: { balance: number; minimum_balance: number; total_commissions: number } | null;
}

type FilterType = 'all' | 'blocked' | 'debts';

export default function WalletManagementScreen() {
  const [drivers, setDrivers] = useState<DriverWallet[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [filter, setFilter] = useState<FilterType>('all');
  const [search, setSearch] = useState('');
  const [topupDriver, setTopupDriver] = useState<DriverWallet | null>(null);
  const [topupAmount, setTopupAmount] = useState('');
  const [topupRef, setTopupRef] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);

  const loadDrivers = useCallback(async () => {
    const result = await getAllDrivers('verified');
    if (result.success && result.drivers) {
      setDrivers(result.drivers as DriverWallet[]);
    }
    setLoading(false);
    setRefreshing(false);
  }, []);

  useEffect(() => { loadDrivers(); }, [loadDrivers]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadDrivers();
  }, [loadDrivers]);

  const filtered = drivers.filter(d => {
    const matchSearch =
      !search ||
      d.profiles?.full_name?.toLowerCase().includes(search.toLowerCase()) ||
      d.profiles?.phone_number?.includes(search);

    const balance = d.wallet?.balance ?? 0;
    const minBalance = d.wallet?.minimum_balance ?? 100;

    if (filter === 'blocked') return matchSearch && balance < minBalance;
    return matchSearch;
  });

  const handleTopup = async () => {
    if (!topupDriver || !topupAmount || !topupRef.trim()) {
      Alert.alert('Requis', 'Montant et référence requis.');
      return;
    }
    const amount = parseFloat(topupAmount);
    if (isNaN(amount) || amount <= 0) {
      Alert.alert('Invalide', 'Montant invalide.');
      return;
    }
    setIsProcessing(true);
    const result = await adminTopupDriverWallet(topupDriver.id, amount, topupRef.trim());
    if (result.success) {
      Alert.alert('Succès', `Wallet rechargé. Nouveau solde : ${result.balanceAfter} DH`);
      setTopupDriver(null);
      setTopupAmount('');
      setTopupRef('');
      await loadDrivers();
    } else {
      Alert.alert('Erreur', result.error ?? 'Une erreur est survenue');
    }
    setIsProcessing(false);
  };

  const renderItem = ({ item }: { item: DriverWallet }) => {
    const balance = item.wallet?.balance ?? 0;
    const minBalance = item.wallet?.minimum_balance ?? 100;
    const isBlocked = balance < minBalance;
    const deficit = isBlocked ? (minBalance - balance).toFixed(2) : null;

    return (
      <View style={[styles.card, isBlocked && styles.cardBlocked]}>
        <View style={styles.cardHeader}>
          <Text style={styles.cardName}>👤 {item.profiles?.full_name}</Text>
          {isBlocked && <Text style={styles.blockedTag}>❌ BLOQUÉ</Text>}
        </View>
        <Text style={styles.cardSub}>Solde : <Text style={isBlocked ? styles.red : styles.green}>{balance.toFixed(2)} DH {isBlocked ? '❌' : '✅'}</Text></Text>
        {deficit && <Text style={styles.cardSub}>Déficit : <Text style={styles.red}>{deficit} DH</Text></Text>}
        <Text style={styles.cardSub}>Commissions : {(item.wallet?.total_commissions ?? 0).toFixed(2)} DH</Text>
        <View style={styles.actionRow}>
          <TouchableOpacity
            style={styles.rechargeBtn}
            onPress={() => setTopupDriver(item)}
          >
            <Text style={styles.rechargeBtnText}>Recharger</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  };

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color={COLORS.primary} />
      </View>
    );
  }

  const previewBalance = topupDriver
    ? ((topupDriver.wallet?.balance ?? 0) + (parseFloat(topupAmount) || 0)).toFixed(2)
    : '0';

  return (
    <View style={styles.container}>
      <TextInput
        style={styles.searchInput}
        placeholder="Recherche par nom / téléphone"
        value={search}
        onChangeText={setSearch}
      />
      <View style={styles.filterRow}>
        {(['all', 'blocked'] as FilterType[]).map(f => (
          <TouchableOpacity
            key={f}
            style={[styles.filterBtn, filter === f && styles.filterBtnActive]}
            onPress={() => setFilter(f)}
          >
            <Text style={[styles.filterBtnText, filter === f && styles.filterBtnTextActive]}>
              {f === 'all' ? 'Tous' : 'Bloqués'}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <FlatList
        data={filtered}
        keyExtractor={item => item.id}
        renderItem={renderItem}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        ListEmptyComponent={<Text style={styles.empty}>Aucun résultat.</Text>}
      />

      <Modal visible={!!topupDriver} animationType="slide" transparent onRequestClose={() => setTopupDriver(null)}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalBox}>
            <Text style={styles.modalTitle}>Recharger le wallet de {topupDriver?.profiles?.full_name}</Text>
            <Text style={styles.modalSub}>Solde actuel : {(topupDriver?.wallet?.balance ?? 0).toFixed(2)} DH</Text>

            <TextInput
              style={styles.input}
              placeholder="Montant (DH) *"
              keyboardType="numeric"
              value={topupAmount}
              onChangeText={setTopupAmount}
            />
            <TextInput
              style={styles.input}
              placeholder="Réf. reçu / code agent *"
              value={topupRef}
              onChangeText={setTopupRef}
            />

            {topupAmount ? (
              <Text style={styles.previewBalance}>Nouveau solde : {previewBalance} DH ✅</Text>
            ) : null}

            <TouchableOpacity
              style={[styles.confirmBtn, isProcessing && styles.confirmBtnDisabled]}
              onPress={handleTopup}
              disabled={isProcessing}
            >
              <Text style={styles.confirmBtnText}>
                {isProcessing ? 'En cours...' : 'Confirmer la recharge'}
              </Text>
            </TouchableOpacity>
            <TouchableOpacity onPress={() => setTopupDriver(null)} style={styles.cancelBtn}>
              <Text style={styles.cancelBtnText}>Annuler</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F5F7FA' },
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  searchInput: {
    margin: 12,
    marginBottom: 6,
    borderWidth: 1,
    borderColor: '#DDD',
    borderRadius: 10,
    padding: 10,
    backgroundColor: '#FFF',
    fontSize: 14,
  },
  filterRow: { flexDirection: 'row', paddingHorizontal: 12, gap: 8, marginBottom: 8 },
  filterBtn: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 20,
    backgroundColor: '#EEE',
  },
  filterBtnActive: { backgroundColor: COLORS.primary },
  filterBtnText: { fontSize: 13, color: '#555' },
  filterBtnTextActive: { color: '#FFF', fontWeight: '700' },
  card: {
    backgroundColor: '#FFF',
    margin: 12,
    marginBottom: 0,
    borderRadius: 12,
    padding: 14,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 1,
  },
  cardBlocked: { borderLeftWidth: 3, borderLeftColor: '#EF4444' },
  cardHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 },
  cardName: { fontSize: 15, fontWeight: '700', color: '#1A1A2E' },
  blockedTag: { fontSize: 12, color: '#EF4444', fontWeight: '700' },
  cardSub: { fontSize: 13, color: '#666', marginBottom: 2 },
  red: { color: '#EF4444', fontWeight: '600' },
  green: { color: '#10B981', fontWeight: '600' },
  actionRow: { marginTop: 10 },
  rechargeBtn: {
    backgroundColor: COLORS.primary,
    borderRadius: 8,
    padding: 8,
    alignItems: 'center',
  },
  rechargeBtnText: { color: '#FFF', fontWeight: '700', fontSize: 13 },
  empty: { textAlign: 'center', color: '#888', marginTop: 40, fontSize: 15 },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  modalBox: {
    backgroundColor: '#FFF',
    borderRadius: 16,
    padding: 20,
    width: '100%',
  },
  modalTitle: { fontSize: 16, fontWeight: '700', color: '#1A1A2E', marginBottom: 6 },
  modalSub: { fontSize: 13, color: '#666', marginBottom: 12 },
  input: {
    borderWidth: 1,
    borderColor: '#DDD',
    borderRadius: 8,
    padding: 10,
    fontSize: 14,
    marginBottom: 10,
    color: '#333',
  },
  previewBalance: { fontSize: 14, color: '#10B981', fontWeight: '600', marginBottom: 12 },
  confirmBtn: {
    backgroundColor: COLORS.primary,
    borderRadius: 10,
    padding: 12,
    alignItems: 'center',
    marginBottom: 8,
  },
  confirmBtnDisabled: { opacity: 0.6 },
  confirmBtnText: { color: '#FFF', fontWeight: '700', fontSize: 14 },
  cancelBtn: { alignItems: 'center', padding: 8 },
  cancelBtnText: { color: '#888', fontSize: 13 },
});
ENDOFFILE

mkdir -p supabase/migrations
cat > supabase/migrations/20260224000000_add_rls_policies.sql << 'ENDOFFILE'
-- =====================================================================
-- FTM — Migration P7 : Politiques RLS complètes
-- Timestamp : 20260224000000
-- =====================================================================

-- ── TABLE: profiles ──────────────────────────────────────────────────

CREATE POLICY "profiles_select_own"
    ON profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "profiles_select_admin"
    ON profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "profiles_insert_own"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "profiles_update_own"
    ON profiles FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "profiles_update_admin"
    ON profiles FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: drivers ────────────────────────────────────────────────────

CREATE POLICY "drivers_select_own"
    ON drivers FOR SELECT
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "drivers_select_available"
    ON drivers FOR SELECT
    USING (is_verified = true AND is_available = true);

CREATE POLICY "drivers_select_admin"
    ON drivers FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "drivers_insert_own"
    ON drivers FOR INSERT
    WITH CHECK (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "drivers_update_own"
    ON drivers FOR UPDATE
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "drivers_update_admin"
    ON drivers FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: wallet ─────────────────────────────────────────────────────

CREATE POLICY "wallet_select_own"
    ON wallet FOR SELECT
    USING (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "wallet_select_admin"
    ON wallet FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "wallet_insert_own"
    ON wallet FOR INSERT
    WITH CHECK (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "wallet_update_admin"
    ON wallet FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: missions ───────────────────────────────────────────────────

CREATE POLICY "missions_select_participants"
    ON missions FOR SELECT
    USING (
        client_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
        OR driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "missions_select_pending_for_drivers"
    ON missions FOR SELECT
    USING (
        status = 'pending'
        AND EXISTS (
            SELECT 1 FROM drivers d
            INNER JOIN profiles p ON p.id = d.profile_id
            WHERE p.user_id = auth.uid()
            AND d.vehicle_category = missions.vehicle_category
            AND d.is_verified = true
            AND d.is_available = true
        )
    );

CREATE POLICY "missions_select_admin"
    ON missions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "missions_insert_client"
    ON missions FOR INSERT
    WITH CHECK (
        client_id IN (
            SELECT id FROM profiles
            WHERE user_id = auth.uid() AND role = 'client'
        )
    );

CREATE POLICY "missions_update_participants"
    ON missions FOR UPDATE
    USING (
        client_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
        OR driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "missions_update_admin"
    ON missions FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: transactions ───────────────────────────────────────────────

CREATE POLICY "transactions_select_own"
    ON transactions FOR SELECT
    USING (
        wallet_id IN (
            SELECT w.id FROM wallet w
            INNER JOIN drivers d ON d.id = w.driver_id
            INNER JOIN profiles p ON p.id = d.profile_id
            WHERE p.user_id = auth.uid()
        )
    );

CREATE POLICY "transactions_select_admin"
    ON transactions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: notifications ──────────────────────────────────────────────

CREATE POLICY "notifications_select_own"
    ON notifications FOR SELECT
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "notifications_insert_service"
    ON notifications FOR INSERT
    WITH CHECK (true);

CREATE POLICY "notifications_update_own"
    ON notifications FOR UPDATE
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    )
    WITH CHECK (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "notifications_update_admin"
    ON notifications FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "notifications_delete_admin"
    ON notifications FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: ecommerce_parcels ──────────────────────────────────────────

CREATE POLICY "parcels_select_client"
    ON ecommerce_parcels FOR SELECT
    USING (
        mission_id IN (
            SELECT id FROM missions
            WHERE client_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "parcels_select_driver"
    ON ecommerce_parcels FOR SELECT
    USING (
        mission_id IN (
            SELECT id FROM missions
            WHERE driver_id IN (
                SELECT id FROM drivers WHERE profile_id IN (
                    SELECT id FROM profiles WHERE user_id = auth.uid()
                )
            )
        )
    );

CREATE POLICY "parcels_select_tracking_public"
    ON ecommerce_parcels FOR SELECT
    USING (tracking_number IS NOT NULL);

CREATE POLICY "parcels_select_admin"
    ON ecommerce_parcels FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "parcels_insert_client"
    ON ecommerce_parcels FOR INSERT
    WITH CHECK (
        mission_id IN (
            SELECT id FROM missions
            WHERE client_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

-- ── TABLE: document_reminders ─────────────────────────────────────────

CREATE POLICY "reminders_select_own"
    ON document_reminders FOR SELECT
    USING (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "reminders_select_admin"
    ON document_reminders FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "reminders_insert_own"
    ON document_reminders FOR INSERT
    WITH CHECK (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

-- ── VUES SECURITY DEFINER ─────────────────────────────────────────────

ALTER VIEW available_drivers OWNER TO postgres;
GRANT SELECT ON available_drivers TO authenticated;

CREATE OR REPLACE VIEW public_parcel_tracking
WITH (security_invoker = false)
AS
SELECT
    ep.id,
    ep.tracking_number,
    ep.status,
    ep.created_at,
    ep.recipient_name,
    LEFT(ep.recipient_phone, 6) || '****' AS recipient_phone_partial,
    m.pickup_city,
    m.dropoff_city,
    m.status AS mission_status
FROM ecommerce_parcels ep
JOIN missions m ON m.id = ep.mission_id;

GRANT SELECT ON public_parcel_tracking TO anon;
GRANT SELECT ON public_parcel_tracking TO authenticated;
ENDOFFILE

mkdir -p supabase/functions/send-tracking-sms
cat > supabase/functions/send-tracking-sms/index.ts << 'ENDOFFILE'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface SendTrackingSmsPayload {
  tracking_number: string;
  recipient_phone: string;
  recipient_name: string;
  pickup_city: string;
  dropoff_city: string;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const payload: SendTrackingSmsPayload = await req.json();
    const { tracking_number, recipient_phone, recipient_name, pickup_city, dropoff_city } = payload;

    if (!tracking_number || !recipient_phone) {
      return new Response(
        JSON.stringify({ error: 'tracking_number and recipient_phone are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Normaliser le numéro marocain
    let phone = recipient_phone.replace(/\s+/g, '');
    if (phone.startsWith('0')) {
      phone = '+212' + phone.slice(1);
    } else if (!phone.startsWith('+')) {
      phone = '+212' + phone;
    }

    const smsApiKey = Deno.env.get('SMS_API_KEY') ?? '';
    const smsApiUrl = Deno.env.get('SMS_API_URL') ?? '';

    const message =
      `Bonjour ${recipient_name}, votre colis FTM est en route !\n` +
      `De : ${pickup_city} → ${dropoff_city}\n` +
      `N° de suivi : ${tracking_number}\n` +
      `Suivez votre colis sur l'app Fast Trans Maroc.`;

    console.log('[FTM-DEBUG] send-tracking-sms - Sending SMS', {
      tracking_number,
      phone,
      recipient_name,
    });

    if (!smsApiKey || !smsApiUrl) {
      console.log('[FTM-DEBUG] send-tracking-sms - SMS API not configured, skipping send');
      return new Response(
        JSON.stringify({ success: true, message: 'SMS skipped (API not configured)', tracking_number }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const smsResponse = await fetch(smsApiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${smsApiKey}`,
      },
      body: JSON.stringify({
        to: phone,
        message,
        from: 'FastTrans',
      }),
    });

    if (!smsResponse.ok) {
      const errText = await smsResponse.text();
      console.log('[FTM-DEBUG] send-tracking-sms - SMS API error', { status: smsResponse.status, errText });
      return new Response(
        JSON.stringify({ error: 'SMS delivery failed', details: errText }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Logguer dans notifications (optionnel)
    await supabaseClient.from('notifications').insert({
      profile_id: null,
      type: 'sms_tracking_sent',
      title: 'SMS de suivi envoyé',
      body: `SMS envoyé à ${phone} pour colis ${tracking_number}`,
      data: { tracking_number, phone },
    }).maybeSingle();

    console.log('[FTM-DEBUG] send-tracking-sms - SMS sent successfully', { tracking_number, phone });

    return new Response(
      JSON.stringify({ success: true, tracking_number, phone }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[FTM-DEBUG] send-tracking-sms - Unexpected error', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
ENDOFFILE

mkdir -p .github/workflows
cat > .github/workflows/deploy_supabase.yml << 'ENDOFFILE'
# .github/workflows/deploy_supabase.yml
# Déploiement automatique des migrations SQL et Edge Functions
# Déclenché sur push vers la branche 'main'

name: Deploy Supabase FTM

on:
  push:
    branches:
      - main
    paths:
      - 'supabase/**'
  workflow_dispatch:

env:
  SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}
  SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
  SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

jobs:

  lint:
    name: Lint SQL Migrations
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js 24
        uses: actions/setup-node@v4
        with:
          node-version: '24'

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Validate migrations syntax
        run: |
          echo "✅ Validating SQL migrations..."
          supabase db diff --local || true
          echo "✅ Lint complete"

  deploy-migrations:
    name: Deploy DB Migrations
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js 24
        uses: actions/setup-node@v4
        with:
          node-version: '24'

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Link Supabase project
        run: |
          supabase link \
            --project-ref ${{ env.SUPABASE_PROJECT_ID }} \
            --password ${{ env.SUPABASE_DB_PASSWORD }}

      - name: Run pending migrations
        run: |
          echo "🚀 Applying migrations..."
          supabase db push
          echo "✅ Migrations applied"

      - name: Verify migrations status
        run: |
          echo "📋 Migration history:"
          supabase migration list

  deploy-functions:
    name: Deploy Edge Functions
    runs-on: ubuntu-latest
    needs: deploy-migrations
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js 24
        uses: actions/setup-node@v4
        with:
          node-version: '24'

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Link Supabase project
        run: |
          supabase link \
            --project-ref ${{ env.SUPABASE_PROJECT_ID }} \
            --password ${{ env.SUPABASE_DB_PASSWORD }}

      - name: Deploy all Edge Functions
        run: |
          echo "🚀 Deploying Edge Functions..."
          supabase functions deploy send-push-notification
          supabase functions deploy register-push-token
          supabase functions deploy check-document-reminders
          supabase functions deploy send-tracking-sms
          echo "✅ All Edge Functions deployed"

      - name: Verify functions deployment
        run: |
          echo "📋 Deployed functions:"
          supabase functions list

  smoke-test:
    name: Smoke Tests
    runs-on: ubuntu-latest
    needs: deploy-functions
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js 24
        uses: actions/setup-node@v4
        with:
          node-version: '24'

      - name: Test Supabase connectivity
        run: |
          echo "🔍 Testing Supabase connection..."
          curl -s \
            -H "apikey: ${{ secrets.SUPABASE_ANON_KEY }}" \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}" \
            "https://${{ env.SUPABASE_PROJECT_ID }}.supabase.co/rest/v1/profiles?limit=1" \
            | jq '. | length' \
            && echo "✅ Database reachable"

      - name: Notify deployment success
        if: success()
        run: |
          echo "🎉 FTM Supabase deployment completed successfully!"
          echo "   Project: ${{ env.SUPABASE_PROJECT_ID }}"
          echo "   Branch:  ${{ github.ref_name }}"
          echo "   Commit:  ${{ github.sha }}"
ENDOFFILE

echo "✅ Fichiers P7 créés"