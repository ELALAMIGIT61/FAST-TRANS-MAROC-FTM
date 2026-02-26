# SPEC NATIVELY — Fast Trans Maroc (FTM)
# PARTIE P5 : Wallet Revolving & Transactions
# Fichier : docs/SPEC_NATIVELY_P5.md
# Version : 1.0 | Backend : Supabase | App : Natively.dev
# =====================================================================
# PRÉREQUIS : P1 (Auth), P2 (wallet créé à l'onboarding driver),
#             P3 (completeMission déclenche trigger commission)
# TABLES SQL : wallet, transactions, drivers, missions
# VUES SQL   : driver_dashboard
# TRIGGERS   : trigger_process_commission (défini dans schéma SQL initial)
# =====================================================================

---

## 1. CONTEXTE & LOGIQUE MÉTIER WALLET

```
MODÈLE ÉCONOMIQUE FTM — Wallet Revolving

Le chauffeur maintient un SOLDE PRÉPAYÉ dans son wallet.
À chaque mission complétée, FTM prélève automatiquement la commission.

RÈGLE FONDAMENTALE :
  wallet.balance >= wallet.minimum_balance (100 DH)
  pour pouvoir accepter de nouvelles missions.

  Si balance < 100 DH → Driver BLOQUÉ jusqu'à recharge.

FLUX FINANCIER :
  ┌─────────────────────────────────────────────────────┐
  │  Driver recharge son wallet (topup)                 │
  │  wallet.balance += montant_recharge                 │
  └─────────────────────────────────────────────────────┘
                          │
                          ▼
  ┌─────────────────────────────────────────────────────┐
  │  Driver complète une mission                        │
  │  trigger_process_commission() déclenché AUTO :      │
  │  wallet.balance         -= commission_amount        │
  │  wallet.total_commissions += commission_amount      │
  │  → INSERT transactions (type='commission')          │
  │  → UPDATE drivers.total_missions + 1               │
  └─────────────────────────────────────────────────────┘
                          │
                          ▼
  ┌─────────────────────────────────────────────────────┐
  │  Si wallet.balance < 100 DH :                       │
  │  → drivers.is_available forcé à FALSE               │
  │  → Notification Push "Rechargez votre wallet"       │
  │  → Blocage acceptation nouvelles missions           │
  └─────────────────────────────────────────────────────┘

COMMISSIONS PAR CATÉGORIE (via calculate_commission()) :
  'vul'       → 25 DH
  'n2_medium' → 40 DH
  'n2_large'  → 50 DH
```

---

## 2. STRUCTURE SQL DE RÉFÉRENCE

### 2.1 Table wallet

```sql
-- TABLE: wallet — Source de vérité
CREATE TABLE wallet (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id         UUID REFERENCES drivers(id) ON DELETE CASCADE UNIQUE NOT NULL,

    balance           DECIMAL(10,2) DEFAULT 0 CHECK (balance >= 0),
    -- ⚠️ CHECK balance >= 0 : empêche solde négatif au niveau BDD
    -- Le trigger vérifie le seuil AVANT de déduire

    minimum_balance   DECIMAL(10,2) DEFAULT 100.00,
    -- Seuil de blocage (100 DH par défaut, modifiable par Admin)

    total_earned      DECIMAL(10,2) DEFAULT 0,
    -- Cumul des gains bruts (revenus des missions — non géré par FTM)
    -- Champ informatif, alimenté manuellement si besoin

    total_commissions DECIMAL(10,2) DEFAULT 0,
    -- Cumul total des commissions prélevées par FTM

    created_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 2.2 Table transactions

```sql
-- TABLE: transactions — Historique complet
CREATE TABLE transactions (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wallet_id        UUID REFERENCES wallet(id) ON DELETE CASCADE NOT NULL,
    mission_id       UUID REFERENCES missions(id) ON DELETE SET NULL,
    -- NULL pour topup et refund non liés à une mission

    transaction_type transaction_type NOT NULL,
    -- 'commission' : prélevé automatiquement par trigger
    -- 'topup'      : recharge manuelle par le driver
    -- 'refund'     : remboursement par Admin

    amount           DECIMAL(10,2) NOT NULL,
    -- Toujours POSITIF : le signe est donné par transaction_type
    -- commission → soustrait du solde
    -- topup/refund → ajouté au solde

    balance_before   DECIMAL(10,2) NOT NULL,
    balance_after    DECIMAL(10,2) NOT NULL,

    status           transaction_status DEFAULT 'pending',
    -- 'pending' | 'completed' | 'failed'

    description      TEXT,
    -- ex: "Commission pour mission FTM20260220047"
    --     "Recharge wallet — Agence Casablanca"
    --     "Remboursement mission annulée FTM20260220031"

    metadata         JSONB,
    -- Données additionnelles libres :
    -- { "payment_method": "cash_agent", "agent_id": "...", "receipt_ref": "..." }

    created_at       TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at     TIMESTAMP WITH TIME ZONE
);
```

### 2.3 Vue driver_dashboard

```sql
-- VUE: driver_dashboard — Tableau de bord complet chauffeur
CREATE OR REPLACE VIEW driver_dashboard AS
SELECT
    d.id                AS driver_id,
    p.full_name,
    d.vehicle_category,
    d.rating_average,
    d.total_missions,
    d.total_reviews,
    w.id                AS wallet_id,
    w.balance           AS wallet_balance,
    w.minimum_balance,
    w.total_earned,
    w.total_commissions,
    -- Indicateur de blocage calculé
    (w.balance < w.minimum_balance) AS is_wallet_blocked,
    d.is_available,
    d.is_verified,
    -- Missions actives en cours
    COUNT(CASE WHEN m.status = 'pending'     THEN 1 END) AS pending_missions,
    COUNT(CASE WHEN m.status = 'in_progress' THEN 1 END) AS active_missions,
    -- Revenus du mois en cours (missions complétées ce mois)
    COALESCE(SUM(
        CASE WHEN m.status = 'completed'
             AND DATE_TRUNC('month', m.completed_at) = DATE_TRUNC('month', NOW())
        THEN m.negotiated_price END
    ), 0) AS revenue_current_month,
    -- Commissions du mois en cours
    COALESCE(SUM(
        CASE WHEN m.status = 'completed'
             AND DATE_TRUNC('month', m.completed_at) = DATE_TRUNC('month', NOW())
        THEN m.commission_amount END
    ), 0) AS commissions_current_month
