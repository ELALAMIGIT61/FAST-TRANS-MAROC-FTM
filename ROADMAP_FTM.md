# ROADMAP FTM — Document de Référence Sessions Claude

# Fast Trans Maroc — Application Mobile Marocaine

# Dernière mise à jour : 23/04/2026

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
✅ .env doit être dans frontend/ (pas à la racine)
✅ Migrations : timestamps uniques obligatoires
✅ 1 session Claude = 1 objectif précis
✅ Toujours fournir ce fichier en début de session
✅ Toujours ouvrir console navigateur DevTools
avant tout test web

---

## 3. ÉTAT TECHNIQUE ACTUEL
SDK Expo          : 50.0.21 ✅ stable
Vulnerabilities   : 23 (outils dev uniquement)
Impact ZÉRO sur app/publication
NE PAS corriger avec --force
App démarre       : ✅ Web Bundled confirmé
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
Auth DRIVER       : ⏳ reporté — onboarding requis
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

---

## 4. GITHUB SECRETS CONFIGURÉS
SUPABASE_ACCESS_TOKEN  ✅
SUPABASE_PROJECT_ID    ✅ (ustckqnecsilxqlyjute)
SUPABASE_DB_PASSWORD   ✅
SUPABASE_ANON_KEY      ✅

---

## 5. HISTORIQUE COMMITS CLÉS
bd7ead0 fix: SIGNED_IN pour utilisateurs existants
navigation admin et reconnexion ✅ session 2.3
53725fe fix: clientProfileId transmis à
CreateMissionScreen ✅ session 2.3
8a78903 fix: navigation post-profil via callback
onProfileCreated ✅ session 2.3
e7beed2 fix: BORDER_RADIUS ajouté theme.ts
page blanche web résolue ✅ session 2.2
8951aea fix: expo-notifications installé + guard
Platform.OS pushNotificationService
bea9a3d feat: 3 écrans réels connectés
RootNavigator — client/driver/admin
5075470 fix: correct infinite recursion in
profiles_select_admin RLS policy
ec7d061 fix(security): enable RLS on push_tokens
d2379c5 fix(P7): drop and recreate
public_parcel_tracking view
24ccfbb fix(P7): correct ep.status to m.status
dbe39f7 feat(P7): admin dashboard, RLS, CI/CD
0f481b3 feat(P6): add push_tokens migration
037a2be feat(P6): notifications push, chat audio
4dda161 feat(P5): wallet revolving, transactions
8f14560 feat(P4): e-commerce, colisage, tracking
7d89469 feat(P3): missions, géolocalisation
0646372 feat(P2): onboarding driver, documents
8e4508f feat(P1): config, auth OTP, Supabase

---

## 6. MIGRATIONS SUPABASE DÉPLOYÉES
20260220155500_initial_schema.sql                 ✅ P1-P2
20260221000000_add_rpc_nearby_drivers.sql         ✅ P3
20260222000000_add_tracking_functions.sql         ✅ P4
20260223000000_add_push_tokens.sql                ✅ P6
20260224000000_add_rls_policies.sql               ✅ P7
20260226000000_fix_profiles_rls_recursion.sql     ✅ Phase 2.1

---

## 7. EDGE FUNCTIONS DÉPLOYÉES
send-push-notification   ✅
register-push-token      ✅
check-document-reminders ✅
send-tracking-sms        ✅

---

## 8. ARBORESCENCE COMPLÈTE DU REPO
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
│   ├── package.json
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
│       │   └── RootNavigator.tsx ← callback + SIGNED_IN
│       ├── screens/
│       │   ├── admin/
│       │   │   ├── AdminDashboardScreen.tsx
│       │   │   ├── DocumentReviewScreen.tsx
│       │   │   └── WalletManagementScreen.tsx
│       │   ├── auth/
│       │   │   ├── OTPVerificationScreen.tsx
│       │   │   ├── PhoneInputScreen.tsx
│       │   │   └── ProfileSetupScreen.tsx ← onProfileCreated
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
│       │   ├── authService.ts  ← user.id dans ProfileResult
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
│       │   └── database.ts
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

## 9. SERVICES EXTERNES — ÉTAT
Twilio SMS       : ⏳ pas encore configuré
Nécessaire avant production
FCM Android      : ⏳ pas encore configuré
APNs iOS         : ⏳ pas encore configuré
Storage buckets  : ⏳ à créer dans Supabase
CRON reminders   : ⏳ à planifier dans Supabase

---

## 10. ÉTAPES RESTANTES
PHASE 2 — TESTS & DEBUGGING
2.1 ✅ OTP sans Twilio résolu
→ MessageBird fictif configuré
→ Numéro test +212600000000 / 123456
→ Récursion RLS profiles corrigée
2.2 ✅ Tester auth complète (client/driver/admin)
→ Page blanche web rencontrée et résolue
BORDER_RADIUS manquant dans theme.ts
Commit e7beed2 pushé sur main
→ Navigation auth confirmée sur web
→ Test auth 3 rôles partiellement effectué
2.3 ✅ Finaliser test auth client et admin
→ Auth CLIENT confirmé ✅
Navigation → CreateMissionScreen
Commits 8a78903 + 53725fe + bd7ead0
→ Auth ADMIN confirmé ✅
Navigation → AdminDashboardScreen
Rôle admin via SQL Editor Supabase
→ Auth DRIVER reporté ⏳
Onboarding driver (4 écrans) non connecté
Session dédiée nécessaire
2.4 ⏳ Connecter et tester onboarding DRIVER
→ VehicleInfoScreen
→ DocumentUploadScreen
→ LegalDocumentsScreen
→ PendingVerificationScreen
→ Tester navigation → DriverHomeScreen
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

## 11. TEMPLATE DÉBUT DE SESSION CLAUDE
PROJET : Fast Trans Maroc (FTM)
STACK : Expo SDK 50 / React Native / TypeScript
SUPABASE : ustckqnecsilxqlyjute
GITHUB : ELALAMIGIT61/FAST-TRANS-MAROC-FTM
RÈGLES CRITIQUES :

NE JAMAIS npm audit fix --force
SDK 50 stable — 23 vulnerabilities outils dev
.env dans frontend/

OBJECTIF SESSION :
[Décrire précisément]
ERREUR ACTUELLE :
[Coller l'erreur si applicable]

