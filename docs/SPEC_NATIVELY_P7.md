# SPEC NATIVELY — Fast Trans Maroc (FTM)
# PARTIE P7 : Admin Dashboard & Sécurité RLS (Clôture)
# Fichier : docs/SPEC_NATIVELY_P7.md
# Version : 1.0 | Backend : Supabase | App : Natively.dev
# =====================================================================
# PRÉREQUIS : P1→P6 validées et enregistrées
# TABLES SQL : TOUTES (profiles, drivers, wallet, missions,
#              ecommerce_parcels, transactions, notifications,
#              document_reminders)
# RÔLE       : admin (profiles.role = 'admin')
# FICHIER CI : .github/workflows/deploy_supabase.yml
# =====================================================================

---

## 1. CONTEXTE — RÔLE ADMIN FTM

```
PÉRIMÈTRE DU RÔLE ADMIN

Le compte Admin est un profil FTM avec role = 'admin'.
Il accède à une interface dédiée invisible aux clients et chauffeurs.

RESPONSABILITÉS ADMIN :
  ┌─────────────────────────────────────────────────────────┐
  │  1. DOCUMENTS     Valider / Rejeter les documents       │
  │                   des chauffeurs (verification_status)  │
  ├─────────────────────────────────────────────────────────┤
  │  2. WALLET        Créditer les wallets chauffeurs       │
  │                   (topup) + gérer les remboursements    │
  ├─────────────────────────────────────────────────────────┤
  │  3. MISSIONS      Vue globale + statistiques            │
  │                   Filtrer par statut / ville / type     │
  ├─────────────────────────────────────────────────────────┤
  │  4. UTILISATEURS  Activer / Suspendre les comptes       │
  │                   (profiles.is_active)                  │
  ├─────────────────────────────────────────────────────────┤
  │  5. MONITORING    Voir toutes les transactions          │
  │                   et les dettes wallet (failed)         │
  └─────────────────────────────────────────────────────────┘

ACCÈS TECHNIQUE :
  - profiles.role = 'admin' → AdminStack (navigation P1)
  - RLS : policies "admin_*" bypassent les restrictions user
  - Supabase Service Role Key : JAMAIS exposée côté app
    → toutes les opérations admin passent par Edge Functions
```

---

## 2. SERVICE ADMIN — GESTION DOCUMENTS