FROM drivers d
INNER JOIN profiles p ON p.id = d.profile_id
LEFT  JOIN wallet   w ON w.driver_id = d.id
LEFT  JOIN missions m ON m.driver_id = d.id
GROUP BY d.id, p.full_name, d.vehicle_category, d.rating_average,
         d.total_missions, d.total_reviews, w.id, w.balance,
         w.minimum_balance, w.total_earned, w.total_commissions,
         d.is_available, d.is_verified;
```

### 2.4 Trigger process_commission_payment (rappel)

```sql
-- TRIGGER EXISTANT dans le schéma initial — rappel pour référence P5
-- Déclenché sur UPDATE missions WHERE status passe à 'completed'

CREATE OR REPLACE FUNCTION process_commission_payment()
RETURNS TRIGGER AS $$
DECLARE
    driver_wallet_id UUID;
    current_balance  DECIMAL(10,2);
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN

        -- Récupérer le wallet du chauffeur
        SELECT w.id, w.balance INTO driver_wallet_id, current_balance
        FROM wallet w
        INNER JOIN drivers d ON d.id = w.driver_id
        WHERE d.id = NEW.driver_id;

        IF driver_wallet_id IS NOT NULL THEN

            -- ⚠️ Vérifier solde suffisant avant déduction
            -- (Le CHECK balance >= 0 empêche le passage en négatif)
            -- Si solde < commission → transaction 'failed' créée
            IF current_balance >= NEW.commission_amount THEN

                UPDATE wallet
                SET balance            = balance - NEW.commission_amount,
                    total_commissions  = total_commissions + NEW.commission_amount
                WHERE id = driver_wallet_id;

                INSERT INTO transactions (
                    wallet_id, mission_id, transaction_type,
                    amount, balance_before, balance_after,
                    status, description, processed_at
                ) VALUES (
                    driver_wallet_id, NEW.id, 'commission',
                    NEW.commission_amount,
                    current_balance,
                    current_balance - NEW.commission_amount,
                    'completed',
                    'Commission pour mission ' || NEW.mission_number,
                    NOW()
                );

            ELSE
                -- Solde insuffisant : enregistrer transaction 'failed'
                INSERT INTO transactions (
                    wallet_id, mission_id, transaction_type,
                    amount, balance_before, balance_after,
                    status, description, processed_at
                ) VALUES (
                    driver_wallet_id, NEW.id, 'commission',
                    NEW.commission_amount,
                    current_balance,
                    current_balance, -- inchangé
                    'failed',
                    'Commission ÉCHOUÉE — solde insuffisant pour mission '
                        || NEW.mission_number,
                    NOW()
                );
                -- La dette est visible dans l'historique transactions
            END IF;

            -- Mettre à jour les statistiques du chauffeur dans tous les cas
            UPDATE drivers
            SET total_missions = total_missions + 1
            WHERE id = NEW.driver_id;

        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## 3. SERVICE WALLET

