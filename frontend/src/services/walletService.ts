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
