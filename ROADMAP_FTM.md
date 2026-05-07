# ROADMAP FTM — Document de Référence Sessions Claude
# Fast Trans Maroc — Application Mobile Marocaine
# Dernière mise à jour : 07/05/2026

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
   Prochain timestamp ≥ 20260504000004
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
3 écrans réels    : ✅ connectés et fonctionnels
                    CreateMissionScreen
                    DriverHomeScreen
                    AdminDashboardScreen
Bundle web        : ✅ 1173ms
Auth CLIENT       : ✅ confirmé — session 2.3
                    Navigation → CreateMissionScreen
Auth ADMIN        : ✅ confirmé — session 2.3
                    Navigation → AdminDashboardScreen
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
Packages ajoutés  : expo-image-picker ~14.7.1 ✅
                    expo-document-picker ~11.10.1 ✅
                    commit c318a92
Storage           : ✅ Bucket driver-documents créé
                    5 MB max — jpeg/png/pdf
                    RLS policies configurées
                    commits 7222601 + c39cafb
Connexion Supabase: ✅ .env configuré dans frontend/
Token Supabase    : ✅ Renouvelé le 29/04/2026
                    Nom : FTM_GITHUB_ACTIONS
                    Expiration : Never
Mode test OTP     : ✅ configuré (MessageBird fictif)
                    Numéro test : +212600000000
                    Code fixe   : 123456
                    Valide jusqu'au : 31/12/2026
⚠️ Compte ADMIN test :
   Numéro : +212600000001
   Rôle admin défini via SQL Editor Supabase
   UPDATE profiles SET role='admin'
   WHERE phone_number='+212600000001'
   NE PAS SUPPRIMER CE PROFIL

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
9f22d9d fix: add UNIQUE constraint on
        document_reminders (driver_id, document_type)
        enables upsert ON CONFLICT ✅ session 2.5
b4ec2ba fix: correct wallet table name
        wallets → wallet in DriverHomeScreen ✅ session 2.5
475274c fix: ignore SIGNED_IN during driver onboarding
        use ref to prevent spontaneous navigation ✅ session 2.5
f377534 docs: update ROADMAP session 2.4 ✅
c39cafb feat: add RLS policies driver-documents bucket ✅
7222601 feat: create driver-documents storage bucket ✅
6b9dae8 fix: prevent skip to PendingStack
        check doc URLs + web DatePicker fallback ✅
a23df8b fix: keep driver on onboarding if
        driver_license_number is null ✅
1c9af9c fix: allow null legal docs fields at step 1 ✅
6f7ed8c fix: allow null driver_license_number
        at step 1 ✅
ef9f0b4 docs: update ROADMAP session 2.4 partiel ✅
8acc64c feat: connect driver onboarding
        VehicleInfo/LegalDocs/DocumentUpload/
        PendingVerification navigators ✅
c318a92 feat: add DriverOnboardingStack/DriverPendingStack
        routes + install expo-image-picker
        expo-document-picker ✅
b669da7 docs: update ROADMAP_FTM session 2.3 ✅
bd7ead0 fix: SIGNED_IN pour utilisateurs existants ✅
53725fe fix: clientProfileId transmis à
        CreateMissionScreen ✅
8a78903 fix: navigation post-profil via callback ✅
e7beed2 fix: BORDER_RADIUS ajouté theme.ts ✅
bea9a3d feat: 3 écrans réels connectés ✅
5075470 fix: correct infinite recursion RLS ✅
ec7d061 fix: enable RLS on push_tokens ✅
d2379c5 fix: drop and recreate parcel_tracking view ✅
24ccfbb fix: correct ep.status to m.status ✅
dbe39f7 feat: admin dashboard, RLS, CI/CD ✅
0f481b3 feat: add push_tokens migration ✅
037a2be feat: notifications push, chat audio ✅
4dda161 feat: wallet revolving, transactions ✅
8f14560 feat: e-commerce, colisage, tracking ✅
7d89469 feat: missions, géolocalisation ✅
0646372 feat: onboarding driver, documents ✅
8e4508f feat: config, auth OTP, Supabase ✅

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
1. Type retour initializeApp() étendu :
   Promise<{ route: AppRoute;
             driverId?: string;
             vehicleCategory?: string }>
2. Cas driver dans initializeApp() :
   → !driver → DriverOnboardingStack
   → !is_verified → DriverPendingStack
   → vérifié → DriverHomeStack
3. States ajoutés :
   driverProfileId
   driverVehicleCategory