```javascript
// /services/walletService.js

import { supabase } from '../lib/supabaseClient';

/**
 * RÉCUPÉRER LE DASHBOARD COMPLET DU DRIVER
 * Utilise la vue driver_dashboard
 */
export async function getDriverDashboard(driverId) {
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
    return { error };
  }

  console.log('[FTM-DEBUG] Wallet - Dashboard loaded', {
    driverId,
    walletBalance:       data.wallet_balance,
    minimumBalance:      data.minimum_balance,
    isWalletBlocked:     data.is_wallet_blocked,
    totalCommissions:    data.total_commissions,
    totalMissions:       data.total_missions,
    revenueThisMonth:    data.revenue_current_month,
    commissionsThisMonth: data.commissions_current_month,
  });

  return { success: true, dashboard: data };
}

/**
 * RÉCUPÉRER LE SOLDE ACTUEL DU WALLET
 * (Version légère — pour le header et les vérifications rapides)
 */
export async function getWalletBalance(driverId) {
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
    return { error };
  }

  const isBlocked = data.balance < data.minimum_balance;

  console.log('[FTM-DEBUG] Wallet - Balance fetched', {
    driverId,
    balance:    data.balance,
    minimum:    data.minimum_balance,
    isBlocked,
  });

  return {
    success:    true,
    walletId:   data.id,
    balance:    data.balance,
    minimum:    data.minimum_balance,
    isBlocked,
  };
}

/**
 * RECHARGER LE WALLET (TOPUP)
 * Dans FTM v1 : recharge via agent physique (cash).
 * L'opération est saisie manuellement par l'Admin (P7) ou
 * via un code de recharge fourni à l'agent.
 *
 * Cette fonction simule la recharge côté app pour les tests
 * et sera branchée sur le flux Admin/Agent en production.
 *
 * @param {string} walletId   - UUID du wallet
 * @param {number} amount     - Montant en DH (min: 100 DH)
 * @param {string} agentRef   - Référence agent / reçu cash
 */
export async function topupWallet(walletId, amount, agentRef) {
  console.log('[FTM-DEBUG] Wallet - Topup initiated', {
    walletId,
    amount,
    agentRef,
  });

  // Validation montant minimum
  if (parseFloat(amount) < 100) {
    console.log('[FTM-DEBUG] Wallet - Topup amount too low', { amount });
    return { error: 'Recharge minimum : 100 DH' };
  }

  // Récupérer le solde actuel
  const { data: currentWallet, error: fetchError } = await supabase
    .from('wallet')
    .select('balance')
    .eq('id', walletId)
    .single();

  if (fetchError) {
    console.log('[FTM-DEBUG] Wallet - Topup fetch error', { error: fetchError.message });
    return { error: fetchError.message };
  }

  const balanceBefore = parseFloat(currentWallet.balance);
  const balanceAfter  = balanceBefore + parseFloat(amount);

  // Mettre à jour le solde
  const { error: updateError } = await supabase
    .from('wallet')
    .update({ balance: balanceAfter })
    .eq('id', walletId);

  if (updateError) {
    console.log('[FTM-DEBUG] Wallet - Topup update error', { error: updateError.message });
    return { error: updateError.message };
  }

  // Enregistrer la transaction
  const { data: transaction, error: txError } = await supabase
    .from('transactions')
    .insert({
      wallet_id:        walletId,
      mission_id:       null,
      transaction_type: 'topup',
      amount:           parseFloat(amount),
      balance_before:   balanceBefore,
      balance_after:    balanceAfter,
      status:           'completed',
      description:      `Recharge wallet — Réf: ${agentRef || 'N/A'}`,
      metadata:         { agent_ref: agentRef, payment_method: 'cash_agent' },
      processed_at:     new Date().toISOString(),
    })
    .select()
    .single();

  if (txError) {
    console.log('[FTM-DEBUG] Wallet - Topup transaction record error', {
      error: txError.message,
    });
    // Non-bloquant : le solde est mis à jour, juste le log échoue
  }

  console.log('[FTM-DEBUG] Wallet - Topup completed', {
    walletId,
    amount,
    balanceBefore,
    balanceAfter,
    transactionId: transaction?.id,
  });

  return {
    success:      true,
    balanceBefore,
    balanceAfter,
    transaction,
  };
}

/**
 * REMBOURSEMENT (REFUND) — Initié par Admin (P7)
 * Ex: mission annulée après prélèvement, litige résolu en faveur du driver
 */
export async function refundWallet(walletId, amount, missionId, reason) {
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

  const balanceBefore = parseFloat(currentWallet.balance);
  const balanceAfter  = balanceBefore + parseFloat(amount);

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
      wallet_id:        walletId,
      mission_id:       missionId || null,
      transaction_type: 'refund',
      amount:           parseFloat(amount),
      balance_before:   balanceBefore,
      balance_after:    balanceAfter,
      status:           'completed',
      description:      `Remboursement — ${reason}`,
      metadata:         { reason, initiated_by: 'admin' },
      processed_at:     new Date().toISOString(),
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
    transactionId: transaction?.id,
  });

  return { success: true, balanceBefore, balanceAfter, transaction };
}

/**
 * RÉCUPÉRER L'HISTORIQUE DES TRANSACTIONS
 * Paginé — 20 transactions par page
 *
 * @param {string} walletId - UUID du wallet
 * @param {number} page     - Numéro de page (commence à 0)
 * @param {string} filter   - 'all' | 'commission' | 'topup' | 'refund'
 */
export async function getTransactionHistory(walletId, page = 0, filter = 'all') {
  const PAGE_SIZE = 20;
  const from      = page * PAGE_SIZE;
  const to        = from + PAGE_SIZE - 1;

  console.log('[FTM-DEBUG] Wallet - Fetching transaction history', {
    walletId,
    page,
    filter,
    range: `${from}-${to}`,
  });

  let query = supabase
    .from('transactions')
    .select(`
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
    `, { count: 'exact' })
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
    return { error };
  }

  console.log('[FTM-DEBUG] Wallet - Transaction history fetched', {
    walletId,
    count:       data?.length,
    totalCount:  count,
    page,
    filter,
  });

  return {
    success:     true,
    transactions: data || [],
    totalCount:  count,
    hasMore:     (from + PAGE_SIZE) < count,
  };
}

/**
 * VÉRIFIER LE BLOCAGE WALLET & METTRE À JOUR is_available
 * Appelé après chaque prélèvement de commission
 * ou à l'initialisation de l'écran driver
 */
export async function checkAndEnforceWalletBlock(driverId, walletId) {
  console.log('[FTM-DEBUG] Wallet - Checking block status', { driverId, walletId });

  const { data: wallet, error } = await supabase
    .from('wallet')
    .select('balance, minimum_balance')
    .eq('id', walletId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Wallet - Block check fetch error', { error: error.message });
    return { error };
  }

  const isBlocked = wallet.balance < wallet.minimum_balance;

  if (isBlocked) {
    console.log('[FTM-DEBUG] Wallet - BLOCKED — balance below minimum', {
      driverId,
      balance: wallet.balance,
      minimum: wallet.minimum_balance,
      deficit: (wallet.minimum_balance - wallet.balance).toFixed(2) + ' DH',
    });

    // Forcer is_available à false
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
      balance: wallet.balance,
      minimum: wallet.minimum_balance,
    });
  }

  return {
    success:   true,
    isBlocked,
    balance:   wallet.balance,
    minimum:   wallet.minimum_balance,
  };
}

/**
 * ABONNEMENT REALTIME — Écouter les changements du wallet
 * Permet de mettre à jour l'affichage du solde en temps réel
 * (notamment après un prélèvement de commission déclenché par le trigger)
 */
export function subscribeToWalletUpdates(walletId, driverId, onUpdate) {
  console.log('[FTM-DEBUG] Wallet - Subscribing to wallet updates', { walletId });

  const channel = supabase
    .channel(`wallet-${walletId}`)
    .on(
      'postgres_changes',
      {
        event:  'UPDATE',
        schema: 'public',
        table:  'wallet',
        filter: `id=eq.${walletId}`,
      },
      async (payload) => {
        const newBalance = payload.new.balance;
        const oldBalance = payload.old.balance;
        const minimum    = payload.new.minimum_balance;
        const isBlocked  = newBalance < minimum;

        console.log('[FTM-DEBUG] Wallet - Balance updated via Realtime', {
          walletId,
          oldBalance,
          newBalance,
          delta:     (newBalance - oldBalance).toFixed(2) + ' DH',
          isBlocked,
        });

        // Si le solde passe sous le seuil → forcer le blocage
        if (isBlocked) {
          await checkAndEnforceWalletBlock(driverId, walletId);
        }

        onUpdate({
          balance:   newBalance,
          minimum,
          isBlocked,
        });
      }
    )
    .subscribe((status) => {
      console.log('[FTM-DEBUG] Wallet - Subscription status', { walletId, status });
    });

  return channel;
}
```

