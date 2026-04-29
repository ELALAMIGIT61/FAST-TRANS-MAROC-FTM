# ROADMAP FTM — Document de Référence Sessions Claude

# Fast Trans Maroc — Application Mobile Marocaine

# Dernière mise à jour : 29/04/2026

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
Prochain timestamp ≥ 20260227000000
Jamais via SQL Editor directement
✅ 1 session Claude = 1 objectif précis
✅ Toujours fournir ce fichier en début de session
✅ Toujours ouvrir console navigateur DevTools
avant tout test web
✅ 1 terminal de travail uniquement
Ne jamais ouvrir un 3ème terminal
✅ Vérifier texte exact via sed avant
tout replace() Python3
✅ Backup obligatoire avant chaque modification
✅ Test non-régression CLIENT + ADMIN
après chaque étape de modification
✅ 3 workflows GitHub INTOUCHABLES :
check_supabase.yml
deploy_supabase.yml
lint_code.yml
⛔ NE JAMAIS modifier authService.ts
⛔ NE JAMAIS modifier ProfileSetupScreen.tsx

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
Auth DRIVER       : ⚠️ PARTIEL — session 2.4
Onboarding connecté ✅
VehicleInfoScreen affiché ✅
Flux complet non encore testé ⏳
Packages ajoutés  : expo-image-picker ~14.7.1 ✅
expo-document-picker ~11.10.1 ✅
commit c318a92
Connexion Supabase: ✅ .env configuré dans frontend/
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
SUPABASE_ACCESS_TOKEN  ✅
SUPABASE_PROJECT_ID    ✅ (ustckqnecsilxqlyjute)
SUPABASE_DB_PASSWORD   ✅
SUPABASE_ANON_KEY      ✅

---

## 5. HISTORIQUE COMMITS CLÉS
8acc64c feat: connect driver onboarding
VehicleInfo/LegalDocs/DocumentUpload/
PendingVerification navigators ✅ session 2.4
c318a92 feat: add DriverOnboardingStack/DriverPendingStack
routes + install expo-image-picker
expo-document-picker ✅ session 2.4
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

## 6. MODIFICATIONS COMMITÉES — DÉTAIL SESSION 2.4

### `frontend/src/types/database.ts` — commit c318a92
Ajout 2 nouvelles routes dans type AppRoute :

'DriverOnboardingStack'
'DriverPendingStack'


### `frontend/package.json` + `package-lock.json` — commit c318a92

expo-image-picker ~14.7.1
expo-document-picker ~11.10.1
Commande : npx expo install expo-image-picker
expo-document-picker


### `frontend/src/navigation/RootNavigator.tsx` — commit 8acc64c

Type retour initializeApp() étendu :
Promise<{ route: AppRoute;
driverId?: string;
vehicleCategory?: string }>
Cas driver dans initializeApp() —
requête table drivers :
→ !driver          → DriverOnboardingStack
→ !driver.is_verified → DriverPendingStack
→ driver vérifié   → DriverHomeStack
States ajoutés :
const [driverProfileId, setDriverProfileId]
const [driverVehicleCategory, setDriverVehicleCategory]
useEffect mis à jour :
capte driverId + vehicleCategory
SIGNED_IN mis à jour :
capte driverId + vehicleCategory
Imports ajoutés :
VehicleInfoScreen
LegalDocumentsScreen
DocumentUploadScreen
PendingVerificationScreen
Types de navigation ajoutés :
DriverOnboardingStackParamList
DriverPendingStackParamList
Navigateurs stack créés :
DriverOnboardingStack
DriverPendingStack
Navigateurs créés :
DriverOnboardingNavigator (4 écrans)
DriverPendingNavigator (driverId en prop)
DriverNavigator mis à jour :
reçoit driverId + vehicleCategory
transmis via initialParams
Rendu conditionnel ajouté :
showDriverOnboarding
showDriverPending

callback onProfileCreated driver
→ DriverOnboardingStack




---

## 7. CHAÎNE DE NAVIGATION DRIVER
ProfileSetupScreen
→ onProfileCreated(role='driver')
→ DriverOnboardingStack
VehicleInfoScreen
→ appelle createDriverProfile()
→ navigate('LegalDocuments', { driverId })
LegalDocumentsScreen  [reçoit driverId]
→ appelle saveDriverDocuments()
→ navigate('DocumentUpload', { driverId })
DocumentUploadScreen  [reçoit driverId]
→ appelle uploadDocument()
→ navigate('PendingVerification', { driverId })
PendingVerificationScreen  [reçoit driverId]
→ souscrit realtime driver-verification-{driverId}
→ si is_verified === true
→ navigation.replace('DriverHome')
DriverHomeScreen
→ attend driverId : string — obligatoire
→ attend vehicleCategory : string — obligatoire
('vul' | 'n2_medium' | 'n2_large')
⚠️ is_verified = GENERATED ALWAYS AS
Devient true quand ces 4 champs sont true :

driver_license_verified
vehicle_registration_verified
insurance_verified
technical_inspection_verified
Pour tester : modifier les 4 champs manuellement
dans Supabase Table Editor


---

