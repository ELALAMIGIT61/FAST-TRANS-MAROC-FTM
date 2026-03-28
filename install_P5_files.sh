#!/bin/bash
mkdir -p frontend/src/services
mkdir -p frontend/src/screens/driver

cat > frontend/src/services/walletService.ts << 'ENDOFFILE'
import { supabase } from '../lib/supabaseClient';
import { RealtimeChannel } from '@supabase/supabase-js';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface DriverDashboard {
  driver_id: string;
  full_name: string;
  vehicle_category: string;
  rating_average: number;
  total_missions: number;
  total_reviews: number;
  wallet_id: string;
  wallet_balance: number;
  minimum_balance: number;
  total_earned: number;
  total_commissions: number;
  is_wallet_blocked: boolean;
  is_available: boolean;
  is_verified: boolean;
  pending_missions: number;
  active_missions: number;
  revenue_current_month: number;
  commissions_current_month: number;
}

export interface WalletBalance {
  id: string;
  balance: number;
  minimum_balance: number;
  total_commissions: number;
}

export interface Transaction {
  id: string;
  wallet_id: string;
  mission_id: string | null;
  transaction_type: 'commission' | 'topup' | 'refund';
  amount: number;
  balance_before: number;
  balance_after: number;
  status: 'pending' | 'completed' | 'failed';
  description: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
  processed_at: string | null;
  missions?: {
    mission_number: string;
    pickup_city: string;
    dropoff_city: string;
    vehicle_category: string;
  } | null;
}

export type TransactionFilter = 'all' | 'commission' | 'topup' | 'refund';
export type VehicleCategory = 'vul' | 'n2_medium' | 'n2_large';

// ─── getDriverDashboard ───────────────────────────────────────────────────────

export async function getDriverDashboard(
  driverId: string
): Promise<{ success?: true; dashboard?: DriverDashboard; error?: string }> {
  console.log('[FTM-DEBUG] Wallet - Fetching driver dashboard', { driverId });

  const { data, error } = await supabase
    .from('driver_dashboard')
    .select('*')
    .eq('driver_id', driverId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Wallet - Dashboard fetch error', {
      driverId,
      error: error.message,
    });
    return { error: error.message };
  }

  const dashboard = data as DriverDashboard;

  console.log('[FTM-DEBUG] Wallet - Dashboard loaded', {
    driverId,
    walletBalance: dashboard.wallet_balance,
    minimumBalance: dashboard.minimum_balance,
    isWalletBlocked: dashboard.is_wallet_blocked,
    totalCommissions: dashboard.total_commissions,
    totalMissions: dashboard.total_missions,
    revenueThisMonth: dashboard.revenue_current_month,
    commissionsThisMonth: dashboard.commissions_current_month,
  });

  return { success: true, dashboard };
}

// ─── getWalletBalance ─────────────────────────────────────────────────────────

export async function getWalletBalance(driverId: string): Promise<{
  success?: true;
  walletId?: string;
  balance?: number;
  minimum?: number;
  isBlocked?: boolean;
  error?: string;
}> {
  console.log('[FTM-DEBUG] Wallet - Fetching balance', { driverId });

  const { data, error } = await supabase
    .from('wallet')
    .select('id, balance, minimum_balance, total_commissions')
    .eq('driver_id', driverId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Wallet - Balance fetch error', {
      driverId,
      error: error.message,
    });
    return { error: error.message };
  }

  const wallet = data as WalletBalance;
  const isBlocked = wallet.balance < wallet.minimum_balance;

  console.log('[FTM-DEBUG] Wallet - Balance fetched', {
    driverId,
    balance: wallet.balance,
    minimum: wallet.minimum_balance,
    isBlocked,
  });

  return {
    success: true,
    walletId: wallet.id,
    balance: wallet.balance,
    minimum: wallet.minimum_balance,
    isBlocked,
  };
}

// ─── topupWallet ──────────────────────────────────────────────────────────────

