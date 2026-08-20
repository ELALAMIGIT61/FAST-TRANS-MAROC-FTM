ROADMAP-DOCUMENT DE REFERENCE SESSION CLAUDE — FAST TRANS MAROC — VERSION 20/08/2026

Fast Trans Maroc — Application Mobile Marocaine
Dernière mise à jour : 20/08/2026

# INFORMATIONS PROJET

Projet : Fast Trans Maroc (FTM)
Stack : Expo SDK 50 / React Native / TypeScript strict
Supabase : ustckqnecsilxqlyjute (org: Tamesna Plus)
GitHub : ELALAMIGIT61/FAST-TRANS-MAROC-FTM
Codespaces : zany-disco-jj95647gqv473pj9

# RÈGLES CRITIQUES — À LIRE EN PREMIER

⛔ NE JAMAIS utiliser npm audit fix --force (casse la stack SDK 50 → SDK 55 incompatible)
✅ Toujours utiliser --legacy-peer-deps si conflit
✅ Toujours utiliser npx expo install pour packages Expo
✅ .env doit être dans frontend/ (pas à la racine)
✅ Migrations : timestamps uniques obligatoires
   Prochain timestamp ≥ 20260504000017
   Jamais via SQL Editor directement
   Toujours via GitHub Actions
✅ 1 session Claude = 1 objectif précis
✅ Toujours fournir ce fichier en début de session
✅ Toujours ouvrir console navigateur DevTools avant tout test web
✅ Toujours regarder console DevTools en cas de page blanche ou crash silencieux
✅ 1 terminal de travail uniquement
   Ne jamais ouvrir un 3ème terminal
✅ Vérifier pwd systématiquement avant tout npx expo start
   Refuser par principe toute invite d'installation de package non explicitement prévue — incident session 2.13 : terminal remonté à la racine du dépôt a proposé l'installation d'Expo 57 (incompatible SDK 50.0.21), correctement annulée
✅ Vérifier texte exact via sed avant tout replace() Python3
✅ Si replace() échoue → réécrire le fichier entier
   Ne jamais tâtonner avec replace() successifs
✅ Vérifier contenu exact d'un fichier via repr() Python
   Ne jamais se fier à cat pour les lignes longues (cat tronque les lignes — trompeur)