---

## 4. ÉCRANS WALLET

### 4.1 Dashboard Driver Principal

```javascript
// /screens/driver/WalletDashboardScreen.js

/**
 * ÉTAT LOCAL
 * - dashboard     : object | null (depuis getDriverDashboard)
 * - isLoading     : boolean
 * - walletChannel : channel Supabase
 */

/**
 * UI — WalletDashboardScreen
 *
 * LAYOUT COMPLET :
 * ┌──────────────────────────────────────┐
 * │  💰 Mon Wallet                       │
 * │                                      │
 * │  ┌────────────────────────────────┐  │
 * │  │  SOLDE ACTUEL                  │  │
 * │  │                                │  │
 * │  │  340.00 DH                     │  │  ← Grand, centré
 * │  │  (COLORS.success si ≥ 100 DH) │  │  ← COLORS.alert si < 100 DH
 * │  │                                │  │
 * │  │  Seuil minimum : 100.00 DH    │  │
 * │  │  ████████████░░░  (barre)      │  │  ← Progression balance/minimum
 * │  └────────────────────────────────┘  │
 * │                                      │
 * │  ⚠️ BANNER BLOCAGE (si isBlocked) :  │
 * │  ┌────────────────────────────────┐  │
 * │  │ ❌ Wallet insuffisant          │  │  ← Fond COLORS.alert/10
 * │  │ Rechargez pour reprendre       │  │    Bordure COLORS.alert
 * │  │ les missions.                  │  │    Texte COLORS.alert
 * │  │ [Recharger maintenant →]       │  │
 * │  └────────────────────────────────┘  │
 * │                                      │
 * │  ── STATISTIQUES ──                 │
 * │  ┌──────────┐  ┌──────────────────┐  │
 * │  │ Missions │  │  Commissions     │  │
 * │  │   Total  │  │    Total payées  │  │
 * │  │   🚚 47  │  │   💸 1,650 DH   │  │
 * │  └──────────┘  └──────────────────┘  │
 * │  ┌──────────┐  ┌──────────────────┐  │
 * │  │ Ce mois  │  │   Ce mois        │  │
 * │  │  🚚 8    │  │   💸 280 DH     │  │
 * │  └──────────┘  └──────────────────┘  │
 * │                                      │
 * │  ── NOTE MOYENNE ──                 │
 * │  ⭐ 4.8 / 5  (47 avis)             │  │
 * │                                      │
 * │  [Bouton "Recharger mon wallet"]    │
 * │  (COLORS.cta — Jaune Ambre, 52px)  │
 * │                                      │
 * │  [Lien "Voir l'historique →"]       │
 * └──────────────────────────────────────┘
 *
 * BARRE DE PROGRESSION SOLDE :
 * - Calcul : Math.min((balance / minimum) * 100, 100)
 * - 0-49%   → COLORS.alert (rouge)
 * - 50-99%  → COLORS.cta (ambre)
 * - 100%+   → COLORS.success (vert)
 *
 * COMPORTEMENT :
 * - Données chargées via getDriverDashboard() au mount
 * - Realtime subscribeToWalletUpdates() actif en permanence
 * - Solde mis à jour instantanément après chaque commission (trigger SQL)
 * - Banner blocage apparaît/disparaît dynamiquement selon le solde
 * - Unsubscribe sur unmount
 */
```

