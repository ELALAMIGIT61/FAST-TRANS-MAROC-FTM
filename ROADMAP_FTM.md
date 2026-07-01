# ROADMAP-DOCUMENT DE REFERENCE SESSION CLAUDE — FAST TRANS MAROC — VERSION 01/07/2026
# Fast Trans Maroc — Application Mobile Marocaine
# Dernière mise à jour : 01/07/2026

---

## 1. INFORMATIONS PROJET
Projet      : Fast Trans Maroc (FTM)
Stack       : Expo SDK 50 / React Native / TypeScript strict
Supabase    : ustckqnecsilxqlyjute (org: Tamesna Plus)
GitHub      : ELALAMIGIT61/FAST-TRANS-MAROC-FTM
Codespaces  : zany-disco-jj95647gqv473pj9

---

## 2. RÈGLES CRITIQUES — À LIRE EN PREMIER
⛔ NE JAMAIS utiliser npm audit fix --force
   (casse la stack SDK 50 → SDK 55 incompatible)
✅ Toujours utiliser --legacy-peer-deps si conflit
✅ Toujours utiliser npx expo install pour packages Expo
✅ .env doit être dans frontend/ (pas à la racine)
✅ Migrations : timestamps uniques obligatoires
   Prochain timestamp ≥ 20260504000013
   Jamais via SQL Editor directement
   Toujours via GitHub Actions
✅ 1 session Claude = 1 objectif précis
✅ Toujours fournir ce fichier en début de session
✅ Toujours ouvrir console navigateur DevTools
   avant tout test web
✅ Toujours regarder console DevTools
   en cas de page blanche ou crash silencieux
✅ 1 terminal de travail uniquement
   Ne jamais ouvrir un 3ème terminal
✅ Vérifier texte exact via sed avant
   tout replace() Python3
✅ Si replace() échoue → réécrire le fichier entier
   Ne jamais tâtonner avec replace() successifs
✅ Vérifier contenu exact d'un fichier via repr() Python
   Ne jamais se fier à cat pour les lignes longues
   (cat tronque les lignes — trompeur)
✅ git pull --rebase origin main avant tout push
   (ROADMAP mise à jour directement sur GitHub)
✅ Backup obligatoire avant chaque modification
✅ Test non-régression CLIENT + ADMIN + DRIVER
   après chaque étape de modification
✅ Ne jamais retester ce qui est écarté
✅ Ne jamais modifier ce qui fonctionne
✅ Toujours vérifier l'état des fichiers
   avant toute action
✅ 3 workflows GitHub INTOUCHABLES :
   check_supabase.yml
   deploy_supabase.yml
   lint_code.yml
⛔ NE JAMAIS modifier authService.ts
⛔ NE JAMAIS modifier ProfileSetupScreen.tsx
⛔ NE JAMAIS modifier driverService.ts
   Contient createDriverProfile,
   saveDriverDocuments, createDriverWallet
   Fichier stable — ne pas recréer
⚠️ COMPTE ADMIN +212600000001
   NE JAMAIS SUPPRIMER CE PROFIL
   Même entre les tests
⚠️ NUMÉRO PARTAGÉ +212600000000 — CLIENT OU DRIVER (exclusif)
   Le même numéro ne peut avoir qu'UN profil actif à la fois
   (recherche par user_id, suppression Auth = cascade profil/driver)

   Session 2.8 : profil DRIVER (1b6e684e-..., wallet 200 DH,
   vérifié) → SUPPRIMÉ pour tester CLIENT (ordre DRIVER→ADMIN→CLIENT)
   Session 2.9 : +212600000000 recréé en mode DRIVER
   driverId : 29849a0a-5017-4eda-99d4-2c4f5c75a6c3
   is_verified = true (validé admin session 2.9)
   Session 2.10 : profil DRIVER recréé
   driverId : eadc9d5e-0db9-4983-b0a3-b69ca46c0b60
   is_verified = true — wallet_balance : 200 DH
   État actuel : mode DRIVER actif

   Si un test CLIENT est à nouveau nécessaire :
   1. Supprimer +212600000000 dans Supabase Auth
   2. Reconnexion → ProfileSetupScreen → sélectionner "Client"

   Si un test DRIVER est à nouveau nécessaire
   (depuis un état CLIENT) :
   1. Supprimer +212600000000 dans Supabase Auth
   2. Reconnexion → ProfileSetupScreen → sélectionner "Driver"
   3. Remplir à nouveau les 4 pages onboarding :
      VehicleInfo → LegalDocuments → DocumentUpload → PendingVerification
   4. Validation admin requise pour is_verified=true
   5. Wallet 200 DH à recréditer manuellement si besoin
⚠️ window.history.back() ne fonctionne pas
   toujours sur web
   Utiliser le bouton "← Retour" (navigation.goBack())
✅ vault.create_secret(valeur, nom, description)
   Ordre exact : valeur en PREMIER, nom en SECOND
   Toujours vérifier avec SELECT name FROM vault.secrets
   immédiatement après création
✅ timeout_milliseconds := 30000 pour net.http_post
   Le timeout par défaut 5000 ms est insuffisant
   en cas de cold start Edge Function Supabase
✅ cron.unschedule() WHERE EXISTS
   Pattern obligatoire dans toute migration
   qui recrée un CRON job — évite les erreurs de doublon
✅ Diagnostic structuré obligatoire
   Établir un plan d'investigation complet et priorisé
   avant tout test — tester maillon par maillon dans l'ordre
✅ net.http_post → 401 persistant
   Première hypothèse : vérifier la clé Vault
   (longueur et comparaison directe avec Dashboard)
   pas uniquement le nom
✅ cron.job_run_details
   Table pg_cron contenant l'historique des exécutions
   avec statut et timestamps — consulter pour vérifier
   le fonctionnement réel du CRON
✅ Vérification git obligatoire
   Avant et après chaque pause, avant tout commit

---

## 3. ÉTAT TECHNIQUE ACTUEL
SDK Expo          : 50.0.21 ✅ stable
Vulnerabilities   : 39 (outils dev uniquement)
                    Impact ZÉRO sur app/publication
                    NE PAS corriger avec --force
                    Passage de 23 à 39 en session 2.4
                    Cause : dépendances dev de
                    expo-image-picker +
                    expo-document-picker
App démarre       : ✅ Web Bundled confirmé
Lancement app web : cd frontend &&
                    npx expo start --web --no-dev
URL web           : https://zany-disco-jj95647gqv473pj9
                    -8081.app.github.dev
Page blanche web  : ✅ RÉSOLUE — session 2.2
                    Cause : BORDER_RADIUS manquant
                    dans theme.ts — commit e7beed2
Bundle web        : ✅ 1173ms
Auth CLIENT       : ✅ confirmé — session 2.3
                    Navigation → CreateMissionScreen
Auth ADMIN        : ✅ confirmé — session 2.7
                    Navigation → AdminDashboardScreen
                    5 écrans dans AdminNavigator :
                    AdminHome ✅
                    DocumentReview ✅
                    WalletManagement ✅
                    AdminMissions ✅
                    AdminUsers ✅
Auth DRIVER       : ✅ COMPLET — session 2.4 suite
                    Flux complet testé et validé
                    Étape 1 → VehicleInfoScreen    ✅
                    Étape 2 → LegalDocumentsScreen ✅
                    Étape 3 → DocumentUploadScreen ✅
                    Étape 4 → PendingVerification  ✅
                    Validation admin → DriverHome  ✅
                    Realtime Supabase              ✅
Bugs session 2.5  : ✅ 3 bugs corrigés
                    BUG 1 → SIGNED_IN onboarding ✅
                    BUG 2 → wallet 404 ✅
                    BUG 3 → document_reminders ✅
Bugs session 2.7  : ✅ 5 bugs corrigés
                    BUG A → wallet RLS récursion ✅
                    BUG → navigation admin 4 menus ✅
                    BUG → SIGNED_IN loop admin ✅
                    BUG → 403 notifications ✅
                    BUG → enum mission_status ✅
                    BUG 4 → INFIRMÉ ✅
Packages ajoutés  : expo-image-picker ~14.7.1 ✅
                    expo-document-picker ~11.10.1 ✅
                    commit c318a92
