import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { COLORS } from '../../constants/theme';
import { getAdminMissions } from '../../services/adminService';

interface Mission {
  id: string;
  mission_number: string;
  mission_type: string;
  vehicle_category: string;
  status: string;
  pickup_city: string;
  dropoff_city: string;
  negotiated_price: number;
  commission_amount: number;
  created_at: string;
  profiles: { full_name: string; phone_number: string } | null;
  drivers: {
    license_plate: string;
    vehicle_brand: string;
    profiles: { full_name: string; phone_number: string } | null;
  } | null;
}

const STATUS_LABELS: Record<string, string> = {
  pending: '⏳ En attente',
  accepted: '✅ Acceptée',
  in_progress: '🚛 En cours',
  completed: '🏁 Terminée',
  cancelled: '❌ Annulée',
};

const STATUS_FILTERS = ['all', 'pending', 'in_progress', 'completed', 'cancelled'];
const FILTER_LABELS: Record<string, string> = {
  all: 'Toutes',
  pending: 'En attente',
  in_progress: 'En cours',
  completed: 'Terminées',
  cancelled: 'Annulées',
};

export default function AdminMissionsScreen() {
  const navigation = useNavigation<any>();
  const [missions, setMissions] = useState<Mission[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [filter, setFilter] = useState('all');
  const [page, setPage] = useState(0);
  const [totalCount, setTotalCount] = useState(0);

  const loadMissions = useCallback(async (selectedFilter = filter, selectedPage = 0) => {
    console.log('[FTM-DEBUG] Admin - Loading missions', { filter: selectedFilter, page: selectedPage });
    const filters = selectedFilter !== 'all' ? { status: selectedFilter } : {};
    const result = await getAdminMissions(filters, selectedPage);
    if (result.success && result.missions) {
      setMissions(result.missions as Mission[]);
      setTotalCount(result.totalCount ?? 0);
    }
    setLoading(false);
    setRefreshing(false);
  }, [filter]);

  useEffect(() => { loadMissions(); }, [loadMissions]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadMissions(filter, 0);
  }, [filter, loadMissions]);

  const handleFilterChange = (newFilter: string) => {
    setFilter(newFilter);
    setPage(0);
    setLoading(true);
    loadMissions(newFilter, 0);
  };

  const renderMissionCard = ({ item }: { item: Mission }) => (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <Text style={styles.missionNumber}>#{item.mission_number}</Text>
        <Text style={styles.statusBadge}>{STATUS_LABELS[item.status] ?? item.status}</Text>
      </View>
      <Text style={styles.cardRoute}>📍 {item.pickup_city} → {item.dropoff_city}</Text>
      <Text style={styles.cardSub}>🚐 {item.vehicle_category?.toUpperCase()}</Text>
      {item.profiles && (
        <Text style={styles.cardSub}>👤 Client : {item.profiles.full_name}</Text>
      )}
      {item.drivers && (
        <Text style={styles.cardSub}>🚛 Chauffeur : {item.drivers.profiles?.full_name ?? 'Non assigné'}</Text>
      )}
      <View style={styles.cardFooter}>
        <Text style={styles.cardPrice}>{item.negotiated_price} DH</Text>
        <Text style={styles.cardCommission}>Commission : {item.commission_amount} DH</Text>
      </View>
      <Text style={styles.cardDate}>{new Date(item.created_at).toLocaleDateString('fr-MA')}</Text>
    </View>
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
        data={missions}
        keyExtractor={item => item.id}
        renderItem={renderMissionCard}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        ListHeaderComponent={
          <View>
            <View style={styles.headerRow}>
              <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
                <Text style={styles.backBtnText}>← Retour</Text>
              </TouchableOpacity>
              <Text style={styles.header}>Toutes les missions ({totalCount})</Text>
            </View>
            <View style={styles.filterRow}>
              {STATUS_FILTERS.map(f => (
                <TouchableOpacity
                  key={f}
                  style={[styles.filterBtn, filter === f && styles.filterBtnActive]}
                  onPress={() => handleFilterChange(f)}
                >
                  <Text style={[styles.filterBtnText, filter === f && styles.filterBtnTextActive]}>
                    {FILTER_LABELS[f]}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>
        }
        ListEmptyComponent={
          <Text style={styles.empty}>Aucune mission trouvée.</Text>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F5F7FA' },
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  headerRow: { flexDirection: 'row', alignItems: 'center', padding: 16, paddingBottom: 8, gap: 12 },
  backBtn: { padding: 4 },
  backBtnText: { color: COLORS.primary, fontSize: 14, fontWeight: '600' },
  header: { fontSize: 16, fontWeight: '700', color: COLORS.primary, flex: 1 },
  filterRow: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 12, gap: 8, marginBottom: 8 },
  filterBtn: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
    backgroundColor: '#E5E7EB',
  },
  filterBtnActive: { backgroundColor: COLORS.primary },
  filterBtnText: { fontSize: 12, color: '#555', fontWeight: '500' },
  filterBtnTextActive: { color: '#FFF' },
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
  cardHeader: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 6 },
  missionNumber: { fontSize: 14, fontWeight: '700', color: '#1A1A2E' },
  statusBadge: { fontSize: 12, color: '#555' },
  cardRoute: { fontSize: 14, fontWeight: '600', color: '#333', marginBottom: 4 },
  cardSub: { fontSize: 13, color: '#666', marginBottom: 2 },
  cardFooter: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 8 },
  cardPrice: { fontSize: 14, fontWeight: '700', color: COLORS.primary },
  cardCommission: { fontSize: 12, color: '#888' },
  cardDate: { fontSize: 11, color: '#AAA', marginTop: 4 },
  empty: { textAlign: 'center', color: '#888', marginTop: 40, fontSize: 15 },
});