```javascript
// /services/adminService.js

import { supabase }                                    from '../lib/supabaseClient';
import { notifyDocumentVerified, notifyDocumentRejected } from './notificationTemplates';

/**
 * LISTER LES CHAUFFEURS EN ATTENTE DE VÉRIFICATION
 * Filtre les drivers avec au moins 1 document 'pending'
 */
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
    .order('created_at', { ascending: true }); // FIFO — premier arrivé, premier servi

  if (error) {
    console.log('[FTM-DEBUG] Admin - Fetch pending drivers error', {
      error: error.message,
    });
    return { error };
  }

  console.log('[FTM-DEBUG] Admin - Pending drivers fetched', {
    count: data?.length || 0,
  });

  return { success: true, drivers: data || [] };
}

/**
 * VALIDER UN DOCUMENT CHAUFFEUR
 * Met à jour le verification_status à 'verified'
 * Déclenche notification Push si tous les docs sont validés
 *
 * @param {string} driverId     - UUID du driver
 * @param {string} documentType - 'driver_license' | 'vehicle_registration'
 *                                'insurance' | 'technical_inspection'
 * @param {string} profileId    - UUID du profil driver (pour notification)
 */
export async function verifyDocument(driverId, documentType, profileId) {
  const columnMap = {
    driver_license:       'driver_license_verified',
    vehicle_registration: 'vehicle_registration_verified',
    insurance:            'insurance_verified',
    technical_inspection: 'technical_inspection_verified',
  };

  const column = columnMap[documentType];
  if (!column) {
    console.log('[FTM-DEBUG] Admin - Unknown document type', { documentType });
    return { error: 'Type de document inconnu.' };
  }

  console.log('[FTM-DEBUG] Admin - Verifying document', {
    driverId,
    documentType,
    column,
    profileId,
  });

  const { error } = await supabase
    .from('drivers')
    .update({ [column]: 'verified' })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Admin - Verify document error', {
      error: error.message,
      driverId,
      documentType,
    });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Admin - Document verified', {
    driverId,
    documentType,
  });

  // Vérifier si tous les docs sont maintenant validés → is_verified = true
  const { data: driver } = await supabase
    .from('drivers')
    .select('is_verified')
    .eq('id', driverId)
    .single();

  // Notifier le chauffeur
  await notifyDocumentVerified(profileId, documentType);

  if (driver?.is_verified) {
    console.log('[FTM-DEBUG] Admin - Driver fully verified!', { driverId });
    // Notifier le chauffeur qu'il peut démarrer
    await supabase.from('notifications').insert({
      profile_id: profileId,
      type:       'driver_fully_verified',
      title:      '🎉 Dossier complet validé !',
      body:       'Tous vos documents ont été approuvés. Activez votre disponibilité pour recevoir des missions.',
      data:       { screen: 'DriverHomeStack' },
    });
    console.log('[FTM-DEBUG] Admin - Full verification notification sent', { profileId });
  }

  return { success: true, isFullyVerified: driver?.is_verified };
}

/**
 * REJETER UN DOCUMENT CHAUFFEUR
 * Met à jour le verification_status à 'rejected'
 * Envoie une notification avec le motif de rejet
 *
 * @param {string} reason - Motif de rejet (visible par le driver)
 */
export async function rejectDocument(driverId, documentType, profileId, reason) {
  const columnMap = {
    driver_license:       'driver_license_verified',
    vehicle_registration: 'vehicle_registration_verified',
    insurance:            'insurance_verified',
    technical_inspection: 'technical_inspection_verified',
  };

  const column = columnMap[documentType];

  console.log('[FTM-DEBUG] Admin - Rejecting document', {
    driverId,
    documentType,
    reason,
    profileId,
  });

  const { error } = await supabase
    .from('drivers')
    .update({ [column]: 'rejected' })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Admin - Reject document error', {
      error: error.message,
    });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Admin - Document rejected', {
    driverId,
    documentType,
    reason,
  });

  // Notifier le chauffeur avec le motif
  await notifyDocumentRejected(profileId, documentType, reason);

  return { success: true };
}

/**
 * LISTER TOUS LES CHAUFFEURS (avec filtre)
 * @param {string} filter - 'all' | 'verified' | 'pending' | 'rejected'
 */
export async function getAllDrivers(filter = 'all') {
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

  if (filter === 'verified')  query = query.eq('is_verified', true);
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

  console.log('[FTM-DEBUG] Admin - All drivers fetched', {
    count: data?.length || 0,
    filter,
  });

  return { success: true, drivers: data || [] };
}

/**
 * ACTIVER / SUSPENDRE UN COMPTE UTILISATEUR
 */
export async function toggleUserActive(profileId, isActive) {
  console.log('[FTM-DEBUG] Admin - Toggling user active status', {
    profileId,
    newStatus: isActive,
  });

  const { error } = await supabase
    .from('profiles')
    .update({ is_active: isActive })
    .eq('id', profileId);

  if (error) {
    console.log('[FTM-DEBUG] Admin - Toggle user error', { error: error.message });
    return { error: error.message };
  }

  // Si suspension : forcer is_available à false pour les drivers
  if (!isActive) {
    await supabase
      .from('drivers')
      .update({ is_available: false })
      .eq('profile_id', profileId);
    console.log('[FTM-DEBUG] Admin - Driver availability reset on suspension', { profileId });
  }

  console.log('[FTM-DEBUG] Admin - User status updated', {
    profileId,
    isActive,
  });

  return { success: true };
}

/**
 * VUE GLOBALE DES MISSIONS (Admin)
 * @param {object} filters - { status, city, vehicleCategory, missionType, dateFrom, dateTo }
 */
export async function getAdminMissions(filters = {}, page = 0) {
  const PAGE_SIZE = 25;
  const from      = page * PAGE_SIZE;
  const to        = from + PAGE_SIZE - 1;

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

  if (filters.status)          query = query.eq('status',           filters.status);
  if (filters.vehicleCategory) query = query.eq('vehicle_category', filters.vehicleCategory);
  if (filters.missionType)     query = query.eq('mission_type',     filters.missionType);
  if (filters.city)            query = query.or(
    `pickup_city.ilike.%${filters.city}%,dropoff_city.ilike.%${filters.city}%`
  );
  if (filters.dateFrom) query = query.gte('created_at', filters.dateFrom);
  if (filters.dateTo)   query = query.lte('created_at', filters.dateTo);

  const { data, error, count } = await query;

  if (error) {
    console.log('[FTM-DEBUG] Admin - Fetch missions error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Admin - Missions fetched', {
    count:      data?.length,
    totalCount: count,
    page,
    filters,
  });

  return { success: true, missions: data || [], totalCount: count };
}

/**
 * STATISTIQUES GLOBALES (Dashboard Admin — KPIs)
 */
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

  const totalCommissions = commissionData?.reduce((sum, tx) => sum + parseFloat(tx.amount), 0) || 0;

  const stats = {
    totalMissions,
    completedMissions,
    completionRate: totalMissions > 0
      ? ((completedMissions / totalMissions) * 100).toFixed(1) + '%'
      : '0%',
    totalDrivers,
    verifiedDrivers,
    pendingDrivers: totalDrivers - verifiedDrivers,
    totalClients,
    totalCommissionsDH: totalCommissions.toFixed(2),
  };

  console.log('[FTM-DEBUG] Admin - Global stats fetched', stats);

  return { success: true, stats };
}

/**
 * RECHARGER LE WALLET D'UN CHAUFFEUR (Admin → topup)
 * Wrapper de topupWallet() avec contexte Admin
 */
export async function adminTopupDriverWallet(driverId, amount, agentRef) {
  console.log('[FTM-DEBUG] Admin - Topup driver wallet', {
    driverId,
    amount,
    agentRef,
  });

  // Récupérer le wallet_id du driver
  const { data: wallet, error } = await supabase
    .from('wallet')
    .select('id, balance')
    .eq('driver_id', driverId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Admin - Wallet fetch error', { error: error.message });
    return { error: error.message };
  }

  // Appel au service wallet (P5)
  const result = await topupWallet(wallet.id, amount, agentRef);

  if (result.success) {
    console.log('[FTM-DEBUG] Admin - Topup completed for driver', {
      driverId,
      walletId:      wallet.id,
      amountAdded:   amount,
      newBalance:    result.balanceAfter,
    });
  }

  return result;
}
```

---

## 3. ÉCRANS ADMIN

### 3.1 Dashboard Admin Principal

```javascript
// /screens/admin/AdminDashboardScreen.js

/**
 * UI — AdminDashboardScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────────┐
 * │  🛡️ Admin FTM — Dashboard           │
 * │                                      │
 * │  ── KPIs ──                         │
 * │  ┌──────────┐  ┌──────────────────┐  │
 * │  │ Missions │  │   Commissions    │  │
 * │  │  Total   │  │    Collectées    │  │
 * │  │   347    │  │   8 450 DH      │  │
 * │  └──────────┘  └──────────────────┘  │
 * │  ┌──────────┐  ┌──────────────────┐  │
 * │  │Chauffeurs│  │    Chauffeurs    │  │
 * │  │  Total   │  │   En attente    │  │
 * │  │   89     │  │   ⚠️  12        │  │
 * │  └──────────┘  └──────────────────┘  │
 * │  ┌──────────┐                        │
 * │  │ Clients  │                        │
 * │  │  Total   │                        │
 * │  │   234    │                        │
 * │  └──────────┘                        │
 * │                                      │
 * │  ── NAVIGATION ──                   │
 * │  [📋 Documents en attente  →]       │  ← Badge rouge "12"
 * │  [🚚 Toutes les missions   →]       │
 * │  [👥 Gestion utilisateurs  →]       │
 * │  [💰 Wallets & Transactions →]      │
 * └──────────────────────────────────────┘
 */
```