### 4.2 Écran Recharge Wallet (Topup)

```javascript
// /screens/driver/WalletTopupScreen.js

/**
 * ÉTAT LOCAL
 * - selectedAmount  : number | null  (montants prédéfinis)
 * - customAmount    : string          (saisie libre)
 * - finalAmount     : number          (selectedAmount || customAmount)
 * - agentRef        : string          (référence reçu agent)
 * - isLoading       : boolean
 * - confirmation    : boolean         (étape de confirmation)
 */

/**
 * MONTANTS PRÉDÉFINIS (Quick Select)
 */
const PRESET_AMOUNTS = [100, 200, 300, 500, 1000];

/**
 * UI — WalletTopupScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────────┐
 * │  ← Recharger mon wallet             │
 * │                                      │
 * │  SOLDE ACTUEL : 60.00 DH ❌         │
 * │  Minimum requis : 100.00 DH         │
 * │  À recharger minimum : 40.00 DH    │
 * │                                      │
 * │  ── MONTANT DE RECHARGE ──          │
 * │                                      │
 * │  [100 DH] [200 DH] [300 DH]         │
 * │  [500 DH] [1000 DH]                 │
 * │  (Cards, sélection unique,          │
 * │   sélectionnée = COLORS.primary)    │
 * │                                      │
 * │  ── OU MONTANT PERSONNALISÉ ──      │
 * │  [Input] Autre montant (DH)         │
 * │  (clavier numérique)               │
 * │                                      │
 * │  ── RÉFÉRENCE DE PAIEMENT ──        │
 * │  [Input] Réf. reçu / code agent    │
 * │  (optionnel en v1)                  │
 * │                                      │
 * │  ── RÉCAPITULATIF ──                │
 * │  Solde actuel   : 60.00 DH         │
 * │  Recharge       : +200.00 DH       │
 * │  Nouveau solde  : 260.00 DH ✅     │
 * │                                      │
 * │  ℹ️ "Le paiement s'effectue en     │
 * │  espèces auprès d'un agent FTM.    │
 * │  Présentez votre numéro de tel."   │
 * │                                      │
 * │  [Bouton "Confirmer la recharge"]  │
 * │  (COLORS.primary, désactivé si     │
 * │   montant < 100 DH)                │
 * └──────────────────────────────────────┘
 *
 * VERSION 1 PRODUCTION NOTE :
 * ┌────────────────────────────────────┐
 * │  ⚠️ WORKFLOW v1 (sans paiement     │
 * │  en ligne) :                       │
 * │  1. Driver va chez un agent FTM   │
 * │  2. Paie en cash le montant       │
 * │  3. Agent saisit dans Admin (P7)  │
 * │     → topupWallet() côté admin    │
 * │  4. Le solde est crédité          │
 * │                                    │
 * │  Ce formulaire est pour :         │
 * │  a) Tests en dev (topup direct)   │
 * │  b) Future intégration paiement   │
 * │     en ligne (CMI, PayZone, etc.) │
 * └────────────────────────────────────┘
 */
```