4. useEffect — capte driverId + vehicleCategory
5. SIGNED_IN — capte driverId + vehicleCategory
6. Imports ajoutés :
   VehicleInfoScreen
   LegalDocumentsScreen
   DocumentUploadScreen
   PendingVerificationScreen
7. Types de navigation ajoutés :
   DriverOnboardingStackParamList
   DriverPendingStackParamList
8. Navigateurs stack créés :
   DriverOnboardingStack
   DriverPendingStack
9. Navigateurs créés :
   DriverOnboardingNavigator (4 écrans)
   DriverPendingNavigator
10. DriverNavigator mis à jour :
    reçoit driverId + vehicleCategory
    transmis via initialParams
11. Rendu conditionnel ajouté :
    showDriverOnboarding
    showDriverPending
    callback onProfileCreated driver
    → DriverOnboardingStack

---

### SESSION 2.4 SUITE — commits 6f7ed8c → c39cafb

#### `frontend/src/navigation/RootNavigator.tsx`
initializeApp() — select étendu :
  id, vehicle_category, is_verified,
  driver_license_number,
  driver_license_url,
  vehicle_registration_url,
  insurance_url,
  technical_inspection_url

Logique driver complète et définitive :
  !driver                → OnboardingStack
  !driver_license_number → OnboardingStack
  !toutes 4 URLs         → OnboardingStack
  !is_verified           → PendingStack
  sinon                  → HomeStack

#### `frontend/src/screens/driver/onboarding/LegalDocumentsScreen.tsx`
Fallback web pour DateTimePicker :
  Platform.OS === 'web'
  → input type="date" HTML natif
  Mobile → DateTimePicker natif inchangé

#### Migrations SQL ajoutées :
20260429000001 → driver_license_number DROP NOT NULL
20260429000002 → 5 champs légaux DROP NOT NULL :
                  driver_license_expiry
                  vehicle_registration_number
                  insurance_number
                  insurance_expiry
                  technical_inspection_expiry
20260504000001 → CREATE bucket driver-documents
                  (5 MB, jpeg/png/pdf, privé)
20260504000002 → RLS policies bucket driver-documents
                  INSERT / SELECT / UPDATE / DELETE
                  pour utilisateurs authentifiés

---

### SESSION 2.5 — commits 475274c → 9f22d9d

#### `frontend/src/navigation/RootNavigator.tsx` — commit 475274c
Correction BUG 1 — SIGNED_IN interrompt onboarding :
  Problème : stale closure sur initialRoute
             SIGNED_IN relançait initializeApp()
             → PendingStack pendant étape 3
  Correction — 4 modifications :
  1. useRef ajouté dans import React
  2. initialRouteRef = useRef<AppRoute>("AuthStack")
  3. initialRouteRef.current = route
     à chaque setInitialRoute
  4. Condition SIGNED_IN :
     if (initialRouteRef.current !== "DriverOnboardingStack")

Backup créé : RootNavigator.tsx.bak.fix.signedin
              (11337 bytes)

#### `frontend/src/screens/driver/DriverHomeScreen.tsx` — commit b4ec2ba
Correction BUG 2 — GET /wallets → 404 :
  Problème : .from('wallets') — 's' en trop
  Correction: .from('wallet') — ligne 36
  Table en base : wallet (sans 's') ✅

Backup créé : DriverHomeScreen.tsx.bak
              (6113 bytes)

#### Migrations SQL ajoutées :
20260504000003 → ADD UNIQUE CONSTRAINT
                  document_reminders
                  (driver_id, document_type)
                  Correction BUG 3 — ON CONFLICT 400

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

## 8. PROBLÈMES RENCONTRÉS ET RÉSOLUS

PROBLÈME 1 — Page blanche après ajout navigateurs
Cause    : expo-image-picker absent de package.json
Correctif: npx expo install expo-image-picker
           expo-document-picker
Statut   : RÉSOLU ✅ commit c318a92

PROBLÈME 2 — Terminal défaillant
Cause    : 3ème terminal ouvert manuellement
Correctif: fermeture + reprise terminal bash
Statut   : RÉSOLU ✅
Règle    : 1 terminal de travail uniquement

PROBLÈME 3 — replace() Python3 sans effet
Cause    : texte cible inexact
Correctif: vérification via sed avant replace()
           Si échec → réécrire fichier entier
Statut   : RÉSOLU ✅

PROBLÈME 4 — driver_license_number NOT NULL
Cause    : champ collecté étape 2
           mais contrainte dès étape 1
