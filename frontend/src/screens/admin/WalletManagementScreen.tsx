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
