import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  RefreshControl,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useRoute, RouteProp } from '@react-navigation/native';

import { COLORS } from '../../constants/theme';
import {
  Transaction,
  TransactionFilter,
  getTransactionHistory,
} from '../../services/walletService';

// ─── Types ────────────────────────────────────────────────────────────────────

type RootStackParamList = {
  TransactionHistory: { walletId: string };
};
type RoutePropType = RouteProp<RootStackParamList, 'TransactionHistory'>;

interface TransactionConfig {
  icon: string;
  label: string;
  color: string;
  sign: string;
}

// ─── Config ───────────────────────────────────────────────────────────────────

const TRANSACTION_CONFIG: Record<string, TransactionConfig> = {
  commission: {
    icon: '💸',
    label: 'Commission FTM',
    color: '#DC3545',
    sign: '−',
  },
  topup: {
    icon: '💰',
    label: 'Recharge',
    color: '#28A745',
    sign: '+',
  },
  refund: {
    icon: '↩️',
    label: 'Remboursement',
    color: '#28A745',
    sign: '+',
  },
};

const FILTERS: { key: TransactionFilter; label: string }[] = [
  { key: 'all', label: 'Tous' },
  { key: 'commission', label: 'Commissions' },
  { key: 'topup', label: 'Recharges' },
  { key: 'refund', label: 'Remboursements' },
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function formatTransactionDate(isoDate: string | null): string {
  if (!isoDate) return '—';
  const d = new Date(isoDate);
  return d.toLocaleDateString('fr-MA', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

// ─── TransactionCard ──────────────────────────────────────────────────────────

interface TransactionCardProps {
  tx: Transaction;
  onPress: (tx: Transaction) => void;
}

function TransactionCard({ tx, onPress }: TransactionCardProps) {
  const cfg = TRANSACTION_CONFIG[tx.transaction_type] ?? TRANSACTION_CONFIG.commission;
  const isFailed = tx.status === 'failed';

  return (
    <TouchableOpacity
      style={[styles.card, isFailed && styles.cardFailed]}
      onPress={() => onPress(tx)}
      activeOpacity={0.7}
    >
      <View style={styles.cardLeft}>
        <Text style={styles.cardIcon}>{cfg.icon}</Text>
        <View style={{ flex: 1 }}>
          <View style={styles.cardTitleRow}>
            <Text style={styles.cardType}>{cfg.label}</Text>
            {isFailed && (
              <View style={styles.failedBadge}>
                <Text style={styles.failedBadgeText}>ÉCHOUÉ</Text>
              </View>
            )}
          </View>
          {tx.missions && (
            <Text style={styles.cardMission}>
              Mission {tx.missions.mission_number} · {tx.missions.pickup_city} →{' '}
              {tx.missions.dropoff_city}
            </Text>
          )}
          {!tx.missions && tx.description && (
            <Text style={styles.cardDesc} numberOfLines={1}>
              {tx.description}
            </Text>
          )}
          <Text style={styles.cardDate}>
            {formatTransactionDate(tx.processed_at ?? tx.created_at)}
          </Text>
          <Text style={styles.cardBalance}>
            Solde : {tx.balance_after.toFixed(2)} DH
          </Text>
        </View>
      </View>
      <Text style={[styles.cardAmount, { color: cfg.color }]}>
        {cfg.sign} {tx.amount.toFixed(2)} DH
      </Text>
    </TouchableOpacity>
  );
}

// ─── Component ────────────────────────────────────────────────────────────────

interface TransactionHistoryScreenProps {
  onTransactionPress?: (tx: Transaction) => void;
}

export default function TransactionHistoryScreen({
  onTransactionPress,
}: TransactionHistoryScreenProps) {
  const route = useRoute<RoutePropType>();
  const { walletId } = route.params;

  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [currentPage, setCurrentPage] = useState(0);
  const [activeFilter, setActiveFilter] = useState<TransactionFilter>('all');
  const [isLoading, setIsLoading] = useState(true);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const filterRef = useRef(activeFilter);
  filterRef.current = activeFilter;

  const loadPage = useCallback(
    async (page: number, filter: TransactionFilter, replace = false) => {
      const result = await getTransactionHistory(walletId, page, filter);
      if (result.success && result.transactions) {
        setTransactions((prev) =>
          replace ? result.transactions! : [...prev, ...result.transactions!]
        );
        setTotalCount(result.totalCount ?? 0);
        setHasMore(result.hasMore ?? false);
      }
    },
    [walletId]
  );

  useEffect(() => {
    setIsLoading(true);
    setCurrentPage(0);
    loadPage(0, activeFilter, true).finally(() => setIsLoading(false));
  }, [activeFilter, loadPage]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    setCurrentPage(0);
    await loadPage(0, activeFilter, true);
    setRefreshing(false);
  }, [activeFilter, loadPage]);

  const loadMore = useCallback(async () => {
    if (!hasMore || isLoadingMore) return;
    const nextPage = currentPage + 1;
    setIsLoadingMore(true);
    await loadPage(nextPage, activeFilter, false);
    setCurrentPage(nextPage);
    setIsLoadingMore(false);
  }, [hasMore, isLoadingMore, currentPage, activeFilter, loadPage]);

  const handleFilterChange = (filter: TransactionFilter) => {
    if (filter === activeFilter) return;
    setActiveFilter(filter);
  };

  // Summary
  const totalDebit = transactions
    .filter((t) => t.transaction_type === 'commission' && t.status === 'completed')
    .reduce((s, t) => s + t.amount, 0);
  const totalCredit = transactions
    .filter((t) => t.transaction_type !== 'commission' && t.status === 'completed')
    .reduce((s, t) => s + t.amount, 0);

  const handleCardPress = (tx: Transaction) => {
    onTransactionPress?.(tx);
  };

  return (
    <View style={styles.container}>
      {/* Filter tabs */}
      <View style={styles.filterRow}>
        {FILTERS.map((f) => (
          <TouchableOpacity
            key={f.key}
            style={[styles.filterTab, activeFilter === f.key && styles.filterTabActive]}
            onPress={() => handleFilterChange(f.key)}
          >
            <Text
              style={[
                styles.filterTabText,
                activeFilter === f.key && styles.filterTabTextActive,
              ]}
            >
              {f.label}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* Summary */}
      <View style={styles.summaryRow}>
        <Text style={[styles.summaryItem, { color: '#DC3545' }]}>
          Prélevé : −{totalDebit.toFixed(2)} DH
        </Text>
        <Text style={[styles.summaryItem, { color: '#28A745' }]}>
          Rechargé : +{totalCredit.toFixed(2)} DH
        </Text>
      </View>

      {isLoading ? (
        <View style={styles.centered}>
          <ActivityIndicator size="large" color={COLORS.primary ?? '#007AFF'} />
        </View>
      ) : (
        <FlatList
          data={transactions}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => (
            <TransactionCard tx={item} onPress={handleCardPress} />
          )}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
          contentContainerStyle={styles.list}
          ListEmptyComponent={
            <Text style={styles.emptyText}>Aucune transaction trouvée.</Text>
          }
          ListFooterComponent={
            hasMore ? (
              <TouchableOpacity style={styles.loadMoreBtn} onPress={loadMore} disabled={isLoadingMore}>
                {isLoadingMore ? (
                  <ActivityIndicator color={COLORS.primary ?? '#007AFF'} />
                ) : (
                  <Text style={styles.loadMoreText}>Charger plus...</Text>
                )}
              </TouchableOpacity>
            ) : null
          }
        />
      )}
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background ?? '#F5F5F5' },
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center', marginTop: 60 },

  filterRow: {
    flexDirection: 'row',
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border ?? '#E0E0E0',
  },
  filterTab: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
    backgroundColor: COLORS.border ?? '#E0E0E0',
  },
  filterTabActive: { backgroundColor: COLORS.primary ?? '#007AFF' },
  filterTabText: { fontSize: 12, fontWeight: '600', color: COLORS.text ?? '#1A1A1A' },
  filterTabTextActive: { color: COLORS.white ?? '#FFFFFF' },

  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: 10,
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border ?? '#E0E0E0',
    marginBottom: 4,
  },
  summaryItem: { fontSize: 13, fontWeight: '600' },

  list: { padding: 12, paddingBottom: 40 },

  card: {
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderRadius: 10,
    padding: 14,
    marginBottom: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    shadowColor: '#000',
    shadowOpacity: 0.04,
    shadowOffset: { width: 0, height: 1 },
    shadowRadius: 4,
    elevation: 2,
  },
  cardFailed: { backgroundColor: '#FFF0F0' },
  cardLeft: { flexDirection: 'row', alignItems: 'flex-start', flex: 1, marginRight: 10 },
  cardIcon: { fontSize: 22, marginRight: 10, marginTop: 2 },
  cardTitleRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 2 },
  cardType: { fontSize: 14, fontWeight: '600', color: COLORS.text ?? '#1A1A1A', marginRight: 6 },
  failedBadge: {
    backgroundColor: '#DC3545',
    borderRadius: 4,
    paddingHorizontal: 5,
    paddingVertical: 1,
  },
  failedBadgeText: { fontSize: 9, fontWeight: '700', color: '#FFFFFF' },
  cardMission: { fontSize: 12, color: COLORS.textSecondary ?? '#777', marginBottom: 2 },
  cardDesc: { fontSize: 12, color: COLORS.textSecondary ?? '#777', marginBottom: 2 },
  cardDate: { fontSize: 11, color: COLORS.textSecondary ?? '#777', marginBottom: 2 },
  cardBalance: { fontSize: 11, color: COLORS.textSecondary ?? '#777' },
  cardAmount: { fontSize: 15, fontWeight: '700', textAlign: 'right' },

  emptyText: {
    textAlign: 'center',
    color: COLORS.textSecondary ?? '#777',
    marginTop: 40,
    fontSize: 14,
  },

  loadMoreBtn: {
    alignItems: 'center',
    paddingVertical: 14,
  },
  loadMoreText: {
    fontSize: 14,
    color: COLORS.primary ?? '#007AFF',
    fontWeight: '600',
  },
});