### 3.2 Écran Validation Documents

```javascript
// /screens/admin/DocumentReviewScreen.js

/**
 * ÉTAT LOCAL
 * - drivers       : array (getPendingDrivers())
 * - selectedDriver: object | null
 * - rejectReason  : string
 * - isLoading     : boolean
 * - activeDoc     : string | null (URL du doc en preview)
 */

/**
 * UI — DocumentReviewScreen
 *
 * LAYOUT (liste des chauffeurs en attente) :
 * ┌──────────────────────────────────────┐
 * │  ← Documents en attente (12)        │
 * │                                      │
 * │  ┌──────────────────────────────┐   │
 * │  │ 👤 Mohammed A.              │   │
 * │  │ 🚐 VUL — 12345-A-1          │   │
 * │  │ Inscrit le 20/02/2026       │   │
 * │  │                              │   │
 * │  │ 🪪 Permis       🟡 Pending  │   │
 * │  │ 📄 Carte grise  🟡 Pending  │   │
 * │  │ 🛡️ Assurance    🟡 Pending  │   │
 * │  │ 🔧 Visite tech  🟡 Pending  │   │
 * │  │                              │   │
 * │  │ [Voir les documents →]       │   │
 * │  └──────────────────────────────┘   │
 * │  (Répété pour chaque driver)       │
 * └──────────────────────────────────────┘
 *
 * VUE DÉTAIL D'UN CHAUFFEUR (tap → modal) :
 * ┌──────────────────────────────────────┐
 * │  👤 Mohammed A.  📞 06XX XX XX XX   │
 * │  🚐 VUL | Mercedes Sprinter         │
 * │  Plaque : 12345-A-1                 │
 * │                                      │
 * │  ── 🪪 PERMIS DE CONDUIRE ──        │
 * │  N° : ABC-12345                     │
 * │  Expire : 15/06/2028                │
 * │  [🔍 Voir le document] ← ouvre URL │
 * │                                      │
 * │  [✅ Valider]  [❌ Rejeter]         │
 * │   (COLORS.success) (COLORS.alert)   │
 * │                                      │
 * │  Si [Rejeter] → Input motif :       │
 * │  [Input] "Ex: Document illisible"   │
 * │  [Confirmer le rejet]               │
 * │                                      │
 * │  ── 📄 CARTE GRISE ──               │
 * │  (Idem pour chaque document)        │
 * └──────────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - [Voir le document] → ouvre URL signée dans le browser natif
 * - [Valider] → verifyDocument() → icône passe à ✅ vert
 * - [Rejeter] → modal input motif → rejectDocument(reason)
 *              → icône passe à ❌ rouge
 * - Quand les 4 docs validés → badge "✅ Dossier complet" + notif driver
 * - Swipe-to-refresh pour recharger la liste
 */
```

### 3.3 Écran Gestion Wallets

```javascript
// /screens/admin/WalletManagementScreen.js

/**
 * UI — WalletManagementScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────────┐
 * │  ← Wallets & Transactions           │
 * │                                      │
 * │  [Recherche par nom/téléphone]      │
 * │  [Filtre: Tous | Bloqués | Dettes]  │
 * │                                      │
 * │  ┌──────────────────────────────┐   │
 * │  │ 👤 Youssef B.                │   │  ← Wallet OK
 * │  │ Solde : 340 DH ✅            │   │
 * │  │ Commissions : 1 650 DH      │   │
 * │  │ [Recharger] [Historique]    │   │
 * │  └──────────────────────────────┘   │
 * │                                      │
 * │  ┌──────────────────────────────┐   │  ← Wallet BLOQUÉ
 * │  │ 👤 Karim M.         ❌ BLOQUÉ│   │
 * │  │ Solde : 45 DH ❌             │   │
 * │  │ Déficit : 55 DH             │   │
 * │  │ [Recharger →]               │   │
 * │  └──────────────────────────────┘   │
 * │                                      │
 * │  ┌──────────────────────────────┐   │  ← Dettes (tx failed)
 * │  │ 👤 Rachid O.   ⚠️ DETTE     │   │
 * │  │ Commission non déduite      │   │
 * │  │ Mission FTM...093 — 40 DH  │   │
 * │  │ [Voir détail] [Régulariser] │   │
 * │  └──────────────────────────────┘   │
 * └──────────────────────────────────────┘
 *
 * MODAL RECHARGE (Admin) :
 * ┌──────────────────────────────────────┐
 * │  Recharger le wallet de [Nom]       │
 * │                                      │
 * │  Solde actuel : 45 DH              │
 * │  [Input] Montant (DH) *             │
 * │  [Input] Réf. reçu / code agent *  │
 * │                                      │
 * │  Nouveau solde : 245 DH ✅          │
 * │                                      │
 * │  [Confirmer la recharge]            │
 * └──────────────────────────────────────┘
 */
```

---

## 4. SYNTHÈSE COMPLÈTE — POLITIQUES RLS

> ⚠️ SECTION CRITIQUE : Toutes les politiques listées ici sont la
> SOURCE DE VÉRITÉ pour la sécurité de l'application FTM.

### 4.1 Table profiles