export async function topupWallet(
  walletId: string,
  amount: number,
  agentRef: string
): Promise<{
  success?: true;
  balanceBefore?: number;
  balanceAfter?: number;
  transaction?: Transaction;
  error?: string;
}> {
  console.log('[FTM-DEBUG] Wallet - Topup initiated', { walletId, amount, agentRef });

  if (parseFloat(String(amount)) < 100) {
    console.log('[FTM-DEBUG] Wallet - Topup amount too low', { amount });
    return { error: 'Recharge minimum : 100 DH' };
  }

  const { data: currentWallet, error: fetchError } = await supabase
    .from('wallet')
    .select('balance')
    .eq('id', walletId)
    .single();

  if (fetchError) {
    console.log('[FTM-DEBUG] Wallet - Topup fetch error', { error: fetchError.message });
    return { error: fetchError.message };
  }

  const balanceBefore = parseFloat(String((currentWallet as { balance: number }).balance));
  const balanceAfter = balanceBefore + parseFloat(String(amount));

  const { error: updateError } = await supabase
    .from('wallet')
    .update({ balance: balanceAfter })
    .eq('id', walletId);

  if (updateError) {
    console.log('[FTM-DEBUG] Wallet - Topup update error', { error: updateError.message });
    return { error: updateError.message };
  }

  const { data: transaction, error: txError } = await supabase
    .from('transactions')
    .insert({
      wallet_id: walletId,
      mission_id: null,
      transaction_type: 'topup',
      amount: parseFloat(String(amount)),
      balance_before: balanceBefore,
      balance_after: balanceAfter,
      status: 'completed',
      description: `Recharge wallet — Réf: ${agentRef || 'N/A'}`,
      metadata: { agent_ref: agentRef, payment_method: 'cash_agent' },
      processed_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (txError) {
    console.log('[FTM-DEBUG] Wallet - Topup transaction record error', {
      error: txError.message,
    });
  }

  console.log('[FTM-DEBUG] Wallet - Topup completed', {
    walletId,
    amount,
    balanceBefore,
    balanceAfter,
    transactionId: (transaction as Transaction | null)?.id,
  });

  return {
    success: true,
    balanceBefore,
    balanceAfter,
    transaction: transaction as Transaction,
  };
}

// ─── refundWallet ─────────────────────────────────────────────────────────────

export async function refundWallet(
  walletId: string,
  amount: number,
  missionId: string | null,
  reason: string
): Promise<{
  success?: true;
  balanceBefore?: number;
  balanceAfter?: number;
  transaction?: Transaction;
  error?: string;
}> {
  console.log('[FTM-DEBUG] Wallet - Refund initiated', {
    walletId,
    amount,
    missionId,
    reason,
  });

  const { data: currentWallet, error: fetchError } = await supabase
    .from('wallet')
    .select('balance')
    .eq('id', walletId)
    .single();

  if (fetchError) {
    console.log('[FTM-DEBUG] Wallet - Refund fetch error', { error: fetchError.message });
    return { error: fetchError.message };
  }

  const balanceBefore = parseFloat(String((currentWallet as { balance: number }).balance));
  const balanceAfter = balanceBefore + parseFloat(String(amount));

  const { error: updateError } = await supabase
    .from('wallet')
    .update({ balance: balanceAfter })
    .eq('id', walletId);

  if (updateError) {
    console.log('[FTM-DEBUG] Wallet - Refund update error', { error: updateError.message });
    return { error: updateError.message };
  }

  const { data: transaction, error: txError } = await supabase
    .from('transactions')
    .insert({
      wallet_id: walletId,
      mission_id: missionId || null,
      transaction_type: 'refund',
      amount: parseFloat(String(amount)),
      balance_before: balanceBefore,
      balance_after: balanceAfter,
      status: 'completed',
      description: `Remboursement — ${reason}`,
      metadata: { reason, initiated_by: 'admin' },
      processed_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (txError) {
    console.log('[FTM-DEBUG] Wallet - Refund transaction record error', {
      error: txError.message,
    });
  }

  console.log('[FTM-DEBUG] Wallet - Refund completed', {
    walletId,
    amount,
    balanceBefore,
    balanceAfter,
    reason,
    transactionId: (transaction as Transaction | null)?.id,
  });

  return {
    success: true,
    balanceBefore,
    balanceAfter,
    transaction: transaction as Transaction,
  };
}

// ─── getTransactionHistory ────────────────────────────────────────────────────

export async function getTransactionHistory(
  walletId: string,
  page = 0,
  filter: TransactionFilter = 'all'
): Promise<{
  success?: true;
  transactions?: Transaction[];
  totalCount?: number;
  hasMore?: boolean;
  error?: string;
}> {
  const PAGE_SIZE = 20;
  const from = page * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

  console.log('[FTM-DEBUG] Wallet - Fetching transaction history', {
    walletId,
    page,
    filter,
    range: `${from}-${to}`,
  });

  let query = supabase
    .from('transactions')
    .select(
      `
      id,
      transaction_type,
      amount,
      balance_before,
      balance_after,
      status,
      description,
      metadata,
      created_at,
      processed_at,
      missions (
        mission_number,
        pickup_city,
        dropoff_city,
        vehicle_category
      )
    `,
      { count: 'exact' }
    )
    .eq('wallet_id', walletId)
    .order('created_at', { ascending: false })
    .range(from, to);

  if (filter !== 'all') {
    query = query.eq('transaction_type', filter);
  }

  const { data, error, count } = await query;

  if (error) {
    console.log('[FTM-DEBUG] Wallet - Transaction history fetch error', {
      error: error.message,
    });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Wallet - Transaction history fetched', {
    walletId,
    count: data?.length,
    totalCount: count,
    page,
    filter,
  });

  return {
    success: true,
    transactions: (data as Transaction[]) || [],
    totalCount: count ?? 0,
    hasMore: (from + PAGE_SIZE) < (count ?? 0),
  };
}

// ─── checkAndEnforceWalletBlock ───────────────────────────────────────────────

export async function checkAndEnforceWalletBlock(
  driverId: string,
  walletId: string
): Promise<{
  success?: true;
  isBlocked?: boolean;
  balance?: number;
  minimum?: number;
  error?: string;
}> {
  console.log('[FTM-DEBUG] Wallet - Checking block status', { driverId, walletId });

  const { data: wallet, error } = await supabase
    .from('wallet')
    .select('balance, minimum_balance')
    .eq('id', walletId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Wallet - Block check fetch error', { error: error.message });
    return { error: error.message };
  }

  const w = wallet as { balance: number; minimum_balance: number };
  const isBlocked = w.balance < w.minimum_balance;

  if (isBlocked) {
    console.log('[FTM-DEBUG] Wallet - BLOCKED — balance below minimum', {
      driverId,
      balance: w.balance,
      minimum: w.minimum_balance,
      deficit: (w.minimum_balance - w.balance).toFixed(2) + ' DH',
    });

    const { error: blockError } = await supabase
      .from('drivers')
      .update({ is_available: false })
      .eq('id', driverId);

    if (blockError) {
      console.log('[FTM-DEBUG] Wallet - Block enforcement error', {
        error: blockError.message,
      });
    } else {
      console.log('[FTM-DEBUG] Wallet - Driver availability forced to false', { driverId });
    }
  } else {
    console.log('[FTM-DEBUG] Wallet - Balance OK, no block applied', {
      driverId,
      balance: w.balance,
      minimum: w.minimum_balance,
    });
  }

  return {
    success: true,
    isBlocked,
    balance: w.balance,
    minimum: w.minimum_balance,
  };
}

// ─── canDriverAcceptMission ───────────────────────────────────────────────────

export async function canDriverAcceptMission(
  driverId: string,
  vehicleCategory: VehicleCategory
): Promise<{
  canAccept: boolean;
  reason?: string;
  needed?: number;
  error?: string;
}> {
  console.log('[FTM-DEBUG] Wallet - Checking driver eligibility', {
    driverId,
    vehicleCategory,
  });

  const COMMISSION_MAP: Record<VehicleCategory, number> = {
    vul: 25,
    n2_medium: 40,
    n2_large: 50,
  };
  const commission = COMMISSION_MAP[vehicleCategory] ?? 25;

  const { data: wallet, error } = await supabase
    .from('wallet')
    .select('balance, minimum_balance')
    .eq('driver_id', driverId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Wallet - Eligibility check error', { error: error.message });
    return { canAccept: false, error: error.message };
  }

  const w = wallet as { balance: number; minimum_balance: number };
  const balanceAfterCommission = w.balance - commission;
  const canAccept =
    w.balance >= w.minimum_balance && balanceAfterCommission >= 0;

  console.log('[FTM-DEBUG] Wallet - Eligibility result', {
    driverId,
    currentBalance: w.balance,
    minimum: w.minimum_balance,
    futureCommission: commission,
    balanceAfterCommission,
    canAccept,
  });

  if (!canAccept) {
    const needed = Math.max(
      w.minimum_balance - w.balance,
      commission - w.balance
    );
    return {
      canAccept: false,
      reason: `Solde insuffisant. Rechargez au moins ${needed.toFixed(2)} DH pour accepter cette mission.`,
      needed,
    };
  }

  return { canAccept: true };
}

// ─── subscribeToWalletUpdates ─────────────────────────────────────────────────

export function subscribeToWalletUpdates(
  walletId: string,
  driverId: string,
  onUpdate: (data: { balance: number; minimum: number; isBlocked: boolean }) => void
): RealtimeChannel {
  console.log('[FTM-DEBUG] Wallet - Subscribing to wallet updates', { walletId });

  const channel = supabase
    .channel(`wallet-${walletId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'wallet',
        filter: `id=eq.${walletId}`,
      },
      async (payload) => {
        const newData = payload.new as { balance: number; minimum_balance: number };
        const oldData = payload.old as { balance: number };
        const newBalance = newData.balance;
        const oldBalance = oldData.balance;
        const minimum = newData.minimum_balance;
        const isBlocked = newBalance < minimum;

        console.log('[FTM-DEBUG] Wallet - Balance updated via Realtime', {
          walletId,
          oldBalance,
          newBalance,
          delta: (newBalance - oldBalance).toFixed(2) + ' DH',
          isBlocked,
        });

        if (isBlocked) {
          await checkAndEnforceWalletBlock(driverId, walletId);
        }

        onUpdate({ balance: newBalance, minimum, isBlocked });
      }
    )
    .subscribe((status) => {
      console.log('[FTM-DEBUG] Wallet - Subscription status', { walletId, status });
    });

  return channel;
}

// ─── subscribeToNewTransactions ───────────────────────────────────────────────

export function subscribeToNewTransactions(
  walletId: string,
  onNewTransaction: (tx: Transaction) => void
): RealtimeChannel {
  console.log('[FTM-DEBUG] Wallet - Subscribing to new transactions', { walletId });

  const channel = supabase
    .channel(`transactions-${walletId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'transactions',
        filter: `wallet_id=eq.${walletId}`,
      },
      (payload) => {
        const tx = payload.new as Transaction;
        console.log('[FTM-DEBUG] Wallet - New transaction received', {
          walletId,
          type: tx.transaction_type,
          amount: tx.amount,
          balanceBefore: tx.balance_before,
          balanceAfter: tx.balance_after,
          status: tx.status,
        });
        onNewTransaction(tx);
      }
    )
    .subscribe();

  return channel;
}

// ─── notifyWalletLowBalance ───────────────────────────────────────────────────

export async function notifyWalletLowBalance(
  profileId: string,
  balance: number,
  minimum: number
): Promise<void> {
  const deficit = (minimum - balance).toFixed(2);

  console.log('[FTM-DEBUG] Wallet - Sending low balance notification', {
    profileId,
    balance,
    minimum,
    deficit,
  });

  const { error } = await supabase.from('notifications').insert({
    profile_id: profileId,
    title: 'Wallet insuffisant — Missions bloquées',
    body: `Votre solde (${balance} DH) est sous le minimum requis. Rechargez ${deficit} DH pour reprendre les missions.`,
    type: 'wallet_low_balance',
    data: { balance, minimum, deficit, action: 'topup_wallet' },
    is_read: false,
  });

  if (error) {
    console.log('[FTM-DEBUG] Wallet - Low balance notification error', {
      error: error.message,
    });
  } else {
    console.log('[FTM-DEBUG] Wallet - Low balance notification inserted', {
      profileId,
      balance,
    });
  }
}
ENDOFFILE

cat > frontend/src/screens/driver/WalletDashboardScreen.tsx << 'ENDOFFILE'
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
ENDOFFILE

cat > frontend/src/screens/driver/WalletTopupScreen.tsx << 'ENDOFFILE'
import React, { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';

import { COLORS } from '../../constants/theme';
import { topupWallet } from '../../services/walletService';

// ─── Types ────────────────────────────────────────────────────────────────────

type RootStackParamList = {
  WalletDashboard: undefined;
  WalletTopup: { walletId: string; currentBalance: number; minimumBalance: number };
  TransactionHistory: { walletId: string };
};

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'WalletTopup'>;
type RoutePropType = RouteProp<RootStackParamList, 'WalletTopup'>;

const PRESET_AMOUNTS = [100, 200, 300, 500, 1000];

// ─── Component ────────────────────────────────────────────────────────────────

export default function WalletTopupScreen() {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<RoutePropType>();
  const { walletId, currentBalance, minimumBalance } = route.params;

  const [selectedAmount, setSelectedAmount] = useState<number | null>(null);
  const [customAmount, setCustomAmount] = useState('');
  const [agentRef, setAgentRef] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const finalAmount = selectedAmount ?? (customAmount ? parseFloat(customAmount) : 0);
  const newBalance = currentBalance + finalAmount;
  const isValid = finalAmount >= 100;
  const deficit = Math.max(minimumBalance - currentBalance, 0);

  const handlePreset = (amount: number) => {
    setSelectedAmount(amount);
    setCustomAmount('');
  };

  const handleCustomChange = (text: string) => {
    setCustomAmount(text);
    setSelectedAmount(null);
  };

  const handleConfirm = async () => {
    if (!isValid) return;
    setIsLoading(true);
    const result = await topupWallet(walletId, finalAmount, agentRef);
    setIsLoading(false);

    if (result.error) {
      Alert.alert('Erreur', result.error);
      return;
    }

    Alert.alert(
      '✅ Recharge effectuée',
      `Nouveau solde : ${result.balanceAfter?.toFixed(2)} DH`,
      [{ text: 'OK', onPress: () => navigation.goBack() }]
    );
  };

  return (
    <KeyboardAvoidingView
      style={{ flex: 1 }}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView
        style={styles.container}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        <Text style={styles.screenTitle}>Recharger mon wallet</Text>

        {/* Current balance */}
        <View style={styles.infoBox}>
          <Text style={styles.infoRow}>
            Solde actuel :{' '}
            <Text style={{ color: currentBalance >= minimumBalance ? (COLORS.success ?? '#28A745') : (COLORS.alert ?? '#DC3545'), fontWeight: '700' }}>
              {currentBalance.toFixed(2)} DH {currentBalance >= minimumBalance ? '✅' : '❌'}
            </Text>
          </Text>
          <Text style={styles.infoRow}>Minimum requis : {minimumBalance.toFixed(2)} DH</Text>
          {deficit > 0 && (
            <Text style={[styles.infoRow, { color: COLORS.alert ?? '#DC3545' }]}>
              À recharger minimum : {deficit.toFixed(2)} DH
            </Text>
          )}
        </View>

        {/* Preset amounts */}
        <Text style={styles.sectionTitle}>── MONTANT DE RECHARGE ──</Text>
        <View style={styles.presetGrid}>
          {PRESET_AMOUNTS.map((amt) => (
            <TouchableOpacity
              key={amt}
              style={[
                styles.presetCard,
                selectedAmount === amt && styles.presetCardSelected,
              ]}
              onPress={() => handlePreset(amt)}
            >
              <Text
                style={[
                  styles.presetText,
                  selectedAmount === amt && styles.presetTextSelected,
                ]}
              >
                {amt} DH
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* Custom amount */}
        <Text style={styles.sectionTitle}>── OU MONTANT PERSONNALISÉ ──</Text>
        <TextInput
          style={styles.input}
          placeholder="Autre montant (DH)"
          placeholderTextColor={COLORS.textSecondary ?? '#999'}
          keyboardType="numeric"
          value={customAmount}
          onChangeText={handleCustomChange}
        />

        {/* Agent ref */}
        <Text style={styles.sectionTitle}>── RÉFÉRENCE DE PAIEMENT ──</Text>
        <TextInput
          style={styles.input}
          placeholder="Réf. reçu / code agent (optionnel)"
          placeholderTextColor={COLORS.textSecondary ?? '#999'}
          value={agentRef}
          onChangeText={setAgentRef}
        />

        {/* Summary */}
        {finalAmount > 0 && (
          <View style={styles.summaryBox}>
            <Text style={styles.summaryTitle}>── RÉCAPITULATIF ──</Text>
            <Text style={styles.summaryRow}>
              Solde actuel : {currentBalance.toFixed(2)} DH
            </Text>
            <Text style={styles.summaryRow}>
              Recharge :{' '}
              <Text style={{ color: COLORS.success ?? '#28A745', fontWeight: '700' }}>
                +{finalAmount.toFixed(2)} DH
              </Text>
            </Text>
            <Text style={styles.summaryRow}>
              Nouveau solde :{' '}
              <Text
                style={{
                  color: newBalance >= minimumBalance ? (COLORS.success ?? '#28A745') : (COLORS.alert ?? '#DC3545'),
                  fontWeight: '700',
                }}
              >
                {newBalance.toFixed(2)} DH {newBalance >= minimumBalance ? '✅' : '⚠️'}
              </Text>
            </Text>
          </View>
        )}

        {/* Info note */}
        <View style={styles.noteBox}>
          <Text style={styles.noteText}>
            ℹ️ Le paiement s'effectue en espèces auprès d'un agent FTM.
            Présentez votre numéro de téléphone à l'agent.
          </Text>
        </View>

        {/* CTA */}
        <TouchableOpacity
          style={[styles.confirmButton, !isValid && styles.confirmButtonDisabled]}
          onPress={handleConfirm}
          disabled={!isValid || isLoading}
        >
          {isLoading ? (
            <ActivityIndicator color="#1A1A1A" />
          ) : (
            <Text style={styles.confirmButtonText}>Confirmer la recharge</Text>
          )}
        </TouchableOpacity>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background ?? '#F5F5F5' },
  content: { padding: 16, paddingBottom: 40 },
  screenTitle: {
    fontSize: 22,
    fontWeight: '700',
    color: COLORS.text ?? '#1A1A1A',
    marginBottom: 16,
  },

  infoBox: {
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderRadius: 10,
    padding: 14,
    marginBottom: 16,
  },
  infoRow: { fontSize: 14, color: COLORS.text ?? '#1A1A1A', marginBottom: 4 },

  sectionTitle: {
    fontSize: 12,
    color: COLORS.textSecondary ?? '#777',
    letterSpacing: 1,
    marginBottom: 10,
    marginTop: 16,
  },

  presetGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  presetCard: {
    flex: 1,
    minWidth: '28%',
    borderWidth: 1.5,
    borderColor: COLORS.border ?? '#E0E0E0',
    borderRadius: 8,
    paddingVertical: 12,
    alignItems: 'center',
    backgroundColor: COLORS.white ?? '#FFFFFF',
  },
  presetCardSelected: {
    borderColor: COLORS.primary ?? '#007AFF',
    backgroundColor: (COLORS.primary ?? '#007AFF') + '15',
  },
  presetText: { fontSize: 15, fontWeight: '600', color: COLORS.text ?? '#1A1A1A' },
  presetTextSelected: { color: COLORS.primary ?? '#007AFF' },

  input: {
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderWidth: 1,
    borderColor: COLORS.border ?? '#E0E0E0',
    borderRadius: 8,
    height: 48,
    paddingHorizontal: 14,
    fontSize: 15,
    color: COLORS.text ?? '#1A1A1A',
  },

  summaryBox: {
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderRadius: 10,
    padding: 14,
    marginTop: 16,
  },
  summaryTitle: { fontSize: 12, color: COLORS.textSecondary ?? '#777', letterSpacing: 1, marginBottom: 8 },
  summaryRow: { fontSize: 14, color: COLORS.text ?? '#1A1A1A', marginBottom: 4 },

  noteBox: {
    backgroundColor: '#FFF9E6',
    borderRadius: 8,
    padding: 12,
    marginTop: 16,
  },
  noteText: { fontSize: 13, color: '#7A6000', lineHeight: 18 },

  confirmButton: {
    backgroundColor: COLORS.primary ?? '#007AFF',
    borderRadius: 10,
    height: 52,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 24,
  },
  confirmButtonDisabled: { opacity: 0.4 },
  confirmButtonText: { fontSize: 16, fontWeight: '700', color: COLORS.white ?? '#FFFFFF' },
});
ENDOFFILE

cat > frontend/src/screens/driver/TransactionHistoryScreen.tsx << 'ENDOFFILE'
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
ENDOFFILE

cat > frontend/src/screens/driver/TransactionDetailModal.tsx << 'ENDOFFILE'
import React from 'react';
import {
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

import { COLORS } from '../../constants/theme';
import { Transaction } from '../../services/walletService';

// ─── Types ────────────────────────────────────────────────────────────────────

interface TransactionDetailModalProps {
  transaction: Transaction | null;
  visible: boolean;
  onClose: () => void;
}

interface TransactionConfig {
  icon: string;
  label: string;
  color: string;
  sign: string;
}

// ─── Config ───────────────────────────────────────────────────────────────────

const TRANSACTION_CONFIG: Record<string, TransactionConfig> = {
  commission: { icon: '💸', label: 'Commission FTM', color: '#DC3545', sign: '−' },
  topup:      { icon: '💰', label: 'Recharge',        color: '#28A745', sign: '+' },
  refund:     { icon: '↩️', label: 'Remboursement',   color: '#28A745', sign: '+' },
};

const VEHICLE_LABELS: Record<string, string> = {
  vul:       '🚐 VUL',
  n2_medium: '🚛 N2 Medium',
  n2_large:  '🚚 N2 Large',
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

function formatDate(isoDate: string | null): string {
  if (!isoDate) return '—';
  const d = new Date(isoDate);
  return d.toLocaleDateString('fr-MA', {
    day:    '2-digit',
    month:  '2-digit',
    year:   'numeric',
    hour:   '2-digit',
    minute: '2-digit',
  });
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={styles.rowValue}>{value}</Text>
    </View>
  );
}

// ─── Component ────────────────────────────────────────────────────────────────

export default function TransactionDetailModal({
  transaction,
  visible,
  onClose,
}: TransactionDetailModalProps) {
  if (!transaction) return null;

  const cfg = TRANSACTION_CONFIG[transaction.transaction_type] ?? TRANSACTION_CONFIG.commission;
  const isFailed = transaction.status === 'failed';
  const metadata = transaction.metadata as Record<string, string> | null;

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
    >
      <View style={styles.container}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.headerTitle}>
            {cfg.icon} {cfg.label}
          </Text>
          <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
            <Text style={styles.closeBtnText}>✕</Text>
          </TouchableOpacity>
        </View>

        <ScrollView contentContainerStyle={styles.content}>
          {/* Amount */}
          <View style={styles.amountSection}>
            <Text style={[styles.amountText, { color: cfg.color }]}>
              {cfg.sign} {transaction.amount.toFixed(2)} DH
            </Text>
            <View
              style={[
                styles.statusBadge,
                { backgroundColor: isFailed ? '#DC3545' : '#28A745' },
              ]}
            >
              <Text style={styles.statusBadgeText}>
                {isFailed ? '❌ Échoué' : '✅ Complété'}
              </Text>
            </View>
          </View>

          {/* Détails */}
          <Text style={styles.sectionTitle}>── DÉTAILS ──</Text>
          <Row label="Type" value={cfg.label} />
          <Row
            label="Date"
            value={formatDate(transaction.processed_at ?? transaction.created_at)}
          />
          {transaction.description && (
            <Row label="Description" value={transaction.description} />
          )}

          {/* Solde */}
          <Text style={styles.sectionTitle}>── SOLDE ──</Text>
          <Row label="Avant" value={`${transaction.balance_before.toFixed(2)} DH`} />
          <Row label="Après" value={`${transaction.balance_after.toFixed(2)} DH`} />

          {/* Mission associée */}
          {transaction.missions && (
            <>
              <Text style={styles.sectionTitle}>── MISSION ASSOCIÉE ──</Text>
              <Row label="N°" value={transaction.missions.mission_number} />
              <Row
                label="Trajet"
                value={`${transaction.missions.pickup_city} → ${transaction.missions.dropoff_city}`}
              />
              <Row
                label="Véhicule"
                value={VEHICLE_LABELS[transaction.missions.vehicle_category] ?? transaction.missions.vehicle_category}
              />
            </>
          )}

          {/* Metadata (topup/refund) */}
          {metadata && Object.keys(metadata).length > 0 && (
            <>
              <Text style={styles.sectionTitle}>── INFORMATIONS PAIEMENT ──</Text>
              {metadata.agent_ref && (
                <Row label="Réf agent" value={metadata.agent_ref} />
              )}
              {metadata.payment_method && (
                <Row
                  label="Méthode"
                  value={
                    metadata.payment_method === 'cash_agent' ? 'Cash agent' : metadata.payment_method
                  }
                />
              )}
              {metadata.reason && (
                <Row label="Motif" value={metadata.reason} />
              )}
            </>
          )}

          <TouchableOpacity style={styles.closeButton} onPress={onClose}>
            <Text style={styles.closeButtonText}>Fermer</Text>
          </TouchableOpacity>
        </ScrollView>
      </View>
    </Modal>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background ?? '#F5F5F5' },

  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 12,
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border ?? '#E0E0E0',
  },
  headerTitle: { fontSize: 17, fontWeight: '700', color: COLORS.text ?? '#1A1A1A', flex: 1 },
  closeBtn: { padding: 4 },
  closeBtnText: { fontSize: 18, color: COLORS.textSecondary ?? '#777' },

  content: { padding: 16, paddingBottom: 40 },

  amountSection: { alignItems: 'center', paddingVertical: 24 },
  amountText: { fontSize: 36, fontWeight: '800', marginBottom: 10 },
  statusBadge: { borderRadius: 20, paddingHorizontal: 14, paddingVertical: 5 },
  statusBadgeText: { color: '#FFFFFF', fontWeight: '700', fontSize: 13 },

  sectionTitle: {
    fontSize: 11,
    color: COLORS.textSecondary ?? '#777',
    letterSpacing: 1,
    marginTop: 20,
    marginBottom: 10,
  },

  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border ?? '#F0F0F0',
  },
  rowLabel: { fontSize: 13, color: COLORS.textSecondary ?? '#777', flex: 1 },
  rowValue: { fontSize: 13, fontWeight: '600', color: COLORS.text ?? '#1A1A1A', flex: 2, textAlign: 'right' },

  closeButton: {
    backgroundColor: COLORS.primary ?? '#007AFF',
    borderRadius: 10,
    height: 48,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 28,
  },
  closeButtonText: { fontSize: 15, fontWeight: '700', color: COLORS.white ?? '#FFFFFF' },
});
ENDOFFILE

echo "✅ Fichiers P5 créés"