Storage           : ✅ Bucket driver-documents créé
                    5 MB max — jpeg/png/pdf
                    RLS policies configurées
                    commits 7222601 + c39cafb
                    ✅ Bucket voice-messages créé — session 2.8
                    5 MB max — audio/m4a, mp4, mpeg, wav, x-m4a
                    RLS policies configurées (4)
                    commit 5ee383e
                    ⚠️ Infrastructure créée mais NON testée
                    fonctionnellement (audioService.ts non
                    référencé dans aucun screen — voir item 4.4)
Connexion Supabase: ✅ .env configuré dans frontend/
Token Supabase    : ✅ Renouvelé le 29/04/2026
                    Nom : FTM_GITHUB_ACTIONS
                    Expiration : Never
Mode test OTP     : ✅ configuré (MessageBird fictif)
                    Numéro test : +212600000000
                    Code fixe   : 123456
                    Valide jusqu'au : 31/12/2026
Extensions Supabase : ✅ pg_cron 1.6.4 — installée session 2.9
                      ✅ pg_net 0.19.5 — installée session 2.9
CRON reminders    : ✅ OPÉRATIONNEL — session 2.9
                    jobid=2, 0 8 * * *, active=true
                    timeout_milliseconds := 30000
                    5 exécutions succeeded : 18→22/06/2026
                    check-document-reminders appelée quotidiennement
Vault Supabase    : ✅ Secret supabase_service_role_key
                    219 caractères — identique Dashboard
                    Créé session 2.9 (correction ancien secret
                    incorrect 244 caractères)
Realtime Supabase : ✅ OPÉRATIONNEL — session 2.10
                    5 tables activées :
                    drivers, missions, wallet,
                    transactions, notifications
                    Migration 20260504000012 déployée
                    WalletDashboardScreen SUBSCRIBED ✅
                    Effets ⏳ probables (2 fenêtres/device)
                    transactions + notifications :
                    Realtime actif — non branché UI ⚠️
⚠️ Compte ADMIN test :
   Numéro : +212600000001
   Rôle admin défini via SQL Editor Supabase
   UPDATE profiles SET role='admin'
   WHERE phone_number='+212600000001'
   NE PAS SUPPRIMER CE PROFIL
⚠️ DRIVER TEST ACTIF — session 2.10 :
   driverId : eadc9d5e-0db9-4983-b0a3-b69ca46c0b60
   Numéro : +212600000000
   role : 'driver', is_verified : true
   wallet_balance : 200 DH
   vehicle_category : vul
   (Remplace 29849a0a-... de session 2.9)

⚠️ SIGNED_IN répétés en console admin :
   Comportement normal Supabase web
   via refresh token périodique
   Non bloquant — initializeApp() protégé

---

## 4. GITHUB SECRETS CONFIGURÉS
SUPABASE_ACCESS_TOKEN  ✅ renouvelé 29/04/2026
                          Token : FTM_GITHUB_ACTIONS
                          Expiration : Never
SUPABASE_PROJECT_ID    ✅ (ustckqnecsilxqlyjute)
SUPABASE_DB_PASSWORD   ✅
SUPABASE_ANON_KEY      ✅
SUPABASE_URL           ✅

---

## 5. HISTORIQUE COMMITS CLÉS
b65eb9d feat: enable Realtime on 5 tables
        (drivers, missions, wallet, transactions,
        notifications) — session 2.10 ✅
34b32c1 feat: configure CRON job for document expiry
        reminders - session 2.9 ✅
5ee383e feat: create voice-messages storage bucket
        and RLS policies ✅ session 2.8
aed0bee fix: replace Alert.alert with window.confirm
        in AdminUsersScreen for web compatibility
        ✅ session 2.8
750db88 fix: correct mission_status enum values
        in AdminMissionsScreen ✅ session 2.7
626e851 feat: add AdminMissions and AdminUsers
        screens to admin navigation ✅ session 2.7
445bdcb fix: add SELECT RLS policy on notifications
        for admin role ✅ session 2.7
2351bf3 fix: add INSERT RLS policy on notifications
        for authenticated users ✅ session 2.7
4ff3499 fix: add DocumentReview and WalletManagement
        screens to AdminNavigator ✅ session 2.7
6ee89b1 fix: prevent SIGNED_IN loop for admin role
        in RootNavigator ✅ session 2.7
d420007 fix: replace wallet_update_admin RLS policy
        use get_my_role() to fix infinite recursion
        ✅ session 2.7
c4194db docs: update ROADMAP session 2.6 ✅
0207e97 fix: add DocumentStatusScreen to driver
        navigation + add Mes documents button
        ✅ session 2.6
8c5d8c5 fix: add RLS INSERT policy on transactions
        table ✅ session 2.6
cac7f4d fix: drop and recreate driver_dashboard view
        fix column order error SQLSTATE 42P16
        ✅ session 2.6
884f00e fix: connect wallet screens to driver
        navigation + fix driver_dashboard view
        missing columns ✅ session 2.6
9f22d9d fix: add UNIQUE constraint on
        document_reminders (driver_id, document_type)
        enables upsert ON CONFLICT ✅ session 2.5
b4ec2ba fix: correct wallet table name
        wallets → wallet in DriverHomeScreen
        ✅ session 2.5
475274c fix: ignore SIGNED_IN during driver onboarding
        use ref to prevent spontaneous navigation
        ✅ session 2.5
f377534 docs: update ROADMAP session 2.4 ✅
c39cafb feat: add RLS policies driver-documents
        bucket ✅
7222601 feat: create driver-documents storage
        bucket ✅
6b9dae8 fix: prevent skip to PendingStack
        check doc URLs + web DatePicker fallback ✅
a23df8b fix: keep driver on onboarding if
        driver_license_number is null ✅
1c9af9c fix: allow null legal docs fields
        at step 1 ✅
6f7ed8c fix: allow null driver_license_number
        at step 1 ✅
8acc64c feat: connect driver onboarding
        VehicleInfo/LegalDocs/DocumentUpload/
        PendingVerification navigators ✅
c318a92 feat: add DriverOnboardingStack/
        DriverPendingStack routes + install
        expo-image-picker expo-document-picker ✅
b669da7 docs: update ROADMAP_FTM session 2.3 ✅
bd7ead0 fix: SIGNED_IN pour utilisateurs existants ✅
53725fe fix: clientProfileId transmis à
        CreateMissionScreen ✅
8a78903 fix: navigation post-profil via callback ✅
e7beed2 fix: BORDER_RADIUS ajouté theme.ts ✅

---

## 6. MODIFICATIONS COMMITÉES — DÉTAIL

### SESSION 2.4 INITIALE — commits c318a92 + 8acc64c

#### `frontend/src/types/database.ts` — commit c318a92
Ajout 2 nouvelles routes dans type AppRoute :
  'DriverOnboardingStack'
  'DriverPendingStack'

#### `frontend/package.json` — commit c318a92
  expo-image-picker ~14.7.1
  expo-document-picker ~11.10.1
  Commande : npx expo install expo-image-picker
             expo-document-picker

#### `frontend/src/navigation/RootNavigator.tsx` — commit 8acc64c
11 modifications :
1. Type retour initializeApp() étendu
2. Cas driver dans initializeApp() complet
3. States ajoutés : driverProfileId + driverVehicleCategory
4. useEffect — capte driverId + vehicleCategory
5. SIGNED_IN — capte driverId + vehicleCategory
6. Imports ajoutés : 4 écrans onboarding
7. Types navigation ajoutés : DriverOnboardingStackParamList
                               DriverPendingStackParamList
8. Navigateurs stack créés : DriverOnboardingStack
                              DriverPendingStack
9. Navigateurs créés : DriverOnboardingNavigator (4 écrans)
                        DriverPendingNavigator
10. DriverNavigator mis à jour
11. Rendu conditionnel ajouté

---

### SESSION 2.4 SUITE — commits 6f7ed8c → c39cafb

#### `frontend/src/navigation/RootNavigator.tsx`
Logique driver complète et définitive :
  !driver                → OnboardingStack
  !driver_license_number → OnboardingStack
  !toutes 4 URLs         → OnboardingStack
  !is_verified           → PendingStack
  sinon                  → HomeStack