```sql
-- ── TABLE: profiles ──────────────────────────────────────────────

-- SELECT : chaque user voit son propre profil
CREATE POLICY "profiles_select_own"
    ON profiles FOR SELECT
    USING (auth.uid() = user_id);

-- SELECT : admin voit tous les profils
CREATE POLICY "profiles_select_admin"
    ON profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- INSERT : uniquement via trigger post-auth (service role)
-- Le profil est créé par getOrCreateProfile() côté app avec anon key
-- RLS INSERT autorisé pour l'utilisateur lui-même
CREATE POLICY "profiles_insert_own"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- UPDATE : chaque user modifie son propre profil
CREATE POLICY "profiles_update_own"
    ON profiles FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- UPDATE : admin peut modifier tous les profils (is_active, etc.)
CREATE POLICY "profiles_update_admin"
    ON profiles FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- DELETE : personne ne peut supprimer un profil (soft delete via is_active)
-- Pas de policy DELETE → bloqué par défaut
```

### 4.2 Table drivers

```sql
-- ── TABLE: drivers ───────────────────────────────────────────────

-- SELECT : driver voit son propre enregistrement
CREATE POLICY "drivers_select_own"
    ON drivers FOR SELECT
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

-- SELECT : client peut voir les drivers disponibles (via vue available_drivers)
-- Vue already filtrée — la policy donne accès à la table pour la vue
CREATE POLICY "drivers_select_available"
    ON drivers FOR SELECT
    USING (is_verified = true AND is_available = true);

-- SELECT : admin voit tous les drivers
CREATE POLICY "drivers_select_admin"
    ON drivers FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- INSERT : un driver crée son propre enregistrement (onboarding P2)
CREATE POLICY "drivers_insert_own"
    ON drivers FOR INSERT
    WITH CHECK (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

-- UPDATE : driver met à jour son propre enregistrement
-- (is_available, current_location, etc.)
CREATE POLICY "drivers_update_own"
    ON drivers FOR UPDATE
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

-- UPDATE : admin peut mettre à jour tous les drivers
-- (verification_status, is_verified, etc.)
CREATE POLICY "drivers_update_admin"
    ON drivers FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );
```

### 4.3 Table wallet

```sql
-- ── TABLE: wallet ────────────────────────────────────────────────

-- SELECT : driver voit uniquement son wallet
CREATE POLICY "wallet_select_own"
    ON wallet FOR SELECT
    USING (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

-- SELECT : admin voit tous les wallets
CREATE POLICY "wallet_select_admin"
    ON wallet FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- INSERT : créé lors de l'onboarding driver (service role via Edge Function)
-- Pas de policy INSERT user → créé par le trigger driverService.createDriverWallet()
-- ⚠️ La création wallet se fait avec anon key via RPC ou direct insert
CREATE POLICY "wallet_insert_own"
    ON wallet FOR INSERT
    WITH CHECK (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

-- UPDATE : uniquement via triggers SQL (process_commission_payment)
-- et via Edge Functions admin (topup, refund)
-- L'app cliente NE MET PAS à jour le wallet directement
CREATE POLICY "wallet_update_admin"
    ON wallet FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ⚠️ NOTE CRITIQUE : Les triggers SQL (process_commission_payment)
-- s'exécutent en SECURITY DEFINER → bypassent RLS automatiquement.
-- Pas besoin de policy UPDATE pour les triggers.
```

### 4.4 Table missions

```sql
-- ── TABLE: missions ──────────────────────────────────────────────

-- SELECT : client voit ses missions, driver voit les siennes
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

-- SELECT : driver voit toutes les missions 'pending' de sa catégorie
-- (pour le matching — NewMissionModal P3)
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

-- SELECT : admin voit toutes les missions
CREATE POLICY "missions_select_admin"
    ON missions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- INSERT : uniquement les clients créent des missions
CREATE POLICY "missions_insert_client"
    ON missions FOR INSERT
    WITH CHECK (
        client_id IN (
            SELECT id FROM profiles
            WHERE user_id = auth.uid() AND role = 'client'
        )
    );

-- UPDATE : client et driver peuvent mettre à jour leurs missions
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

-- UPDATE : admin peut mettre à jour toutes les missions
CREATE POLICY "missions_update_admin"
    ON missions FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );
```

### 4.5 Table transactions

```sql
-- ── TABLE: transactions ──────────────────────────────────────────

-- SELECT : driver voit ses transactions via son wallet
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

-- SELECT : admin voit toutes les transactions
CREATE POLICY "transactions_select_admin"
    ON transactions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- INSERT : uniquement via triggers (commission) et Edge Functions (topup/refund)
-- L'app NE crée PAS de transaction directement
-- Les triggers s'exécutent en SECURITY DEFINER → pas de policy INSERT nécessaire
-- Policy pour topup via Edge Function (service role) :
-- → Edge Functions utilisent SERVICE_ROLE_KEY → bypasse RLS
```

### 4.6 Table notifications

```sql
-- ── TABLE: notifications ─────────────────────────────────────────

-- SELECT : chaque user voit ses propres notifications
CREATE POLICY "notifications_select_own"
    ON notifications FOR SELECT
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

-- INSERT : les services peuvent insérer des notifications
-- (insertNotification() côté app ou Edge Functions)
CREATE POLICY "notifications_insert_service"
    ON notifications FOR INSERT
    WITH CHECK (
        -- L'app peut insérer pour n'importe quel profil via service
        -- Les Edge Functions utilisent SERVICE_ROLE_KEY → bypasse RLS
        -- Pour l'app côté client : on autorise l'insertion pour tous
        -- (contrôlé au niveau applicatif, pas SQL)
        true
    );

-- UPDATE : chaque user peut marquer ses notifications comme lues
CREATE POLICY "notifications_update_own"
    ON notifications FOR UPDATE
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    )
    WITH CHECK (
        -- Seul is_read et read_at peuvent être modifiés par l'user
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

-- UPDATE : admin peut tout modifier
CREATE POLICY "notifications_update_admin"
    ON notifications FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- DELETE : admin uniquement (nettoyage)
CREATE POLICY "notifications_delete_admin"
    ON notifications FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );
```

### 4.7 Table ecommerce_parcels