### 4.3 Écran Historique des Transactions

```javascript
// /screens/driver/TransactionHistoryScreen.js

/**
 * ÉTAT LOCAL
 * - transactions  : array
 * - totalCount    : number
 * - currentPage   : number (commence à 0)
 * - activeFilter  : 'all' | 'commission' | 'topup' | 'refund'
 * - isLoading     : boolean
 * - isLoadingMore : boolean (pagination)
 */

/**
 * CONFIGURATION VISUELLE PAR TYPE DE TRANSACTION
 */
const TRANSACTION_CONFIG = {
  commission: {
    icon:       '💸',
    label_fr:   'Commission FTM',
    label_ar:   'عمولة FTM',
    color:      '#DC3545', // COLORS.alert — soustraction
    sign:       '−',       // Affiché devant le montant
    direction:  'debit',
  },
  topup: {
    icon:       '💰',
    label_fr:   'Recharge',
    label_ar:   'شحن',
    color:      '#28A745', // COLORS.success — ajout
    sign:       '+',
    direction:  'credit',
  },
  refund: {
    icon:       '↩️',
    label_fr:   'Remboursement',
    label_ar:   'استرداد',
    color:      '#28A745', // COLORS.success — ajout
    sign:       '+',
    direction:  'credit',
  },
};

/**
 * FORMATER UNE DATE pour affichage dans la liste
 * "2026-02-20T14:35:00Z" → "20/02/2026 à 14:35"
 */
function formatTransactionDate(isoDate) {
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

/**
 * UI — TransactionHistoryScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────────┐
 * │  ← Historique transactions          │
 * │                                      │
 * │  [Tous] [Commissions] [Recharges]    │
 * │  [Remboursements]                    │
 * │  (Filtres tabs — actif=COLORS.primary)│
 * │                                      │
 * │  ── RÉSUMÉ PÉRIODE ──               │
 * │  Prélevé : -1 650 DH (rouge)        │
 * │  Rechargé : +2 400 DH (vert)        │
 * │                                      │
 * │  ── LISTE ──                        │
 * │  ┌──────────────────────────────┐   │
 * │  │ 💸 Commission FTM            │   │
 * │  │ Mission FTM20260220047       │   │
 * │  │ Casa → Marrakech  🚐 VUL    │   │
 * │  │ 20/02/2026 à 14:35          │   │
 * │  │               − 25.00 DH ❌  │   │  ← Rouge, aligné droite
 * │  │ Solde : 340.00 DH           │   │
 * │  └──────────────────────────────┘   │
 * │                                      │
 * │  ┌──────────────────────────────┐   │
 * │  │ 💰 Recharge                  │   │
 * │  │ Réf: AGENT-CASA-0042        │   │
 * │  │ 18/02/2026 à 10:00          │   │
 * │  │               + 300.00 DH ✅ │   │  ← Vert, aligné droite
 * │  │ Solde : 365.00 DH           │   │
 * │  └──────────────────────────────┘   │
 * │                                      │
 * │  [Charger plus...] (pagination)     │
 * └──────────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - Filtre "Tous" par défaut, changer filtre = reset page 0
 * - Chaque card transaction : tap pour voir le détail (modal)
 * - Transaction status='failed' → fond rouge pâle + "ÉCHOUÉ" badge
 * - Pagination "load more" au scroll bas (page++)
 * - Pull-to-refresh pour recharger la liste
 */
```

### 4.4 Modal Détail Transaction

```javascript
// /screens/driver/TransactionDetailModal.js

/**
 * Affiché au tap sur une transaction dans l'historique
 * PROPS : transaction (objet complet)
 *
 * UI — TransactionDetailModal
 *
 * LAYOUT :
 * ┌──────────────────────────────────────┐
 * │  ✕  [Type transaction]              │
 * │                                      │
 * │  ── MONTANT ──                      │
 * │  − 25.00 DH                         │
 * │  (Large, COLORS.alert ou .success)  │
 * │                                      │
 * │  Statut : ✅ Complété               │
 * │           ❌ Échoué  (si failed)    │
 * │                                      │
 * │  ── DÉTAILS ──                      │
 * │  Type         : Commission FTM      │
 * │  Date         : 20/02/2026 14:35    │
 * │  Description  : Commission pour     │
 * │                 mission FTM...047   │
 * │                                      │
 * │  ── SOLDE ──                        │
 * │  Avant  : 365.00 DH                │
 * │  Après  : 340.00 DH                │
 * │                                      │
 * │  ── MISSION ASSOCIÉE ── (si dispo)  │
 * │  N°     : FTM20260220047           │
 * │  Trajet : Casa → Marrakech         │
 * │  Véhicule: 🚐 VUL                  │
 * │                                      │
 * │  ── MÉTADONNÉES ── (si topup)       │
 * │  Réf agent : AGENT-CASA-0042       │
 * │  Méthode   : Cash agent            │
 * │                                      │
 * │  [Fermer]                           │
 * └──────────────────────────────────────┘
 */
```

