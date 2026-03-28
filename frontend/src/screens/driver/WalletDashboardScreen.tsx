import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { RealtimeChannel } from '@supabase/supabase-js';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';

import { COLORS } from '../../constants/theme';
import {
  DriverDashboard,
  getDriverDashboard,
  subscribeToWalletUpdates,
} from '../../services/walletService';

// ─── Types ────────────────────────────────────────────────────────────────────

type RootStackParamList = {
  WalletDashboard: undefined;
  WalletTopup: { walletId: string; currentBalance: number; minimumBalance: number };
  TransactionHistory: { walletId: string };
};

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'WalletDashboard'>;

interface WalletDashboardScreenProps {
  driverId: string;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function getProgressColor(pct: number): string {
  if (pct < 50) return COLORS.alert ?? '#DC3545';
  if (pct < 100) return COLORS.cta ?? '#FFC107';
  return COLORS.success ?? '#28A745';
}

function formatAmount(amount: number): string {
  return amount.toLocaleString('fr-MA', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

// ─── Component ────────────────────────────────────────────────────────────────

export default function WalletDashboardScreen({ driverId }: WalletDashboardScreenProps) {
  const navigation = useNavigation<NavigationProp>();
  const [dashboard, setDashboard] = useState<DriverDashboard | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [liveBalance, setLiveBalance] = useState<number | null>(null);
  const [liveBlocked, setLiveBlocked] = useState<boolean | null>(null);
  const channelRef = useRef<RealtimeChannel | null>(null);

  const load = useCallback(async () => {
    const result = await getDriverDashboard(driverId);
    if (result.success && result.dashboard) {
      setDashboard(result.dashboard);
      setLiveBalance(result.dashboard.wallet_balance);
      setLiveBlocked(result.dashboard.is_wallet_blocked);
    }
  }, [driverId]);

  useEffect(() => {
    setIsLoading(true);
    load().finally(() => setIsLoading(false));
  }, [load]);

  // Realtime subscription
  useEffect(() => {
    if (!dashboard?.wallet_id) return;
    channelRef.current = subscribeToWalletUpdates(
      dashboard.wallet_id,
      driverId,
      ({ balance, isBlocked }) => {
        setLiveBalance(balance);
        setLiveBlocked(isBlocked);
      }
    );
    return () => {
      channelRef.current?.unsubscribe();
    };
  }, [dashboard?.wallet_id, driverId]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  if (isLoading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color={COLORS.primary ?? '#007AFF'} />
      </View>
    );
  }

  if (!dashboard) {
    return (
      <View style={styles.centered}>
        <Text style={styles.errorText}>Impossible de charger le wallet.</Text>
      </View>
    );
  }

  const balance = liveBalance ?? dashboard.wallet_balance;
  const isBlocked = liveBlocked ?? dashboard.is_wallet_blocked;
  const minimum = dashboard.minimum_balance;

  const progressPct = Math.min((balance / minimum) * 100, 100);
  const progressColor = getProgressColor(progressPct);

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
    >
      <Text style={styles.screenTitle}>💰 Mon Wallet</Text>

      {/* ── Solde Card ── */}
      <View style={styles.balanceCard}>
        <Text style={styles.balanceLabel}>SOLDE ACTUEL</Text>
        <Text style={[styles.balanceAmount, { color: progressColor }]}>
          {formatAmount(balance)} DH
        </Text>
        <Text style={styles.minimumLabel}>Seuil minimum : {formatAmount(minimum)} DH</Text>

        {/* Progress bar */}
        <View style={styles.progressTrack}>
          <View
            style={[
              styles.progressFill,
              { width: `${progressPct}%` as unknown as number, backgroundColor: progressColor },
            ]}
          />
        </View>
      </View>

      {/* ── Banner blocage ── */}
      {isBlocked && (
        <View style={styles.blockBanner}>
          <Text style={styles.blockBannerTitle}>❌ Wallet insuffisant</Text>
          <Text style={styles.blockBannerText}>
            Rechargez pour reprendre les missions.
          </Text>
          <TouchableOpacity
            onPress={() =>
              navigation.navigate('WalletTopup', {
                walletId: dashboard.wallet_id,
                currentBalance: balance,
                minimumBalance: minimum,
              })
            }
          >
            <Text style={styles.blockBannerCta}>Recharger maintenant →</Text>
          </TouchableOpacity>
        </View>
      )}

      {/* ── Statistiques ── */}
      <Text style={styles.sectionTitle}>── STATISTIQUES ──</Text>
      <View style={styles.statsGrid}>
        <View style={styles.statCard}>
          <Text style={styles.statIcon}>🚚</Text>
          <Text style={styles.statValue}>{dashboard.total_missions}</Text>
          <Text style={styles.statLabel}>Missions total</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statIcon}>💸</Text>
          <Text style={styles.statValue}>{formatAmount(dashboard.total_commissions)} DH</Text>
          <Text style={styles.statLabel}>Commissions totales</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statIcon}>🚚</Text>
          <Text style={styles.statValue}>
            {/* monthly missions not in view — derived from active+pending */}
            {dashboard.active_missions + dashboard.pending_missions}
          </Text>
          <Text style={styles.statLabel}>Ce mois (actives)</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statIcon}>💸</Text>
          <Text style={styles.statValue}>
            {formatAmount(dashboard.commissions_current_month)} DH
          </Text>
          <Text style={styles.statLabel}>Commissions ce mois</Text>
        </View>
      </View>