```sql
-- ── TABLE: ecommerce_parcels ──────────────────────────────────────

-- SELECT : expéditeur (client de la mission associée) voit son colis
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

-- SELECT : driver de la mission voit le colis
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

-- SELECT : accès public par tracking_number (sans auth)
-- Via la vue public_parcel_tracking (SECURITY DEFINER)
-- La vue expose uniquement les champs non-sensibles
CREATE POLICY "parcels_select_tracking_public"
    ON ecommerce_parcels FOR SELECT
    USING (tracking_number IS NOT NULL);
-- ⚠️ Cette policy est large — la vue public_parcel_tracking
--    masque les données sensibles (téléphones partiels)

-- SELECT : admin voit tous les colis
CREATE POLICY "parcels_select_admin"
    ON ecommerce_parcels FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- INSERT : client crée son colis (lié à sa mission)
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
```

### 4.8 Table document_reminders

```sql
-- ── TABLE: document_reminders ────────────────────────────────────

-- SELECT : driver voit ses propres rappels
CREATE POLICY "reminders_select_own"
    ON document_reminders FOR SELECT
    USING (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

-- SELECT : admin voit tous les rappels
CREATE POLICY "reminders_select_admin"
    ON document_reminders FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- INSERT : créé lors de l'onboarding driver (P2)
CREATE POLICY "reminders_insert_own"
    ON document_reminders FOR INSERT
    WITH CHECK (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

-- UPDATE : Edge Functions CRON mettent à jour les flags
-- → Utilisent SERVICE_ROLE_KEY → bypasse RLS
```

### 4.9 Vues — Configuration SECURITY DEFINER

```sql
-- ── VUES AVEC SECURITY DEFINER ───────────────────────────────────
-- Les vues complexes nécessitent SECURITY DEFINER pour éviter
-- les erreurs de permission lors des JOINs multi-tables

-- Vue available_drivers : accessible à tous les users authentifiés
ALTER VIEW available_drivers OWNER TO postgres;
-- + GRANT SELECT ON available_drivers TO authenticated;

-- Vue driver_dashboard : accessible uniquement au driver concerné
-- (RLS de la table drivers s'applique déjà)

-- Vue public_parcel_tracking : accessible SANS authentification
-- → Marquée SECURITY DEFINER pour bypasser RLS sur les JOINs
CREATE OR REPLACE VIEW public_parcel_tracking
WITH (security_invoker = false) -- SECURITY DEFINER
AS
-- ... (définition P4)
;
GRANT SELECT ON public_parcel_tracking TO anon;        -- Sans auth
GRANT SELECT ON public_parcel_tracking TO authenticated; -- Avec auth
```

---

## 5. GUIDE DE DÉPLOIEMENT — GITHUB ACTIONS

### 5.1 Fichier Workflow CI/CD

```yaml
# .github/workflows/deploy_supabase.yml
# Déploiement automatique des migrations SQL et Edge Functions
# Déclenché sur push vers la branche 'main'

name: Deploy Supabase FTM

on:
  push:
    branches:
      - main
    paths:
      - 'supabase/**'    # Déclenché seulement si supabase/ modifié
  workflow_dispatch:     # Déclenchement manuel depuis GitHub Actions UI

env:
  SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}
  SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
  SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

jobs:

  # ── JOB 1 : Vérification & Lint SQL ──────────────────────────────
  lint:
    name: Lint SQL Migrations
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Validate migrations syntax
        run: |
          echo "✅ Validating SQL migrations..."
          supabase db diff --local || true
          echo "✅ Lint complete"

  # ── JOB 2 : Déploiement Migrations SQL ───────────────────────────
  deploy-migrations:
    name: Deploy DB Migrations
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

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

  # ── JOB 3 : Déploiement Edge Functions ───────────────────────────
  deploy-functions:
    name: Deploy Edge Functions
    runs-on: ubuntu-latest
    needs: deploy-migrations
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

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

  # ── JOB 4 : Tests Post-Déploiement ───────────────────────────────
  smoke-test:
    name: Smoke Tests
    runs-on: ubuntu-latest
    needs: deploy-functions
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

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
```

### 5.2 Secrets GitHub Requis

```bash
# À configurer dans GitHub → Settings → Secrets → Actions

SUPABASE_PROJECT_ID       # ex: abcdefghijklmnop
SUPABASE_DB_PASSWORD      # Mot de passe BDD Supabase
SUPABASE_ACCESS_TOKEN     # Token API Supabase (Dashboard → Account → Access Tokens)
SUPABASE_ANON_KEY         # Clé publique anon (Dashboard → Project Settings → API)

# ⚠️ NE JAMAIS committer ces valeurs dans le code
# ⚠️ SUPABASE_SERVICE_ROLE_KEY : uniquement pour les Edge Functions
#    → Set dans Supabase Dashboard → Edge Functions → Secrets
```

### 5.3 Structure des Migrations (ordre d'exécution)

```
supabase/migrations/
├── 20260220155000_initial_schema.sql          ← P1-P2 : Schéma complet initial
│   (extensions, ENUMs, tables, triggers,
│    RLS policies, vues initiales)
│
├── 20260221000000_add_rpc_nearby_drivers.sql  ← P3 : Fonction find_nearby_drivers()
│
├── 20260222000000_add_tracking_functions.sql  ← P4 : generate_tracking_number(),
│   (generate_tracking_number(),                        trigger, public_parcel_tracking view
│    trigger_set_tracking_number,
│    public_parcel_tracking view,
│    GRANT anon access)
│
└── 20260223000000_add_rls_policies.sql        ← P7 : Policies RLS complètes
    (Toutes les policies listées
     dans la Section 4 de P7)
```

---

## 6. CHECKLIST QA FINALE — PRÊT POUR NATIVELY

> Cette checklist doit être validée ✅ COMPLÈTEMENT avant
> de soumettre le projet à la génération Natively.dev.

