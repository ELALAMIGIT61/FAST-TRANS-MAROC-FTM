import React, { useEffect, useState, useCallback } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, RefreshControl, ActivityIndicator, TextInput, Alert } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { COLORS } from '../../constants/theme';
import { getAllDrivers, toggleUserActive } from '../../services/adminService';

interface UserProfile { id: string; full_name: string; phone_number: string; is_active: boolean; }
interface DriverUser { id: string; vehicle_category: string; license_plate: string; is_verified: boolean; profiles: UserProfile; }

export default function AdminUsersScreen() {
  const navigation = useNavigation<any>();
  const [drivers, setDrivers] = useState<DriverUser[]>([]);
  const [filtered, setFiltered] = useState<DriverUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [search, setSearch] = useState('');
  const [processing, setProcessing] = useState<string | null>(null);
  const loadUsers = useCallback(async () => {
    const result = await getAllDrivers('all');
    if (result.success && result.drivers) {
      setDrivers(result.drivers as DriverUser[]);
      setFiltered(result.drivers as DriverUser[]);
    }
    setLoading(false);
    setRefreshing(false);
  }, []);
  useEffect(() => { loadUsers(); }, [loadUsers]);
  const onRefresh = useCallback(() => { setRefreshing(true); loadUsers(); }, [loadUsers]);
  const handleSearch = (text: string) => {
    setSearch(text);
    if (text.trim() === '') { setFiltered(drivers); return; }
    const lower = text.toLowerCase();
    setFiltered(drivers.filter(d => d.profiles?.full_name?.toLowerCase().includes(lower) || d.profiles?.phone_number?.includes(text)));
  };
  const handleToggleActive = async (driver: DriverUser) => {
    const newStatus = driver.profiles.is_active === false;
    const action = newStatus ? 'activer' : 'suspendre';
    const confirmed = window.confirm('Voulez-vous ' + action + ' le compte de ' + driver.profiles.full_name + ' ?');
    if (confirmed === false) return;
    setProcessing(driver.id);
    const result = await toggleUserActive(driver.profiles.id, newStatus);
    if (result.success) { await loadUsers(); }
    else { window.alert('Erreur : ' + (result.error ?? 'Une erreur est survenue')); }
    setProcessing(null);
  };
  const renderUserCard = ({ item }: { item: DriverUser }) => (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <View>
          <Text style={styles.cardName}>👤 {item.profiles?.full_name}</Text>
          <Text style={styles.cardSub}>📞 {item.profiles?.phone_number}</Text>
        </View>
        <View style={[styles.statusBadge, item.profiles?.is_active ? styles.activeBadge : styles.suspendedBadge]}>
          <Text style={styles.statusBadgeText}>{item.profiles?.is_active ? 'Actif' : 'Suspendu'}</Text>
        </View>
      </View>
      <Text style={styles.cardSub}>{item.vehicle_category?.toUpperCase()} — {item.license_plate}</Text>
      <Text style={styles.cardSub}>{item.is_verified ? 'Verifie' : 'Non verifie'}</Text>
      <TouchableOpacity
        style={[styles.toggleBtn, item.profiles?.is_active ? styles.suspendBtn : styles.activateBtn]}
        onPress={() => handleToggleActive(item)}
        disabled={processing === item.id}
      >
        {processing === item.id
          ? <ActivityIndicator size='small' color='#FFF' />
          : <Text style={styles.toggleBtnText}>{item.profiles?.is_active ? 'Suspendre' : 'Activer'}</Text>
        }
      </TouchableOpacity>
    </View>
  );
  if (loading) {
    return <View style={styles.centered}><ActivityIndicator size='large' color={COLORS.primary} /></View>;
  }
  return (
    <View style={styles.container}>
      <FlatList
        data={filtered}
        keyExtractor={item => item.id}
        renderItem={renderUserCard}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        ListHeaderComponent={
          <View>
            <View style={styles.headerRow}>
              <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
                <Text style={styles.backBtnText}>Retour</Text>
              </TouchableOpacity>
              <Text style={styles.header}>Gestion utilisateurs ({drivers.length})</Text>
            </View>
            <TextInput
              style={styles.searchInput}
              placeholder='Recherche par nom / telephone'
              value={search}
              onChangeText={handleSearch}
              placeholderTextColor='#AAA'
            />
          </View>
        }
        ListEmptyComponent={<Text style={styles.empty}>Aucun utilisateur trouve.</Text>}
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
  searchInput: { backgroundColor: '#FFF', borderRadius: 10, padding: 12, marginHorizontal: 12, marginBottom: 8, fontSize: 14, color: '#333', borderWidth: 1, borderColor: '#E5E7EB' },
  card: { backgroundColor: '#FFF', margin: 12, marginBottom: 0, borderRadius: 12, padding: 16, shadowColor: '#000', shadowOffset: { width: 0, height: 1 }, shadowOpacity: 0.06, shadowRadius: 3, elevation: 2 },
  cardHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 6 },
  cardName: { fontSize: 15, fontWeight: '700', color: '#1A1A2E', marginBottom: 2 },
  cardSub: { fontSize: 13, color: '#666', marginBottom: 2 },
  statusBadge: { borderRadius: 8, paddingHorizontal: 8, paddingVertical: 4 },
  activeBadge: { backgroundColor: '#D1FAE5' },
  suspendedBadge: { backgroundColor: '#FEE2E2' },
  statusBadgeText: { fontSize: 11, fontWeight: '600' },
  toggleBtn: { borderRadius: 8, padding: 10, alignItems: 'center', marginTop: 10 },
  activateBtn: { backgroundColor: '#10B981' },
  suspendBtn: { backgroundColor: '#EF4444' },
  toggleBtnText: { color: '#FFF', fontWeight: '700', fontSize: 13 },
  empty: { textAlign: 'center', color: '#888', marginTop: 40, fontSize: 15 },
});