---

## 5. LOGIQUE DE BLOCAGE — CONTRÔLE AVANT ACCEPTATION MISSION

```javascript
// /services/walletService.js (suite)

/**
 * VÉRIFICATION PRÉ-ACCEPTATION
 * Appelée dans acceptMission() (P3) avant de mettre à jour le statut
 * Empêche un driver avec wallet insuffisant d'accepter une mission
 *
 * @param {string} driverId        - UUID du driver
 * @param {string} vehicleCategory - Pour connaître la commission qui sera prélevée
 */
export async function canDriverAcceptMission(driverId, vehicleCategory) {
  console.log('[FTM-DEBUG] Wallet - Checking driver eligibility', {
    driverId,
    vehicleCategory,
  });

  // Commissions par catégorie (miroir de calculate_commission() SQL)
  const COMMISSION_MAP = { vul: 25, n2_medium: 40, n2_large: 50 };
  const commission = COMMISSION_MAP[vehicleCategory] || 25;

  const { data: wallet, error } = await supabase
    .from('wallet')
    .select('balance, minimum_balance')
    .eq('driver_id', driverId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Wallet - Eligibility check error', { error: error.message });
    return { canAccept: false, error: error.message };
  }

  const balanceAfterCommission = wallet.balance - commission;
  const canAccept = wallet.balance >= wallet.minimum_balance
                 && balanceAfterCommission >= 0;

  console.log('[FTM-DEBUG] Wallet - Eligibility result', {
    driverId,
    currentBalance:       wallet.balance,
    minimum:              wallet.minimum_balance,
    futureCommission:     commission,
    balanceAfterCommission,
    canAccept,
  });

  if (!canAccept) {
    const needed = Math.max(
      wallet.minimum_balance - wallet.balance,
      commission - wallet.balance
    );
    return {
      canAccept: false,
      reason:    `Solde insuffisant. Rechargez au moins ${needed.toFixed(2)} DH pour accepter cette mission.`,
      needed,
    };
  }

  return { canAccept: true };
}
```

---

## 6. REALTIME — ABONNEMENT TRANSACTIONS

```javascript
// /services/walletService.js (suite)

/**
 * ÉCOUTER LES NOUVELLES TRANSACTIONS
 * Appelé depuis WalletDashboardScreen pour afficher
 * une notification visuelle à chaque prélèvement commission
 */
export function subscribeToNewTransactions(walletId, onNewTransaction) {
  console.log('[FTM-DEBUG] Wallet - Subscribing to new transactions', { walletId });

  const channel = supabase
    .channel(`transactions-${walletId}`)
    .on(
      'postgres_changes',
      {
        event:  'INSERT',
        schema: 'public',
        table:  'transactions',
        filter: `wallet_id=eq.${walletId}`,
      },
      (payload) => {
        const tx = payload.new;
        console.log('[FTM-DEBUG] Wallet - New transaction received', {
          walletId,
          type:          tx.transaction_type,
          amount:        tx.amount,
          balanceBefore: tx.balance_before,
          balanceAfter:  tx.balance_after,
          status:        tx.status,
        });
        onNewTransaction(tx);
      }
    )
    .subscribe();

  return channel;
}
```

---

## 7. NOTIFICATIONS WALLET (INTÉGRATION P6)

```javascript
// /services/walletService.js (suite)

/**
 * GÉNÉRER UNE NOTIFICATION WALLET
 * Appelée après checkAndEnforceWalletBlock() si blocage détecté
 * La notification est insérée dans la table `notifications` (P6)
 * et envoyée en Push via le service P6
 */
export async function notifyWalletLowBalance(profileId, balance, minimum) {
  const deficit = (minimum - balance).toFixed(2);

  console.log('[FTM-DEBUG] Wallet - Sending low balance notification', {
    profileId,
    balance,
    minimum,
    deficit,
  });

  const { error } = await supabase
    .from('notifications')
    .insert({
      profile_id: profileId,
      title:      'Wallet insuffisant — Missions bloquées',
      body:       `Votre solde (${balance} DH) est sous le minimum requis. Rechargez ${deficit} DH pour reprendre les missions.`,
      type:       'wallet_low_balance',
      data:       {
        balance,
        minimum,
        deficit,
        action: 'topup_wallet',
      },
      is_read:    false,
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
```

---

## 8. ARBORESCENCE DES FICHIERS — PÉRIMÈTRE P5