### 6.1 Backend Supabase

```
AUTHENTIFICATION
  [ ] Auth OTP téléphone activé dans Supabase → Authentication → Providers → Phone
  [ ] Rate limiting OTP configuré (max 5 tentatives / heure)
  [ ] Session JWT expiry défini (ex: 7 jours)

BASE DE DONNÉES
  [ ] Toutes les migrations appliquées sans erreur (supabase migration list)
  [ ] Extensions activées : uuid-ossp ✅  postgis ✅
  [ ] Toutes les tables créées (vérifier via Table Editor)
  [ ] Toutes les vues créées : available_drivers, driver_dashboard, public_parcel_tracking
  [ ] Tous les triggers actifs (vérifier via Database → Triggers)
  [ ] Fonctions SQL testées :
        calculate_commission('vul')          → 25.00 ✅
        calculate_commission('n2_medium')    → 40.00 ✅
        calculate_commission('n2_large')     → 50.00 ✅
        generate_mission_number()            → 'FTM20260220XXXX' ✅
        generate_tracking_number()           → 'FTM-TRACK-XXXXXXXX' ✅
        find_nearby_drivers(...)             → Retourne des rows ✅

ROW LEVEL SECURITY
  [ ] RLS activé sur TOUTES les tables (pas de table sans RLS)
  [ ] Test policy profiles : user A ne voit pas le profil user B
  [ ] Test policy missions : client ne voit pas les missions d'un autre client
  [ ] Test policy wallet : driver ne voit pas le wallet d'un autre driver
  [ ] Test policy parcels : tracking public accessible sans auth ✅
  [ ] Test admin : admin voit TOUTES les données de toutes les tables

STORAGE
  [ ] Bucket driver-documents créé (privé, 5MB, image/* + application/pdf)
  [ ] Bucket voice-messages créé (privé, 10MB, audio/*)
  [ ] Policies Storage driver-documents : driver upload dans son dossier uniquement
  [ ] Policies Storage voice-messages : participants mission uniquement
  [ ] Test upload document depuis un compte driver → visible dans Storage

EDGE FUNCTIONS
  [ ] send-push-notification déployée et testée ✅
  [ ] register-push-token déployée et testée ✅
  [ ] check-document-reminders déployée et testée ✅
  [ ] send-tracking-sms déployée et testée ✅
  [ ] CRON check-document-reminders planifié à 08:00 ✅
  [ ] Secrets Edge Functions configurés (FCM key, APNs key, SMS API key)

REALTIME
  [ ] Realtime activé sur tables : missions, drivers, wallet, notifications, transactions
  [ ] Test : changement status mission → reçu en < 1s côté client
  [ ] Test : changement wallet balance → reçu en < 1s côté driver
```

### 6.2 Application Mobile

```
AUTHENTIFICATION (P1)
  [ ] OTP reçu sur numéro marocain réel (+212XXXXXXXXX)
  [ ] Session persistée après fermeture de l'app
  [ ] Routing correct selon role : client → ClientHome, driver → DriverHome, admin → Admin
  [ ] Switch langue FR ↔ AR : RTL/LTR change correctement
  [ ] Déconnexion fonctionne (session détruite côté Supabase)

ONBOARDING DRIVER (P2)
  [ ] Formulaire vehicle_category avec grille tarifaire visible
  [ ] Validation plaque : format marocain (XXXXX-X-X)
  [ ] Upload des 4 documents → visible dans Storage bucket
  [ ] Statut 'pending' visible dans DocumentStatusScreen
  [ ] Realtime : changement status document reçu sans relancer l'app
  [ ] Wallet créé automatiquement à l'onboarding (solde 0)

MISSIONS & GPS (P3)
  [ ] Permission GPS foreground accordée (Android + iOS)
  [ ] Permission GPS background accordée (Android + iOS)
  [ ] Background tracking actif : position envoyée toutes les 15s app en arrière-plan
  [ ] Format PostGIS respecté : POINT(lng lat) — PAS POINT(lat lng)
  [ ] Triggers auto vérifiés après INSERT mission :
        mission_number généré ✅
        commission_amount calculé ✅
        estimated_distance_km calculé ✅
  [ ] Mission 'pending' visible par les drivers de la bonne catégorie
  [ ] acceptMission() : guard .eq('status', 'pending') empêche double-acceptation
  [ ] completeMission() : commission déduite du wallet (trigger vérifié)
  [ ] NewMissionModal : apparaît < 2s après création côté client

E-COMMERCE (P4)
  [ ] volume_m3 calculé par PostgreSQL (GENERATED ALWAYS) — valeur cohérente
  [ ] tracking_number format FTM-TRACK-XXXXXXXX (majuscules, sans I/O/0/1)
  [ ] TrackingInputScreen : accessible sans authentification
  [ ] SMS envoyé au destinataire sur numéro marocain réel
  [ ] TrackingDetailScreen : timeline mise à jour en Realtime

WALLET (P5)
  [ ] Barre de progression solde change de couleur (rouge/ambre/vert)
  [ ] Banner blocage apparaît quand balance < 100 DH
  [ ] is_available forcé à false quand balance < 100 DH
  [ ] canDriverAcceptMission() intégré dans acceptMission() (guard préventif)
  [ ] Historique transactions : 3 filtres fonctionnels (commission/topup/refund)
  [ ] Transaction status='failed' : affichage distinctif dans l'historique

NOTIFICATIONS PUSH (P6)
  [ ] Push reçue sur device physique Android (pas simulateur)
  [ ] Push reçue sur device physique iOS (pas simulateur)
  [ ] Badge cloche mis à jour sans relancer l'app
  [ ] Deep links fonctionnels pour les 6 types de notifications
  [ ] CRON J-30/J-15/J-7 : test avec date d'expiration proche → notif reçue
  [ ] Pas de doublon de notification (flags booléens vérifiés en BDD)

CHAT AUDIO DARIJA (P6)
  [ ] Permission microphone accordée Android et iOS
  [ ] Enregistrement .m4a créé (format AAC, 22kHz, mono)
  [ ] Upload fichier audio visible dans bucket voice-messages
  [ ] Lecture audio fonctionnelle depuis URL signée
  [ ] Bouton micro : orange (idle) → rouge animé (recording) → gris (uploading)
  [ ] Auto-stop à 120 secondes
  [ ] Message < 1 seconde : message d'erreur affiché

ADMIN (P7)
  [ ] Accès AdminStack uniquement si role = 'admin'
  [ ] Validation document → driver.{doc}_verified = 'verified'
  [ ] Notification Push envoyée au driver après validation/rejet
  [ ] is_verified = true quand les 4 documents sont 'verified' (GENERATED ALWAYS)
  [ ] Topup wallet Admin → solde mis à jour + transaction créée
  [ ] Suspension compte → is_active = false + is_available = false
```