Correctif: migration DROP NOT NULL
Statut   : RÉSOLU ✅ commit 6f7ed8c

PROBLÈME 5 — Champs légaux NOT NULL (5 champs)
Cause    : même architecture étape 1 / étape 2
Correctif: migration DROP NOT NULL × 5
Statut   : RÉSOLU ✅ commit 1c9af9c

PROBLÈME 6 — Passage spontané étape 2 → étape 4
Cause    : SIGNED_IN relançait initializeApp()
           driver sans license_number
           → PendingStack immédiatement
Correctif: condition !driver_license_number
           → OnboardingStack
Statut   : RÉSOLU ✅ commit a23df8b

PROBLÈME 7 — Passage spontané étape 3 → étape 4
Cause    : SIGNED_IN relançait initializeApp()
           driver avec license_number
           mais sans vérifier URLs documents
           → PendingStack immédiatement
Correctif: condition !toutes 4 URLs
           → OnboardingStack
Statut   : RÉSOLU ✅ commit 6b9dae8

PROBLÈME 8 — DateTimePicker non supporté web
Cause    : composant natif mobile uniquement
Correctif: fallback Platform.OS === 'web'
           → input type="date" HTML natif
Statut   : RÉSOLU ✅ commit 6b9dae8

PROBLÈME 9 — Bucket not found (Storage)
Cause    : bucket driver-documents non créé
Correctif: migration SQL CREATE bucket
Statut   : RÉSOLU ✅ commit 7222601

PROBLÈME 10 — RLS Storage bloque upload
Cause    : bucket sans politique d'accès
Correctif: migration RLS policies × 4
           INSERT/SELECT/UPDATE/DELETE
Statut   : RÉSOLU ✅ commit c39cafb

PROBLÈME 11 — Token Supabase expiré
Cause    : SUPABASE_ACCESS_TOKEN expiré
           GitHub Actions rejeté "Unauthorized"
Correctif: nouveau token FTM_GITHUB_ACTIONS
           Never expires — mis à jour GitHub Secrets
Statut   : RÉSOLU ✅ 29/04/2026

PROBLÈME 12 — SIGNED_IN interrompt onboarding étape 3
Cause    : stale closure — initialRoute capturé
           dans onAuthStateChange gardait
           l'ancienne valeur
           → initializeApp() relancé
           → PendingStack immédiat
Correctif: useRef<AppRoute> ajouté
           initialRouteRef.current synchronisé
           Condition !== "DriverOnboardingStack"
           dans SIGNED_IN
Statut   : RÉSOLU ✅ commit 475274c

PROBLÈME 13 — GET /wallets → 404
Cause    : .from('wallets') — 's' en trop
           Table en base : wallet (sans 's')
Correctif: .from('wallet') — ligne 36
           DriverHomeScreen.tsx
Statut   : RÉSOLU ✅ commit b4ec2ba

PROBLÈME 14 — document_reminders ON CONFLICT → 400
Cause    : contrainte UNIQUE manquante sur
           (driver_id, document_type)
           upsert impossible sans contrainte
Correctif: migration SQL
           ADD CONSTRAINT UNIQUE
           (driver_id, document_type)
Statut   : RÉSOLU ✅ commit 9f22d9d

---

## 9. PISTES DÉFINITIVEMENT ÉCARTÉES
Ne pas retester pour la page blanche :
❌ locationService import statique
❌ expo-haptics / expo-notifications
❌ expo-location fallback web
❌ missionService / realtimeService
❌ react-native-screens sans fallback web
❌ NativeStackScreenProps sans type
❌ Dépendance circulaire missionService
❌ audioService / expo-av
❌ supabaseClient.ts
❌ showAuth logique incorrecte
❌ ErrorBoundary capture l'erreur
❌ --no-dev résout seul

---

## 10. MIGRATIONS SUPABASE DÉPLOYÉES
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

Prochain timestamp disponible : 20260504000004

---

## 11. EDGE FUNCTIONS DÉPLOYÉES
send-push-notification   ✅
register-push-token      ✅
check-document-reminders ✅
send-tracking-sms        ✅

---