#### `frontend/src/screens/driver/onboarding/LegalDocumentsScreen.tsx`
Fallback web pour DateTimePicker :
  Platform.OS === 'web' → input type="date" HTML natif
  Mobile → DateTimePicker natif inchangé

#### Migrations SQL ajoutées :
20260429000001 → driver_license_number DROP NOT NULL
20260429000002 → 5 champs légaux DROP NOT NULL
20260504000001 → CREATE bucket driver-documents
20260504000002 → RLS policies bucket driver-documents

---

### SESSION 2.5 — commits 475274c → 9f22d9d

#### `frontend/src/navigation/RootNavigator.tsx` — commit 475274c
Correction BUG 1 — SIGNED_IN stale closure :
  useRef<AppRoute> ajouté
  initialRouteRef.current synchronisé
  Condition : if (initialRouteRef.current
              !== "DriverOnboardingStack")

#### `frontend/src/screens/driver/DriverHomeScreen.tsx` — commit b4ec2ba
Correction BUG 2 — wallet 404 :
  .from('wallets') → .from('wallet') ligne 36

#### Migrations SQL ajoutées :
20260504000003 → UNIQUE constraint document_reminders

---

### SESSION 2.6 — commits 884f00e → c4194db

#### `frontend/src/navigation/RootNavigator.tsx` — commit 884f00e
4 écrans ajoutés dans DriverStackParamList + DriverNavigator :
  WalletDashboard, WalletTopup,
  TransactionHistory, DocumentStatus

#### Migrations SQL ajoutées :
20260504000004 → DROP + CREATE VIEW driver_dashboard
                  5 colonnes ajoutées
20260504000005 → RLS INSERT policy transactions
                  pour authenticated

---

### SESSION 2.7 — commits d420007 → 750db88

#### Migration `20260504000006` — commit d420007
Correction BUG A — wallet_update_admin RLS récursion :
  DROP POLICY wallet_update_admin
  CREATE POLICY wallet_update_admin
  USING (get_my_role() = 'admin')
  Même correctif que 20260226000000 sur profiles

#### `frontend/src/navigation/RootNavigator.tsx` — commit 6ee89b1
Correction SIGNED_IN loop admin :
  Condition étendue :
  if (initialRouteRef.current !== "DriverOnboardingStack"
      && initialRouteRef.current !== "AdminStack")
  Backup : RootNavigator.tsx.bak.session2.7

#### `frontend/src/navigation/RootNavigator.tsx` — commit 4ff3499
2 écrans admin connectés à AdminNavigator :
  DocumentReview → DocumentReviewScreen
  WalletManagement → WalletManagementScreen
  + imports + AdminStackParamList étendu
  Backup : RootNavigator.tsx.bak.session2.7b

#### Migrations `20260504000007` + `20260504000008` — commits 2351bf3 + 445bdcb
Correction 403 notifications — 2 couches :
  Couche 1 (007) : INSERT authenticated sur notifications
  Couche 2 (008) : SELECT admin via get_my_role()
  Cause : .insert({...}).select().single() tentait
          de lire la notification du driver avec
          le rôle admin → politique SELECT manquante

#### `frontend/src/screens/admin/AdminMissionsScreen.tsx` — commit 626e851
Nouvel écran créé (7130 bytes) :
  Liste toutes les missions avec filtres
  6 filtres : Toutes, En attente, En cours,
              Terminées, Annulées (client),
              Annulées (chauffeur)
  Pagination 25/page via getAdminMissions()
  Bouton Retour via navigation.goBack()
  Enum corrigé : cancelled → cancelled_client
                              + cancelled_driver

#### `frontend/src/screens/admin/AdminUsersScreen.tsx` — commit 626e851
Nouvel écran créé (6585 bytes) :
  Liste drivers avec statut actif/suspendu
  Barre de recherche par nom/téléphone
  Bouton Suspendre/Activer via toggleUserActive()
  Bouton Retour via navigation.goBack()
  ⚠️ Méthode création : Python 7 étapes séquentielles
     heredoc et -c posent problème avec ! et longueur
     Utiliser cette méthode pour fichiers longs

#### `frontend/src/navigation/RootNavigator.tsx` — commit 626e851
2 nouveaux écrans connectés à AdminNavigator :
  AdminMissions → AdminMissionsScreen
  AdminUsers → AdminUsersScreen
  + imports + AdminStackParamList étendu
  Backup : RootNavigator.tsx.bak.session2.7c

#### `frontend/src/screens/admin/AdminMissionsScreen.tsx` — commit 750db88
Correction enum mission_status :
  'cancelled' → 'cancelled_client' + 'cancelled_driver'
  STATUS_FILTERS, STATUS_LABELS, FILTER_LABELS mis à jour

---

### SESSION 2.8 — commits aed0bee → 5ee383e

#### `frontend/src/screens/admin/AdminUsersScreen.tsx` — commit aed0bee
Correction bug "Suspendre" non fonctionnel sur web :
  Cause : Alert.alert() (React Native) ne s'affiche pas sur web
          → clic silencieux, aucun appel réseau
  Correctif handleToggleActive() :
    Alert.alert(...) → window.confirm(...)
    if (confirmed === false) return;
    Erreurs → window.alert() au lieu de Alert.alert()
  Backup : AdminUsersScreen.tsx.bak.session2.8 (6585 bytes)
  Tests confirmés :
    "Annuler" ×2 → aucune action ✅
    "Suspendre"+OK → badge "Suspendu", isActive:false,
      driver availability reset ✅
    "Activer"+OK → badge "Actif", isActive:true ✅

#### Migrations `20260504000009` + `20260504000010` — commit 5ee383e
Création bucket voice-messages + RLS policies :
  20260504000009 : INSERT storage.buckets
    id/name: voice-messages, privé, 5MB,
    types: audio/m4a, mp4, mpeg, wav, x-m4a
  20260504000010 : 4 policies storage.objects
    (INSERT/SELECT/UPDATE/DELETE, bucket_id='voice-messages',
    authenticated) — même modèle que driver-documents
  Justification : audioService.ts (uploadVoiceMessage,
    loadVoiceMessages) référence ce bucket — confirmé
    par grep exhaustif (screens + services + edge functions)
  Vérifié en base : storage.buckets (2 lignes),
    pg_policies storage.objects (8/8)
  ⚠️ Non testé fonctionnellement — audioService.ts non
    intégré dans l'UI (aucun screen ne l'appelle)

#### Test CLIENT — `CreateMissionScreen` (session 2.8)
Procédure :
  Suppression +212600000000 Auth → cascade suppression
  profil/driver 1b6e684e-... → reconnexion → ProfileSetupScreen
  → "Client" → nouveau profil 86c76d5f-...
Formulaire rempli et fonctionnel (Avenue Mohammed V/RABAT/
  VUL/1000 DH/commission 25 DH) ✅
Bouton "Trouver un chauffeur" — CONFIRMÉ désactivé :
  [FTM-DEBUG] GPS - Client location permission denied
  pickupCoords === null → bouton grisé
Tentative déblocage permission navigateur (Bloqué→Demander)
  → permission denied persiste → limitation environnement
  Codespaces/iframe confirmée (pas un bug applicatif)

---

### SESSION 2.9 — commit 34b32c1

#### Migration `20260504000011` — commit 34b32c1
Configuration CRON job document expiry reminders :
  Activation extensions :
    CREATE EXTENSION IF NOT EXISTS pg_net  → 0.19.5 ✅
    CREATE EXTENSION IF NOT EXISTS pg_cron → 1.6.4 ✅
  Secret Vault :
    vault.create_secret(service_role_key,
      'supabase_service_role_key',
      'Service role key for CRON job - FTM')
    219 caractères — identique Dashboard ✅
  CRON job :
    cron.unschedule() WHERE EXISTS (pattern anti-doublon)
    cron.schedule('check-document-reminders',
      '0 8 * * *', net.http_post(...,
      timeout_milliseconds := 30000))
    jobid=2, active=true ✅
  Résultat Edge Function :
    {sent: 3, errors: 0} ✅ (test avec driver 29849a0a-...)
    Flags reminder_30/15/7_days_sent → true ✅
    3 notifications document_expiry créées ✅
  5 exécutions succeeded confirmées : 18→22/06/2026 ✅
  Nettoyage post-test :
    notifications document_expiry supprimées
    document_reminders driver test supprimées

