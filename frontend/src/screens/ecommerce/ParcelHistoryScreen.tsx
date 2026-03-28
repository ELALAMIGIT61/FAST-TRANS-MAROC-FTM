import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { supabase } from '../../lib/supabaseClient';
import { getClientParcels } from '../../services/parcelService';
import { formatVolume } from '../../utils/parcelCalculations';

type FilterType = 'all' | 'active' | 'completed';

const STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  pending: { label: '⏳ En attente', color: '#F59E0B' },
  accepted: { label: '🔵 Accepté', color: '#2563EB' },
  in_progress: { label: '🔄 En transit', color: '#2563EB' },
  completed: { label: '✅ Livré', color: '#16A34A' },
  cancelled_client: { label: '⛔ Annulé', color: '#9CA3AF' },
  cancelled_driver: { label: '⛔ Annulé', color: '#9CA3AF' },
};

export default function ParcelHistoryScreen(): JSX.Element {
  const navigation = useNavigation<any>();
  const [parcels, setParcels] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<FilterType>('all');

  useEffect(() => {
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const result = await getClientParcels(user.id);
      if (result.success) {
        setParcels(result.parcels || []);
      }
      setLoading(false);
    })();
  }, []);

  function filterParcels(list: any[]): any[] {
    if (filter === 'active') {
      return list.filter(p => ['pending', 'accepted', 'in_progress'].includes(p.missions?.status));
    }
    if (filter === 'completed') {
      return list.filter(p => p.missions?.status === 'completed');
    }
    return list;
  }

  function renderItem({ item }: { item: any }) {
    const mission = item.missions;
    const status = mission?.status || 'pending';
    const statusConf = STATUS_CONFIG[status] || STATUS_CONFIG.pending;

    return (
      <TouchableOpacity
        style={styles.card}
        onPress={() => navigation.navigate('TrackingDetail', { trackingNumber: item.tracking_number })}
      >
        <Text style={styles.trackingNum}>{item.tracking_number}</Text>
        <Text style={styles.route}>
          📍 {mission?.pickup_city || '—'} → 🏁 {mission?.dropoff_city || '—'}
        </Text>
        <Text style={styles.recipient}>Pour : {item.recipient_name}</Text>
        <Text style={styles.details}>
          ⚖️ {item.weight_kg} kg  {item.volume_m3 ? `📦 ${formatVolume(item.volume_m3)}` : ''}
        </Text>
        <View style={styles.statusRow}>
          <Text style={[styles.statusBadge, { color: statusConf.color }]}>{statusConf.label}</Text>
          {item.created_at && (
            <Text style={styles.dateText}>
              {new Date(item.created_at).toLocaleDateString('fr-MA')}
            </Text>
          )}
        </View>
      </TouchableOpacity>
    );
  }

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#2563EB" />
      </View>
    );
  }

  const filtered = filterParcels(parcels);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Mes expéditions</Text>

      <View style={styles.filterRow}>
        {(['all', 'active', 'completed'] as FilterType[]).map(f => (
          <TouchableOpacity
            key={f}
            style={[styles.filterBtn, filter === f && styles.filterBtnActive]}
            onPress={() => setFilter(f)}
          >
            <Text style={[styles.filterBtnText, filter === f && styles.filterBtnTextActive]}>
              {f === 'all' ? 'Tous' : f === 'active' ? 'En cours' : 'Livrés'}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <FlatList
        data={filtered}
        keyExtractor={item => item.id}
        renderItem={renderItem}
        contentContainerStyle={styles.list}
        ListEmptyComponent={<Text style={styles.emptyText}>Aucune expédition trouvée.</Text>}
      />

      <TouchableOpacity
        style={styles.fab}
        onPress={() => navigation.navigate('CreateParcel')}
      >
        <Text style={styles.fabText}>+ Envoyer un colis</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F9FAFB' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  title: { fontSize: 22, fontWeight: '700', color: '#111827', padding: 16, paddingBottom: 8 },
  filterRow: { flexDirection: 'row', paddingHorizontal: 16, gap: 8, marginBottom: 8 },
  filterBtn: { paddingHorizontal: 14, paddingVertical: 6, borderRadius: 20, borderWidth: 1, borderColor: '#E5E7EB', backgroundColor: '#fff' },
  filterBtnActive: { backgroundColor: '#2563EB', borderColor: '#2563EB' },
  filterBtnText: { color: '#6B7280', fontSize: 13, fontWeight: '500' },
  filterBtnTextActive: { color: '#fff', fontWeight: '700' },
  list: { padding: 16, paddingBottom: 80 },
  card: { backgroundColor: '#fff', borderRadius: 12, padding: 14, marginBottom: 10, shadowColor: '#000', shadowOpacity: 0.05, shadowRadius: 4, elevation: 2 },
  trackingNum: { fontSize: 15, fontWeight: '700', color: '#2563EB', marginBottom: 4 },
  route: { fontSize: 14, color: '#374151', marginBottom: 2 },
  recipient: { fontSize: 13, color: '#6B7280', marginBottom: 2 },
  details: { fontSize: 13, color: '#6B7280', marginBottom: 6 },
  statusRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  statusBadge: { fontSize: 13, fontWeight: '600' },
  dateText: { fontSize: 12, color: '#9CA3AF' },
  emptyText: { textAlign: 'center', color: '#9CA3AF', marginTop: 40, fontSize: 14 },
  fab: { position: 'absolute', bottom: 20, right: 20, left: 20, backgroundColor: '#2563EB', borderRadius: 12, height: 52, alignItems: 'center', justifyContent: 'center' },
  fabText: { color: '#fff', fontSize: 16, fontWeight: '700' },
});