```
src/
├── services/
│   └── walletService.js          ← getDriverDashboard, getWalletBalance,
│                                    topupWallet, refundWallet,
│                                    getTransactionHistory,
│                                    checkAndEnforceWalletBlock,
│                                    canDriverAcceptMission,
│                                    subscribeToWalletUpdates,
│                                    subscribeToNewTransactions,
│                                    notifyWalletLowBalance
├── screens/
│   └── driver/
│       ├── WalletDashboardScreen.js      ← Solde + stats + barre progression
│       ├── WalletTopupScreen.js          ← Recharge montants prédéfinis + custom
│       ├── TransactionHistoryScreen.js   ← Liste paginée + filtres par type
│       └── TransactionDetailModal.js     ← Détail complet d'une transaction
```

---

## 9. RÉCAPITULATIF DES LOGS DE DEBUG (P5)

| Action | Log FTM-DEBUG |
|--------|---------------|
| Chargement dashboard | `[FTM-DEBUG] Wallet - Fetching driver dashboard` |
| Dashboard chargé | `[FTM-DEBUG] Wallet - Dashboard loaded` |
| Fetch solde | `[FTM-DEBUG] Wallet - Fetching balance` |
| Solde chargé | `[FTM-DEBUG] Wallet - Balance fetched` |
| Topup initié | `[FTM-DEBUG] Wallet - Topup initiated` |
| Montant trop faible | `[FTM-DEBUG] Wallet - Topup amount too low` |
| Topup complété | `[FTM-DEBUG] Wallet - Topup completed` |
| Remboursement initié | `[FTM-DEBUG] Wallet - Refund initiated` |
| Remboursement complété | `[FTM-DEBUG] Wallet - Refund completed` |
| Historique transactions | `[FTM-DEBUG] Wallet - Fetching transaction history` |
| Historique chargé | `[FTM-DEBUG] Wallet - Transaction history fetched` |
| Vérification blocage | `[FTM-DEBUG] Wallet - Checking block status` |
| Wallet BLOQUÉ | `[FTM-DEBUG] Wallet - BLOCKED — balance below minimum` |
| Blocage appliqué | `[FTM-DEBUG] Wallet - Driver availability forced to false` |
| Solde OK | `[FTM-DEBUG] Wallet - Balance OK, no block applied` |
| Vérification éligibilité | `[FTM-DEBUG] Wallet - Checking driver eligibility` |
| Résultat éligibilité | `[FTM-DEBUG] Wallet - Eligibility result` |
| Sub. wallet | `[FTM-DEBUG] Wallet - Subscribing to wallet updates` |
| Solde MàJ Realtime | `[FTM-DEBUG] Wallet - Balance updated via Realtime` |
| Sub. transactions | `[FTM-DEBUG] Wallet - Subscribing to new transactions` |
| Nouvelle transaction | `[FTM-DEBUG] Wallet - New transaction received` |
| Notif solde faible | `[FTM-DEBUG] Wallet - Sending low balance notification` |
| Notif insérée | `[FTM-DEBUG] Wallet - Low balance notification inserted` |

---

## 10. CHECKLIST DE VALIDATION P5

- [ ] Vue `driver_dashboard` : `is_wallet_blocked` correct (true si balance < minimum)
- [ ] `getDriverDashboard()` : `revenue_current_month` et `commissions_current_month` calculés pour le mois courant
- [ ] `process_commission_payment` trigger : vérifié en BDD — prélèvement auto sur `completeMission()`
- [ ] Trigger : transaction `status='failed'` créée si solde insuffisant au moment de la complétion
- [ ] `checkAndEnforceWalletBlock()` : `drivers.is_available` forcé à `false` si balance < 100 DH
- [ ] `canDriverAcceptMission()` : intégré dans `acceptMission()` (P3) avant le UPDATE Supabase
- [ ] Realtime `subscribeToWalletUpdates()` : solde mis à jour < 1s après `completeMission()`
- [ ] `WalletDashboardScreen` : barre de progression change de couleur (rouge/ambre/vert)
- [ ] Banner blocage visible/caché dynamiquement selon le solde Realtime
- [ ] `TransactionHistoryScreen` : filtre tabs fonctionnel (commission / topup / refund)
- [ ] Transaction `status='failed'` : fond rouge pâle dans l'historique
- [ ] Pagination "load more" : 20 transactions par page, bouton masqué si plus rien
- [ ] `notifyWalletLowBalance()` : entrée insérée dans `notifications` table (vérifier en BDD)
- [ ] Tous les `console.log('[FTM-DEBUG]...')` visibles dans Debug Console Codespaces

---

## 11. LIAISON AVEC LES PARTIES SUIVANTES

| Partie | Dépendance de P5 |
|--------|-----------------|
| **P6** | `notifyWalletLowBalance()` → INSERT `notifications` → Push notification driver |
| **P7** | Admin peut `topupWallet()` et `refundWallet()` depuis le dashboard Admin |
| **P7** | Admin voit tous les wallets, détecte les dettes (transactions `status='failed'`) |

---

*FTM Spec P5 — Fin du fichier*
*Prochaine étape : SPEC_NATIVELY_P6.md — Notifications Push & Chat Audio Darija*