#### Driver test recréé — session 2.9
  Procédure :
    +212600000000 supprimé de Auth (était CLIENT 86c76d5f-...)
    Recréé via app → mode DRIVER — 4 pages onboarding
    driverId : 29849a0a-5017-4eda-99d4-2c4f5c75a6c3
    Validation admin +212600000001 → is_verified=true ✅
    document_reminders créées automatiquement par l'app ✅
  État : remplacé par eadc9d5e-... en session 2.10

---

### SESSION 2.10 — commit b65eb9d

#### Migration `20260504000012` — commit b65eb9d
Activation Realtime sur 5 tables :
  ALTER PUBLICATION supabase_realtime
  ADD TABLE drivers, missions, wallet,
  transactions, notifications;
  Taille : 152 bytes ✅
  Déploiement : Deploy Supabase FTM #42
    Run 1 ❌ Lint SQL — rate limit exceeded (transitoire)
    Run 2 ✅ Success — 2m 25s
  Vérification : 5 rows dans supabase_realtime ✅
    public | drivers       ✅
    public | missions      ✅
    public | notifications ✅
    public | transactions  ✅
    public | wallet        ✅

#### Constats identifiés — session 2.10
  Navigation cross-stack :
    navigation.replace('DriverHome') dans
    PendingVerificationScreen cible écran absent
    du stack DriverPendingStack ⚠️
    Navigation actuelle via onAuthStateChange/
    initializeApp() — pas via Realtime
  revenue_current_month : nommage trompeur
    Calcule total topup du mois (transaction_type='topup')
    Libellé UI "REVENUS CE MOIS" à corriger
    en "RECHARGES CE MOIS" ⚠️
  NotificationBell : composant prêt
    Jamais monté dans l'app ⚠️
  subscribeToNewTransactions : défini
    dans walletService.ts — jamais appelé ⚠️
  TrackingDetailScreen : souscription définie
    mais commentée — manque requête
    mission_id depuis tracking_number ⚠️

---

## 7. CHAÎNE DE NAVIGATION DRIVER
ProfileSetupScreen
  → onProfileCreated(role='driver')
  → DriverOnboardingStack

VehicleInfoScreen
  → appelle createDriverProfile()
  → navigate('LegalDocuments', { driverId })

LegalDocumentsScreen [reçoit driverId]
  → appelle saveDriverDocuments()
  → navigate('DocumentUpload', { driverId })

DocumentUploadScreen [reçoit driverId]
  → appelle uploadDocument() × 4
  → upload dans bucket driver-documents
  ⚠️ limitations web : bouton Photo non disponible
     utiliser bouton Fichier uniquement sur web
  → navigate('PendingVerification', { driverId })

PendingVerificationScreen [reçoit driverId]
  → souscrit realtime driver-verification-{driverId}
  → si is_verified === true
  → navigation.replace('DriverHome')

DriverHomeScreen
  → attend driverId : string — obligatoire
  → attend vehicleCategory : string — obligatoire
    ('vul' | 'n2_medium' | 'n2_large')
  → affiche solde wallet (table wallet sans 's')
  → carte Wallet → WalletDashboard { driverId }
  → bouton Mes documents → DocumentStatus

⚠️ is_verified = GENERATED ALWAYS AS
   Devient true quand ces 4 champs = 'verified' :
   driver_license_verified
   vehicle_registration_verified
   insurance_verified
   technical_inspection_verified

   Pour simuler validation admin — SQL Editor :
   UPDATE drivers SET
     driver_license_verified = 'verified',
     vehicle_registration_verified = 'verified',
     insurance_verified = 'verified',
     technical_inspection_verified = 'verified'
   WHERE license_plate = 'VOTRE_PLAQUE';

---

## 8. CHAÎNE DE NAVIGATION ADMIN
AdminDashboardScreen
  → Documents en attente → DocumentReviewScreen ✅
  → Toutes les missions  → AdminMissionsScreen  ✅
  → Gestion utilisateurs → AdminUsersScreen     ✅
  → Wallets & Transactions → WalletManagementScreen ✅

DocumentReviewScreen
  → Valider/Rejeter documents driver
  → Notification driver via insertNotification()
  → Driver fully verified → DriverHomeScreen (realtime)

WalletManagementScreen
  → Liste drivers vérifiés avec solde
  → Recharger wallet → adminTopupDriverWallet()
  → Solde mis à jour en temps réel ✅

AdminMissionsScreen
  → Liste toutes missions avec 6 filtres
  → Enum mission_status :
    pending / accepted / in_progress /
    completed / cancelled_client / cancelled_driver

AdminUsersScreen
  → Liste drivers avec statut actif/suspendu
  → Suspendre/Activer via toggleUserActive()

---

## 9. PROBLÈMES RENCONTRÉS ET RÉSOLUS

RÉSOLU 1 — Page blanche web (session 2.2)
Cause    : BORDER_RADIUS manquant theme.ts
Correctif: export BORDER_RADIUS ajouté
Commit   : e7beed2

RÉSOLU 2 — Navigation post-profil (session 2.3)
Cause    : SIGNED_IN déclenché avant création
           profil — closure JavaScript —
           initialRoute figé
Correctif: callback onProfileCreated depuis
           ProfileSetupScreen → RootNavigator
Commits  : 8a78903 + 53725fe + bd7ead0

RÉSOLU 3 — Page blanche après packages (2.4)
Cause    : expo-image-picker absent package.json
Correctif: npx expo install expo-image-picker
           expo-document-picker
Commit   : c318a92

RÉSOLU 4 — Terminal défaillant (session 2.4)
Cause    : 3ème terminal ouvert manuellement
Correctif: fermeture + reprise terminal frontend
Règle    : 1 terminal de travail uniquement

RÉSOLU 5 — replace() Python3 sans effet
Cause    : texte cible inexact
Correctif: vérification via sed avant replace()
           Si échec → réécrire le fichier entier

RÉSOLU 6 — driver_license_number NOT NULL
Cause    : champ collecté étape 2
           mais contrainte dès étape 1
Correctif: migration DROP NOT NULL
Commit   : 6f7ed8c

RÉSOLU 7 — Champs légaux NOT NULL (5 champs)
Cause    : même architecture étape 1 / étape 2
Correctif: migration DROP NOT NULL × 5
Commit   : 1c9af9c

RÉSOLU 8 — Passage spontané étape 2 → étape 4
Cause    : SIGNED_IN relançait initializeApp()
           driver sans license_number
           → PendingStack immédiatement
Correctif: condition !driver_license_number
           → OnboardingStack
Commit   : a23df8b

RÉSOLU 9 — Passage spontané étape 3 → étape 4
Cause    : SIGNED_IN relançait initializeApp()
           driver avec license_number
           mais sans vérifier URLs documents
Correctif: condition !toutes 4 URLs
           → OnboardingStack
Commit   : 6b9dae8

RÉSOLU 10 — DateTimePicker non supporté web
Cause    : composant natif mobile uniquement
Correctif: fallback Platform.OS === 'web'
           → input type="date" HTML natif
Commit   : 6b9dae8

RÉSOLU 11 — Bucket not found (Storage)
Cause    : bucket driver-documents non créé
Correctif: migration SQL CREATE bucket
Commit   : 7222601

RÉSOLU 12 — RLS Storage bloque upload
Cause    : bucket sans politique d'accès
Correctif: migration RLS policies × 4
Commit   : c39cafb

RÉSOLU 13 — Token Supabase expiré
Cause    : SUPABASE_ACCESS_TOKEN expiré
           GitHub Actions rejeté "Unauthorized"
Correctif: nouveau token FTM_GITHUB_ACTIONS
           Never expires — mis à jour GitHub Secrets
Statut   : RÉSOLU ✅ 29/04/2026

RÉSOLU 14 — SIGNED_IN interrompt onboarding
           étape 3 (BUG 1 session 2.5)
Cause    : stale closure — initialRoute capturé
           dans onAuthStateChange gardait
           l'ancienne valeur
           → initializeApp() relancé
           → PendingStack immédiat