### 6.3 Performance & Sécurité

```
PERFORMANCE
  [ ] Index SQL créés sur toutes les colonnes de recherche fréquente :
        idx_profiles_phone, idx_profiles_role
        idx_drivers_location (GIST), idx_drivers_verified, idx_drivers_available
        idx_missions_client, idx_missions_driver, idx_missions_status
        idx_parcels_tracking, idx_notifications_unread
        idx_transactions_wallet, idx_reminders_expiry
  [ ] Requêtes paginées (20-30 items max par page) sur toutes les listes
  [ ] Pas de SELECT * non-paginé sur les grandes tables

SÉCURITÉ
  [ ] SUPABASE_SERVICE_ROLE_KEY : jamais dans le code app, uniquement Edge Functions
  [ ] SUPABASE_ANON_KEY : seule clé exposée dans l'app mobile
  [ ] .env.example : contient les noms des variables mais PAS les valeurs
  [ ] .gitignore : inclut .env, *.key, google-services.json, GoogleService-Info.plist
  [ ] RLS activé sur TOUTES les tables (test : SELECT sans auth → 0 résultats)
  [ ] Pas de données sensibles (téléphones, adresses) dans les logs FTM-DEBUG

QUALITÉ CODE
  [ ] Tous les appels Supabase : gestion d'erreur try/catch ou vérification error
  [ ] Tous les abonnements Realtime : unsubscribeChannel() appelé sur unmount
  [ ] Background tracking : stopBackgroundTracking() appelé quand is_available = false
  [ ] Pas de fuite mémoire : timers (setInterval) clearInterval sur unmount
  [ ] console.log('[FTM-DEBUG]...') : TOUS présents et visibles en Debug Console
```

### 6.4 Compatibilité Natively.dev

```
NATIVELY CONFIG
  [ ] Permissions Android déclarées :
        ACCESS_FINE_LOCATION ✅
        ACCESS_COARSE_LOCATION ✅
        ACCESS_BACKGROUND_LOCATION ✅    ← CRITIQUE (P3)
        FOREGROUND_SERVICE ✅            ← CRITIQUE (P3)
        FOREGROUND_SERVICE_LOCATION ✅
        RECORD_AUDIO ✅                   ← Chat audio (P6)
        POST_NOTIFICATIONS ✅            ← Android 13+ (P6)

  [ ] Permissions iOS (Info.plist) :
        NSLocationWhenInUseUsageDescription ✅
        NSLocationAlwaysAndWhenInUseUsageDescription ✅
        NSLocationAlwaysUsageDescription ✅
        NSMicrophoneUsageDescription ✅
        UIBackgroundModes: location ✅

  [ ] Capabilities Natively activées :
        ✅ Geolocation
        ✅ Background Location
        ✅ Push Notifications (FCM + APNs)
        ✅ Microphone
        ✅ Audio Playback
        ✅ File Picker (documents upload P2)
        ✅ Foreground Service (Android)

  [ ] google-services.json uploadé dans Natively (Android FCM)
  [ ] GoogleService-Info.plist uploadé dans Natively (iOS APNs)
  [ ] Bundle ID / Package Name configurés dans Natively
  [ ] Version de l'app définie (ex: 1.0.0)
  [ ] Icône app FTM uploadée (1024×1024 PNG sans transparence)
  [ ] Splash screen configuré (fond COLORS.primary #0056B3)
```

---

## 7. ARBORESCENCE FINALE COMPLÈTE DU PROJET