⚠️ Fusions de caractères silencieuses possibles au copier-coller lors de la rédaction de migrations SQL (ex. "ONp.id", "IFEXISTS", "driversd") — invisibles au simple cat, révélées uniquement par repr() — session 2.12. Méthode stabilisée : blocs courts, repr() systématique après chaque ajout ; renommer un alias (ex. d → dr) si un bug de fusion récurrent persiste sur une ligne donnée. Session 2.13 : méthode reconduite avec succès sur walletService.ts (faux positif de fusion détecté et infirmé après vérification).
✅ Tout texte contenant un caractère à signification spéciale en bash (!, mais vigilance également sur ` (backtick), $, ) doit systématiquement transiter par un heredoc à délimiteur quoté (<< 'PYEOF'), jamais par un python3 -c "..." en ligne directe — règle consolidée session 2.14, suite à un incident réel (voir Section 6, bloc session 2.14, "Incident réel — completeMission / interférence bash")
✅ NE JAMAIS exécuter une commande SQL de modification de schéma (DROP POLICY, CREATE POLICY, ALTER TABLE, etc.) directement en SQL Editor, même à titre de "préparation" ou "test rapide" — toujours l'intégrer d'abord au fichier de migration, puis déployer via le canal standard (GitHub Actions). Règle renforcée session 2.14 ter, suite à l'Incident 1 (DROP POLICY exécuté hors circuit, voir Section 6, bloc session 2.14 ter) : le risque de confusion entre "commande proposée à discuter" et "commande prête à exécuter" est réel dès lors que plusieurs blocs SQL sont présentés à la suite dans une même interface — ne jamais présenter une commande de modification de schéma comme une action isolée sans préciser explicitement qu'elle doit d'abord être intégrée à la migration.
✅ Indexation storage.foldername() : l'indice du segment de dossier recherché n'est PAS systématiquement [1] — il dépend du nombre de segments fixes précédant l'identifiant recherché dans la convention de chemin du bucket concerné (ex. driver-documents : {driver_id}/... → [1] ; voice-messages : missions/{missionId}/... → [2]). Règle consolidée session 2.14 ter : toujours vérifier par simulation directe (storage.foldername('chemin/exemple')) plutôt que de copier l'indice utilisé dans un pattern de référence différent.
✅ La discipline de lecture intégrale d'un fichier avant modification s'applique aussi aux fichiers de référence/modèle de conception (pas seulement aux fichiers directement modifiés) — règle renforcée session 2.14 quater, suite à un gap d'investigation réel : une lecture en deux extraits disjoints de LegalDocumentsScreen.tsx (fichier de référence, non modifié) a laissé un angle mort de ~25 lignes exactement sur la branche Platform.OS === 'web', découvert seulement lors de l'implémentation, provoquant un retour en arrière évitable (voir Section 6, bloc session 2.14 quater).
✅ git pull --rebase origin main avant tout push (ROADMAP mise à jour directement sur GitHub)
✅ Backup obligatoire avant chaque modification
✅ Test non-régression CLIENT + ADMIN + DRIVER après chaque étape de modification
✅ Ne jamais retester ce qui est écarté
✅ Ne jamais modifier ce qui fonctionne
✅ Toujours vérifier l'état des fichiers avant toute action
✅ 3 workflows GitHub INTOUCHABLES :
   check_supabase.yml
   deploy_supabase.yml
   lint_code.yml
⛔ NE JAMAIS modifier authService.ts
⛔ NE JAMAIS modifier ProfileSetupScreen.tsx
⛔ NE JAMAIS modifier driverService.ts
   Contient createDriverProfile, saveDriverDocuments, createDriverWallet
   Fichier stable — ne pas recréer
⛔ NE JAMAIS modifier wallet_update_admin
   Reste un privilège admin exclusif — confirmé explicitement hors périmètre par le porteur, session 2.13
⚠️ COMPTE ADMIN +212600000001
   NE JAMAIS SUPPRIMER CE PROFIL
   Même entre les tests
⚠️ NUMÉRO PARTAGÉ +212600000000 — CLIENT OU DRIVER (exclusif)
   Le même numéro ne peut avoir qu'UN profil actif à la fois (recherche par user_id, suppression Auth = cascade profil/driver)
   ⚠️ ÉTAT ACTUEL (depuis session 2.14 quater) : rôle CLIENT ("TEST CLIENT FTM") — voir bloc dédié Section 3. Le profil DRIVER historique (2ec2b439-..., wallet 800 DH, 4 transactions pending) n'a plus d'accès Auth mais ses données restent intactes en base — récupérable via un futur onboarding DRIVER + validation admin.
   ⚠️ Limitation confirmée à nouveau sessions 2.14, 2.14 ter et 2.14 quater : absence de second numéro de test dédié au rôle client — a empêché tout test du Volet 4 (notify* mission), de la cloche côté client, du test fonctionnel RLS voice-messages en conditions réelles, et du parcours transport complet — recommandation transmise en Section 17

Historique des rotations du numéro partagé (chronologique) :
Session 2.8 : profil DRIVER (1b6e684e-..., wallet 200 DH, vérifié) → SUPPRIMÉ pour tester CLIENT (ordre DRIVER→ADMIN→CLIENT)
Session 2.9 : +212600000000 recréé en mode DRIVER
   driverId : 29849a0a-5017-4eda-99d4-2c4f5c75a6c3
   is_verified = true (validé admin session 2.9)
Session 2.10 : profil DRIVER recréé
   driverId : eadc9d5e-0db9-4903-b0a3-b69ca46c0b60
   is_verified = true — wallet_balance : 200 DH
Session 2.12 : profil supprimé puis recréé plusieurs fois (test onboarding driver, puis test client, puis second driver pour test transactions_insert_own)
Session 2.13 : aucune rotation du numéro — même profil DRIVER (2ec2b439-...) conservé et réutilisé tout au long de la session (is_verified passé à true en cours de session, pour les besoins des tests de compatibilité admin) — voir bloc dédié Section 3
Session 2.14 : aucune rotation du numéro — même profil DRIVER (2ec2b439-...) conservé, confirmé intact (wallet 800 DH, 3 transactions pending à l'époque) après un cycle déconnexion/reconnexion complet (localStorage.clear()) — voir bloc dédié Section 3
Session 2.14 bis : session sans code ni accès applicatif — aucune rotation, aucun impact sur le numéro partagé ni sur l'état du driver test (voir confirmation de compatibilité, bloc session 2.14 bis, Section 6)
Session 2.14 ter : aucune rotation du numéro — session strictement RLS Storage, aucune table métier touchée. Driver test reconfirmé intact par lecture directe, avec une clarification : 4 transactions pending recensées (50/200/500/1000 DH), et non 3 comme le résumait le document jusqu'alors — la transaction de 50 DH (14/07/2026) est une donnée de test antérieure à la session 2.12, confirmée non anormale et sans lien avec cette session (voir bloc dédié Section 3 et Section 6)
Session 2.14 quater : ROTATION — le compte Auth DRIVER (+212600000000) a été supprimé pour les besoins des tests de la session, puis recréé en rôle CLIENT ("TEST CLIENT FTM"). Le profil DRIVER historique (2ec2b439-...) n'a pas été reconstitué à l'issue de la session ; ses données (wallet, transactions) restent intactes en base, seul l'accès Auth a été supprimé. Décision de reconstitution laissée à la discrétion du porteur / d'une session future — voir bloc dédié Section 3 et Section 17

Si un test DRIVER est à nouveau nécessaire (depuis l'état CLIENT actuel) :
   Supprimer +212600000000 dans Supabase Auth
   Reconnexion → ProfileSetupScreen → sélectionner "Driver"
   Remplir à nouveau les 4 pages onboarding : VehicleInfo → LegalDocuments → DocumentUpload → PendingVerification
   Validation admin requise pour is_verified=true
   Wallet à recréditer manuellement si besoin — NOTE : le profil historique 2ec2b439-... et son wallet 800 DH ne seront pas automatiquement récupérés par cette procédure (nouvel onboarding = nouveau driverId), sauf action explicite de récupération des données existantes

Si un test CLIENT est à nouveau nécessaire depuis un état DRIVER :
   Supprimer +212600000000 dans Supabase Auth
   Reconnexion → ProfileSetupScreen → sélectionner "Client"

⚠️ window.history.back() ne fonctionne pas toujours sur web
   Utiliser le bouton "← Retour" (navigation.goBack())
⚠️ Convention non appliquée sur NotificationCenterScreen.tsx (nouvel écran, session 2.14) — voir Anomalie #1, Section 15
✅ vault.create_secret(valeur, nom, description)
   Ordre exact : valeur en PREMIER, nom en SECOND
   Toujours vérifier avec SELECT name FROM vault.secrets immédiatement après création
✅ timeout_milliseconds := 30000 pour net.http_post
   Le timeout par défaut 5000 ms est insuffisant en cas de cold start Edge Function Supabase
✅ cron.unschedule() WHERE EXISTS
   Pattern obligatoire dans toute migration qui recrée un CRON job — évite les erreurs de doublon
✅ Diagnostic structuré obligatoire
   Établir un plan d'investigation complet et priorisé avant tout test — tester maillon par maillon dans l'ordre
✅ net.http_post → 401 persistant
   Première hypothèse : vérifier la clé Vault (longueur et comparaison directe avec Dashboard) pas uniquement le nom
✅ cron.job_run_details
   Table pg_cron contenant l'historique des exécutions avec statut et timestamps — consulter pour vérifier le fonctionnement réel du CRON
✅ RLS Storage / conception ownership
   Privilégier la chaîne de propriété complète (storage.foldername(name)[n]::uuid = <table pivot>.id → ... → profiles.user_id = auth.uid()) plutôt qu'un raccourci type owner = auth.uid() — session 2.12, confirmé et étendu session 2.14 ter (double chaîne client + chauffeur via UNION, voir Section 6)
✅ Fichier de rollback obligatoire pour toute migration RLS sensible : à placer dans supabase/rollbacks/ (hors du dossier migrations/, pour éviter toute exécution automatique non désirée) — convention introduite session 2.12, reconduite systématiquement depuis (2.13, 2.14 ter, 2.14 quater)
✅ Convention étendue session 2.13 : rollback créé par précaution même pour une migration non-RLS (renommage de vue, contrainte NOT NULL), avec commentaire explicite précisant qu'un rollback SQL seul est insuffisant en cas de déploiement partiel et nécessite un git revert coordonné du code applicatif. Précision session 2.14 quater : pour une contrainte NOT NULL, l'ordre des opérations en cas de rollback complet est impératif — SQL d'abord (retrait de la contrainte), git revert du code applicatif ensuite, jamais l'inverse, sous peine de bloquer toute création de mission.
⚠️ Isoler une clause RLS via fetch() authentifié direct (sans passer par le code applicatif, ex. topupWallet()) peut produire des valeurs déclaratives trompeuses (ex. balance_after renseigné manuellement dans une ligne de test) — toujours vérifier la valeur réelle en base (ex. wallet.balance) plutôt que de se fier au contenu de la ligne insérée manuellement — session 2.12
⚠️ Alert.alert() (React Native) ne s'affiche pas sur web
   Toujours prévoir Platform.OS === 'web' ? window.alert(...) : Alert.alert(...) pour tout message destiné à s'afficher aussi sur web — bug redécouvert session 2.13 (WalletTopupScreen.tsx ligne 70, cf. RÉSOLU 41) après un premier correctif partiel en session 2.8 (AdminUsersScreen.tsx, sans généralisation Platform.OS) — voir audit recommandé section 17
✅ Pattern réappliqué avec succès session 2.14 sur PendingVerificationScreen.tsx (alerte Realtime) — voir RÉSOLU 42.
⚠️ Chemin natif (hors web) toujours non testé à ce jour sur aucun des fichiers concernés — environnement de développement limité au web (Codespaces) — audit systématique proposé (session 2.19) reste pertinent
⚠️ CLARIFICATION MÉTIER FONDAMENTALE (rappelée sessions 2.13, 2.14, 2.14 bis, à ne jamais perdre) : le paiement de la course est TOUJOURS hors application — le client paie directement le chauffeur (espèces ou autre moyen), sans jamais transiter par FTM. Seule la COMMISSION (montant fixe selon catégorie de véhicule) est prélevée automatiquement sur le wallet du chauffeur à chaque mission terminée (trigger process_commission_payment). Le wallet n'est donc alimenté QUE par les recharges (jamais par un paiement client), et diminué QUE par les commissions. Cette clarification est la raison structurelle du renommage revenue_current_month → recharges_current_month (RÉSOLU 39) — à garder impérativement en tête pour toute session touchant au workflow financier (notamment 2.17), pour éviter de reproduire la même confusion de nommage ou de conception ailleurs.
⚠️ negotiated_price (CreateMissionScreen.tsx) ne représente jamais un montant transitant par FTM, uniquement une base d'accord hors app entre client et chauffeur — principe reconfirmé session 2.14 bis (Piste 2, négociation de prix structurée), quel que soit le mécanisme de négociation retenu.
✅ NOUVEAU — Composant DateTimeField.tsx (session 2.14 quater) : sur le modèle des composants Alert.alert()/Platform.OS, ce composant nécessite lui aussi un traitement différencié web/natif (@react-native-community/datetimepicker strictement natif, aucun support web). Toujours vérifier avant tout usage : (1) mémoïsation React.memo si le composant contrôle un champ de saisie texte, pour éviter la corruption de saisie par re-rendu en boucle ; (2) séparation onChange (état local) / onBlur (validation finale) pour tout <input type="date"/"time"> HTML, le navigateur déclenchant onChange dès qu'une valeur techniquement complète est formée, avant la fin de la saisie utilisateur — voir RÉSOLU 44/45/46, session 2.14 quater.

# ÉTAT TECHNIQUE ACTUEL

SDK Expo : 50.0.21 ✅ stable
Vulnerabilities : 39 (outils dev uniquement)
   Impact ZÉRO sur app/publication
   NE PAS corriger avec --force
   Passage de 23 à 39 en session 2.4
   Cause : dépendances dev de expo-image-picker + expo-document-picker
App démarre : ✅ Web Bundled confirmé
   Lancement app web : cd frontend && npx expo start --web --no-dev
   URL web : https://zany-disco-jj95647gqv473pj9-8081.app.github.dev
Page blanche web : ✅ RÉSOLUE — session 2.2
   Cause : BORDER_RADIUS manquant dans theme.ts — commit e7beed2
Bundle web : ✅ 1173ms

Auth CLIENT : ✅ confirmé — session 2.3
   Navigation → CreateMissionScreen
   ⚠️ Non re-testé sessions 2.13, 2.14, 2.14 bis, 2.14 ter (contrainte numéro partagé)
   ⚠️ Session 2.14 quater : le numéro partagé est désormais un profil CLIENT ("TEST CLIENT FTM"), mais le parcours complet (CreateMissionScreen jusqu'à l'insertion en base) reste NON testé — bloqué par l'absence de géolocalisation fonctionnelle en environnement Codespaces/iframe (limitation déjà documentée, hors périmètre, reportée Phase 4.x). Table missions confirmée vide (0 ligne) à l'issue de la session 2.14 quater.

Auth ADMIN : ✅ confirmé — session 2.7
   Navigation → AdminDashboardScreen
   5 écrans dans AdminNavigator : AdminHome ✅ DocumentReview ✅ WalletManagement ✅ AdminMissions ✅ AdminUsers ✅

Auth DRIVER : ✅ COMPLET (historique) — session 2.4 suite
   Flux complet testé et validé à l'époque : Étape 1 → VehicleInfoScreen ✅ / Étape 2 → LegalDocumentsScreen ✅ / Étape 3 → DocumentUploadScreen ✅ / Étape 4 → PendingVerification ✅ / Validation admin → DriverHome ✅
   Realtime Supabase ✅
   ⚠️ ÉTAT ACTUEL (depuis session 2.14 quater) : le compte Auth DRIVER du numéro partagé a été supprimé — le rôle DRIVER n'est PLUS accessible tant qu'un nouvel onboarding n'a pas été effectué. Voir Section 2, bloc "numéro partagé".
   ⚠️ Alerte Realtime de validation sur PendingVerificationScreen.tsx : ✅ CORRIGÉE session 2.14 (RÉSOLU 42) — chemin web uniquement, chemin natif non testé

Bugs session 2.5 : ✅ 3 bugs corrigés (BUG 1 SIGNED_IN onboarding, BUG 2 wallet 404, BUG 3 document_reminders)
Bugs session 2.7 : ✅ 5 bugs corrigés (BUG A wallet RLS récursion, navigation admin 4 menus, SIGNED_IN loop admin, 403 notifications, enum mission_status) — BUG 4 → INFIRMÉ ✅

Packages ajoutés : expo-image-picker ~14.7.1 ✅ expo-document-picker ~11.10.1 ✅ — commit c318a92

Storage :
✅ Bucket driver-documents créé — 5 MB max — jpeg/png/pdf — RLS policies configurées — commits 7222601 + c39cafb
✅ RLS ownership chain corrigée — session 2.12 (commit 67e9e65) — voir item 6.6 / RÉSOLU 36
✅ Bucket voice-messages créé — session 2.8 — 5 MB max — audio/m4a, mp4, mpeg, wav, x-m4a — RLS policies configurées (4) — commit 5ee383e
   ⚠️ Infrastructure créée mais NON testée fonctionnellement (audioService.ts non référencé dans aucun screen — voir item 4.4)
   ✅ RLS ownership CORRIGÉE — session 2.14 ter (commit 9c36d84) — voir RÉSOLU 46. La faille active identifiée en session 2.14 bis est désormais résolue : chaîne de propriété double (client + chauffeur de la mission) via UNION, indice storage.foldername()[2] (convention de chemin missions/{missionId}/...). Fichier applicatif réel confirmé : frontend/src/services/audioService.ts (écart de documentation corrigé — anciennement listé comme missionService.ts/VoiceChatScreen.tsx/VoiceMicButton.tsx).
   ⚠️ Test fonctionnel en conditions réelles reporté à la Phase 4.4 / session 2.18 — décision motivée session 2.14 ter (construire un scénario de test aurait nécessité une mission de test avec données client_id/driver_id réelles, incompatible avec la contrainte du numéro de test partagé unique)

Connexion Supabase : ✅ .env configuré dans frontend/
Token Supabase : ✅ Renouvelé le 29/04/2026 — Nom : FTM_GITHUB_ACTIONS — Expiration : Never
Mode test OTP : ✅ configuré (MessageBird fictif) — Numéro test : +212600000000 — Code fixe : 123456 — Valide jusqu'au : 31/12/2026

Extensions Supabase : ✅ pg_cron 1.6.4 — installée session 2.9 / ✅ pg_net 0.19.5 — installée session 2.9

CRON reminders : ✅ OPÉRATIONNEL — session 2.9
   jobid=2, 0 8 * * *, active=true — timeout_milliseconds := 30000
   5 exécutions succeeded : 18→22/06/2026 — check-document-reminders appelée quotidiennement
   ⚠️ Lien avec notifyDocumentExpiry non vérifié — voir Section 15/17 (en attente depuis session 2.14, non traité en 2.14 bis, 2.14 ter, ni 2.14 quater — hors périmètre de chacune)

Vault Supabase : ✅ Secret supabase_service_role_key — 219 caractères — identique Dashboard — Créé session 2.9

Realtime Supabase : ✅ OPÉRATIONNEL — session 2.10
   5 tables activées : drivers, missions, wallet, transactions, notifications — Migration 20260504000012 déployée
   WalletDashboardScreen SUBSCRIBED ✅
   transactions ✅ écoute branchée — session 2.14
   notifications : Realtime actif — non branché UI directement, remplacé par NotificationBell/Center (résolution du profil via getCurrentProfileId(), déclenché par événement Realtime — PRÉCISION session 2.14 quater : le mécanisme réel n'est PAS un polling par setInterval comme le documentait une version antérieure du présent document, mais bien un abonnement Realtime Supabase déclenché par événement — divergence documentaire corrigée)

RLS transactions : ✅ transactions_insert_own corrigée — session 2.12 (commit 67e9e65) — voir RÉSOLU 37
   ✅ Fondation confirmée fonctionnelle en usage réel session 2.13 : requestWalletTopup() insère des transactions status: 'pending' via cette même politique — RÉSOLU 38
   ✅ Confirmée compatible avec le listener Realtime (Volet 2, session 2.14)
   🔵 Pattern RLS de transactions_select_own / notifications_select_own identifié — session 2.14 bis — réutilisé avec succès comme référence pour voice-messages (session 2.14 ter, via jointure adaptée à un double accès) — reste également la référence prévue pour la future table mission_offers (session 2.14 sexies)

Wallet topup : ✅ Mécanisme honnête — session 2.13 (commit 2e76429) — requestWalletTopup() — voir RÉSOLU 38
   ⛔ wallet_update_admin non modifiée — reste privilège admin exclusif
   ⚠️ Robustesse topupWallet/refundWallet (échec silencieux possible de l'insertion de la transaction après UPDATE du solde) — découverte annexe session 2.14, préexistante, hors périmètre — à documenter pour session future (voir Section 15/17)
   ✅ Reconfirmé sans modification — sessions 2.14 bis et 2.14 ter (aucune de ces deux sessions ne touche au code applicatif wallet)
   ⚠️ Session 2.14 quater : aucune modification non plus (hors périmètre strict, code wallet non touché) — mais le profil DRIVER porteur de ce wallet (2ec2b439-...) a perdu son accès Auth (voir Section 3, bloc numéro partagé) ; les données wallet/transactions elles-mêmes restent inchangées en base

Dashboard driver : ✅ recharges_current_month — session 2.13 (commit 2e76429, migration 20260504000014) — voir RÉSOLU 39

Bug Alert.alert/web : ⚠️ Statut par fichier — mis à jour session 2.14 :
   WalletTopupScreen.tsx ligne 70 (succès) → ✅ CORRIGÉ (commit 480130d, session 2.13) — RÉSOLU 41
   WalletTopupScreen.tsx ligne 66 (erreur) → ⚠️ NON VÉRIFIÉ, laissé inchangé (Option A) — voir bug résiduel Section 15
   AdminUsersScreen.tsx (session 2.8) → ⚠️ fonctionne web, sans distinction Platform.OS — risque mobile natif — voir bug résiduel Section 15
   PendingVerificationScreen.tsx (alerte Realtime) → ✅ CORRIGÉ session 2.14 — RÉSOLU 42 — ⚠️ chemin natif non testé
   Audit systématique recommandé — session 2.19 suggérée (voir Section 17)

Realtime transactions/notifications (Volets 2-3, session 2.14) :
   ✅ subscribeToNewTransactions branché — TransactionHistoryScreen.tsx — écoute INSERT uniquement (limitation assumée, documentée)
   ✅ NotificationBell/NotificationCenterScreen montés sur les 3 rôles (Driver, Client, Admin)
   ⚠️ Anomalie #1 : NotificationCenterScreen.tsx sans bouton "← Retour" — voir Section 15

Fonctions notify mission (Volet 4, session 2.14) : 9 fonctions notify* inventoriées au total
   2 déjà branchées avant 2.14 (notifyDocumentVerified, notifyDocumentRejected)
   4 nouvelles branchées session 2.14 : notifyMissionStarted, notifyMissionAccepted, notifyMissionCompleted (Option C), notifyMissionCancelled
   ⛔ 3 non retenues : notifyNewMission (incompatibilité structurelle), notifyDocumentExpiry (en attente), notifyWalletLowBalance (écartée)
   ⚠️ NON TESTÉES fonctionnellement à ce jour — la rotation du numéro partagé vers CLIENT en session 2.14 quater n'a pas permis de test de bout en bout (absence de GPS fonctionnel en environnement Codespaces, aucune mission insérée en base) — voir Section 15/17

⚠️ Compte ADMIN test :
   Numéro : +212600000001 — Rôle admin défini via SQL Editor — NE PAS SUPPRIMER CE PROFIL
   Reconfirmé intact — sessions 2.14 bis, 2.14 ter, 2.14 quater (aucune modification)

⚠️ DRIVER TEST HISTORIQUE — état à date de la session 2.14 ter (dernière vérification par lecture directe avant la rotation de 2.14 quater) :
   driverId : 2ec2b439-fcdb-443d-8de0-5bee268d30f6
   Numéro : +212600000000 (ACCÈS AUTH DÉSORMAIS SUPPRIMÉ — voir ci-dessous)
   role : 'driver' (données conservées en base)
   is_verified : true (inchangé depuis session 2.13)
   wallet_id : 58b2b8e7-190a-4cbb-8f09-8340feecf498
   wallet_balance réel confirmé : 800.00 DH — CONFIRMÉ INTACT par lecture directe à l'issue de la session 2.14 ter (dernière vérification avant rotation)
   Historique des transactions (chronologique inverse), confirmé par lecture directe session 2.14 ter — 4 transactions au total, count: 7 → 8 non modifié depuis, seule la ventilation pending est clarifiée :
     776ff74b-... | pending | 1000 DH | 800→800 | 21/07
     18d8befd-... | pending | 200 DH | 800→800 | 20/07
     1e3bfbd3-... | completed | 500 DH | 300→800 | 20/07 (recharge admin réelle)
     a976368a-... | pending | 500 DH | 300→300 | 20/07
     3cd42ae1-... | completed | 300 DH | 0→300 | 16/07 (recharge admin réelle, Étape 1.7)
     94322b67-... | failed (requalifiée) | 300 DH | 0→0 | ~16/07 (transaction fantôme originale, corrigée session 2.13)
     42b73573-... | pending | 50 DH | 0→50 | 14/07 (donnée de test antérieure à la session 2.12 — CLARIFICATION session 2.14 ter : cette transaction, jusqu'alors non mentionnée dans le résumé synthétique du présent document, est confirmée par lecture directe de sa date de création comme non anormale et sans lien avec les sessions ultérieures)
   ⚠️ CORRECTION DE COHÉRENCE (session 2.14 ter) : le document mentionnait jusqu'ici "3 demandes de recharge en pending (200, 500, 1000 DH)". Le chiffre exact et confirmé est **4 demandes en pending (50, 200, 500, 1000 DH)**. Cette correction s'applique à toutes les mentions de ce compte dans le présent document (badge NotificationBell, Section 15, etc.).
   ⚠️ ÉTAT DEPUIS SESSION 2.14 quater : l'accès Auth du numéro +212600000000 a été supprimé (le numéro est désormais un profil CLIENT — voir ci-dessous). Le profil DRIVER 2ec2b439-... et l'intégralité de ses données (wallet 800 DH, 4 transactions pending, is_verified=true) restent en base, orphelines de tout accès Auth actif, récupérables sur décision future (voir Section 17).

⚠️ NOUVEAU PROFIL CLIENT ACTIF — depuis session 2.14 quater :
   Numéro : +212600000000
   Profil : "TEST CLIENT FTM"
   role : 'client'
   Créé pour les besoins des tests de la session 2.14 quater (validation UI du champ scheduled_pickup_time)
   Aucune mission créée par ce profil à ce jour (table missions confirmée vide, 0 ligne, à l'issue de la session 2.14 quater)

⚠️ SIGNED_IN répétés en console admin : Comportement normal Supabase web via refresh token périodique — Non bloquant

⚠️ État du dépôt — HEAD : 829f31e (session 2.14 quater), synchronisé avec origin/main, aucune modification en attente de commit. ~55+ fichiers untracked de type .bak* identifiés comme mécanisme de traçabilité délibéré (dont 4 nouveaux ajoutés en session 2.14 quater : CreateMissionScreen.tsx, missionService.ts, CreateParcelScreen.tsx, parcelService.ts, suffixe .bak.session2.14quater) — à préserver tel quel, cohérent avec la politique déjà établie.

# GITHUB SECRETS CONFIGURÉS

SUPABASE_ACCESS_TOKEN ✅ renouvelé 29/04/2026 — Token : FTM_GITHUB_ACTIONS — Expiration : Never
SUPABASE_PROJECT_ID ✅ (ustckqnecsilxqlyjute)
SUPABASE_DB_PASSWORD ✅
SUPABASE_ANON_KEY ✅
SUPABASE_URL ✅

# HISTORIQUE COMMITS CLÉS

829f31e fix: web support for DateTimeField (Platform.OS branch, React.memo, onChange/onBlur split) — session 2.14 quater ✅
0da3e07 feat: scheduled_pickup_time mandatory (NOT NULL) — transport + e-commerce flows, DateTimeField component — session 2.14 quater ✅
9c36d84 fix: RLS ownership chain voice-messages bucket - mission-scoped client+driver access — session 2.14 ter ✅
[Aucun commit — session 2.14 bis, investigation pure]
afba878 fix: subscribe to new transactions realtime + mount NotificationBell/NotificationCenter (3 roles) + branch 4 mission notify functions + fix PendingVerification Realtime alert (Platform.OS) — session 2.14 ✅
480130d fix: window.alert fallback for web compatibility on wallet topup success message — session 2.13 ✅
2e76429 fix: honest wallet topup request mechanism (pending status) + dashboard revenue calculation + navigation fix — session 2.13 ✅
67e9e65 fix: RLS ownership chain Storage (driver-documents) + transactions_insert_own — session 2.12 ✅
b65eb9d feat: enable Realtime on 5 tables (drivers, missions, wallet, transactions, notifications) — session 2.10 ✅
34b32c1 feat: configure CRON job for document expiry reminders - session 2.9 ✅
5ee383e feat: create voice-messages storage bucket and RLS policies ✅ session 2.8
aed0bee fix: replace Alert.alert with window.confirm in AdminUsersScreen for web compatibility ✅ session 2.8
750db88 fix: correct mission_status enum values in AdminMissionsScreen ✅ session 2.7
626e851 feat: add AdminMissions and AdminUsers screens to admin navigation ✅ session 2.7
445bdcb fix: add SELECT RLS policy on notifications for admin role ✅ session 2.7
2351bf3 fix: add INSERT RLS policy on notifications for authenticated users ✅ session 2.7
4ff3499 fix: add DocumentReview and WalletManagement screens to AdminNavigator ✅ session 2.7
6ee89b1 fix: prevent SIGNED_IN loop for admin role in RootNavigator ✅ session 2.7
d420007 fix: replace wallet_update_admin RLS policy use get_my_role() to fix infinite recursion ✅ session 2.7
c4194db docs: update ROADMAP session 2.6 ✅
0207e97 fix: add DocumentStatusScreen to driver navigation + add Mes documents button ✅ session 2.6
8c5d8c5 fix: add RLS INSERT policy on transactions table ✅ session 2.6
cac7f4d fix: drop and recreate driver_dashboard view fix column order error SQLSTATE 42P16 ✅ session 2.6
884f00e fix: connect wallet screens to driver navigation + fix driver_dashboard view missing columns ✅ session 2.6
9f22d9d fix: add UNIQUE constraint on document_reminders (driver_id, document_type) enables upsert ON CONFLICT ✅ session 2.5
b4ec2ba fix: correct wallet table name wallets → wallet in DriverHomeScreen ✅ session 2.5
475274c fix: ignore SIGNED_IN during driver onboarding use ref to prevent spontaneous navigation ✅ session 2.5
f377534 docs: update ROADMAP session 2.4 ✅
c39cafb feat: add RLS policies driver-documents bucket ✅
7222601 feat: create driver-documents storage bucket ✅
6b9dae8 fix: prevent skip to PendingStack check doc URLs + web DatePicker fallback ✅
a23df8b fix: keep driver on onboarding if driver_license_number is null ✅
1c9af9c fix: allow null legal docs fields at step 1 ✅
6f7ed8c fix: allow null driver_license_number at step 1 ✅
8acc64c feat: connect driver onboarding VehicleInfo/LegalDocs/DocumentUpload/PendingVerification navigators ✅
c318a92 feat: add DriverOnboardingStack/DriverPendingStack routes + install expo-image-picker expo-document-picker ✅
b669da7 docs: update ROADMAP_FTM session 2.3 ✅
bd7ead0 fix: SIGNED_IN pour utilisateurs existants ✅
53725fe fix: clientProfileId transmis à CreateMissionScreen ✅
8a78903 fix: navigation post-profil via callback ✅
e7beed2 fix: BORDER_RADIUS ajouté theme.ts ✅

# MODIFICATIONS COMMITÉES — DÉTAIL

[Sections SESSION 2.4 INITIALE à SESSION 2.14 bis — inchangées, reprises intégralement à l'identique de la version du 11/08/2026. Voir blocs détaillés ci-dessous pour les deux nouvelles sessions.]

## SESSION 2.4 INITIALE — commits c318a92 + 8acc64c

frontend/src/types/database.ts — commit c318a92
   Ajout 2 nouvelles routes dans type AppRoute : 'DriverOnboardingStack' 'DriverPendingStack'

frontend/package.json — commit c318a92
   expo-image-picker ~14.7.1 / expo-document-picker ~11.10.1
   Commande : npx expo install expo-image-picker expo-document-picker

frontend/src/navigation/RootNavigator.tsx — commit 8acc64c
   11 modifications : Type retour initializeApp() étendu ; cas driver complet ; states driverProfileId + driverVehicleCategory ; useEffect + SIGNED_IN captent driverId/vehicleCategory ; imports 4 écrans onboarding ; types DriverOnboardingStackParamList/DriverPendingStackParamList ; navigateurs stack créés ; DriverOnboardingNavigator (4 écrans) ; DriverPendingNavigator ; DriverNavigator mis à jour ; rendu conditionnel ajouté

## SESSION 2.4 SUITE — commits 6f7ed8c → c39cafb

frontend/src/navigation/RootNavigator.tsx
   Logique driver complète : !driver → OnboardingStack ; !driver_license_number → OnboardingStack ; !toutes 4 URLs → OnboardingStack ; !is_verified → PendingStack ; sinon → HomeStack

frontend/src/screens/driver/onboarding/LegalDocumentsScreen.tsx
   Fallback web pour DateTimePicker : Platform.OS === 'web' → input type="date" HTML natif ; Mobile → DateTimePicker natif inchangé

Migrations SQL ajoutées :
   20260429000001 → driver_license_number DROP NOT NULL
   20260429000002 → 5 champs légaux DROP NOT NULL
   20260504000001 → CREATE bucket driver-documents
   20260504000002 → RLS policies bucket driver-documents

## SESSION 2.5 — commits 475274c → 9f22d9d

frontend/src/navigation/RootNavigator.tsx — commit 475274c
   Correction BUG 1 — SIGNED_IN stale closure : useRef<AppRoute> ajouté, initialRouteRef.current synchronisé, condition if (initialRouteRef.current !== "DriverOnboardingStack")

frontend/src/screens/driver/DriverHomeScreen.tsx — commit b4ec2ba
   Correction BUG 2 — wallet 404 : .from('wallets') → .from('wallet') ligne 36

Migrations SQL ajoutées : 20260504000003 → UNIQUE constraint document_reminders

## SESSION 2.6 — commits 884f00e → c4194db

frontend/src/navigation/RootNavigator.tsx — commit 884f00e
   4 écrans ajoutés : WalletDashboard, WalletTopup, TransactionHistory, DocumentStatus

Migrations SQL ajoutées :
   20260504000004 → DROP + CREATE VIEW driver_dashboard, 5 colonnes ajoutées
   20260504000005 → RLS INSERT policy transactions pour authenticated

## SESSION 2.7 — commits d420007 → 750db88

Migration 20260504000006 — commit d420007
   Correction BUG A — wallet_update_admin RLS récursion : DROP POLICY + CREATE POLICY USING (get_my_role() = 'admin')

frontend/src/navigation/RootNavigator.tsx — commit 6ee89b1
   Correction SIGNED_IN loop admin : condition étendue à "AdminStack"

frontend/src/navigation/RootNavigator.tsx — commit 4ff3499
   2 écrans admin connectés : DocumentReview → DocumentReviewScreen ; WalletManagement → WalletManagementScreen

Migrations 20260504000007 + 20260504000008 — commits 2351bf3 + 445bdcb
   Correction 403 notifications — 2 couches (INSERT authenticated + SELECT admin via get_my_role())

frontend/src/screens/admin/AdminMissionsScreen.tsx — commit 626e851
   Nouvel écran créé : liste toutes les missions, 6 filtres, pagination 25/page, bouton Retour ; enum corrigé cancelled → cancelled_client + cancelled_driver

frontend/src/screens/admin/AdminUsersScreen.tsx — commit 626e851
   Nouvel écran créé : liste drivers actif/suspendu, recherche, toggleUserActive(), bouton Retour

frontend/src/navigation/RootNavigator.tsx — commit 626e851
   2 nouveaux écrans connectés : AdminMissions, AdminUsers

frontend/src/screens/admin/AdminMissionsScreen.tsx — commit 750db88
   Correction enum mission_status : 'cancelled' → 'cancelled_client' + 'cancelled_driver'

## SESSION 2.8 — commits aed0bee → 5ee383e

frontend/src/screens/admin/AdminUsersScreen.tsx — commit aed0bee
   Correction bug "Suspendre" : Alert.alert() → window.confirm()/window.alert()
   ⚠️ Sans distinction Platform.OS — découvert session 2.13, non corrigé (hors périmètre)

Migrations 20260504000009 + 20260504000010 — commit 5ee383e
   Création bucket voice-messages + RLS policies (4), même modèle que driver-documents à l'époque
   ⚠️ Non testé fonctionnellement (audioService.ts non intégré UI)

Test CLIENT — CreateMissionScreen (session 2.8)
   Procédure de rotation testée ; formulaire fonctionnel ; bouton "Trouver un chauffeur" confirmé désactivé (GPS bloqué Codespaces/iframe, pas un bug applicatif)

## SESSION 2.9 — commit 34b32c1

Migration 20260504000011 — commit 34b32c1
   Configuration CRON job document expiry reminders : extensions pg_net/pg_cron activées, secret Vault corrigé, CRON job jobid=2 opérationnel, Edge Function testée {sent: 3, errors: 0}

Driver test recréé — session 2.9 : driverId 29849a0a-... — État : remplacé par eadc9d5e-... en session 2.10

## SESSION 2.10 — commit b65eb9d

Migration 20260504000012 — commit b65eb9d
   Activation Realtime sur 5 tables (drivers, missions, wallet, transactions, notifications) ; vérifié 5 rows dans supabase_realtime

Constats identifiés — session 2.10 : navigation cross-stack PendingVerification→DriverHome ; revenue_current_month trompeur ; NotificationBell jamais montée ; subscribeToNewTransactions jamais appelée ; TrackingDetailScreen souscription commentée

## SESSION 2.11 — Planification

Session de planification pure — 11 points investigués en profondeur. Cause racine commune identifiée (Points 3, 4, Bug B du 6, Point 9) : échec RLS silencieux sur topupWallet()/refundWallet(). Point 7 (NotificationBell) : portée élargie. Point 8 (TrackingDetailScreen) : bug fonctionnel actif découvert. Points 9, 10, 11 reclassés en chantier stratégique unique.

PLANIFICATION DES SESSIONS (historique, mise à jour continue — voir Section 16 pour le statut courant complet) :
2.12 ✅ RLS Storage + transactions_insert_own
2.13 ✅ Cause racine RLS wallet + recharge honnête
2.14 ✅ Realtime + Notifications (avec réserves)
2.14 bis ✅ Investigation/planification processus de mission
2.14 ter ✅ Correction sécurité RLS voice-messages
2.14 quater ✅ Piste 3 — planification par date/heure (avec réserves)
2.14 quinquies ⏳ Piste 1 — diffusion optimisée (dépendance envers 2.14 quater désormais LEVÉE, voir ci-dessous)
2.14 sexies ⏳ Piste 2 — négociation de prix structurée
2.14 septies ⏳ Piste 4 — activation canal vocal sécurisé
2.15 ⏳ TrackingDetailScreen
2.16 ⏳ Bouton déconnexion 3 rôles
2.17 ⏳ Réforme timing commission + workflow financier générique
2.18 ⏳ Test fonctionnel complet voice-messages (Phase 4.4, RLS déjà déployée depuis 2.14 ter)
2.19 ⏳ Audit systématique Alert.alert()
2.20 ⏳ NOUVELLE — Correction route CreateParcel manquante + test flux e-commerce complet (voir Section 6, bloc 2.14 quater)

⚠️ MISE À JOUR DE DÉPENDANCE (session 2.14 quater → 2.14 quinquies) : la dépendance du Volet 2 de la Piste 1 (expiration d'une mission jamais acceptée) envers la Piste 3 (scheduled_pickup_time) est désormais LEVÉE — le champ est disponible et obligatoire en base depuis le déploiement de la migration 20260504000016. 2.14 quinquies peut démarrer sans prérequis bloquant restant, son Volet 1 (expiration mission acceptée) n'ayant de toute façon jamais eu de dépendance entrante.

Ordre logique actualisé : 2.12 → 2.13 → 2.14 → 2.14 bis → 2.14 ter → 2.14 quater → 2.14 quinquies (débloquée) → 2.14 sexies → 2.14 septies → 2.15 (parallélisable) → 2.16 (glissable) → 2.17 (dernière du chantier wallet) → 2.18 (test fonctionnel voice-messages, Phase 4.4) → 2.19 (glissable, avant Phase 3) → 2.20 (nouvelle, fin de séquence chantier processus de mission, sans dépendance avec les pistes suivantes)

LISTE DE SUIVI — ANOMALIES/OBSERVATIONS DOCUMENTAIRES (à corriger dans le présent document) :
1. ID driver test coquille → CORRIGÉ session 2.12
2-3. Chemins onboarding → confirmés sous frontend/src/screens/driver/onboarding/
4. Bug WalletRecharge → CORRIGÉ session 2.13 (RÉSOLU 40)
5. Filtrage géographique absent → RPC find_nearby_drivers identifiée session 2.14 bis, réutilisation prévue 2.14 quinquies
6. Convention de chemins non documentée (sous-dossiers thématiques)
7. RLS transactions INSERT sans restriction → CORRIGÉ session 2.12 (RÉSOLU 37)
8. RLS voice-messages sans clause de propriété → CORRIGÉ session 2.14 ter (RÉSOLU 46)
9. NOUVEAU (session 2.14 ter) — Décompte transactions pending driver test : le document affichait "3 (200/500/1000 DH)", corrigé en "4 (50/200/500/1000 DH)" — voir Section 3
10. NOUVEAU (session 2.14 quater) — Divergence documentaire NotificationBell : mécanisme réel = Realtime événementiel, pas polling par setInterval — corrigé Section 3
11. NOUVEAU (session 2.14 quater) — Fichier applicatif du canal vocal : confirmé frontend/src/services/audioService.ts (déjà corrigé session 2.14 ter)
12. NOUVEAU (session 2.14 quater) — Route de navigation CreateParcel manquante (bug préexistant découvert, sans rapport avec la session) — voir Section 15, session 2.20 assignée

Prochain timestamp migration disponible : 20260504000017 (consommé : 015 par session 2.14 ter, 016 par session 2.14 quater)

## REQUALIFICATION PHASE 6 — AMÉLIORATIONS POST-TESTS

[Contenu inchangé depuis la version du 11/08/2026 — items 6.1 à 6.6 repris à l'identique, voir Section 16/17 pour statuts courants.]
6.1 ⏳ Modes de paiement multiples wallet → session 2.17
6.2 ⏳ Workflow validation recharge admin → session 2.17 (fondation posée 2.13)
6.3 ⏳ Remboursements flux dédié → session 2.17
6.4 ⏳ Bouton déconnexion 3 rôles → session 2.16
6.5 ✅/⏳ Refonte WalletTopupScreen — Partie 1 ✅ (2.13), Partie 2 ⏳ → session 2.17
6.6 ✅/✅ SÉCURITÉ — RLS Storage : driver-documents ✅ (2.12), voice-messages ✅ CORRIGÉE (2.14 ter, RÉSOLU 46) — reste le test fonctionnel en Phase 4.4/session 2.18

⚠️ DÉPENDANCE CROISÉE À NOTER — Phase 3 / Session 2.14 : les fonctions notify* mission dépendent de l'infrastructure FCM/APNs non réalisée à ce jour (voir Section 13).

## SESSION 2.12 — commit 67e9e65

[Contenu inchangé — reprise intégrale du détail de la version du 11/08/2026 : Partie 1 investigation, Partie 2 implémentation, tests fonctionnels DRIVER/ADMIN/accès croisé/CLIENT/transactions, anomalie DocumentReviewScreen découverte, état final du dépôt. Voir RÉSOLU 36/37.]

## SESSION 2.13 — commits 2e76429 + 480130d

[Contenu inchangé — reprise intégrale : mécanisme requestWalletTopup(), correction revenue→recharges, correction navigation PendingVerificationScreen, correctif Alert.alert/web. Voir RÉSOLU 38/39/40/41.]

## SESSION 2.14 — commit afba878

[Contenu inchangé — reprise intégrale : Volets 1 à 4 (alerte Realtime, subscribeToNewTransactions, NotificationBell/Center, 4 fonctions notify* mission), Incident bash (!), Anomalie #1. Voir RÉSOLU 42.]

## SESSION 2.14 bis — 07/08/2026 (aucun commit)

[Contenu inchangé — reprise intégrale : investigation des 4 pistes (diffusion, négociation, planification, canal vocal), constat de sécurité voice-messages, découpage en 5 sessions 2.14 ter à 2.14 septies.]

## SESSION 2.14 ter — commit 9c36d84

Correction RLS bucket Storage voice-messages

### Objectif et périmètre

Corriger la faille de sécurité RLS active sur le bucket Storage voice-messages (accès non restreint par propriété), en suivant le pattern éprouvé driver-documents (RÉSOLU 36, session 2.12), adapté à la complexité du double accès légitime (client + chauffeur de la mission). Session mixte : investigation ciblée (Partie 1) + implémentation (Partie 2), avec point de validation explicite obligatoire entre les deux.

### Partie 1 — Synthèse des vérifications (toutes CONFIRMÉES par lecture directe)

| Étape | Élément vérifié | Résultat |
|---|---|---|
| 1.0 | État git initial | HEAD 163c545 (roadmap), HEAD CODE afba878 inchangé, RAS |
| 1.2 | Structure missions | client_id uuid NULL, driver_id uuid NULL — noms confirmés, nullable (mission créée sans chauffeur) |
| 1.3 | Contenu bucket voice-messages | Vide (0 ligne) — canal jamais utilisé, UI orpheline |
| 1.4 | Policies RLS existantes | 4 policies (authenticated_{read,upload,update,delete}_voice_messages), aucune ne vérifie la propriété — uniquement bucket_id = 'voice-messages' |
| 1.5 | Pattern driver-documents (RÉSOLU 36) | 4 policies identiques : (bucket_id = 'driver-documents') AND (get_my_role()='admin' OR storage.foldername(name)[1]::uuid IN (SELECT drivers.id via profiles.user_id = auth.uid())) |
| FK | Clés étrangères missions | client_id → profiles.id, driver_id → drivers.id — confirmées |
| 1.7 | Indexation storage.foldername() | Point critique détecté : pour voice-messages, le chemin missions/{missionId}/{senderProfileId}_{timestamp}.ext produit un tableau à 2 segments (['missions', missionId]). L'indice correct est [2], pas [1] comme dans driver-documents (un seul segment de dossier). Vérifié par simulation directe. |
| — | Convention de chemin (code source) | Confirmée dans frontend/src/services/audioService.ts ligne 120 — écart de documentation identifié : le prompt de mission listait missionService.ts, VoiceChatScreen.tsx, VoiceMicButton.tsx, mais le code réel est dans audioService.ts |
| — | Rôle des policies (TO authenticated) | Confirmé identique sur les 8 policies existantes (driver-documents + anciennes voice-messages) |

3 points d'arbitrage tranchés par le porteur :
1. Accès admin dans la clause RLS : exclu. Aucun besoin métier documenté ne justifie qu'un admin lise du contenu audio privé.
2. Modalité de test (Étape 2.6) : Option 1 (test partiel, sans rotation du numéro de test partagé +212600000000).
3. Structure SQL : duplication littérale sur les 4 policies (fidèle au pattern RÉSOLU 36), pas de factorisation via fonction SQL partagée.

### Partie 2 — Implémentation

Clause RLS finale (chaîne de propriété identique pour les 4 opérations) :
```sql
(bucket_id = 'voice-messages'::text) AND (
  ((storage.foldername(name))[2])::uuid IN (
    SELECT m.id FROM missions m
    JOIN profiles p_client ON p_client.id = m.client_id
    WHERE p_client.user_id = auth.uid()
    UNION
    SELECT m.id FROM missions m
    JOIN drivers d ON d.id = m.driver_id
    JOIN profiles p_driver ON p_driver.id = d.profile_id
    WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid()
  )
)
```

Appliquée à 4 policies : voice_messages_read_own (SELECT), voice_messages_upload_own (INSERT, WITH CHECK), voice_messages_update_own (UPDATE), voice_messages_delete_own (DELETE). Chacune précédée d'un DROP POLICY IF EXISTS de l'ancienne policy correspondante.

Livrables :
- supabase/migrations/20260504000015_fix_rls_voice_messages.sql (1049 octets, 4 blocs)
- supabase/rollbacks/20260504000015_fix_rls_voice_messages_rollback.sql (1478 octets) — recrée fidèlement les 4 anciennes policies permissives, avertissement explicite sur l'insuffisance d'un rollback SQL seul en cas de déploiement partiel

Commit et déploiement :
- Commit 9c36d84 : « fix: RLS ownership chain voice-messages bucket - mission-scoped client+driver access », 2 fichiers, 125 insertions
- Poussé sur origin/main (163c545..9c36d84)
- Déploiement via deploy_supabase.yml (Deploy Supabase FTM #45)

État final vérifié en base (post-déploiement, par lecture directe) : 4 policies actives (voice_messages_{read,upload,update,delete}_own), aucune trace des anciennes authenticated_*_voice_messages. Git et base synchronisés.

### Incidents survenus durant la session

**Incident 1 — DROP manuel hors circuit GitHub**

Ce qui s'est passé : lors de la préparation de l'Étape 2.1, la commande DROP POLICY IF EXISTS "authenticated_read_voice_messages" ON storage.objects; a été exécutée directement dans le SQL Editor Supabase (production), avant validation explicite et avant l'écriture du fichier de migration — en contradiction avec la règle de migrations SQL exclusivement via GitHub Actions.

Pourquoi : enchaînement trop rapide entre la proposition d'une commande et son exécution, plusieurs commandes SQL affichées à proximité l'une de l'autre dans la même interface.

Impact réel : nul sur les données (bucket vide) — mais rupture de traçabilité entre l'état de la base et l'état du dépôt Git pendant la fenêtre entre le DROP manuel et le commit 9c36d84. Fail-closed (aucune policy SELECT active pendant cette fenêtre), pas fail-open — pas d'exposition de données.

Résolution : le DROP déjà survenu a été documenté explicitement en commentaire dans le fichier de migration lui-même (traçabilité rétroactive), puis le CREATE POLICY correspondant a été inclus dans le même bloc, déployé via le canal standard.

Leçon méthodologique consolidée en Section 2 : ne jamais présenter une commande SQL de modification de schéma comme une action isolée "à transmettre pour exécution" sans préciser explicitement qu'elle doit être intégrée au fichier de migration avant toute exécution réelle.

**Incident 2 — Échec du premier déploiement (socket hang up)**

Ce qui s'est passé : le run Deploy Supabase FTM #45 a échoué dès la première étape (Lint SQL Migrations, 35s), avec l'erreur socket hang up — coupure de connexion réseau transitoire, sans rapport avec le contenu du fichier SQL.

Vérification effectuée avant toute action corrective : requête sur pg_policy confirmant qu'aucune trace du déploiement raté n'était présente en base (le pipeline séquentiel s'était arrêté avant Deploy DB Migrations).

Résolution : simple relance (Re-run all jobs) — succès complet au second essai (3m 2s, 4/4 étapes vertes). Confirmé a posteriori comme un incident réseau ponctuel, pas structurel — aucune règle nouvelle consolidée pour cet incident.

### Étape 2.6 — Test en conditions réelles : reporté (décision explicite du porteur)

Décision : le test fonctionnel de la clause RLS n'a pas été exécuté dans cette session.

Raison : construire un scénario de test aurait nécessité d'insérer une mission de test avec des données réelles (client_id/driver_id), le numéro de test partagé ne pouvant occuper les deux rôles simultanément (Option 1 retenue en Partie 1). Cette manipulation aurait fait sortir la session, pour la première fois, du registre strict "schéma/RLS" vers "données métier réelles, même factices" — avec risque de pollution de données pour un bénéfice limité.

Cohérence documentaire : ce report est conforme à ce que prévoyait déjà le prompt de passation — le déploiement/test fonctionnel complet du canal reste rattaché à la Phase 4.4 / session 2.18, qui disposera d'un contexte de test représentatif (device physique, vraie mission active, vrai chauffeur).

Ce qui reste acquis, non remis en cause par ce report : la clause RLS est déployée et confirmée active en production par lecture directe.

### Écarts de documentation corrigés (intégrés au présent document)

- Fichier applicatif du canal vocal : confirmé frontend/src/services/audioService.ts (et non missionService.ts/VoiceChatScreen.tsx/VoiceMicButton.tsx comme listé précédemment) — corrigé dans l'arborescence (Section 12) et Section 3.
- Indexation storage.foldername() : règle généralisée, consolidée en Section 2 — l'indice dépend du nombre de segments fixes de la convention de chemin, à vérifier systématiquement par simulation.

### État final du dépôt et continuité inter-sessions

HEAD : 9c36d84, synchronisé avec origin/main. Aucun fichier en attente de commit hors des .bak* déjà identifiés.

Timestamp de migration consommé : 20260504000015. Le prochain disponible est désormais 20260504000016 (consommé à son tour par la session 2.14 quater — voir ci-dessous, prochain réellement disponible : 20260504000017).

### Confirmation de compatibilité et de non-régression

Aucune modification de code applicatif dans cette session — seule la couche RLS Storage (storage.objects, bucket voice-messages) a été touchée, via migration SQL exclusivement. Aucun fichier .ts/.tsx modifié (lecture seule sur audioService.ts, VoiceChatScreen.tsx, VoiceMicButton.tsx).

Le test de non-régression multi-rôles classique (DRIVER → ADMIN → CLIENT) n'était pas applicable au sens où l'exigent les sessions touchant du code applicatif. Vérification faite par lecture directe de l'état des policies en base après déploiement — le test applicatif fonctionnel reste à faire en Phase 4.4.

Aucune des briques fonctionnelles à préserver (recharge wallet, Realtime transactions, NotificationBell/Center, fonctions notify*) n'a été touchée, directement ou indirectement, par cette session.

### Vérification finale — État des comptes de test

Driver test (2ec2b439-fcdb-443d-8de0-5bee268d30f6) — vérifié par lecture directe après clôture des Parties 1 et 2 :
- wallet_id : 58b2b8e7-190a-4cbb-8f09-8340feecf498 — conforme
- balance : 800.00 DH — conforme, inchangé
- 4 transactions en statut pending, confirmées par lecture directe de created_at : 50.00 DH (14/07/2026, donnée de test préexistante non mentionnée dans le résumé synthétique du document jusqu'alors, confirmée non anormale) ; 500.00 DH (20/07/2026) ; 200.00 DH (20/07/2026) ; 1000.00 DH (21/07/2026)
- Confirmation : aucune donnée wallet/transactions n'a été altérée par cette session

Compte admin (+212600000001) : non supprimé, non modifié — conforme.

### Synthèse finale de la session

| Élément | Statut |
|---|---|
| Partie 1 — Investigation | ✅ Complète, toutes vérifications par lecture directe |
| Partie 2 — Migration + rollback | ✅ Écrits, vérifiés bloc par bloc (repr(), wc -c) |
| Déploiement | ✅ Réussi (après relance suite incident réseau) |
| Policies RLS finales | ✅ 4/4 actives, confirmées en base |
| Test fonctionnel (Étape 2.6) | ⏸ Reporté à la Phase 4.4 / session 2.18, décision motivée et tracée |
| Incidents | 2, tous deux documentés, résolus, sans impact final sur les données |
| Comptes de test | ✅ Intacts, vérifiés par lecture directe |
| État du dépôt | ✅ Propre, HEAD 9c36d84, synchronisé |

Fichiers créés :
- supabase/migrations/20260504000015_fix_rls_voice_messages.sql
- supabase/rollbacks/20260504000015_fix_rls_voice_messages_rollback.sql

## SESSION 2.14 quater — commits 0da3e07 + 829f31e

Planification par date/heure — scheduled_pickup_time obligatoire (transport + e-commerce)

### Objectif et périmètre

Rendre scheduled_pickup_time obligatoire dans le flux de création de mission classique, avec arbitrage UI-only vs contrainte DB à trancher en Partie 1. Session multi-jours (13-20/08/2026), plusieurs pauses.

### Partie 1 — Investigation (synthèse)

CONFIRMÉ par lecture directe : scheduled_pickup_time absent de tous les points de création (écran, service missionService.ts) ; table missions vide (0 ligne) en début de session.

Composant DateTimePicker natif existant (LegalDocumentsScreen.tsx) analysé comme référence : mode date seule, limitation Android confirmée par recherche externe (pas de mode="datetime" combiné natif), sous-composant DateField non exporté (privé au fichier).

Découverte majeure : createMission() est également appelée par le flux e-commerce (parcelService.ts), hors périmètre initial du prompt de mission → dérogation actée explicitement par le porteur (Option B + extension de la contrainte au flux e-commerce, strictement limitée à ce champ).

Triggers set_commission_amount et set_estimated_distance vérifiés par lecture directe : aucun conflit avec la future contrainte NOT NULL.

### Partie 2 — Implémentation

**Arbitrage tranché : Option B.** Contrainte NOT NULL en base de données, en complément (pas en remplacement) de la validation côté UI. Justification du porteur : robustesse contre tout point d'entrée non anticipé, présent ou futur.

**Commit 1 — 0da3e07 : code applicatif + migration + rollback**

Fichiers modifiés (5) :
- frontend/src/components/DateTimeField.tsx (nouveau) — composant partagé pour la sélection date+heure. Structure inspirée du pattern DateField (bouton → picker → gestion d'erreur), mais dupliquée et réécrite indépendamment, sans modifier ni importer LegalDocumentsScreen.tsx (hors périmètre, aucune dérogation accordée pour ce fichier).
- frontend/src/screens/client/CreateMissionScreen.tsx — intégration flux transport classique
- frontend/src/services/missionService.ts — intégration flux transport classique
- frontend/src/screens/ecommerce/CreateParcelScreen.tsx — intégration flux e-commerce (dérogation actée)
- frontend/src/services/parcelService.ts — intégration flux e-commerce (dérogation actée)

Migration + rollback SQL :
- supabase/migrations/20260504000016_add_scheduled_pickup_time_not_null.sql — ALTER TABLE missions ALTER COLUMN scheduled_pickup_time SET NOT NULL;
- supabase/rollbacks/20260504000016_add_scheduled_pickup_time_not_null_rollback.sql — rollback correspondant, avec avertissement explicite sur l'ordre des opérations en cas de rollback complet (SQL d'abord, git revert du code applicatif ensuite — jamais l'inverse, sous peine de bloquer toute création de mission)

Déployés et vérifiés en production : is_nullable = NO confirmé par lecture directe du schéma réel (information_schema.columns), pas seulement par le statut du pipeline CI.

**Commit 2 — 829f31e : correctif web de DateTimeField.tsx**

Découvert et corrigé après le déploiement du commit 0da3e07, à l'occasion des premiers tests sur web. Trois causes racines distinctes, diagnostiquées séparément :

1. **Absence totale de support web** de @react-native-community/datetimepicker (bibliothèque strictement native iOS/Android/Windows, confirmé par documentation officielle) → ajout d'une branche Platform.OS === 'web' avec <input type="date">/<input type="time">, inspirée du repli déjà existant dans LegalDocumentsScreen.tsx.
2. **Re-rendu en boucle** du composant non mémoïsé, corrompant la saisie clavier (année transformée en 0002 par exemple) → correctif React.memo appliqué sur l'export du composant.
3. **Validation prématurée** à chaque segment de frappe (le navigateur déclenche onChange sur <input type="date"> dès qu'une valeur techniquement complète est formée, avant la fin de la saisie de l'utilisateur — comportement standard HTML confirmé par recherche) → séparation onChange (mise à jour d'un état local, sans validation) / onBlur (validation finale via applyCombined).

Chaque correctif a été validé empiriquement par instrumentation temporaire (console.log préfixés [FTM-DEBUG-TEMP]), retirée et vérifiée absente après confirmation du bon fonctionnement.

Tous les workflows CI déclenchés sur les deux commits (Check Supabase Connection, Vérification Qualité Code, Deploy Supabase FTM) se sont terminés avec succès.

### Leçon méthodologique — gap d'investigation

Lors de l'Étape 1.3 (Partie 1), LegalDocumentsScreen.tsx a été lu en deux extraits disjoints (lignes 1-45 puis 70-110), laissant un angle mort de ~25 lignes exactement là où se trouvait la branche Platform.OS === 'web' — l'information la plus critique pour la conception du composant DateTimeField. Cette omission n'a été découverte qu'en Partie 2, lors du diagnostic du bug de non-support web (commit 829f31e), provoquant un retour en arrière évitable.

Leçon consolidée en Section 2 : la discipline de lecture intégrale doit s'appliquer avec la même rigueur à tout fichier de référence technique servant de modèle de conception — pas seulement aux fichiers directement modifiés.

### Tests de non-régression — bilan

| Test | Statut | Détail |
|---|---|---|
| Validation UI — bouton désactivé sans date | ✅ Validé | Confirmé sur CreateMissionScreen.tsx |
| Rejet d'une date passée | ✅ Validé | Message d'erreur affiché, logs confirmant le rejet sans corruption de l'affichage |
| Acceptation d'une date future | ✅ Validé | Testé avec succès (25/08/2026, 16:25) |
| Règle « aucun délai minimum requis » | ✅ Validé | Testé le 20/08/2026 : date du jour + heure proche de l'heure courante (~30-40 min d'écart), acceptée sans erreur au premier essai |
| Vérification qu'aucun fichier tiers n'importe DateTimeField | ✅ Validé | grep confirmant exactement 3 fichiers : le composant lui-même + les deux écrans consommateurs prévus |
| Soumission complète du flux transport (jusqu'à l'insertion en base) | ⚠️ Non testé | Bloqué par l'absence de géolocalisation fonctionnelle dans l'environnement Codespaces/iframe (limitation déjà documentée, hors périmètre, reportée Phase 4.x). Aucune mission n'a été insérée en base pendant cette session (table confirmée vide par requête directe). |
| Flux e-commerce (CreateParcelScreen.tsx) | ⚠️ Non testé | Bug préexistant découvert, sans rapport avec cette session : la route 'CreateParcel' appelée par ParcelHistoryScreen.tsx (navigation.navigate('CreateParcel')) n'est déclarée dans aucun fichier du dossier frontend/src/navigation/, rendant l'écran inaccessible depuis l'UI normale. Décision du porteur : reporté à une nouvelle session, 2.20, positionnée en fin de séquence du chantier, sans dépendance avec les pistes suivantes. |
| Tests DRIVER / ADMIN | ⚠️ Non réalisés | Non abordés dans cette session |
| Test symétrique de la contrainte DB par insertion SQL directe | ➖ Retiré | Décision explicite du porteur de ne pas l'exécuter, pour éviter de polluer la base de données de production avec une ligne de test — jugé non nécessaire puisque le code applicatif transmettant scheduled_pickup_time a été vérifié à trois reprises distinctes (lecture de missionService.ts, lecture de parcelService.ts, vérification du schéma post-migration) |

### Points opérationnels documentés

**État du compte de test partagé (+212600000000)** : actuellement en rôle CLIENT (profil "TEST CLIENT FTM"), suite à la suppression du compte Auth DRIVER effectuée pour les besoins des tests de cette session. Le profil DRIVER (wallet 800 DH, 4 transactions pending) n'a pas été reconstitué — les données restent intactes en base (seul l'accès Auth avait été supprimé), récupérables via un futur onboarding DRIVER + validation admin si nécessaire. Décision de reconstitution laissée à la discrétion du porteur / de la session future qui en aurait besoin.

**Backups créés dans cette session** : .bak.session2.14quater, 4 fichiers (CreateMissionScreen.tsx, missionService.ts, CreateParcelScreen.tsx, parcelService.ts) — conservés tels quels, cohérent avec la politique déjà établie dans le prompt de passation (mécanisme de traçabilité délibéré, ~55 fichiers .bak* déjà présents dans le projet). Aucune action de nettoyage requise.

### Points techniques mineurs consignés pour référence future

- Décalage de fuseau horaire (toISOString() en UTC) dans le formatage web du champ date — limitation héritée du pattern de LegalDocumentsScreen.tsx, non corrigée (hors périmètre de cette session).
- min de <input type="date"> figé à la date du rendu initial du composant, cas limite (formulaire resté ouvert plusieurs heures sans rechargement) non explicitement couvert — rattrapé de toute façon par la validation finale sur new Date().
- Cas limite '' (chaîne vide) vs null avec l'opérateur ?? sur localDateStr/localTimeStr — n'affecte pas le comportement principal recherché, jugé non prioritaire à corriger.
- Comportement hérité display="spinner" (iOS) fermant le picker dès le premier onChange — présent également dans DateField d'origine, non corrigé dans cette session (fichier hors périmètre).
- Divergence documentation/code sur NotificationBell.tsx : le prompt de passation documentait un mécanisme de « polling », alors que le code réel utilise un abonnement Realtime Supabase déclenché par événement, sans setInterval — corrigé Section 3.
- Écart de nommage déjà résolu sur cancelMission(userId, ...) par rapport à ce que documentait le prompt de passation (paramètre _userId non utilisé, signalé comme point de sécurité pour une session 2.17) — le code actuel utilise bien userId nommé sans underscore. ⚠️ Nuance importante : ce renommage de paramètre est un fait de code déjà en place, mais NE RÉSOUT PAS le point de sécurité lui-même — aucune vérification que l'appelant est bien client_id ou driver_id de la mission annulée n'a été ajoutée. Le point de sécurité reste entier et rattaché à la session 2.17 (voir Section 15/17, mise à jour de la recommandation existante).
- Deux points d'enrichissement fonctionnel identifiés mais non traités, car hors du périmètre strict de la dérogation (« ajout et transmission du champ », rien de plus) : le SMS envoyé au destinataire d'un colis (notifyRecipientBySMS) et l'historique client (getClientParcels) pourraient à l'avenir inclure scheduled_pickup_time dans leur contenu/sélection — consigné en Section 17 comme piste future, non assignée.

### État final du dépôt

HEAD : 829f31e, aligné avec origin/main. Aucune modification en attente de commit. Contrainte NOT NULL active en production sur missions.scheduled_pickup_time, vérifiée par lecture directe du schéma.

### Reste à faire (sessions futures)

- Session 2.20 (nouvelle) : corriger l'enregistrement manquant de la route CreateParcel dans la navigation, puis tester le flux e-commerce complet (UI + insertion en base).
- Test complet de soumission de bout en bout (transport classique et e-commerce) sur un environnement disposant d'une géolocalisation fonctionnelle (device physique, Phase 4.x).
- Tests de non-régression DRIVER et ADMIN.
- Décision à prendre sur la reconstitution du profil DRIVER pour le numéro de test partagé.

# CHAÎNE DE NAVIGATION DRIVER

ProfileSetupScreen → onProfileCreated(role='driver') → DriverOnboardingStack
VehicleInfoScreen → createDriverProfile() → navigate('LegalDocuments', { driverId })
LegalDocumentsScreen [reçoit driverId] → saveDriverDocuments() → navigate('DocumentUpload', { driverId })
DocumentUploadScreen [reçoit driverId] → uploadDocument() × 4 → upload dans bucket driver-documents
   ⚠️ limitations web : bouton Photo non disponible, utiliser bouton Fichier uniquement sur web
   → navigate('PendingVerification', { driverId })
PendingVerificationScreen [reçoit driverId] → souscrit realtime driver-verification-{driverId} → si is_verified === true → Platform.OS === 'web' ? window.alert(...) + navigation.replace('DriverHome') : Alert.alert(...) ✅ RÉSOLU 42
   ⚠️ Chemin natif non testé
   ⚠️ Bouton "Recharger mon wallet" SUPPRIMÉ — session 2.13 (RÉSOLU 40)
   ⚠️ navigation.replace('DriverHome') cible toujours un écran absent du stack DriverPendingStack — bug distinct, non traité (voir Section 15)
DriverHomeScreen → attend driverId + vehicleCategory obligatoires → affiche solde wallet (table wallet sans 's') → carte Wallet → WalletDashboard { driverId } → bouton Mes documents → DocumentStatus → ✅ NotificationBell montée — session 2.14 → NotificationBell → NotificationCenterScreen ⚠️ Aucun bouton "← Retour" — Anomalie #1
   ⚠️ ACCÈS ACTUELLEMENT INDISPONIBLE pour le numéro de test partagé (rôle DRIVER supprimé depuis session 2.14 quater) — nécessite un nouvel onboarding pour être re-testé
TransactionHistoryScreen → ✅ Écoute Realtime branchée — session 2.14 (INSERT uniquement)

⚠️ is_verified = GENERATED ALWAYS AS — devient true quand driver_license_verified, vehicle_registration_verified, insurance_verified, technical_inspection_verified = 'verified'

# CHAÎNE DE NAVIGATION ADMIN

AdminDashboardScreen → Documents en attente → DocumentReviewScreen ✅ → Toutes les missions → AdminMissionsScreen ✅ → Gestion utilisateurs → AdminUsersScreen ✅ → Wallets & Transactions → WalletManagementScreen ✅ → ✅ NotificationBell montée — session 2.14 → NotificationBell → NotificationCenterScreen ⚠️ Anomalie #1

DocumentReviewScreen → Valider/Rejeter documents driver → Notification driver via insertNotification() → Driver fully verified → DriverHomeScreen (realtime)
   ⚠️ Bug d'affichage session 2.12 : modal ne se rafraîchit pas visuellement après validation du 4e/dernier document — non traité faute de temps, reporté à une session ultérieure à assigner

WalletManagementScreen → Liste drivers vérifiés avec solde → Recharger wallet → adminTopupDriverWallet() → Solde mis à jour en temps réel ✅
   ⚠️ Ne gère pas encore les 4 demandes de recharge chauffeur en statut pending (voir Section 3) — écran de traitement dédié prévu session 2.17

AdminMissionsScreen → Liste toutes missions avec 6 filtres → Enum : pending / accepted / in_progress / completed / cancelled_client / cancelled_driver

AdminUsersScreen → Liste drivers avec statut actif/suspendu → Suspendre/Activer via toggleUserActive() ⚠️ sans distinction Platform.OS

# CHAÎNE DE NAVIGATION CLIENT

CreateMissionScreen → ✅ NotificationBell montée — session 2.14 → NotificationBell → NotificationCenterScreen ⚠️ Anomalie #1
   ✅ NOUVEAU (session 2.14 quater) — champ scheduled_pickup_time désormais OBLIGATOIRE (composant DateTimeField.tsx), bouton de soumission désactivé tant qu'une date/heure valide n'est pas sélectionnée, date passée rejetée, aucun délai minimum requis
   ⚠️ Volet Client non testé fonctionnellement de bout en bout à ce jour (contrainte GPS/Codespaces) — voir Section 15/16
   ⚠️ Le numéro de test partagé occupe désormais ce rôle ("TEST CLIENT FTM") mais aucune mission n'a été insérée en base

CreateParcelScreen (flux e-commerce) → ⚠️ NOUVEAU BUG DÉCOUVERT (session 2.14 quater) — route 'CreateParcel' non déclarée dans frontend/src/navigation/, écran inaccessible depuis l'UI normale (ParcelHistoryScreen.tsx tente navigation.navigate('CreateParcel') sans effet) — correction assignée à la session 2.20
   ✅ Champ scheduled_pickup_time intégré au titre de la dérogation Bloc 6 (session 2.14 quater) — non testable tant que le bug de navigation n'est pas corrigé

# PROBLÈMES RENCONTRÉS ET RÉSOLUS

[RÉSOLU 1 à 42 — inchangés, repris intégralement à l'identique de la version du 11/08/2026. Voir document source pour le détail complet de chaque entrée.]

RÉSOLU 1 — Page blanche web (session 2.2)
RÉSOLU 2 — Navigation post-profil (session 2.3)
RÉSOLU 3 — Page blanche après packages (2.4)
RÉSOLU 4 — Terminal défaillant (session 2.4)
RÉSOLU 5 — replace() Python3 sans effet
RÉSOLU 6 — driver_license_number NOT NULL
RÉSOLU 7 — Champs légaux NOT NULL (5 champs)
RÉSOLU 8 — Passage spontané étape 2 → étape 4
RÉSOLU 9 — Passage spontané étape 3 → étape 4
RÉSOLU 10 — DateTimePicker non supporté web (LegalDocumentsScreen.tsx)
RÉSOLU 11 — Bucket not found (Storage)
RÉSOLU 12 — RLS Storage bloque upload
RÉSOLU 13 — Token Supabase expiré
RÉSOLU 14 — SIGNED_IN interrompt onboarding étape 3 (BUG 1 session 2.5)
RÉSOLU 15 — GET /wallets → 404 (BUG 2 session 2.5)
RÉSOLU 16 — document_reminders ON CONFLICT → 400 (BUG 3 session 2.5)
RÉSOLU 17 — Écrans wallet non connectés navigation (session 2.6)
RÉSOLU 18 — driverId undefined WalletDashboard (session 2.6)
RÉSOLU 19 — Vue driver_dashboard incomplète SQLSTATE 42P16 (session 2.6)
RÉSOLU 20 — Erreur 403 RLS INSERT transactions (session 2.6)
RÉSOLU 21 — DocumentStatusScreen non accessible (session 2.6)
RÉSOLU 22 — BUG 4 SQL UPDATE phone_number → 0 row — INFIRMÉ (session 2.7)
RÉSOLU 23 — BUG A wallet_update_admin récursion RLS (session 2.7)
RÉSOLU 24 — Navigation admin 4 menus silencieuse (session 2.7)
RÉSOLU 25 — SIGNED_IN loop admin (session 2.7)
RÉSOLU 26 — 403 Forbidden notifications (session 2.7)
RÉSOLU 27 — Enum mission_status incorrect (session 2.7)
RÉSOLU 28 — Création fichier long via Python (session 2.7)
RÉSOLU 29 — Bug "Suspendre" AdminUsersScreen non fonctionnel sur web (session 2.8)
RÉSOLU 30 — Bucket voice-messages + RLS (session 2.8) — ⚠️ RLS reclassifiée priorité sécurité session 2.14 bis, DÉSORMAIS CORRIGÉE, voir RÉSOLU 46
RÉSOLU 31 — Cause GPS AdminMissions confirmée (session 2.8)
RÉSOLU 32 — vault.create_secret() arguments inversés
RÉSOLU 33 — net.http_post → 401 persistant
RÉSOLU 34 — pg_cron non activé au démarrage
RÉSOLU 35 — Realtime inactif sur tables FTM (session 2.10)
RÉSOLU 36 — RLS Storage permissif driver-documents (session 2.12)
RÉSOLU 37 — RLS transactions_insert_own sans restriction (session 2.12)
RÉSOLU 38 — Échec silencieux topupWallet() côté chauffeur — fausse recharge (session 2.13)
RÉSOLU 39 — revenue_current_month : nommage trompeur (session 2.13)
RÉSOLU 40 — Bouton navigation cassé PendingVerificationScreen.tsx (session 2.13)
RÉSOLU 41 — Message de succès invisible sur web, WalletTopupScreen.tsx ligne 70 (session 2.13)
RÉSOLU 42 — Alerte Realtime de validation non observée, PendingVerificationScreen.tsx (session 2.14)

Aucun RÉSOLU supplémentaire — session 2.14 bis (session sans implémentation)

**RÉSOLU 43 — RLS permissive bucket voice-messages (session 2.14 ter)**
Cause : les 4 policies storage.objects (authenticated_{read,upload,update,delete}_voice_messages) ne vérifiaient que bucket_id = 'voice-messages', sans aucune clause de propriété — tout utilisateur authentifié pouvait lire/écrire/modifier/supprimer n'importe quel fichier audio de n'importe quelle mission. Faille identifiée dès session 2.12 (exclue du périmètre à l'époque), reclassifiée priorité sécurité active en session 2.14 bis.
Correctif : chaîne de propriété double (client + chauffeur de la mission via UNION), sur le pattern driver-documents (RÉSOLU 36) adapté : storage.foldername(name)[2]::uuid (convention à 2 segments missions/{missionId}/...) IN (missions dont le client OU le chauffeur assigné correspond à auth.uid() via profiles). Accès admin explicitement exclu (décision porteur).
Fichier : supabase/migrations/20260504000015_fix_rls_voice_messages.sql
Commit : 9c36d84
Confirmé : 4/4 policies actives en base par lecture directe post-déploiement ✅
⚠️ Test fonctionnel en conditions réelles reporté à la Phase 4.4 / session 2.18 (décision motivée, contrainte numéro de test partagé)

**RÉSOLU 44 — Absence de support web de DateTimeField.tsx (session 2.14 quater)**
Cause : @react-native-community/datetimepicker est une bibliothèque strictement native (iOS/Android/Windows), sans aucun support web — confirmé par documentation officielle. Le composant DateTimeField.tsx nouvellement créé plantait donc intégralement sur web.
Correctif : ajout d'une branche Platform.OS === 'web' avec <input type="date">/<input type="time"> HTML natif, inspirée du repli déjà existant dans LegalDocumentsScreen.tsx (RÉSOLU 10).
Fichier : frontend/src/components/DateTimeField.tsx
Commit : 829f31e
Confirmé : validé empiriquement par instrumentation temporaire [FTM-DEBUG-TEMP], retirée après confirmation ✅

**RÉSOLU 45 — Re-rendu en boucle corrompant la saisie clavier, DateTimeField.tsx (session 2.14 quater)**
Cause : composant non mémoïsé, re-rendu en boucle corrompant la saisie clavier (ex. année transformée en 0002 durant la frappe).
Correctif : React.memo appliqué sur l'export du composant.
Fichier : frontend/src/components/DateTimeField.tsx
Commit : 829f31e
Confirmé : validé empiriquement par instrumentation temporaire, retirée après confirmation ✅

**RÉSOLU 46 — Validation prématurée à la frappe, DateTimeField.tsx (session 2.14 quater)**
Cause : le navigateur déclenche onChange sur <input type="date"> dès qu'une valeur techniquement complète est formée, avant la fin de la saisie de l'utilisateur — comportement standard HTML confirmé par recherche, provoquant une validation prématurée à chaque segment de frappe.
Correctif : séparation onChange (mise à jour d'un état local, sans validation) / onBlur (validation finale via applyCombined).
Fichier : frontend/src/components/DateTimeField.tsx
Commit : 829f31e
Confirmé : validé empiriquement par instrumentation temporaire, retirée après confirmation ✅

**RÉSOLU 47 — scheduled_pickup_time absent de tout point de création de mission (session 2.14 quater)**
Cause : le champ scheduled_pickup_time n'était jamais collecté ni transmis, ni dans le flux transport classique (CreateMissionScreen.tsx/missionService.ts) ni dans le flux e-commerce (CreateParcelScreen.tsx/parcelService.ts, découverte de dépendance commune à createMission()).
Correctif : Option B retenue par le porteur — contrainte NOT NULL en base (migration dédiée) en complément de la validation UI (nouveau composant DateTimeField.tsx), sur les deux flux.
Fichiers : frontend/src/components/DateTimeField.tsx (nouveau), CreateMissionScreen.tsx, missionService.ts, CreateParcelScreen.tsx, parcelService.ts
Migration : supabase/migrations/20260504000016_add_scheduled_pickup_time_not_null.sql
Commit : 0da3e07
Confirmé : is_nullable = NO vérifié par lecture directe du schéma réel (information_schema.columns) ✅

⚠️ Note de numérotation : RÉSOLU 43 (RLS voice-messages) précède chronologiquement RÉSOLU 44-47 (session 2.14 quater), lesquelles suivent l'ordre interne code → 3 bugs web → contrainte NOT NULL, correspondant à l'ordre de découverte réel au sein de la session 2.14 quater (la contrainte NOT NULL et le composant DateTimeField ont été introduits ensemble dans le commit 0da3e07, les 3 bugs web ont été découverts et corrigés ensuite dans le commit 829f31e).

# PISTES DÉFINITIVEMENT ÉCARTÉES

Ne pas retester : ❌ locationService import statique ❌ expo-haptics / expo-notifications ❌ expo-location fallback web ❌ missionService / realtimeService ❌ react-native-screens sans fallback web ❌ NativeStackScreenProps sans type ❌ Dépendance circulaire missionService ❌ audioService / expo-av (contexte débogage page blanche — n'implique pas l'abandon de la fonctionnalité messages vocaux) ❌ supabaseClient.ts ❌ showAuth logique incorrecte ❌ ErrorBoundary capture l'erreur ❌ --no-dev résout seul ❌ 'cancelled' comme valeur enum mission_status ❌ cron.run_job(integer) ❌ owner = auth.uid() comme clause RLS Storage simple (raccourci écarté au profit de la chaîne de propriété complète, RÉSOLU 36) ❌ Modification directe du solde wallet par le chauffeur (Option B écartée, session 2.13, RÉSOLU 38) ❌ python3 -c "..." en ligne directe pour tout texte contenant un caractère spécial bash (écarté au profit du heredoc quoté, session 2.14) ❌ notifyNewMission comme fonction notify* branchable isolément (incompatibilité structurelle confirmée, session 2.14, reconfirmée 2.14 bis) ❌ Correction d'initializeApp() pour distribuer systématiquement profiles.id (écartée au profit de getCurrentProfileId(), session 2.14) ❌ Remplacement du canal vocal (VoiceChatScreen.tsx) par un canal texte (décision de conservation actée session 2.14 bis)
❌ Accès admin dans la clause RLS voice-messages (session 2.14 ter) — écarté par le porteur : aucun besoin métier documenté ne justifie qu'un admin lise du contenu audio privé
❌ Factorisation SQL des 4 policies voice-messages via fonction partagée (session 2.14 ter) — écartée au profit de la duplication littérale, fidèle au pattern RÉSOLU 36
❌ Test symétrique de la contrainte scheduled_pickup_time NOT NULL par insertion SQL directe (session 2.14 quater) — décision explicite du porteur, pour éviter de polluer la base de production ; jugé non nécessaire, le code applicatif ayant été vérifié à trois reprises distinctes
❌ Modification de LegalDocumentsScreen.tsx ou import direct par DateTimeField.tsx (session 2.14 quater) — hors périmètre, aucune dérogation accordée ; composant dupliqué et réécrit indépendamment

# MIGRATIONS SUPABASE DÉPLOYÉES

20260220155500_initial_schema.sql ✅ P1-P2
20260221000000_add_rpc_nearby_drivers.sql ✅ P3
20260222000000_add_tracking_functions.sql ✅ P4
20260223000000_add_push_tokens.sql ✅ P6
20260224000000_add_rls_policies.sql ✅ P7
20260226000000_fix_profiles_rls_recursion.sql ✅ Phase 2.1
20260429000001_allow_null_driver_license_number.sql ✅ Session 2.4
20260429000002_allow_null_legal_docs_fields.sql ✅ Session 2.4
20260504000001_create_driver_documents_bucket.sql ✅ Session 2.4
20260504000002_storage_rls_policies.sql ✅ Session 2.4
20260504000003_add_unique_constraint_document_reminders.sql ✅ Session 2.5
20260504000004_update_driver_dashboard_view.sql ✅ Session 2.6
20260504000005_add_transactions_insert_policy.sql ✅ Session 2.6
20260504000006_fix_wallet_update_admin_rls.sql ✅ Session 2.7
20260504000007_fix_notifications_insert_rls.sql ✅ Session 2.7
20260504000008_fix_notifications_select_admin.sql ✅ Session 2.7
20260504000009_create_voice_messages_bucket.sql ✅ Session 2.8
20260504000010_voice_messages_storage_rls_policies.sql ✅ Session 2.8
20260504000011_configure_cron_document_reminders.sql ✅ Session 2.9
20260504000012_enable_realtime_tables.sql ✅ Session 2.10
20260504000013_fix_storage_transactions_rls_ownership.sql ✅ Session 2.12
20260504000014_rename_revenue_to_recharges_driver_dashboard.sql ✅ Session 2.13
20260504000015_fix_rls_voice_messages.sql ✅ Session 2.14 ter
20260504000016_add_scheduled_pickup_time_not_null.sql ✅ Session 2.14 quater

Aucune migration SQL déployée en session 2.14 (session applicative/service) ni en session 2.14 bis (session investigative).

Prochain timestamp disponible : 20260504000017

Note prospective : la migration mission_offers (session 2.14 sexies proposée) consommera ce timestamp et les suivants.

# EDGE FUNCTIONS DÉPLOYÉES

send-push-notification ✅ (CORS bloqué sur web — fonctionnel sur device)
register-push-token ✅
check-document-reminders ✅ (CRON opérationnel — session 2.9, 5 exécutions succeeded 18→22/06/2026)
   ⚠️ Lien avec notifyDocumentExpiry non vérifié — non traité en 2.14 bis, 2.14 ter, ni 2.14 quater (hors périmètre de chacune)
send-tracking-sms ✅

# ARBORESCENCE COMPLÈTE DU REPO

```
FAST-TRANS-MAROC-FTM/
├── .github/
│   └── workflows/
│       ├── check_supabase.yml ← INTOUCHABLE
│       ├── deploy_supabase.yml ← INTOUCHABLE
│       └── lint_code.yml ← INTOUCHABLE
├── docs/
│   ├── SPEC_NATIVELY_P1.md … P7.md
├── frontend/
│   ├── .env / .env.example
│   ├── App.tsx
│   ├── package.json ← expo-image-picker ajouté
│   ├── package-lock.json
│   ├── tsconfig.json
│   └── src/
│       ├── components/
│       │   ├── NotificationBell.tsx ← modifié session 2.14
│       │   ├── DateTimeField.tsx ← NOUVEAU, créé session 2.14 quater (commits 0da3e07 + 829f31e)
│       │   └── VoiceMicButton.tsx ← lu intégralement session 2.14 bis, aucune modification
│       ├── constants/theme.ts ← BORDER_RADIUS ajouté
│       ├── lib/supabaseClient.ts
│       ├── navigation/
│       │   └── RootNavigator.tsx ← modifié session 2.14 ; ⚠️ ne déclare TOUJOURS PAS la route 'CreateParcel' (bug découvert session 2.14 quater, assigné session 2.20)
│       ├── screens/
│       │   ├── admin/
│       │   │   ├── AdminDashboardScreen.tsx ← modifié session 2.14
│       │   │   ├── AdminMissionsScreen.tsx ← créé session 2.7
│       │   │   ├── AdminUsersScreen.tsx ← créé session 2.7
│       │   │   ├── DocumentReviewScreen.tsx
│       │   │   └── WalletManagementScreen.tsx
│       │   ├── auth/
│       │   │   ├── OTPVerificationScreen.tsx
│       │   │   ├── PhoneInputScreen.tsx
│       │   │   └── ProfileSetupScreen.tsx ← INTOUCHABLE
│       │   ├── client/
│       │   │   ├── CreateMissionScreen.tsx ← modifié sessions 2.14 + 2.14 quater (scheduled_pickup_time obligatoire, DateTimeField)
│       │   │   ├── MissionTrackingScreen.tsx
│       │   │   └── RatingScreen.tsx
│       │   ├── driver/
│       │   │   ├── DocumentStatusScreen.tsx
│       │   │   ├── DriverHomeScreen.tsx ← modifié session 2.14
│       │   │   ├── MissionActiveScreen.tsx
│       │   │   ├── NewMissionModal.tsx ← lu intégralement session 2.14 bis
│       │   │   ├── ParcelMissionDetailScreen.tsx
│       │   │   ├── TransactionDetailModal.tsx
│       │   │   ├── TransactionHistoryScreen.tsx ← modifié session 2.14
│       │   │   ├── WalletDashboardScreen.tsx ← modifié session 2.13
│       │   │   ├── WalletTopupScreen.tsx ← modifié session 2.13
│       │   │   └── onboarding/
│       │   │       ├── DocumentUploadScreen.tsx
│       │   │       ├── LegalDocumentsScreen.tsx ← lu intégralement (2 extraits, gap identifié) session 2.14 quater — RÉFÉRENCE pour DateTimeField, non modifié
│       │   │       ├── PendingVerificationScreen.tsx ← modifié sessions 2.13 + 2.14
│       │   │       └── VehicleInfoScreen.tsx
│       │   ├── ecommerce/
│       │   │   ├── CreateParcelScreen.tsx ← modifié session 2.14 quater (scheduled_pickup_time) ; ⚠️ inaccessible via navigation (bug, session 2.20)
│       │   │   ├── ParcelConfirmationScreen.tsx
│       │   │   └── ParcelHistoryScreen.tsx ← appelle navigation.navigate('CreateParcel'), sans effet (route non déclarée)
│       │   ├── mission/
│       │   │   └── VoiceChatScreen.tsx ← confirmé orphelin session 2.14 ; canal conservé, activation planifiée session 2.14 septies
│       │   ├── notifications/
│       │   │   └── NotificationCenterScreen.tsx ← modifié session 2.14
│       │   └── tracking/
│       │       ├── TrackingDetailScreen.tsx
│       │       └── TrackingInputScreen.tsx
│       ├── services/
│       │   ├── adminService.ts
│       │   ├── audioService.ts ← CONFIRMÉ fichier réel du canal vocal (écart de documentation corrigé, session 2.14 ter) ; lu intégralement, non modifié
│       │   ├── authService.ts ← INTOUCHABLE
│       │   ├── documentService.ts
│       │   ├── driverService.ts ← STABLE INTOUCHABLE
│       │   ├── i18nService.ts
│       │   ├── locationService.ts
│       │   ├── missionService.ts ← modifié sessions 2.14 + 2.14 quater (scheduled_pickup_time)
│       │   ├── notificationTemplates.ts
│       │   ├── parcelService.ts ← modifié session 2.14 quater (scheduled_pickup_time)
│       │   ├── pushNotificationService.ts ← modifié session 2.14
│       │   ├── realtimeService.ts ← lu session 2.14 bis, aucune modification
│       │   ├── reminderService.ts
│       │   └── walletService.ts ← modifié session 2.13
│       ├── types/database.ts
│       └── utils/parcelCalculations.ts
├── supabase/
│   ├── config.toml
│   ├── functions/
│   │   ├── check-document-reminders/
│   │   ├── register-push-token/
│   │   ├── send-push-notification/
│   │   └── send-tracking-sms/
│   ├── migrations/
│   │   ├── 20260220155500_initial_schema.sql
│   │   ├── 20260221000000_add_rpc_nearby_drivers.sql ← RPC find_nearby_drivers, code mort confirmé session 2.14 bis
│   │   ├── … (fichiers intermédiaires inchangés) …
│   │   ├── 20260504000013_fix_storage_transactions_rls_ownership.sql ← session 2.12
│   │   ├── 20260504000014_rename_revenue_to_recharges_driver_dashboard.sql ← session 2.13
│   │   ├── 20260504000015_fix_rls_voice_messages.sql ← session 2.14 ter
│   │   └── 20260504000016_add_scheduled_pickup_time_not_null.sql ← session 2.14 quater
│   └── rollbacks/
│       ├── rollback_20260504000013.sql ← session 2.12
│       ├── 20260504000014_rename_revenue_to_recharges_driver_dashboard_rollback.sql ← session 2.13
│       ├── 20260504000015_fix_rls_voice_messages_rollback.sql ← session 2.14 ter
│       └── 20260504000016_add_scheduled_pickup_time_not_null_rollback.sql ← session 2.14 quater
├── .env.example
├── .gitignore
├── ROADMAP_FTM.md
└── install_*.sh
```

Note : ~55+ fichiers untracked de type .bak* présents dans le dépôt (mécanisme de traçabilité délibéré), dont 4 nouveaux ajoutés en session 2.14 quater (suffixe .bak.session2.14quater) — non représentés dans l'arborescence ci-dessus par souci de lisibilité.

# SERVICES EXTERNES — ÉTAT

Twilio SMS : ⏳ pas encore configuré
FCM Android : ⏳ pas encore configuré
   ⚠️ send-push-notification bloquée par CORS sur web — fonctionnel sur device physique uniquement
   ⚠️ Dépendance croisée confirmée session 2.14 : les 4 fonctions notify* mission appellent dispatchPushNotification() → push mobile réel non pleinement opérationnel tant que FCM/APNs non configurés
APNs iOS : ⏳ pas encore configuré

Storage buckets :
   ✅ driver-documents créé — ✅ RLS ownership chain — session 2.12
   ✅ voice-messages créé — session 2.8
   ✅ RLS ownership CORRIGÉE — session 2.14 ter (RÉSOLU 46) — double chaîne client + chauffeur, indice [2]
   ⚠️ voice-messages non testé fonctionnellement (audioService.ts non intégré UI côté screen — canal orphelin) — test complet reporté Phase 4.4 / session 2.18

CRON reminders : ✅ OPÉRATIONNEL — session 2.9 — 5 exécutions succeeded 18→22/06/2026
   ⚠️ Lien avec notifyDocumentExpiry non vérifié

Wallet topup : ✅ Mécanisme honnête opérationnel — session 2.13 — reconfirmé intact (données) après sessions 2.14, 2.14 bis, 2.14 ter ; accès Auth du profil porteur supprimé en session 2.14 quater (voir Section 3), données inchangées

Realtime transactions/notifications : ✅ subscribeToNewTransactions branché — session 2.14 (INSERT uniquement) — ✅ NotificationBell/Center montés 3 rôles — mécanisme confirmé Realtime événementiel (pas polling, précision session 2.14 quater)
   ⚠️ Anomalie #1 : bouton retour manquant sur NotificationCenterScreen

Géolocalisation avancée : 🔵 Infrastructure PostGIS complète (RPC find_nearby_drivers) confirmée existante et active mais non exploitée — réutilisation prévue session 2.14 quinquies (dépendance envers 2.14 quater désormais levée pour le Volet 2)

Planification par date/heure : ✅ OPÉRATIONNELLE — session 2.14 quater — scheduled_pickup_time obligatoire (NOT NULL + UI), transport classique et e-commerce
   ⚠️ Flux e-commerce non testable en pratique tant que le bug de navigation CreateParcel n'est pas corrigé (session 2.20)

# BUGS RÉSIDUELS

⚠️ CORS send-push-notification Edge Function bloquée par CORS policy sur web — non bloquant web, fonctionnel sur device physique — à corriger pour production

⚠️ Filtres AdminMissionsScreen — affichés mais aucune mission en base — cause confirmée (GPS bloqué environnement web/Codespaces) — reporté phase 4.x

⚠️ Realtime driver end-to-end — flux avec 2 fenêtres simultanées non testé explicitement

⚠️ AdminMissions pagination — non testée (0 missions en base)

⚠️ DocumentReviewScreen.tsx — rafraîchissement modal (session 2.12) — non traité faute de temps, reporté à une session ultérieure à assigner

⚠️ Driver test historique (données intactes, accès Auth supprimé) — voir Section 3 pour l'état complet :
   driverId : 2ec2b439-fcdb-443d-8de0-5bee268d30f6 (données en base uniquement, aucun accès Auth actif depuis session 2.14 quater)
   wallet_balance réel : 800.00 DH — 4 demandes en pending (50/200/500/1000 DH) — à ne pas altérer sans décision explicite (preuve de fonctionnement du correctif RÉSOLU 38)

⚠️ Dossiers Storage orphelins (session 2.12) — driver-documents : 8 orphelins + 1 actif — aucune session de nettoyage planifiée

⚠️ COMPORTEMENT NON EXPLIQUÉ — repr() vs terminal (session 2.9) — statut INCONNU, non bloquant

⚠️ Navigation cross-stack PendingVerification → DriverHome — navigation.replace('DriverHome') cible un écran absent du stack DriverPendingStack — NON traité à ce jour (2.13, 2.14, 2.14 bis, 2.14 ter, 2.14 quater) — bug entier, session à assigner

⚠️ subscribeToNewTransactions — limitation résiduelle : écoute INSERT uniquement, pas UPDATE

⚠️ AdminUsersScreen.tsx — Alert.alert sans Platform.OS — candidat audit session 2.19

⚠️ WalletTopupScreen.tsx ligne 66 — message d'erreur non vérifié — candidat audit session 2.19

⚠️ Coexistence total_commissions / commissions_current_month — à surveiller lors du chantier reporting financier (Section 17)

⚠️ Risque de pagination totalCredit/totalDebit (TransactionHistoryScreen.tsx) — à surveiller lors du chantier reporting financier (Section 17)

⚠️ Anomalie #1 — Absence de bouton "← Retour" sur NotificationCenterScreen.tsx — non bloquant, à corriger avant Phase 3, candidat audit session 2.19

⚠️ 4 fonctions notify* mission non testées fonctionnellement — nécessite un second numéro de test dédié au rôle client (voir Section 17). Point réactualisé session 2.14 quater : même en disposant désormais d'un profil CLIENT sur le numéro partagé, le test de bout en bout reste bloqué par l'absence de GPS fonctionnel en environnement Codespaces — la contrainte n'est donc plus uniquement le numéro partagé mais aussi l'environnement de test.

⚠️ Cloche NotificationBell côté Client non testée en conditions réelles — reportée avec le test du Volet 4

⚠️ Chemin natif (hors web) non testé — Alert.alert/Platform.OS (RÉSOLU 42) — à vérifier Phase 4

⚠️ Point de sécurité cancelMission/userId — le renommage de paramètre (_userId → userId) est confirmé effectif dans le code (vérifié par lecture directe, session 2.14 quater), mais AUCUNE vérification d'autorisation n'a été ajoutée — le point de sécurité de fond reste entier, rattaché à la session 2.17 (décision actée session 2.14, reconfirmée pertinente session 2.14 quater)

⚠️ notifyDocumentExpiry — en attente, lien check-document-reminders non vérifié — non traité en 2.14 bis, 2.14 ter, ni 2.14 quater

⚠️ Bug de reconnexion clientProfileId vide (RootNavigator.tsx) — découverte annexe session 2.14, hors périmètre, session future non assignée

⚠️ Robustesse topupWallet/refundWallet (échec silencieux insertion transaction) — découverte annexe session 2.14, à vérifier lecture directe début session 2.17

⚠️ VoiceChatScreen.tsx orphelin + dossier ecommerce/ (approfondi 2.14 bis) — canal conservé, activation planifiée session 2.14 septies ; dossier ecommerce/ désormais partiellement exploré (session 2.14 quater : CreateParcelScreen.tsx et parcelService.ts modifiés pour scheduled_pickup_time, bug de navigation découvert), reste non exploré en profondeur au-delà de ce périmètre strict

🔵 Points ouverts non tranchés (Piste 2, négociation de prix, session 2.14 bis) : devenir sémantique de negotiated_price ; extension éventuelle au flux ecommerce_parcels — décisions renvoyées à la session 2.14 sexies

⚠️ Countdown par tour non contraignant sans vérification serveur (Piste 2, session 2.14 bis) — point de conception à traiter en session 2.14 sexies

**⚠️ NOUVEAU (session 2.14 ter) — Correction de cohérence documentaire, décompte transactions pending** : le présent document mentionnait auparavant "3 demandes de recharge en pending (200/500/1000 DH)" pour le driver test 2ec2b439-... — décompte corrigé en 4 demandes (50/200/500/1000 DH), confirmé par lecture directe des dates de création. La transaction de 50 DH (14/07/2026) est une donnée de test antérieure à la session 2.12, non anormale. Cette correction a été répercutée dans toutes les sections concernées du présent document (Section 3, Section 6).

**⚠️ NOUVEAU (session 2.14 quater) — Route de navigation CreateParcel manquante** : la route 'CreateParcel', appelée par ParcelHistoryScreen.tsx (navigation.navigate('CreateParcel')), n'est déclarée dans aucun fichier de frontend/src/navigation/ — l'écran CreateParcelScreen.tsx (pourtant modifié cette même session pour intégrer scheduled_pickup_time) reste inaccessible depuis l'UI normale. Bug préexistant, sans rapport avec la session 2.14 quater. Assigné à la nouvelle **session 2.20**.

**⚠️ NOUVEAU (session 2.14 quater) — Points d'enrichissement fonctionnel non traités liés à scheduled_pickup_time** : notifyRecipientBySMS (SMS destinataire colis) et getClientParcels (historique client) pourraient à l'avenir inclure scheduled_pickup_time dans leur contenu/sélection — hors périmètre strict de la dérogation accordée en session 2.14 quater, consigné pour référence future, aucune session assignée à ce stade.

**⚠️ NOUVEAU (session 2.14 quater) — Points techniques mineurs DateTimeField.tsx** : décalage de fuseau horaire (toISOString() en UTC, hérité de LegalDocumentsScreen.tsx) ; borne min de <input type="date"> figée au rendu initial (cas limite formulaire ouvert plusieurs heures) ; cas limite '' vs null sur localDateStr/localTimeStr ; comportement iOS display="spinner" fermant le picker au premier onChange (hérité de DateField d'origine). Aucun jugé bloquant ni prioritaire, consignés pour référence future.

# TESTS DE NON-RÉGRESSION

[Sessions 2.7 à 2.14 bis — inchangées, reprises intégralement à l'identique de la version du 11/08/2026. Voir document source. Ajout des sessions 2.14 ter et 2.14 quater ci-dessous.]

EFFECTUÉS ET CONFIRMÉS ✅ — SESSIONS 2.7 à 2.14 : [contenu inchangé, voir historique complet ci-dessus dans les blocs "Modifications commitées"]

SESSION 2.14 bis — AUCUN TEST : session strictement investigative.

**SESSION 2.14 ter — TEST NON APPLICABLE AU SENS CLASSIQUE :** aucune modification de code applicatif — vérification par lecture directe de l'état des policies RLS en base (4/4 actives, confirmées) plutôt que par test fonctionnel DRIVER/ADMIN/CLIENT. Test fonctionnel du canal voice-messages en conditions réelles explicitement reporté à la Phase 4.4/session 2.18 (décision motivée, voir Section 6). Comptes de test (driver 2ec2b439-..., admin +212600000001) vérifiés intacts par lecture directe.

**SESSION 2.14 quater — TESTS EFFECTUÉS ET CONFIRMÉS ✅ :**
- Validation UI — bouton désactivé sans date sélectionnée (CreateMissionScreen.tsx) ✅
- Rejet d'une date passée — message d'erreur affiché, logs confirmant le rejet sans corruption de l'affichage ✅
- Acceptation d'une date future — testé avec succès (25/08/2026, 16:25) ✅
- Règle « aucun délai minimum requis » — testé le 20/08/2026, date du jour + heure proche (~30-40 min d'écart), acceptée sans erreur ✅
- Vérification qu'aucun fichier tiers n'importe DateTimeField — grep confirmant exactement 3 fichiers ✅
- Contrainte NOT NULL active en production — vérifiée par lecture directe du schéma (information_schema.columns), is_nullable = NO ✅

**SESSION 2.14 quater — TESTS NON EFFECTUÉS (justifiés) :**
- Soumission complète du flux transport jusqu'à l'insertion en base — bloqué par absence de GPS fonctionnel (Codespaces/iframe), table missions confirmée vide (0 ligne) à l'issue de la session
- Flux e-commerce (CreateParcelScreen.tsx) — bloqué par le bug de navigation CreateParcel découvert (sans rapport avec cette session) — assigné session 2.20
- Tests DRIVER / ADMIN — non abordés dans cette session
- Test symétrique de la contrainte DB par insertion SQL directe — retiré explicitement par décision du porteur (anti-pollution production)

# ÉTAPES RESTANTES

PHASE 2 — TESTS & DEBUGGING
2.1 à 2.11 ✅ COMPLET [inchangé, voir détail Section 6]
2.12 ✅ COMPLET — RLS Storage (driver-documents) + transactions_insert_own
2.13 ✅ COMPLET — Cause racine RLS wallet + recharge honnête + correction nommage + navigation
2.14 ✅ COMPLET (avec réserves) — Realtime + Notification Center + notify mission
2.14 bis ✅ COMPLET — Investigation/planification processus de mission
2.14 ter ✅ COMPLET — Correction sécurité RLS voice-messages
   → Migration 20260504000015 déployée ✅ (commit 9c36d84) — RÉSOLU 43
   → 4/4 policies actives confirmées en base ✅
   → 2 incidents documentés et résolus (DROP hors circuit, échec réseau transitoire) sans impact final
   → Écart de documentation corrigé : audioService.ts est le fichier réel du canal vocal
   → Correction de cohérence : décompte transactions pending driver test 3 → 4
   → Test fonctionnel reporté Phase 4.4 / session 2.18 (décision motivée)
   → Non-régression : N/A (session RLS pure), comptes de test vérifiés intacts ✅

2.14 quater ✅ COMPLET (avec réserves) — Piste 3, planification par date/heure
   → Arbitrage Option B tranché : contrainte NOT NULL + validation UI ✅
   → Composant DateTimeField.tsx créé, intégré aux flux transport ET e-commerce (dérogation actée) ✅
   → Migration 20260504000016 déployée ✅ (commit 0da3e07) — RÉSOLU 47
   → 3 bugs web découverts et corrigés (commit 829f31e) — RÉSOLU 44/45/46
   → Gap d'investigation identifié et corrigé en règle méthodologique (Section 2)
   → 5 tests validés (UI, dates passées/futures, délai minimum, imports) ✅
   → ⚠️ Soumission complète transport et flux e-commerce NON testés (GPS, bug navigation CreateParcel)
   → ⚠️ Tests DRIVER/ADMIN non réalisés
   → Rotation du numéro de test partagé : DRIVER → CLIENT ("TEST CLIENT FTM"), profil DRIVER historique orphelin d'accès Auth mais données intactes
   → Nouveau bug découvert : route CreateParcel manquante → session 2.20 créée
   → Dépendance 2.14 quinquies (Volet 2) envers 2.14 quater : LEVÉE

2.14 quinquies ⏳ Piste 1 — Diffusion optimisée (priorité 2, dépendance envers 2.14 quater désormais levée)
   → Branchement RPC find_nearby_drivers, catégorie VUL, rayon 60 km depuis pickup_location
   → Vérification préalable du contenu de la vue available_drivers
   → Expiration Volet 1 (indépendant) + Volet 2 (débloqué)

2.14 sexies ⏳ Piste 2 — Négociation de prix structurée (session la plus lourde)
   → Nouvelle table mission_offers, RLS sur pattern transactions_select_own/notifications_select_own (référence désormais éprouvée via voice-messages, session 2.14 ter)
   → Refonte du verrou de concurrence — conception prioritaire avant code
   → Décisions à trancher : devenir sémantique de negotiated_price, extension e-commerce

2.14 septies ⏳ Piste 4 — Activation du canal vocal sécurisé (dépendance stricte double : 2.14 quater ET 2.14 sexies)
   → RLS déjà déployée depuis 2.14 ter — reste : logique de contrôle d'accès VoiceMicButton.tsx, montage du canal, notification de message reçu, avertissement anti-partage de coordonnées
   → Ne peut démarrer qu'après livraison effective de 2.14 sexies (2.14 quater désormais livrée)

**2.20 ⏳ NOUVELLE SESSION — Correction route CreateParcel + test flux e-commerce complet**
   → Déclarer la route 'CreateParcel' dans frontend/src/navigation/ (bug découvert session 2.14 quater, sans rapport avec elle)
   → Tester le flux e-commerce complet (UI + insertion en base) une fois l'écran accessible
   → Positionnée en fin de séquence du chantier processus de mission, sans dépendance avec les pistes 2.14 quinquies/sexies/septies

PHASE 3 — SERVICES EXTERNES
3.1 ⏳ Twilio SMS / 3.2 ⏳ FCM Android / 3.3 ⏳ APNs iOS

PHASE 4 — TESTS DEVICE PHYSIQUE
4.1 ⏳ Tests Expo Go Android / 4.2 ⏳ Tests Expo Go iOS
4.3 ⏳ Tests utilisateurs réels — inclut désormais : chemin natif Alert.alert() (RÉSOLU 42), test complet Volet 4 (4 notify* mission) + cloche Client, ET (nouveau) soumission complète du flux transport avec scheduled_pickup_time (bloquée par GPS en environnement Codespaces)
4.4 ⏳ Intégrer messages vocaux dans MissionTrackingScreen (audioService.ts + bucket voice-messages prêts, RLS désormais sécurisée depuis 2.14 ter) — UI à construire — inclut le test fonctionnel complet de la clause RLS voice-messages en conditions réelles (report actée session 2.14 ter)

PHASE 5 — BUILD EAS
5.1 à 5.3 ⏳ — Environnement de staging à évaluer avant cette phase (proposé session 2.13), non déclenché

PHASE 6 — AMÉLIORATIONS POST-TESTS
6.1 à 6.5 ⏳/✅ [statuts inchangés, voir Section 6]
6.6 ✅/✅ SÉCURITÉ — RLS Storage : driver-documents ✅ (2.12), voice-messages ✅ CORRIGÉE (2.14 ter) — reste test fonctionnel Phase 4.4

PHASE 7 — PUBLICATION
7.1 ⏳ Google Play Store / 7.2 ⏳ Apple App Store

# RECOMMANDATIONS STRATÉGIQUES EN ATTENTE D'ARBITRAGE PORTEUR

(issues des sessions 2.13, 2.14, 2.14 bis, 2.14 ter et 2.14 quater, non déclenchées dans l'immédiat)

✅ RÉSOLUE — Correction de sécurité RLS voice-messages : traitée en session 2.14 ter (RÉSOLU 43). Reste seulement le test fonctionnel en Phase 4.4/session 2.18.
Audit systématique Alert.alert() — tous les usages du projet — idéalement session 2.19, avant Phase 3 active. Portée élargie : chemin natif non testé pour 3 fichiers déjà corrigés.
Environnement de staging — à évaluer avant Phase 5 (Build EAS) — décision et calendrier à trancher par le porteur.
Refonte du reporting financier — trois mécanismes de calcul non harmonisés — étude de faisabilité à programmer, hors périmètre 2.13.
Notification admin en temps réel sur nouvelle demande de recharge — renvoyée à la session 2.17.
Second numéro de test dédié au rôle client — nécessaire pour le test complet du Volet 4 et de la cloche côté client. Point réactualisé session 2.14 quater : même avec un profil CLIENT désormais actif sur le numéro partagé, le test de bout en bout reste bloqué par l'environnement (GPS Codespaces) — la recommandation reste donc pertinente mais n'est plus suffisante à elle seule.
Anomalie #1 — bouton "← Retour" manquant NotificationCenterScreen.tsx — non bloquante, rattachement session 2.19 ou point autonome, décision du porteur.
notifyDocumentExpiry — lien check-document-reminders non vérifié — à statuer isolément, session future.
Bug de reconnexion clientProfileId vide (RootNavigator.tsx) — à documenter, session future non assignée.
Robustesse topupWallet/refundWallet — à vérifier par lecture directe en tout début de session 2.17.
subscribeToDriverLocation (realtimeService.ts) — suivi de position en temps réel, non exploité, aucune session dédiée proposée à ce stade.
**NOUVELLE (session 2.14 quater) — Décision sur la reconstitution du profil DRIVER historique** (2ec2b439-..., wallet 800 DH, 4 transactions pending) pour le numéro de test partagé, actuellement orphelin d'accès Auth — décision et calendrier à trancher par le porteur.
**NOUVELLE (session 2.14 quater) — Enrichissement fonctionnel scheduled_pickup_time** : notifyRecipientBySMS et getClientParcels pourraient à l'avenir inclure ce champ — piste non assignée, à arbitrer.
**NOUVELLE (session 2.14 quater) — Correction route CreateParcel** — voir session 2.20 déjà créée pour ce traitement (Section 16).
**NOUVELLE (session 2.14 quater) — Point de sécurité cancelMission/userId** — le renommage de paramètre est en place mais la vérification d'autorisation elle-même reste absente ; recommandation reconfirmée pour la session 2.17 (déjà actée session 2.14, reconfirmée pertinente et non résolue par le renommage de paramètre observé en 2.14 quater).

# 18. ANNEXE — INVESTIGATION SESSION 2.14 — PROCESSUS DE CRÉATION DE MISSION : ÉTAT ACTUEL ET PISTES D'AMÉLIORATION

[Contenu inchangé — reprise intégrale du point zéro de l'investigation, préservé tel quel sans réécriture, y compris l'avertissement de numérotation entre les deux systèmes Piste 1-4. Voir version du 11/08/2026 pour le texte complet des sections § 1 à § 5 et du § TRI.]

Mise à jour de statut (session 2.14 quater) : la Piste "Planification par date/heure" (§ TRI, Piste 2 dans la numérotation de cette section / Piste 3 dans la numérotation de la Section 18 bis et du corps du document) est désormais **traitée** — voir Section 6, bloc "SESSION 2.14 quater", et RÉSOLU 47.

# 18 bis. ANNEXE — SESSION 2.14 bis — SYNTHÈSE DE L'INVESTIGATION ET PLAN D'ACTION (PROCESSUS DE CRÉATION DE MISSION)

[Contenu inchangé — reprise intégrale.]

Synthèse ultra-condensée pour navigation rapide — MISE À JOUR :
Piste 1 (diffusion) : code mort géospatial à réutiliser — ⏳ 2.14 quinquies, dépendance envers Piste 3 désormais LEVÉE
Piste 2 (négociation) : nouvelle table + refonte du verrou — ⏳ 2.14 sexies, la plus lourde
Piste 3 (planification) : champ obligatoire — ✅ TRAITÉE, session 2.14 quater (voir RÉSOLU 47)
Piste 4 (canal vocal) : conservé, activation en dernier — ⏳ 2.14 septies, dépendance double (2.14 quater livrée, 2.14 sexies restante)
Hors piste : sécurité voice-messages — ✅ TRAITÉE, session 2.14 ter (voir RÉSOLU 43)

# TEMPLATE DÉBUT DE SESSION CLAUDE

PROJET : Fast Trans Maroc (FTM)
STACK : Expo SDK 50 / React Native / TypeScript
SUPABASE : ustckqnecsilxqlyjute
GITHUB : ELALAMIGIT61/FAST-TRANS-MAROC-FTM

RÈGLES CRITIQUES :
NE JAMAIS npm audit fix --force
SDK 50 stable — 39 vulnerabilities outils dev
.env dans frontend/
1 terminal de travail uniquement
Vérifier pwd avant tout npx expo start
Vérifier texte exact via sed avant replace()
Si replace() échoue → réécrire fichier entier
Vérifier contenu exact via repr() Python (jamais cat)
Tout texte avec caractère spécial bash (!, `, $, ) → heredoc à délimiteur quoté, jamais python3 -c "..."
NE JAMAIS exécuter de commande SQL de modification de schéma directement en SQL Editor — toujours via fichier de migration + GitHub Actions (règle renforcée session 2.14 ter)
Indexation storage.foldername() : vérifier l'indice par simulation, ne jamais le copier d'un pattern à convention de chemin différente (règle session 2.14 ter)
Lecture intégrale obligatoire, y compris pour les fichiers de référence/modèle non modifiés (règle renforcée session 2.14 quater)
git pull --rebase avant tout push
Migrations via GitHub uniquement
NE JAMAIS modifier authService.ts / ProfileSetupScreen.tsx / driverService.ts / wallet_update_admin
Backup obligatoire avant toute modification
Ne jamais retester ce qui est écarté / Ne jamais modifier ce qui fonctionne
vault.create_secret(valeur, nom, desc) — valeur EN PREMIER
timeout_milliseconds := 30000 pour net.http_post
cron.unschedule() WHERE EXISTS avant tout cron.schedule()
Alert.alert() ne s'affiche pas sur web — toujours Platform.OS === 'web' ? window.alert(...) : Alert.alert(...) (3 fichiers corrigés : AdminUsersScreen, WalletTopupScreen, PendingVerificationScreen — chemin natif non testé)
DateTimeField.tsx : nécessite le même traitement différencié web/natif — voir RÉSOLU 44/45/46 pour les 3 causes distinctes déjà rencontrées (absence support web, re-rendu non mémoïsé, validation prématurée onChange/onBlur)
⚠️ Numéro de test partagé +212600000000 : ACTUELLEMENT EN RÔLE CLIENT ("TEST CLIENT FTM") depuis session 2.14 quater. Le profil DRIVER historique (2ec2b439-..., wallet 800 DH, 4 transactions pending) a perdu son accès Auth mais ses données restent intactes en base. Un seul rôle actif à la fois — envisager un second numéro dédié au rôle Client avant toute session nécessitant un parcours de mission complet.
✅ RLS voice-messages CORRIGÉE (session 2.14 ter) — reste le test fonctionnel en Phase 4.4/session 2.18
✅ scheduled_pickup_time OBLIGATOIRE (NOT NULL) depuis session 2.14 quater — transport ET e-commerce
⚠️ Bug découvert : route 'CreateParcel' non déclarée en navigation — session 2.20 à traiter
Chantier "amélioration processus de création de mission" : 2.14 ter ✅, 2.14 quater ✅ — restent 2.14 quinquies (débloquée), 2.14 sexies, 2.14 septies — voir Section 6/17/18 bis pour dépendances
Prochain timestamp migration : 20260504000017

OBJECTIF SESSION : [Décrire précisément]

ERREUR ACTUELLE : [Coller l'erreur si applicable]