Correctif: useRef<AppRoute> ajouté
           initialRouteRef.current synchronisé
           Condition !== "DriverOnboardingStack"
           dans SIGNED_IN
Commit   : 475274c

RÉSOLU 15 — GET /wallets → 404
           (BUG 2 session 2.5)
Cause    : .from('wallets') — 's' en trop
           Table en base : wallet (sans 's')
Correctif: .from('wallet') — ligne 36
           DriverHomeScreen.tsx
Commit   : b4ec2ba

RÉSOLU 16 — document_reminders ON CONFLICT → 400
           (BUG 3 session 2.5)
Cause    : contrainte UNIQUE manquante sur
           (driver_id, document_type)
           upsert impossible sans contrainte
Correctif: migration SQL
           ADD CONSTRAINT UNIQUE
           (driver_id, document_type)
Commit   : 9f22d9d

RÉSOLU 17 — Écrans wallet non connectés
           navigation (session 2.6)
Cause    : WalletDashboard, WalletTopup,
           TransactionHistory, DocumentStatus
           absents de DriverStackParamList
           et DriverNavigator
Correctif: 4 écrans ajoutés dans RootNavigator
           imports + params + navigateurs
Commit   : 884f00e

RÉSOLU 18 — driverId undefined WalletDashboard
           (session 2.6)
Cause    : driverId non transmis via route.params
           NativeStackScreenProps manquant
Correctif: NativeStackScreenProps ajouté
           lecture driverId depuis route.params
Commit   : 884f00e

RÉSOLU 19 — Vue driver_dashboard incomplète
           SQLSTATE 42P16 (session 2.6)
Cause    : colonnes manquantes :
           wallet_id, minimum_balance,
           is_wallet_blocked,
           commissions_current_month,
           revenue_current_month
Correctif: DROP + CREATE VIEW driver_dashboard
           5 colonnes ajoutées
Commit   : cac7f4d

RÉSOLU 20 — Erreur 403 RLS INSERT transactions
           (session 2.6)
Cause    : politique RLS manquante pour INSERT
           sur table transactions
           pour utilisateurs authenticated
Correctif: migration RLS INSERT policy
           pour authenticated
Commit   : 8c5d8c5

RÉSOLU 21 — DocumentStatusScreen non accessible
           (session 2.6)
Cause    : écran absent de la navigation driver
           bouton manquant dans DriverHomeScreen
Correctif: ajout dans DriverStackParamList
           + DriverNavigator
           + bouton "📄 Mes documents"
             dans DriverHomeScreen
Commit   : 0207e97

RÉSOLU 22 — BUG 4 SQL UPDATE phone_number
           → 0 row — INFIRMÉ (session 2.7)
Cause    : numéro format +212600000000
           présent tel quel en base
           UPDATE fonctionne correctement
Statut   : INFIRMÉ ✅ — non reproduit

RÉSOLU 23 — BUG A wallet_update_admin
           récursion RLS (session 2.7)
Cause    : EXISTS (SELECT FROM profiles)
           → récursion RLS infinie
Correctif: get_my_role() = 'admin'
           Fonction SECURITY DEFINER
Commit   : d420007
Confirmé : balanceBefore: 0
           balanceAfter: 200 DH ✅

RÉSOLU 24 — Navigation admin 4 menus
           silencieuse (session 2.7)
Cause    : AdminNavigator ne contenait
           qu'AdminHome — 4 routes absentes
Correctif: Déclarer tous les écrans
           dans AdminNavigator
Commits  : 4ff3499 + 626e851

RÉSOLU 25 — SIGNED_IN loop admin
           (session 2.7)
Cause    : Condition !== "DriverOnboardingStack"
           ne couvrait pas AdminStack
Correctif: Ajouter && !== "AdminStack"
Commit   : 6ee89b1

RÉSOLU 26 — 403 Forbidden notifications
           (session 2.7)
Cause    : 2 couches :
           1. INSERT — politique {public}
           2. SELECT — admin ne peut pas lire
              notif du driver
Correctif: Migration 007 INSERT authenticated
           Migration 008 SELECT admin
           get_my_role()
Commits  : 2351bf3 + 445bdcb

RÉSOLU 27 — Enum mission_status incorrect
           (session 2.7)
Cause    : 'cancelled' inexistant dans l'enum
Correctif: STATUS_FILTERS + STATUS_LABELS
           + FILTER_LABELS mis à jour
           cancelled_client + cancelled_driver
Commit   : 750db88

RÉSOLU 28 — Création fichier long via Python
           (session 2.7)
Cause    : heredoc et -c posent problème
           avec caractère ! et longueur
Correctif: Écriture en 7 étapes séquentielles
           python3 -c "f=open(...,'a');
           f.write(...)"
Règle    : Utiliser pour tout fichier
           > 100 lignes

RÉSOLU 29 — Bug "Suspendre" AdminUsersScreen
           non fonctionnel sur web (session 2.8)
Cause    : Alert.alert() (React Native)
           ne s'affiche pas sur web
           → clic silencieux, aucun appel réseau
Correctif: window.confirm() à la place
           if (confirmed === false) return;
           Erreurs → window.alert()
Commit   : aed0bee
Confirmé : "Annuler" ×2 → aucune action ✅
           "Suspendre"+OK → isActive:false ✅
           "Activer"+OK → isActive:true ✅

RÉSOLU 30 — Bucket voice-messages + RLS
           (session 2.8)
Cause    : audioService.ts référençait
           un bucket inexistant
Correctif: Migrations 009 + 010
           Bucket créé + 4 RLS policies
Commit   : 5ee383e
⚠️ Non testé fonctionnellement —
   audioService.ts non intégré UI
   Voir item 4.4

RÉSOLU 31 — Cause GPS AdminMissions
           confirmée (session 2.8)
Cause    : pickupCoords=null —
           permission GPS refusée
           environnement Codespaces/iframe
Statut   : Confirmé par logs directs —
           [FTM-DEBUG] GPS - Client location
           permission denied
           Pas un bug applicatif
           Reporté phase 4.x avec TEST 1/2/3

RÉSOLU 32 — vault.create_secret() arguments inversés
Cause    : Supabase a stocké la description comme nom
           → secret stocké avec name =
           'Service role key for CRON job - FTM'
           au lieu de 'supabase_service_role_key'
           → clé Vault incorrecte (244 vs 219 caractères)
Certitude: 100% confirmé — comparaison directe
           cles_identiques = false
Correctif: DELETE FROM vault.secrets WHERE name =
           'Service role key for CRON job - FTM'
           + vault.create_secret(valeur, nom, desc)
           avec ordre correct (valeur en PREMIER)
           + SELECT name FROM vault.secrets
           pour vérification immédiate
Statut   : RÉSOLU ✅ session 2.9

RÉSOLU 33 — net.http_post → 401 persistant
Cause    : Clé Vault incorrecte (244 vs 219 car.)
           + timeout 5000 ms insuffisant
           (cold start Edge Function dépasse 5s)
Diagnostic: Plan en 10 maillons — maillon par maillon :
           Maillon 1 (Vault retourne clé) ✅
           Maillon 2 (Header construit) ✅
           Maillon 3 (DNS+TCP/SSL) ✅
           Maillon 4 (Timeout) → timeout_ms := 30000
           Test httpbin.org → 200 → pg_net OK général
           Comparaison longueur clé → 244 vs 219 ❌
Correctif: Correction Vault (voir RÉSOLU 32)
           + timeout_milliseconds := 30000
Statut   : RÉSOLU ✅ session 2.9
           status_code = 200, timed_out = false ✅

RÉSOLU 34 — pg_cron non activé au démarrage
Cause    : SELECT * FROM cron.job → erreur 42P01
           pg_cron et pg_net disponibles mais
           non installées
Correctif: CREATE EXTENSION IF NOT EXISTS pg_net
           CREATE EXTENSION IF NOT EXISTS pg_cron
           inclus dans migration 20260504000011
Statut   : RÉSOLU ✅ session 2.9

RÉSOLU 35 — Realtime inactif sur tables FTM
           (session 2.10)
Cause    : puballtables = false — aucune table
           dans supabase_realtime avant session
           0 tables activées — souscriptions
           existantes sans effet