## 12. ARBORESCENCE COMPLÈTE DU REPO
FAST-TRANS-MAROC-FTM/
├── .github/
│   └── workflows/
│       ├── check_supabase.yml
│       ├── deploy_supabase.yml
│       └── lint_code.yml
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
│   ├── package-lock.json   ← mis à jour session 2.4
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
│       │   └── RootNavigator.tsx ← useRef fix SIGNED_IN
│       ├── screens/
│       │   ├── admin/
│       │   │   ├── AdminDashboardScreen.tsx
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
│       │   │   ├── DriverHomeScreen.tsx   ← wallet corrigé
│       │   │   ├── MissionActiveScreen.tsx
│       │   │   ├── NewMissionModal.tsx
│       │   │   ├── ParcelMissionDetailScreen.tsx
│       │   │   ├── TransactionDetailModal.tsx
│       │   │   ├── TransactionHistoryScreen.tsx
│       │   │   ├── WalletDashboardScreen.tsx
│       │   │   ├── WalletTopupScreen.tsx
│       │   │   └── onboarding/
│       │   │       ├── DocumentUploadScreen.tsx
│       │   │       ├── LegalDocumentsScreen.tsx ← fallback web
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
│       │   ├── authService.ts      ← INTOUCHABLE
│       │   ├── documentService.ts
│       │   ├── driverService.ts    ← STABLE INTOUCHABLE
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
│       │   └── database.ts ← DriverOnboardingStack ajouté
│       └── utils/
│           └── parcelCalculations.ts
├── supabase/
│   ├── config.toml
│   ├── functions/
│   │   ├── check-document-reminders/
│   │   │   └── index.ts
│   │   ├── register-push-token/
│   │   │   └── index.ts
│   │   ├── send-push-notification/
│   │   │   └── index.ts
│   │   └── send-tracking-sms/
│   │       └── index.ts
│   └── migrations/
│       ├── 20260220155500_initial_schema.sql
│       ├── 20260221000000_add_rpc_nearby_drivers.sql
│       ├── 20260222000000_add_tracking_functions.sql
│       ├── 20260223000000_add_push_tokens.sql
│       ├── 20260224000000_add_rls_policies.sql
│       ├── 20260226000000_fix_profiles_rls_recursion.sql
│       ├── 20260429000001_allow_null_driver_license_number.sql
│       ├── 20260429000002_allow_null_legal_docs_fields.sql
│       ├── 20260504000001_create_driver_documents_bucket.sql
│       ├── 20260504000002_storage_rls_policies.sql
│       └── 20260504000003_add_unique_constraint_document_reminders.sql
├── .env.example
├── .gitignore
├── install_P1_files.sh
├── install_P1_deps.sh
├── install_P2_files.sh
├── install_P2_deps.sh
├── install_P2_AppTsx.sh
├── install_P3_files.sh
├── install_P3_deps.sh
├── install_P4_files.sh
├── install_P4_deps.sh
├── install_P5_files.sh
├── install_P5_deps.sh
├── install_P6_files.sh
├── install_P6_deps.sh
├── install_P7_files.sh
├── install_P7_deps.sh
└── ROADMAP_FTM.md

---

## 13. SERVICES EXTERNES — ÉTAT
Twilio SMS       : ⏳ pas encore configuré
                   Nécessaire avant production
FCM Android      : ⏳ pas encore configuré
APNs iOS         : ⏳ pas encore configuré
Storage buckets  : ✅ driver-documents créé
                   ⏳ autres buckets à créer
CRON reminders   : ⏳ à planifier dans Supabase

---

## 14. BUGS RÉSIDUELS

⚠️ BUG 4 — SQL UPDATE par phone_number → 0 row
   Symptôme : UPDATE drivers WHERE profile_id =
              (SELECT id FROM profiles
               WHERE phone_number = '+212600000000')
              retourne 0 row
   Cause probable : format du numéro différent en base
   Impact   : non bloquant — validation admin
              fonctionne via Table Editor
   À investiguer : session 2.7 (tests écrans admin)

---

## 15. TESTS DE NON-RÉGRESSION

EFFECTUÉS ET CONFIRMÉS ✅ :
AUTH ADMIN  → AdminDashboardScreen ✅
AUTH CLIENT → CreateMissionScreen  ✅
AUTH DRIVER → Flux complet étapes 1-4 ✅
Upload Storage → driver-documents ✅
Realtime Supabase → DriverHomeScreen ✅
Wallet → 0.00 DH affiché sans erreur 404 ✅

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
  Fichier  : CreateMissionScreen.tsx
  Ligne clé: canSubmit = !!pickupCoords &&
             !!dropoffAddress && !!vehicleCategory
             && !isLoading
  Raison   : pickupCoords = null sur web
             géolocalisation refusée