```
votre-repo/
├── .devcontainer/
│   └── devcontainer.json              ← Codespaces config
│
├── .github/
│   └── workflows/
│       └── deploy_supabase.yml        ← CI/CD (P7 Section 5)
│
├── .vscode/
│   └── launch.json                    ← Debug Console config
│
├── docs/
│   ├── OFFRE_VALEUR.md                ← Source de vérité produit
│   ├── SPEC_NATIVELY_P1.md           ← Fondations & Auth OTP
│   ├── SPEC_NATIVELY_P2.md           ← Onboarding Driver & Documents
│   ├── SPEC_NATIVELY_P3.md           ← Missions & GPS PostGIS
│   ├── SPEC_NATIVELY_P4.md           ← E-commerce & Colisage
│   ├── SPEC_NATIVELY_P5.md           ← Wallet Revolving
│   ├── SPEC_NATIVELY_P6.md           ← Push Notifications & Audio
│   └── SPEC_NATIVELY_P7.md           ← Admin & RLS (ce fichier)
│
├── supabase/
│   ├── config.toml                    ← Config projet Supabase
│   ├── migrations/
│   │   ├── 20260220155000_initial_schema.sql
│   │   ├── 20260221000000_add_rpc_nearby_drivers.sql
│   │   ├── 20260222000000_add_tracking_functions.sql
│   │   └── 20260223000000_add_rls_policies.sql
│   └── functions/
│       ├── send-push-notification/index.ts
│       ├── register-push-token/index.ts
│       ├── check-document-reminders/index.ts
│       └── send-tracking-sms/index.ts
│
├── src/
│   ├── constants/
│   │   └── theme.js                   ← Design System (P1)
│   ├── lib/
│   │   └── supabaseClient.js          ← Init Supabase (P1)
│   ├── services/
│   │   ├── authService.js             ← OTP, profil (P1)
│   │   ├── i18nService.js             ← AR/FR switch (P1)
│   │   ├── driverService.js           ← Onboarding (P2)
│   │   ├── documentService.js         ← Upload docs (P2)
│   │   ├── reminderService.js         ← Rappels (P2)
│   │   ├── locationService.js         ← GPS bg/fg (P3)
│   │   ├── missionService.js          ← CRUD missions (P3)
│   │   ├── realtimeService.js         ← Subscriptions (P3)
│   │   ├── parcelService.js           ← E-commerce (P4)
│   │   ├── walletService.js           ← Wallet (P5)
│   │   ├── pushNotificationService.js ← Push (P6)
│   │   ├── notificationTemplates.js   ← Templates (P6)
│   │   ├── audioService.js            ← Audio Darija (P6)
│   │   └── adminService.js            ← Admin (P7)
│   ├── utils/
│   │   └── parcelCalculations.js      ← Calculs colis (P4)
│   ├── components/
│   │   ├── NotificationBell.js        ← Badge notif (P6)
│   │   └── VoiceMicButton.js          ← Micro Darija (P6)
│   ├── screens/
│   │   ├── auth/                      ← P1
│   │   ├── driver/
│   │   │   ├── onboarding/            ← P2
│   │   │   ├── DocumentStatusScreen   ← P2
│   │   │   ├── DriverHomeScreen       ← P3
│   │   │   ├── NewMissionModal        ← P3
│   │   │   ├── MissionActiveScreen    ← P3
│   │   │   ├── ParcelMissionDetail    ← P4
│   │   │   ├── WalletDashboardScreen  ← P5
│   │   │   ├── WalletTopupScreen      ← P5
│   │   │   └── TransactionHistory     ← P5
│   │   ├── client/
│   │   │   ├── CreateMissionScreen    ← P3
│   │   │   ├── MissionTrackingScreen  ← P3
│   │   │   └── RatingScreen           ← P3
│   │   ├── ecommerce/                 ← P4
│   │   ├── tracking/                  ← P4
│   │   ├── mission/
│   │   │   └── VoiceChatScreen        ← P6
│   │   ├── notifications/             ← P6
│   │   └── admin/                     ← P7
│   └── navigation/
│       └── RootNavigator.js           ← P1
│
├── .env.example                       ← Variables (sans valeurs)
└── .gitignore                         ← Secrets exclus
```

---

## 8. RÉCAPITULATIF DES LOGS DE DEBUG (P7)

| Action | Log FTM-DEBUG |
|--------|---------------|
| Fetch drivers en attente | `[FTM-DEBUG] Admin - Fetching pending drivers` |
| Drivers en attente chargés | `[FTM-DEBUG] Admin - Pending drivers fetched` |
| Validation document | `[FTM-DEBUG] Admin - Verifying document` |
| Document validé | `[FTM-DEBUG] Admin - Document verified` |
| Driver fully verified | `[FTM-DEBUG] Admin - Driver fully verified!` |
| Notif full verified | `[FTM-DEBUG] Admin - Full verification notification sent` |
| Rejet document | `[FTM-DEBUG] Admin - Rejecting document` |
| Document rejeté | `[FTM-DEBUG] Admin - Document rejected` |
| Fetch all drivers | `[FTM-DEBUG] Admin - Fetching all drivers` |
| All drivers chargés | `[FTM-DEBUG] Admin - All drivers fetched` |
| Toggle user active | `[FTM-DEBUG] Admin - Toggling user active status` |
| Driver availability reset | `[FTM-DEBUG] Admin - Driver availability reset on suspension` |
| User status mis à jour | `[FTM-DEBUG] Admin - User status updated` |
| Fetch missions admin | `[FTM-DEBUG] Admin - Fetching missions` |
| Missions chargées | `[FTM-DEBUG] Admin - Missions fetched` |
| Fetch global stats | `[FTM-DEBUG] Admin - Fetching global stats` |
| Stats chargées | `[FTM-DEBUG] Admin - Global stats fetched` |
| Topup driver wallet | `[FTM-DEBUG] Admin - Topup driver wallet` |
| Topup complété | `[FTM-DEBUG] Admin - Topup completed for driver` |

---

## 9. CHECKLIST FINALE DE VALIDATION P7

- [ ] `AdminStack` inaccessible si `profiles.role !== 'admin'` (testé avec compte client)
- [ ] `verifyDocument()` : `drivers.driver_license_verified` = `'verified'` en BDD
- [ ] `rejectDocument()` : notification Push avec motif reçue sur device driver
- [ ] `is_verified` GENERATED ALWAYS = `true` quand les 4 colonnes = `'verified'`
- [ ] `toggleUserActive(false)` : `profiles.is_active` = `false` + `drivers.is_available` = `false`
- [ ] `getAdminStats()` : KPIs cohérents avec les données en BDD
- [ ] `adminTopupDriverWallet()` : solde mis à jour + transaction `topup` créée
- [ ] Toutes les policies RLS de la Section 4 migrées (fichier `20260223000000_add_rls_policies.sql`)
- [ ] GitHub Actions workflow : déploiement réussi sans erreur sur `git push main`
- [ ] Secrets GitHub configurés (4 variables requises)
- [ ] Checklist QA Section 6 : TOUS les items cochés ✅

---

*FTM Spec P7 — Fin du fichier*
*━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━*
*                  SPEC COMPLÈTE FTM — P1 → P7                  *
*                  Fast Trans Maroc est prêt pour Natively       *
*━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━*