Correctif: ALTER PUBLICATION supabase_realtime
           ADD TABLE drivers, missions, wallet,
           transactions, notifications
           Migration 20260504000012
Commit   : b65eb9d
Confirmé : 5 rows supabase_realtime ✅
           WalletDashboardScreen SUBSCRIBED ✅

---

## 10. PISTES DÉFINITIVEMENT ÉCARTÉES
Ne pas retester :
❌ locationService import statique
❌ expo-haptics / expo-notifications
❌ expo-location fallback web
❌ missionService / realtimeService
❌ react-native-screens sans fallback web
❌ NativeStackScreenProps sans type
❌ Dépendance circulaire missionService
❌ audioService / expo-av (contexte : débogage page blanche
   session 2.x — N'IMPLIQUE PAS l'abandon de la fonctionnalité
   messages vocaux, voir item 4.4)
❌ supabaseClient.ts
❌ showAuth logique incorrecte
❌ ErrorBoundary capture l'erreur
❌ --no-dev résout seul
❌ 'cancelled' comme valeur enum mission_status
   Valeurs correctes : cancelled_client
                       + cancelled_driver
❌ cron.run_job(integer)
   pg_cron 1.6.4 ne supporte pas cette fonction

---

## 11. MIGRATIONS SUPABASE DÉPLOYÉES
20260220155500_initial_schema.sql                    ✅ P1-P2
20260221000000_add_rpc_nearby_drivers.sql            ✅ P3
20260222000000_add_tracking_functions.sql            ✅ P4
20260223000000_add_push_tokens.sql                   ✅ P6
20260224000000_add_rls_policies.sql                  ✅ P7
20260226000000_fix_profiles_rls_recursion.sql        ✅ Phase 2.1
20260429000001_allow_null_driver_license_number.sql  ✅ Session 2.4
20260429000002_allow_null_legal_docs_fields.sql      ✅ Session 2.4
20260504000001_create_driver_documents_bucket.sql    ✅ Session 2.4
20260504000002_storage_rls_policies.sql              ✅ Session 2.4
20260504000003_add_unique_constraint_document_reminders.sql ✅ Session 2.5
20260504000004_update_driver_dashboard_view.sql      ✅ Session 2.6
20260504000005_add_transactions_insert_policy.sql    ✅ Session 2.6
20260504000006_fix_wallet_update_admin_rls.sql       ✅ Session 2.7
20260504000007_fix_notifications_insert_rls.sql      ✅ Session 2.7
20260504000008_fix_notifications_select_admin.sql    ✅ Session 2.7
20260504000009_create_voice_messages_bucket.sql      ✅ Session 2.8
20260504000010_voice_messages_storage_rls_policies.sql ✅ Session 2.8
20260504000011_configure_cron_document_reminders.sql ✅ Session 2.9
20260504000012_enable_realtime_tables.sql            ✅ Session 2.10

Prochain timestamp disponible : 20260504000013

---

## 12. EDGE FUNCTIONS DÉPLOYÉES
send-push-notification   ✅ (CORS bloqué sur web —
                            fonctionnel sur device)
register-push-token      ✅
check-document-reminders ✅ (CRON opérationnel — session 2.9
                            5 exécutions succeeded 18→22/06/2026)
send-tracking-sms        ✅

---

## 13. ARBORESCENCE COMPLÈTE DU REPO
FAST-TRANS-MAROC-FTM/
├── .github/
│   └── workflows/
│       ├── check_supabase.yml        ← INTOUCHABLE
│       ├── deploy_supabase.yml       ← INTOUCHABLE
│       └── lint_code.yml             ← INTOUCHABLE
├── docs/
│   ├── SPEC_NATIVELY_P1.md
│   ├── SPEC_NATIVELY_P2.md
│   ├── SPEC_NATIVELY_P3.md
│   ├── SPEC_NATIVELY_P4.md
│   ├── SPEC_NATIVELY_P5.md
│   ├── SPEC_NATIVELY_P6.md
│   └── SPEC_NATIVELY_P7.md
├── frontend/
│   ├── .env
│   ├── .env.example
│   ├── App.tsx
│   ├── package.json        ← expo-image-picker ajouté
│   ├── package-lock.json
│   ├── tsconfig.json
│   └── src/
│       ├── components/
│       │   ├── NotificationBell.tsx
│       │   └── VoiceMicButton.tsx
│       ├── constants/
│       │   └── theme.ts        ← BORDER_RADIUS ajouté
│       ├── lib/
│       │   └── supabaseClient.ts
│       ├── navigation/
│       │   └── RootNavigator.tsx ← session 2.7 — 5 écrans admin
│       ├── screens/
│       │   ├── admin/
│       │   │   ├── AdminDashboardScreen.tsx
│       │   │   ├── AdminMissionsScreen.tsx  ← créé session 2.7
│       │   │   ├── AdminUsersScreen.tsx     ← créé session 2.7
│       │   │   ├── DocumentReviewScreen.tsx
│       │   │   └── WalletManagementScreen.tsx
│       │   ├── auth/
│       │   │   ├── OTPVerificationScreen.tsx
│       │   │   ├── PhoneInputScreen.tsx
│       │   │   └── ProfileSetupScreen.tsx ← INTOUCHABLE
│       │   ├── client/
│       │   │   ├── CreateMissionScreen.tsx
│       │   │   ├── MissionTrackingScreen.tsx
│       │   │   └── RatingScreen.tsx
│       │   ├── driver/
│       │   │   ├── DocumentStatusScreen.tsx
│       │   │   ├── DriverHomeScreen.tsx
│       │   │   ├── MissionActiveScreen.tsx
│       │   │   ├── NewMissionModal.tsx
│       │   │   ├── ParcelMissionDetailScreen.tsx
│       │   │   ├── TransactionDetailModal.tsx
│       │   │   ├── TransactionHistoryScreen.tsx
│       │   │   ├── WalletDashboardScreen.tsx
│       │   │   ├── WalletTopupScreen.tsx
│       │   │   └── onboarding/
│       │   │       ├── DocumentUploadScreen.tsx
│       │   │       ├── LegalDocumentsScreen.tsx
│       │   │       ├── PendingVerificationScreen.tsx
│       │   │       └── VehicleInfoScreen.tsx
│       │   ├── ecommerce/
│       │   │   ├── CreateParcelScreen.tsx
│       │   │   ├── ParcelConfirmationScreen.tsx
│       │   │   └── ParcelHistoryScreen.tsx
│       │   ├── mission/
│       │   │   └── VoiceChatScreen.tsx
│       │   ├── notifications/
│       │   │   └── NotificationCenterScreen.tsx
│       │   └── tracking/
│       │       ├── TrackingDetailScreen.tsx
│       │       └── TrackingInputScreen.tsx
│       ├── services/
│       │   ├── adminService.ts
│       │   ├── audioService.ts
│       │   ├── authService.ts         ← INTOUCHABLE
│       │   ├── documentService.ts
│       │   ├── driverService.ts       ← STABLE INTOUCHABLE
│       │   ├── i18nService.ts
│       │   ├── locationService.ts
│       │   ├── missionService.ts
│       │   ├── notificationTemplates.ts
│       │   ├── parcelService.ts
│       │   ├── pushNotificationService.ts
│       │   ├── realtimeService.ts
│       │   ├── reminderService.ts
│       │   └── walletService.ts
│       ├── types/
│       │   └── database.ts
│       └── utils/
│           └── parcelCalculations.ts
├── supabase/
│   ├── config.toml
│   ├── functions/
│   │   ├── check-document-reminders/
│   │   ├── register-push-token/
│   │   ├── send-push-notification/
│   │   └── send-tracking-sms/
│   └── migrations/
│       ├── 20260220155500_initial_schema.sql
│       ├── 20260221000000_add_rpc_nearby_drivers.sql
│       ├── 20260222000000_add_tracking_functions.sql
│       ├── 20260223000000_add_push_tokens.sql
│       ├── 20260224000000_add_rls_policies.sql
│       ├── 20260225000000_enable_rls_push_tokens.sql
│       ├── 20260226000000_fix_profiles_rls_recursion.sql
│       ├── 20260429000001_allow_null_driver_license_number.sql
│       ├── 20260429000002_allow_null_legal_docs_fields.sql
│       ├── 20260504000001_create_driver_documents_bucket.sql
│       ├── 20260504000002_storage_rls_policies.sql
│       ├── 20260504000003_add_unique_constraint_document_reminders.sql
│       ├── 20260504000004_update_driver_dashboard_view.sql
│       ├── 20260504000005_add_transactions_insert_policy.sql
│       ├── 20260504000006_fix_wallet_update_admin_rls.sql
│       ├── 20260504000007_fix_notifications_insert_rls.sql
│       ├── 20260504000008_fix_notifications_select_admin.sql
│       ├── 20260504000009_create_voice_messages_bucket.sql
│       ├── 20260504000010_voice_messages_storage_rls_policies.sql
│       ├── 20260504000011_configure_cron_document_reminders.sql ← session 2.9
│       └── 20260504000012_enable_realtime_tables.sql            ← session 2.10
├── .env.example
├── .gitignore
├── ROADMAP_FTM.md
└── install_*.sh