## 8. PROBLÈMES RENCONTRÉS ET RÉSOLUS
PROBLÈME 1 — Page blanche après ajout navigateurs
Cause    : expo-image-picker et expo-document-picker
absents de package.json
Preuve   : "Unable to resolve expo-image-picker
from documentService.ts"
Correctif: npx expo install expo-image-picker
expo-document-picker
Statut   : RÉSOLU ✅
PROBLÈME 2 — Terminal défaillant
Cause    : 3ème terminal ouvert manuellement
Symptôme : echo "test" ne retournait rien
Impact   : confusion sur l'état des fichiers
Correctif: fermeture terminal défaillant
reprise dans terminal bash frontend
Statut   : RÉSOLU ✅
Règle    : 1 terminal de travail uniquement
PROBLÈME 3 — replace() Python3 sans effet
Cause    : texte cible ne correspondait pas
exactement au contenu du fichier
Symptôme : OK retourné mais rien modifié
Correctif: vérification texte exact via sed
avant chaque commande replace()
Statut   : RÉSOLU ✅

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
20260220155500_initial_schema.sql                 ✅ P1-P2
20260221000000_add_rpc_nearby_drivers.sql         ✅ P3
20260222000000_add_tracking_functions.sql         ✅ P4
20260223000000_add_push_tokens.sql                ✅ P6
20260224000000_add_rls_policies.sql               ✅ P7
20260226000000_fix_profiles_rls_recursion.sql     ✅ Phase 2.1

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
│       │   └── RootNavigator.tsx ← onboarding driver
│       ├── screens/
│       │   ├── admin/
│       │   │   ├── AdminDashboardScreen.tsx
│       │   │   ├── DocumentReviewScreen.tsx
│       │   │   └── WalletManagementScreen.tsx
│       │   ├── auth/
│       │   │   ├── OTPVerificationScreen.tsx
│       │   │   ├── PhoneInputScreen.tsx
│       │   │   └── ProfileSetupScreen.tsx
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
│       │   ├── authService.ts      ← INTOUCHABLE
│       │   ├── documentService.ts
│       │   ├── driverService.ts
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
│       └── 20260226000000_fix_profiles_rls_recursion.sql
├── .env.example
├── .gitignore
├── install_P1_files.sh
├── install_P1_deps.sh
├── install_P2_files.sh
├── install_P2_deps.sh
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
Storage buckets  : ⏳ à créer dans Supabase
CRON reminders   : ⏳ à planifier dans Supabase

---

## 14. ÉTAPES RESTANTES
PHASE 2 — TESTS & DEBUGGING
2.1 ✅ OTP sans Twilio résolu
→ MessageBird fictif configuré
→ Numéro test +212600000000 / 123456
→ Récursion RLS profiles corrigée
2.2 ✅ Page blanche web résolue
→ BORDER_RADIUS manquant dans theme.ts
→ 3 écrans réels connectés et fonctionnels
→ Navigation auth confirmée sur web
→ Commit e7beed2 pushé sur main
2.3 ✅ Finaliser test auth client et admin
→ Auth CLIENT confirmé ✅
Navigation → CreateMissionScreen
Commits 8a78903 + 53725fe + bd7ead0
→ Auth ADMIN confirmé ✅
Navigation → AdminDashboardScreen
→ Auth DRIVER reporté ⏳
Onboarding driver non connecté
2.4 ⚠️ PARTIEL — Connecter et tester onboarding DRIVER
→ Onboarding connecté ✅
4 navigateurs créés dans RootNavigator
Commits c318a92 + 8acc64c
→ VehicleInfoScreen confirmé ✅
"Étape 1 sur 4" affiché
→ Flux complet non encore testé ⏳
À compléter dans l'ordre :
1. VehicleInfoScreen → remplir + Suivant
→ vérifier LegalDocumentsScreen
2. LegalDocumentsScreen → remplir
→ vérifier DocumentUploadScreen
3. DocumentUploadScreen → tenter upload
⚠️ limitations web possibles
4. PendingVerificationScreen
→ vérifier affichage écran attente
5. DriverHomeScreen
→ simuler is_verified=true via
4 champs individuels Supabase :
driver_license_verified
vehicle_registration_verified
insurance_verified
technical_inspection_verified
→ vérifier driverId + vehicleCategory
transmis correctement
2.5 ⏳ Tester écrans client
2.6 ⏳ Tester écrans driver
2.7 ⏳ Tester écrans admin
2.8 ⏳ Créer buckets Storage
2.9 ⏳ Configurer CRON reminders
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

## 15. TEMPLATE DÉBUT DE SESSION CLAUDE
PROJET : Fast Trans Maroc (FTM)
STACK : Expo SDK 50 / React Native / TypeScript
SUPABASE : ustckqnecsilxqlyjute
GITHUB : ELALAMIGIT61/FAST-TRANS-MAROC-FTM
RÈGLES CRITIQUES :

NE JAMAIS npm audit fix --force
SDK 50 stable — 39 vulnerabilities outils dev
.env dans frontend/
1 terminal de travail uniquement
Vérifier texte exact via sed avant replace()
NE JAMAIS modifier authService.ts
NE JAMAIS modifier ProfileSetupScreen.tsx

OBJECTIF SESSION :
[Décrire précisément]
ERREUR ACTUELLE :
[Coller l'erreur si applicable]