      {/* ── Note moyenne ── */}
      <Text style={styles.sectionTitle}>── NOTE MOYENNE ──</Text>
      <Text style={styles.ratingText}>
        ⭐ {dashboard.rating_average?.toFixed(1) ?? '—'} / 5{' '}
        <Text style={styles.ratingSubtext}>({dashboard.total_reviews} avis)</Text>
      </Text>

      {/* ── Revenus mois ── */}
      <Text style={styles.sectionTitle}>── REVENUS CE MOIS ──</Text>
      <Text style={styles.revenueText}>
        {formatAmount(dashboard.revenue_current_month)} DH
      </Text>

      {/* ── CTA Buttons ── */}
      <TouchableOpacity
        style={styles.topupButton}
        onPress={() =>
          navigation.navigate('WalletTopup', {
            walletId: dashboard.wallet_id,
            currentBalance: balance,
            minimumBalance: minimum,
          })
        }
      >
        <Text style={styles.topupButtonText}>Recharger mon wallet</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.historyLink}
        onPress={() =>
          navigation.navigate('TransactionHistory', { walletId: dashboard.wallet_id })
        }
      >
        <Text style={styles.historyLinkText}>Voir l'historique →</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background ?? '#F5F5F5' },
  content: { padding: 16, paddingBottom: 40 },
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  errorText: { color: COLORS.alert ?? '#DC3545', fontSize: 14 },

  screenTitle: {
    fontSize: 22,
    fontWeight: '700',
    color: COLORS.text ?? '#1A1A1A',
    marginBottom: 16,
  },

  // Balance card
  balanceCard: {
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderRadius: 12,
    padding: 20,
    alignItems: 'center',
    marginBottom: 16,
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowOffset: { width: 0, height: 2 },
    shadowRadius: 6,
    elevation: 3,
  },
  balanceLabel: { fontSize: 12, color: COLORS.textSecondary ?? '#777', marginBottom: 6, letterSpacing: 1 },
  balanceAmount: { fontSize: 40, fontWeight: '800', marginBottom: 8 },
  minimumLabel: { fontSize: 13, color: COLORS.textSecondary ?? '#777', marginBottom: 12 },
  progressTrack: {
    width: '100%',
    height: 8,
    backgroundColor: COLORS.border ?? '#E0E0E0',
    borderRadius: 4,
    overflow: 'hidden',
  },
  progressFill: { height: 8, borderRadius: 4 },

  // Block banner
  blockBanner: {
    borderWidth: 1,
    borderColor: COLORS.alert ?? '#DC3545',
    backgroundColor: '#FFF5F5',
    borderRadius: 10,
    padding: 14,
    marginBottom: 16,
  },
  blockBannerTitle: { fontSize: 15, fontWeight: '700', color: COLORS.alert ?? '#DC3545', marginBottom: 4 },
  blockBannerText: { fontSize: 13, color: COLORS.alert ?? '#DC3545', marginBottom: 8 },
  blockBannerCta: { fontSize: 13, fontWeight: '600', color: COLORS.alert ?? '#DC3545', textDecorationLine: 'underline' },

  // Stats
  sectionTitle: {
    fontSize: 12,
    color: COLORS.textSecondary ?? '#777',
    letterSpacing: 1,
    marginBottom: 10,
    marginTop: 16,
  },
  statsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginBottom: 4 },
  statCard: {
    flex: 1,
    minWidth: '45%',
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderRadius: 10,
    padding: 14,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.04,
    shadowOffset: { width: 0, height: 1 },
    shadowRadius: 4,
    elevation: 2,
  },
  statIcon: { fontSize: 20, marginBottom: 4 },
  statValue: { fontSize: 16, fontWeight: '700', color: COLORS.text ?? '#1A1A1A', marginBottom: 2 },
  statLabel: { fontSize: 11, color: COLORS.textSecondary ?? '#777', textAlign: 'center' },

  // Rating
  ratingText: { fontSize: 18, fontWeight: '600', color: COLORS.text ?? '#1A1A1A', marginBottom: 4 },
  ratingSubtext: { fontSize: 13, color: COLORS.textSecondary ?? '#777', fontWeight: '400' },

  // Revenue
  revenueText: { fontSize: 20, fontWeight: '700', color: COLORS.success ?? '#28A745', marginBottom: 4 },

  // CTA
  topupButton: {
    backgroundColor: COLORS.cta ?? '#FFC107',
    borderRadius: 10,
    height: 52,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 24,
  },
  topupButtonText: { fontSize: 16, fontWeight: '700', color: '#1A1A1A' },
  historyLink: { marginTop: 16, alignItems: 'center' },
  historyLinkText: { fontSize: 14, color: COLORS.primary ?? '#007AFF', fontWeight: '600' },
});