---

## 14. SERVICES EXTERNES — ÉTAT
Twilio SMS       : ⏳ pas encore configuré
FCM Android      : ⏳ pas encore configuré
                   ⚠️ send-push-notification bloquée
                   par CORS sur web — fonctionnel
                   sur device physique uniquement
APNs iOS         : ⏳ pas encore configuré
Storage buckets  : ✅ driver-documents créé
                   ✅ voice-messages créé — session 2.8
                   ⚠️ voice-messages non testé fonctionnellement
                   (audioService.ts non intégré UI — item 4.4)
CRON reminders   : ✅ OPÉRATIONNEL — session 2.9
                   check-document-reminders — 0 8 * * *
                   5 exécutions succeeded : 18→22/06/2026
                   timeout_milliseconds := 30000

---

## 15. BUGS RÉSIDUELS — SESSION 2.10

⚠️ CORS send-push-notification
   Edge Function bloquée par CORS policy sur web
   net::ERR_FAILED — non bloquant sur web
   Fonctionnel sur device physique
   À corriger pour production

⚠️ Filtres AdminMissionsScreen
   Affichés ✅ mais aucune mission en base
   Cause CONFIRMÉE (session 2.8) : pickupCoords=null,
   géolocalisation bloquée en environnement web/Codespaces
   → reporté phase 4.x avec TEST 1/2/3

⚠️ Realtime driver end-to-end
   Navigation directe DriverHomeScreen ✅
   Mais flux avec 2 fenêtres simultanées
   non testé explicitement

⚠️ AdminMissions pagination
   Non testée — 0 missions en base
   (même cause que ci-dessus)

⚠️ WalletTopupScreen
   Transaction enregistrée ✅
   Solde non mis à jour — comportement voulu
   Refonte prévue Phase 6.5

⚠️ Point sécurité 6.6 (session 2.8)
   RLS Storage permissif sur driver-documents +
   voice-messages : tout utilisateur authenticated peut
   lire/écrire/modifier/supprimer N'IMPORTE QUEL fichier
   (pas de vérification auth.uid()/propriété/mission)
   À traiter avant production — voir item 6.6

⚠️ voice-messages non testé fonctionnellement
   (session 2.8) — audioService.ts non intégré UI,
   voir item 4.4

⚠️ Driver test recréé (session 2.10)
   driverId : eadc9d5e-0db9-4983-b0a3-b69ca46c0b60
   +212600000000 → DRIVER actif — is_verified = true
   wallet_balance : 200 DH — vehicle_category : vul
   document_reminders : créées automatiquement
   à l'onboarding — non nettoyées après session 2.10
   (Remplace 29849a0a-... de session 2.9)

⚠️ COMPORTEMENT NON EXPLIQUÉ — repr() vs terminal
   (session 2.9) — statut INCONNU
   Plusieurs vérifications via repr() affichaient
   'CRONjob' collé alors que VS Code montrait
   'CRON job' avec espace
   Hypothèse : décalage entre exécutions successives
   Cause exacte inconnue
   Fichier final validé correct par repr() frais
   et Ctrl+F VS Code
   Règle : toujours valider avec repr() frais
   après chaque modification

⚠️ Navigation cross-stack PendingVerification → DriverHome
   navigation.replace('DriverHome') cible écran absent
   du stack DriverPendingStack
   Navigation actuelle via onAuthStateChange/initializeApp()
   — pas via Realtime
   À corriger — session 2.11 à planifier

⚠️ revenue_current_month — nommage trompeur
   Libellé UI "REVENUS CE MOIS" incorrect
   Calcule total topup du mois — pas revenus missions
   Calcul correct — libellé à corriger
   À traiter — session 2.11 à planifier

⚠️ NotificationBell — jamais monté dans l'app
   Composant prêt — NotificationCenter absent
   de RootNavigator
   À intégrer — décision porteur (session 2.11)

⚠️ subscribeToNewTransactions — jamais appelé
   Défini dans walletService.ts
   À brancher dans TransactionHistoryScreen
   À intégrer — décision porteur (session 2.11)

⚠️ TrackingDetailScreen — souscription commentée
   Manque requête mission_id depuis tracking_number
   À compléter — décision porteur (session 2.11)

---

## 16. TESTS DE NON-RÉGRESSION

EFFECTUÉS ET CONFIRMÉS ✅ — SESSION 2.7 :
AUTH CLIENT  +212600000000 → CreateMissionScreen  ✅
AUTH ADMIN   +212600000001 → AdminDashboardScreen ✅
AUTH DRIVER  +212600000000 → DriverHomeScreen     ✅
             Solde wallet : 200 DH ✅

ÉCRANS ADMIN TESTÉS ✅ :
Documents en attente  → DocumentReviewScreen  ✅
                         Validation 4 docs ✅
                         Driver fully verified ✅
Toutes les missions   → AdminMissionsScreen   ✅
                         6 filtres sans erreur ✅
Gestion utilisateurs  → AdminUsersScreen      ✅
                         Driver visible ✅
Wallets & Transactions → WalletManagementScreen ✅
                         adminTopupDriverWallet ✅
                         balanceBefore: 0
                         balanceAfter: 200 DH ✅

TESTS PARTIELS — CONFIRMÉS SUR WEB ✅ :
CreateMissionScreen :
  Formulaire affiché ✅
  Champs remplissables ✅
  Véhicule sélectionnable ✅
  Commission calculée ✅
  Toggle manutention ✅

TESTS REPORTÉS — Session 4.x ⏳ :
  (nécessitent GPS + device physique)
TEST 1 — Bouton "Trouver un chauffeur"
TEST 2 — MissionTrackingScreen
TEST 3 — RatingScreen
⚠️ Ces 3 tests forment une chaîne indissociable
⚠️ Session 2.8 : TEST 1 — cause CONFIRMÉE par logs directs
   [FTM-DEBUG] GPS - Client location permission denied
   Bouton désactivé tant que pickupCoords===null
   Persiste même après changement permission navigateur
   → limitation environnement Codespaces/iframe confirmée

TESTS EFFECTUÉS ET CONFIRMÉS ✅ — SESSION 2.8 :
AdminUsersScreen — bouton Suspendre/Activer :
  "Annuler" ×2 → aucune action ✅
  "Suspendre"+OK → badge "Suspendu" ✅
  "Activer"+OK → badge "Actif" ✅
CreateMissionScreen — formulaire complet rempli
  et fonctionnel ✅ (bouton soumission bloqué par
  limitation GPS — voir ci-dessus)

TESTS EFFECTUÉS ET CONFIRMÉS ✅ — SESSION 2.9 :
Edge Function check-document-reminders :
  Appel via bouton "Test" Dashboard ✅
  {sent: 3, errors: 0} ✅
  Flags reminder_30/15/7_days_sent → true ✅
  3 notifications document_expiry créées ✅
CRON job jobid=2 :
  5 exécutions succeeded : 18→22/06/2026 ✅
  active = true, timeout_milliseconds := 30000 ✅
net.http_post avec bonne clé Vault :
  status_code = 200, timed_out = false ✅
Driver onboarding complet :
  +212600000000 → 4 pages onboarding ✅
  Validation admin → is_verified = true ✅
  document_reminders créées automatiquement ✅