TEST 2 — MissionTrackingScreen
  Fichier  : MissionTrackingScreen.tsx
  Raison   : nécessite mission active
             créée via "Trouver un chauffeur"

TEST 3 — RatingScreen
  Fichier  : RatingScreen.tsx
  Raison   : nécessite mission complétée
             pour noter le chauffeur

⚠️ Ces 3 tests forment une chaîne indissociable
   Aucun ne peut être testé sans le précédent
   Tous nécessitent GPS + device physique

RESTANT À FAIRE ⏳ :
→ Écrans driver complets (session 2.6)
→ Écrans admin complets (session 2.7)
→ Buckets Storage restants (session 2.8)
→ CRON reminders (session 2.9)
→ Realtime tables (session 2.10)

---

## 16. ÉTAPES RESTANTES
PHASE 2 — TESTS & DEBUGGING
2.1  ✅ OTP sans Twilio résolu
     → MessageBird fictif configuré
     → Numéro test +212600000000 / 123456
     → Récursion RLS profiles corrigée
2.2  ✅ Page blanche web résolue
     → BORDER_RADIUS manquant dans theme.ts
     → 3 écrans réels connectés et fonctionnels
     → Navigation auth confirmée sur web
     → Commit e7beed2 pushé sur main
2.3  ✅ Finaliser test auth client et admin
     → Auth CLIENT confirmé ✅
       Navigation → CreateMissionScreen
       Commits 8a78903 + 53725fe + bd7ead0
     → Auth ADMIN confirmé ✅
       Navigation → AdminDashboardScreen
2.4  ✅ COMPLET — Flux driver testé bout en bout
     → Onboarding connecté ✅
       4 navigateurs créés dans RootNavigator
       Commits c318a92 + 8acc64c
     → VehicleInfoScreen confirmé ✅
     → LegalDocumentsScreen confirmé ✅
       DatePicker web fallback ajouté
     → DocumentUploadScreen confirmé ✅
       Upload Storage fonctionnel
       Bucket driver-documents créé
       RLS policies configurées
     → PendingVerificationScreen confirmé ✅
     → DriverHomeScreen confirmé ✅
       Realtime Supabase fonctionnel
     → Non-régression CLIENT + ADMIN ✅
2.5  ✅ COMPLET — Bugs corrigés + écrans client
     → BUG 1 corrigé ✅ (475274c)
       SIGNED_IN — useRef stale closure
     → BUG 2 corrigé ✅ (b4ec2ba)
       wallet table name — wallets → wallet
     → BUG 3 corrigé ✅ (9f22d9d)
       document_reminders UNIQUE constraint
     → CreateMissionScreen testé ✅
       Formulaire, véhicule, commission OK
     → Tests reportés session 4.x notés ✅
       Trouver un chauffeur / Tracking / Rating
     → BUG 4 noté ⚠️ — session 2.7
2.6  ⏳ Tester écrans driver
2.7  ⏳ Tester écrans admin + investiguer BUG 4
2.8  ⏳ Créer buckets Storage restants
2.9  ⏳ Configurer CRON reminders
2.10 ⏳ Activer Realtime tables

PHASE 3 — SERVICES EXTERNES
3.1 ⏳ Twilio SMS
3.2 ⏳ FCM Android
3.3 ⏳ APNs iOS

PHASE 4 — TESTS DEVICE PHYSIQUE
4.1 ⏳ Tests Expo Go Android
4.2 ⏳ Tests Expo Go iOS
4.3 ⏳ Tests utilisateurs réels

PHASE 5 — BUILD EAS
5.1 ⏳ Configurer app.json + eas.json
5.2 ⏳ Build Android (.aab)
5.3 ⏳ Build iOS (.ipa)

PHASE 6 — PUBLICATION
6.1 ⏳ Google Play Store (25$)
6.2 ⏳ Apple App Store (99$/an)

---

## 17. TEMPLATE DÉBUT DE SESSION CLAUDE
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
- git pull --rebase avant tout push
- Migrations via GitHub uniquement
- NE JAMAIS modifier authService.ts
- NE JAMAIS modifier ProfileSetupScreen.tsx
- NE JAMAIS modifier driverService.ts
- Backup obligatoire avant toute modification
- Ne jamais retester ce qui est écarté
- Ne jamais modifier ce qui fonctionne
- Prochain timestamp migration : 20260504000004

OBJECTIF SESSION :
[Décrire précisément]

ERREUR ACTUELLE :
[Coller l'erreur si applicable]