TESTS EFFECTUÉS ET CONFIRMÉS ✅ — SESSION 2.10 :
Migration 20260504000012 déployée ✅
5 tables supabase_realtime activées ✅
WalletDashboardScreen — SUBSCRIBED confirmé
  en console DevTools ✅
Flux onboarding driver complet — 4 pages ✅
Flux validation admin via DocumentReviewScreen ✅
DriverHomeScreen direct si is_verified=true
  via initializeApp() ✅
Solde wallet 200 DH affiché après recharge admin ✅
Non-régression driver ✅
Non-régression admin ✅
CORS send-push-notification — comportement
  attendu — non bloquant ✅

TESTS PROBABLES ⏳ — non observés directement (session 2.10) :
PendingVerificationScreen — navigation automatique
  via Realtime drivers
  → nécessite 2 fenêtres ou device physique
WalletDashboardScreen — mise à jour solde
  en temps réel
  → nécessite 2 fenêtres ou device physique

TESTS NON TESTABLES — limitation web/GPS (session 2.10) :
DriverHomeScreen — réception nouvelles missions
  → GPS bloqué Codespaces
MissionTrackingScreen — suivi mission temps réel
  → nécessite mission active + GPS

---

## 17. ÉTAPES RESTANTES

PHASE 2 — TESTS & DEBUGGING
2.1  ✅ OTP sans Twilio résolu
2.2  ✅ Page blanche web résolue
2.3  ✅ Auth client et admin confirmés
2.4  ✅ Flux driver testé bout en bout
2.5  ✅ Bugs corrigés + écrans client
2.6  ✅ Tests écrans driver réalisés
2.7  ✅ COMPLET — Tests écrans admin
     → BUG A wallet RLS corrigé ✅ (d420007)
     → SIGNED_IN loop admin corrigé ✅ (6ee89b1)
     → Navigation admin 4 menus corrigée ✅ (4ff3499)
     → 403 notifications corrigé ✅ (2351bf3 + 445bdcb)
     → AdminMissions + AdminUsers créés ✅ (626e851)
     → Enum mission_status corrigé ✅ (750db88)
     → adminTopupDriverWallet confirmé ✅
     → Non-régression CLIENT + DRIVER + ADMIN ✅
     → BUG 4 INFIRMÉ ✅
2.8  ✅ COMPLET — Bugs résiduels session 2.7
     → Bug "Suspendre" AdminUsers corrigé et testé ✅
       (Alert.alert → window.confirm, commit aed0bee)
     → Bucket voice-messages créé + RLS ✅ (commit 5ee383e)
     → Test AdminMissions avec missions réelles : cause
       GPS confirmée par logs, reporté phase 4.x ✅
     → Point sécurité 6.6 identifié (RLS Storage permissif)
     → Driver test supprimé (cascade, test client) —
       voir §2 procédure recréation
2.9  ✅ COMPLET — CRON reminders opérationnel
     → Extensions pg_cron 1.6.4 + pg_net 0.19.5 activées ✅
     → Secret Vault supabase_service_role_key corrigé ✅
       (244 → 219 caractères, ordre args vault.create_secret)
     → CRON job jobid=2, 0 8 * * *, active=true ✅
       timeout_milliseconds := 30000
     → Migration 20260504000011 déployée ✅ (commit 34b32c1)
     → 5 exécutions succeeded confirmées (18→22/06/2026) ✅
     → Driver test recréé 29849a0a-... is_verified=true ✅
     → Base nettoyée (reminders + notifications test) ✅
2.10 ✅ COMPLET — Realtime tables activé
     → Migration 20260504000012 déployée ✅ (commit b65eb9d)
     → 5 tables activées : drivers, missions,
       wallet, transactions, notifications ✅
     → WalletDashboardScreen SUBSCRIBED ✅
     → Constats identifiés : navigation cross-stack,
       revenue_current_month, NotificationBell,
       subscribeToNewTransactions,
       TrackingDetailScreen ⚠️
     → Non-régression CLIENT + DRIVER + ADMIN ✅
2.11 ⏳ Planification sessions complémentaires
        avant Phase 3
     → Sur la base des points identifiés en 2.10
       sans investigation code supplémentaire
     → Trancher pour chaque point :
       session dédiée / reporté Phase 3+ /
       scope à préciser
     → Produire liste sessions 2.12, 2.13…
       avec objectif précis + contenu +
       ordre logique + complexité estimée
     → Points à couvrir :
       1. RLS Storage 6.6 — bloquant production
       2. Bouton déconnexion 3 rôles — 6.4
       3. Refonte WalletTopupScreen — 6.5
       4. Renommage revenue_current_month
       5. subscribeToNewTransactions
       6. Navigation cross-stack driver
       7. NotificationBell + NotificationCenter
       8. TrackingDetailScreen souscription
       9. Workflow validation recharge admin — 6.2
       10. Remboursements flux dédié — 6.3
       11. Modes de paiement multiples — 6.1

PHASE 3 — SERVICES EXTERNES
3.1 ⏳ Twilio SMS
3.2 ⏳ FCM Android
3.3 ⏳ APNs iOS

PHASE 4 — TESTS DEVICE PHYSIQUE
4.1 ⏳ Tests Expo Go Android
4.2 ⏳ Tests Expo Go iOS
4.3 ⏳ Tests utilisateurs réels
4.4 ⏳ Intégrer messages vocaux dans MissionTrackingScreen
    (audioService.ts + bucket voice-messages prêts —
    session 2.8) — UI à construire : bouton enregistrement,
    liste lecture — à traiter avec TEST 2 (nécessite
    device physique + mission active)

PHASE 5 — BUILD EAS
5.1 ⏳ Configurer app.json + eas.json
5.2 ⏳ Build Android (.aab)
5.3 ⏳ Build iOS (.ipa)

PHASE 6 — AMÉLIORATIONS POST-TESTS
6.1 ⏳ Modes de paiement multiples wallet
6.2 ⏳ Workflow validation recharge admin
    chauffeur soumet demande + pièce justificative
    admin valide — solde crédité après validation
6.3 ⏳ Remboursements — flux dédié
6.4 ⏳ Bouton déconnexion CLIENT + DRIVER + ADMIN
6.5 ⏳ Refonte WalletTopupScreen
    soumettre demande au lieu de créditer directement
6.6 ⏳ SÉCURITÉ — Renforcer RLS Storage
    (driver-documents + voice-messages) — session 2.8
    Actuellement : tout utilisateur authenticated peut
    lire/écrire/supprimer N'IMPORTE QUEL fichier (pas de
    vérification auth.uid()/propriété/mission)
    À traiter avant mise en production réelle

PHASE 7 — PUBLICATION
7.1 ⏳ Google Play Store (25$)
7.2 ⏳ Apple App Store (99$/an)

---

## 18. TEMPLATE DÉBUT DE SESSION CLAUDE
PROJET : Fast Trans Maroc (FTM)
STACK  : Expo SDK 50 / React Native / TypeScript
SUPABASE : ustckqnecsilxqlyjute
GITHUB : ELALAMIGIT61/FAST-TRANS-MAROC-FTM

RÈGLES CRITIQUES :
- NE JAMAIS npm audit fix --force
- SDK 50 stable — 39 vulnerabilities outils dev
- .env dans frontend/
- 1 terminal de travail uniquement
- Vérifier texte exact via sed avant replace()
- Si replace() échoue → réécrire fichier entier
- Vérifier contenu exact via repr() Python (jamais cat)
- git pull --rebase avant tout push
- Migrations via GitHub uniquement
- NE JAMAIS modifier authService.ts
- NE JAMAIS modifier ProfileSetupScreen.tsx
- NE JAMAIS modifier driverService.ts
- Backup obligatoire avant toute modification
- Ne jamais retester ce qui est écarté
- Ne jamais modifier ce qui fonctionne
- vault.create_secret(valeur, nom, desc) — valeur EN PREMIER
- timeout_milliseconds := 30000 pour net.http_post
- cron.unschedule() WHERE EXISTS avant tout cron.schedule()
- Prochain timestamp migration : 20260504000013

OBJECTIF SESSION :
[Décrire précisément]

ERREUR ACTUELLE :
[Coller l'erreur si applicable]
