ROADMAP-DOCUMENT DE REFERENCE SESSION CLAUDE — FAST TRANS MAROC — VERSION 25/08/2026

Fast Trans Maroc — Application Mobile Marocaine
Dernière mise à jour : 25/08/2026

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
   Prochain timestamp ≥ 20260504000019
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
✅ NOUVEAU — Un statut CI vert (workflow "Vérification Qualité Code") ne constitue pas une garantie suffisante que le code compile et s'exécute réellement — règle consolidée session 2.14 quinquies, suite à l'incident de duplication de STATUS_FILTERS (commit 69273c0) : une séquence de trois commandes sed appliquées successivement sur un même fichier a produit une déclaration dupliquée (SyntaxError bloquante à l'exécution), passée inaperçue du linting TypeScript. Après toute séquence de plusieurs sed sur un même fichier, effectuer systématiquement une relecture structurelle complète du fichier, ET un test d'exécution réel (lancement effectif du serveur), avant de committer — ne jamais se contenter d'un CI vert comme validation finale sur une session touchant du code applicatif.
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
   ⚠️ ÉTAT ACTUEL (depuis session 2.14 quinquies) : rôle DRIVER — nouveau profil créé via un nouvel onboarding complet durant la session 2.14 quinquies, is_verified = true, wallet 300.00 DH (recharge admin validée), catégorie véhicule VUL, 4 documents légaux soumis et validés. Ce nouveau profil est distinct du profil DRIVER historique (2ec2b439-..., wallet 800 DH, 4 transactions pending) : il ne s'agit PAS d'une reconstitution de ce dernier, mais d'un profil entièrement nouveau. Le profil historique reste orphelin de tout accès Auth, ses données restant intactes en base — voir bloc dédié Section 3.
   ⚠️ Limitation confirmée à nouveau sessions 2.14, 2.14 ter et 2.14 quater : absence de second numéro de test dédié au rôle client — a empêché tout test du Volet 4 (notify* mission), de la cloche côté client, du test fonctionnel RLS voice-messages en conditions réelles, et du parcours transport complet — recommandation transmise en Section 17. Point réactualisé session 2.14 quinquies : le numéro partagé étant redevenu DRIVER, cette limitation demeure pleinement d'actualité pour tout test nécessitant simultanément un profil CLIENT et un profil DRIVER distincts.

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
Session 2.14 quinquies : ROTATION — le compte Auth CLIENT ("TEST CLIENT FTM") a été supprimé dans le cadre des tests de non-régression, et un nouvel onboarding DRIVER complet a été réalisé sur le numéro partagé. Nouveau profil DRIVER créé et validé (is_verified = true, wallet 300 DH, catégorie VUL, 4 documents validés) — distinct du profil DRIVER historique 2ec2b439-..., toujours orphelin d'accès Auth et inchangé. Un seul profil DRIVER est aujourd'hui opérationnel (le nouveau) — voir bloc dédié Section 3.

Si un test DRIVER est à nouveau nécessaire (depuis l'état CLIENT actuel) :
   Supprimer +212600000000 dans Supabase Auth
   Reconnexion → ProfileSetupScreen → sélectionner "Driver"
   Remplir à nouveau les 4 pages onboarding : VehicleInfo → LegalDocuments → DocumentUpload → PendingVerification
   Validation admin requise pour is_verified=true
   Wallet à recréditer manuellement si besoin — NOTE : le profil historique 2ec2b439-... et son wallet 800 DH ne seront pas automatiquement récupérés par cette procédure (nouvel onboarding = nouveau driverId), sauf action explicite de récupération des données existantes

Si un test CLIENT est à nouveau nécessaire depuis un état DRIVER :
   Supprimer +212600000000 dans Supabase Auth
   Reconnexion → ProfileSetupScreen → sélectionner "Client"
   ⚠️ Depuis session 2.14 quinquies, l'état actuel du numéro partagé est DRIVER (nouveau profil) — cette procédure sera nécessaire pour tout futur test CLIENT.

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
✅ Fichier de rollback obligatoire pour toute migration RLS sensible : à placer dans supabase/rollbacks/ (hors du dossier migrations/, pour éviter toute exécution automatique non désirée) — convention introduite session 2.12, reconduite systématiquement depuis (2.13, 2.14 ter, 2.14 quater, 2.14 quinquies)
✅ Convention étendue session 2.13 : rollback créé par précaution même pour une migration non-RLS (renommage de vue, contrainte NOT NULL), avec commentaire explicite précisant qu'un rollback SQL seul est insuffisant en cas de déploiement partiel et nécessite un git revert coordonné du code applicatif. Précision session 2.14 quater : pour une contrainte NOT NULL, l'ordre des opérations en cas de rollback complet est impératif — SQL d'abord (retrait de la contrainte), git revert du code applicatif ensuite, jamais l'inverse, sous peine de bloquer toute création de mission. Précision session 2.14 quinquies : pour un ajout de valeur d'enum (ALTER TYPE ... ADD VALUE), un rollback complet (retrait de la valeur) n'est pas trivialement automatisable en toute sécurité par PostgreSQL — rollback documentaire uniquement, procédure manuelle à documenter en cas de besoin réel.
⚠️ Isoler une clause RLS via fetch() authentifié direct (sans passer par le code applicatif, ex. topupWallet()) peut produire des valeurs déclaratives trompeuses (ex. balance_after renseigné manuellement dans une ligne de test) — toujours vérifier la valeur réelle en base (ex. wallet.balance) plutôt que de se fier au contenu de la ligne insérée manuellement — session 2.12
⚠️ Alert.alert() (React Native) ne s'affiche pas sur web
   Toujours prévoir Platform.OS === 'web' ? window.alert(...) : Alert.alert(...) pour tout message destiné à s'afficher aussi sur web — bug redécouvert session 2.13 (WalletTopupScreen.tsx ligne 70, cf. RÉSOLU 41) après un premier correctif partiel en session 2.8 (AdminUsersScreen.tsx, sans généralisation Platform.OS) — voir audit recommandé section 17
✅ Pattern réappliqué avec succès session 2.14 sur PendingVerificationScreen.tsx (alerte Realtime) — voir RÉSOLU 42.
⚠️ Chemin natif (hors web) toujours non testé à ce jour sur aucun des fichiers concernés — environnement de développement limité au web (Codespaces) — audit systématique proposé (session 2.19) reste pertinent
⚠️ CLARIFICATION MÉTIER FONDAMENTALE (rappelée sessions 2.13, 2.14, 2.14 bis, à ne jamais perdre) : le paiement de la course est TOUJOURS hors application — le client paie directement le chauffeur (espèces ou autre moyen), sans jamais transiter par FTM. Seule la COMMISSION (montant fixe selon catégorie de véhicule) est prélevée automatiquement sur le wallet du chauffeur à chaque mission terminée (trigger process_commission_payment). Le wallet n'est donc alimenté QUE par les recharges (jamais par un paiement client), et diminué QUE par les commissions. Cette clarification est la raison structurelle du renommage revenue_current_month → recharges_current_month (RÉSOLU 39) — à garder impérativement en tête pour toute session touchant au workflow financier (notamment 2.17), pour éviter de reproduire la même confusion de nommage ou de conception ailleurs.
⚠️ negotiated_price (CreateMissionScreen.tsx) ne représente jamais un montant transitant par FTM, uniquement une base d'accord hors app entre client et chauffeur — principe reconfirmé session 2.14 bis (Piste 2, négociation de prix structurée), quel que soit le mécanisme de négociation retenu.
✅ Composant DateTimeField.tsx (session 2.14 quater) : sur le modèle des composants Alert.alert()/Platform.OS, ce composant nécessite lui aussi un traitement différencié web/natif (@react-native-community/datetimepicker strictement natif, aucun support web). Toujours vérifier avant tout usage : (1) mémoïsation React.memo si le composant contrôle un champ de saisie texte, pour éviter la corruption de saisie par re-rendu en boucle ; (2) séparation onChange (état local) / onBlur (validation finale) pour tout <input type="date"/"time"> HTML, le navigateur déclenchant onChange dès qu'une valeur techniquement complète est formée, avant la fin de la saisie utilisateur — voir RÉSOLU 44/45/46, session 2.14 quater.
✅ NOUVEAU — Vues Supabase exposées sans authentification (session 2.14 quinquies) : toute vue simple (non protégée par RLS, à la différence des tables) accessible en SELECT par les rôles anon/authenticated expose intégralement son contenu, y compris des colonnes sensibles (ex. phone_number sur available_drivers, solde wallet et commissions sur driver_dashboard) — une vue n'hérite pas automatiquement des protections RLS des tables sous-jacentes sauf activation explicite de security_invoker = true (PostgreSQL 17.6, confirmé compatible sur ce projet). Toute nouvelle vue exposant des données issues de tables protégées par RLS doit systématiquement faire l'objet d'une revue de permissions (GRANT) et d'une activation de security_invoker si applicable — voir RÉSOLU 48, session 2.14 quinquies.
✅ NOUVEAU — CREATE OR REPLACE VIEW ne permet pas de retirer une colonne existante (SQLSTATE 42P16 — cannot drop columns from view) — pour retirer une colonne d'une vue, procéder par DROP (et DROP des objets dépendants dans l'ordre, ex. RPC SECURITY DEFINER s'appuyant sur la vue) puis CREATE — session 2.14 quinquies, RÉSOLU 49.

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
   ⚠️ Session 2.14 quater : test complet resté bloqué (GPS Codespaces/iframe), table missions confirmée vide à l'issue de la session
   ⚠️ Session 2.14 quinquies : le compte Auth CLIENT ("TEST CLIENT FTM") a été supprimé en cours de session pour permettre un nouvel onboarding DRIVER — le numéro partagé n'occupe donc plus le rôle CLIENT depuis cette session (voir Section 2)

Auth ADMIN : ✅ confirmé — session 2.7
   Navigation → AdminDashboardScreen
   5 écrans dans AdminNavigator : AdminHome ✅ DocumentReview ✅ WalletManagement ✅ AdminMissions ✅ AdminUsers ✅
   ✅ Reconfirmé en conditions réelles session 2.14 quinquies (tests de non-régression) : dashboard, gestion missions, validation documents 4/4, gestion wallet (recharge 300 DH validée)

Auth DRIVER : ✅ OPÉRATIONNEL — nouveau profil créé session 2.14 quinquies
   Flux complet historique testé et validé à l'époque (session 2.4 suite) : Étape 1 → VehicleInfoScreen ✅ / Étape 2 → LegalDocumentsScreen ✅ / Étape 3 → DocumentUploadScreen ✅ / Étape 4 → PendingVerification ✅ / Validation admin → DriverHome ✅
   Realtime Supabase ✅
   ⚠️ ÉTAT ACTUEL (depuis session 2.14 quinquies) : le rôle DRIVER est de nouveau accessible sur le numéro partagé — un nouvel onboarding complet a été réalisé et validé durant cette session (nouveau profil, distinct du profil historique 2ec2b439-...). Voir Section 2, bloc "numéro partagé", et Section 3.
   ⚠️ Alerte Realtime de validation sur PendingVerificationScreen.tsx : ✅ CORRIGÉE session 2.14 (RÉSOLU 42) — chemin web uniquement, chemin natif non testé
   ✅ Reconfirmé fonctionnel en conditions réelles session 2.14 quinquies : onboarding complet réalisé (nouveau profil, 4 documents soumis et validés), validation admin réussie, recharge wallet fonctionnelle (0 → 300 DH), accès à DriverHomeScreen (fichier modifié pour le Volet 1 de diffusion) réussi

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
   ⚠️ Lien avec notifyDocumentExpiry non vérifié — voir Section 15/17 (en attente depuis session 2.14, non traité en 2.14 bis, 2.14 ter, 2.14 quater, ni 2.14 quinquies — hors périmètre de chacune)

Vault Supabase : ✅ Secret supabase_service_role_key — 219 caractères — identique Dashboard — Créé session 2.9

Realtime Supabase : ✅ OPÉRATIONNEL — session 2.10
   5 tables activées : drivers, missions, wallet, transactions, notifications — Migration 20260504000012 déployée
   WalletDashboardScreen SUBSCRIBED ✅
   transactions ✅ écoute branchée — session 2.14
   notifications : Realtime actif — non branché UI directement, remplacé par NotificationBell/Center (résolution du profil via getCurrentProfileId(), déclenché par événement Realtime — divergence documentaire corrigée session 2.14 quater)
   ✅ NOUVEAU (session 2.14 quinquies) — canal subscribeToMissionUpdates (déjà existant, déjà utilisé dans MissionTrackingScreen.tsx) désormais également exploité côté DriverHomeScreen.tsx : abonnement immédiat dès réception d'une nouvelle mission (Volet 1 diffusion), fermeture automatique du modal de proposition si le statut de la mission change avant acceptation

RLS transactions : ✅ transactions_insert_own corrigée — session 2.12 (commit 67e9e65) — voir RÉSOLU 37
   ✅ Fondation confirmée fonctionnelle en usage réel session 2.13 : requestWalletTopup() insère des transactions status: 'pending' via cette même politique — RÉSOLU 38
   ✅ Confirmée compatible avec le listener Realtime (Volet 2, session 2.14)
   🔵 Pattern RLS de transactions_select_own / notifications_select_own identifié — session 2.14 bis — réutilisé avec succès comme référence pour voice-messages (session 2.14 ter, via jointure adaptée à un double accès) — reste également la référence prévue pour la future table mission_offers (session 2.14 sexies)

Wallet topup : ✅ Mécanisme honnête — session 2.13 (commit 2e76429) — requestWalletTopup() — voir RÉSOLU 38
   ⛔ wallet_update_admin non modifiée — reste privilège admin exclusif
   ⚠️ Robustesse topupWallet/refundWallet (échec silencieux possible de l'insertion de la transaction après UPDATE du solde) — découverte annexe session 2.14, préexistante, hors périmètre — à documenter pour session future (voir Section 15/17)
   ✅ Reconfirmé sans modification — sessions 2.14 bis et 2.14 ter (aucune de ces deux sessions ne touche au code applicatif wallet)
   ⚠️ Session 2.14 quater : aucune modification non plus (hors périmètre strict, code wallet non touché) — mais le profil DRIVER porteur de ce wallet (2ec2b439-...) a perdu son accès Auth (voir Section 3, bloc numéro partagé) ; les données wallet/transactions elles-mêmes restent inchangées en base
   ✅ Session 2.14 quinquies : validation fonctionnelle croisée obtenue en conditions réelles sur le nouveau profil DRIVER — recharge admin de 300 DH testée et confirmée (0 → 300 DH), et le chauffeur ne voit que son propre solde (jamais celui d'un autre profil), confirmant au passage le bon fonctionnement de security_invoker sur driver_dashboard (voir RÉSOLU 48)

Dashboard driver : ✅ recharges_current_month — session 2.13 (commit 2e76429, migration 20260504000014) — voir RÉSOLU 39
   ✅ Vue driver_dashboard désormais protégée : SELECT anon révoqué, security_invoker = true activé — session 2.14 quinquies (voir RÉSOLU 48)

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
   ⛔ 3 non retenues : notifyNewMission (incompatibilité structurelle, exclusion reconfirmée sans réserve session 2.14 quinquies — aucun appelant dans tout le projet, confirmé par grep global), notifyDocumentExpiry (en attente), notifyWalletLowBalance (écartée)
   ⚠️ NON TESTÉES fonctionnellement à ce jour — le retour du numéro partagé au rôle DRIVER en session 2.14 quinquies ne permet toujours pas de test de bout en bout côté Client (absence de second numéro dédié CLIENT) — voir Section 15/17

⚠️ Compte ADMIN test :
   Numéro : +212600000001 — Rôle admin défini via SQL Editor — NE PAS SUPPRIMER CE PROFIL
   Reconfirmé intact — sessions 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies (aucune modification)

⚠️ DRIVER TEST HISTORIQUE — état à date de la session 2.14 ter (dernière vérification par lecture directe avant la rotation de 2.14 quater), TOUJOURS ORPHELIN D'ACCÈS AUTH à l'issue de la session 2.14 quinquies :
   driverId : 2ec2b439-fcdb-443d-8de0-5bee268d30f6
   Numéro : +212600000000 (ACCÈS AUTH DÉSORMAIS OCCUPÉ PAR UN AUTRE PROFIL — voir ci-dessous)
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
   ⚠️ ÉTAT DEPUIS SESSION 2.14 quinquies : l'accès Auth du numéro +212600000000 est désormais occupé par un tout NOUVEAU profil DRIVER (créé cette même session), distinct de ce profil historique. Le profil DRIVER 2ec2b439-... et l'intégralité de ses données (wallet 800 DH, 4 transactions pending, is_verified=true) restent en base, toujours orphelines de tout accès Auth, récupérables sur décision future (voir Section 17). Il ne s'agit PAS de deux profils DRIVER équivalents actifs simultanément — un seul est aujourd'hui opérationnel (le nouveau).

⚠️ NOUVEAU PROFIL DRIVER ACTIF — depuis session 2.14 quinquies :
   Numéro : +212600000000
   Créé via un nouvel onboarding complet (VehicleInfo → LegalDocuments → DocumentUpload → PendingVerification), dans le cadre des tests de non-régression de la session 2.14 quinquies (l'ancien profil CLIENT "TEST CLIENT FTM" ayant été supprimé pour l'occasion)
   role : 'driver'
   is_verified : true (validation admin réalisée durant la session)
   Catégorie véhicule : VUL
   wallet_balance : 300.00 DH (recharge admin de 300 DH validée durant la session)
   Documents légaux : 4/4 soumis et validés (Permis, Carte grise, Assurance, Visite technique)
   ⚠️ driverId non communiqué dans le compte-rendu source — INCONNU, à vérifier par lecture directe en base lors d'une prochaine session si nécessaire.

⚠️ ANCIEN PROFIL CLIENT "TEST CLIENT FTM" — état à l'issue de la session 2.14 quinquies :
   Créé en session 2.14 quater sur le numéro partagé, SUPPRIMÉ en session 2.14 quinquies pour permettre le nouvel onboarding DRIVER. Aucune mission n'avait été créée par ce profil durant son existence (table missions confirmée vide, 0 ligne, à l'issue de la session 2.14 quater, situation inchangée à l'issue de la session 2.14 quinquies — aucune mission insérée en base durant cette dernière non plus).

⚠️ SIGNED_IN répétés en console admin : Comportement normal Supabase web via refresh token périodique — Non bloquant

⚠️ État du dépôt — HEAD : 8941e0a (session 2.14 quinquies), synchronisé avec origin/main, aucune modification en attente de commit hors des .bak* déjà identifiés. ~59+ fichiers untracked de type .bak* identifiés comme mécanisme de traçabilité délibéré (dont 4 nouveaux ajoutés en session 2.14 quinquies : DriverHomeScreen.tsx, missionService.ts, MissionTrackingScreen.tsx, AdminMissionsScreen.tsx, suffixe .bak.session2.14quinquies, en complément des 4 déjà ajoutés en session 2.14 quater) — à préserver tel quel, cohérent avec la politique déjà établie.

# GITHUB SECRETS CONFIGURÉS

SUPABASE_ACCESS_TOKEN ✅ renouvelé 29/04/2026 — Token : FTM_GITHUB_ACTIONS — Expiration : Never
SUPABASE_PROJECT_ID ✅ (ustckqnecsilxqlyjute)
SUPABASE_DB_PASSWORD ✅
SUPABASE_ANON_KEY ✅
SUPABASE_URL ✅

# HISTORIQUE COMMITS CLÉS

8941e0a fix: correct duplicated STATUS_FILTERS declaration in AdminMissionsScreen (post-test critical bug) — session 2.14 quinquies ✅
69273c0 feat: add expired status to AdminMissionsScreen filters (STATUS_LABELS, STATUS_FILTERS, FILTER_LABELS) — session 2.14 quinquies ⚠️ (bug critique introduit, corrigé par 8941e0a)
b1d2540 feat: mission expiration detection (expireMission in missionService.ts) + expired UI state (MissionTrackingScreen.tsx) — session 2.14 quinquies ✅
d1869e4 feat: auto-close pending mission modal on status change via subscribeToMissionUpdates (DriverHomeScreen.tsx) — session 2.14 quinquies ✅
ffd62e8 feat: add expired value to mission_status enum (migration 20260504000018) — session 2.14 quinquies ✅
70b02f0 fix: correct available_drivers/driver_dashboard security migration (SQLSTATE 42P16, DROP+CREATE) — session 2.14 quinquies ✅
3bf1c09 fix: remove phone_number exposure + restrict permissions on available_drivers, driver_dashboard, find_nearby_drivers (migration 20260504000017) — session 2.14 quinquies ✅
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

[Sections SESSION 2.4 INITIALE à SESSION 2.14 bis — inchangées, reprises intégralement à l'identique de la version du 11/08/2026. Voir blocs détaillés ci-dessous pour les nouvelles sessions.]

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
2.14 quinquies ✅ Piste 1 — sécurisation infrastructure diffusion + Volets 1/2 expiration (avec réserves — branchement filtrage réel géospatial reporté)
2.14 quinquies bis ⏳ Piste 1 (suite) — branchement effectif de la diffusion géospatiale par distance réelle
2.14 sexies ⏳ Piste 2 — négociation de prix structurée
2.14 septies ⏳ Piste 4 — activation canal vocal sécurisé
2.15 ⏳ TrackingDetailScreen
2.16 ⏳ Bouton déconnexion 3 rôles
2.17 ⏳ Réforme timing commission + workflow financier générique
2.18 ⏳ Test fonctionnel complet voice-messages (Phase 4.4, RLS déjà déployée depuis 2.14 ter)
2.19 ⏳ Audit systématique Alert.alert()
2.20 ⏳ NOUVELLE — Correction route CreateParcel manquante + test flux e-commerce complet (voir Section 6, bloc 2.14 quater)

⚠️ MISE À JOUR DE DÉPENDANCE (session 2.14 quater → 2.14 quinquies) : la dépendance du Volet 2 de la Piste 1 (expiration d'une mission jamais acceptée) envers la Piste 3 (scheduled_pickup_time) est désormais LEVÉE — le champ est disponible et obligatoire en base depuis le déploiement de la migration 20260504000016. Volets 1 et 2 intégralement réalisés en session 2.14 quinquies.

Ordre logique actualisé : 2.12 → 2.13 → 2.14 → 2.14 bis → 2.14 ter → 2.14 quater → 2.14 quinquies (Volets 1/2 + sécurité, complétée) → 2.14 quinquies bis (branchement diffusion réelle, nouvelle priorité immédiate du chantier) → 2.14 sexies → 2.14 septies → 2.15 (parallélisable) → 2.16 (glissable) → 2.17 (dernière du chantier wallet) → 2.18 (test fonctionnel voice-messages, Phase 4.4) → 2.19 (glissable, avant Phase 3) → 2.20 (nouvelle, fin de séquence chantier processus de mission, sans dépendance avec les pistes suivantes)

LISTE DE SUIVI — ANOMALIES/OBSERVATIONS DOCUMENTAIRES (à corriger dans le présent document) :
1. ID driver test coquille → CORRIGÉ session 2.12
2-3. Chemins onboarding → confirmés sous frontend/src/screens/driver/onboarding/
4. Bug WalletRecharge → CORRIGÉ session 2.13 (RÉSOLU 40)
5. Filtrage géographique absent → RPC find_nearby_drivers identifiée session 2.14 bis, infrastructure sécurisée session 2.14 quinquies, branchement réel prévu 2.14 quinquies bis
6. Convention de chemins non documentée (sous-dossiers thématiques)
7. RLS transactions INSERT sans restriction → CORRIGÉ session 2.12 (RÉSOLU 37)
8. RLS voice-messages sans clause de propriété → CORRIGÉ session 2.14 ter (RÉSOLU 46)
9. NOUVEAU (session 2.14 ter) — Décompte transactions pending driver test : le document affichait "3 (200/500/1000 DH)", corrigé en "4 (50/200/500/1000 DH)" — voir Section 3
10. NOUVEAU (session 2.14 quater) — Divergence documentaire NotificationBell : mécanisme réel = Realtime événementiel, pas polling par setInterval — corrigé Section 3
11. NOUVEAU (session 2.14 quater) — Fichier applicatif du canal vocal : confirmé frontend/src/services/audioService.ts (déjà corrigé session 2.14 ter)
12. NOUVEAU (session 2.14 quater) — Route de navigation CreateParcel manquante (bug préexistant découvert, sans rapport avec la session) — voir Section 15, session 2.20 assignée
13. NOUVEAU (session 2.14 quinquies) — Ambiguïté sur la définition du « Volet 2 » entre le prompt de passation (expiration) et le prompt de mission 2.14 quater (rappel 24h) — levée par lecture directe de la ROADMAP : le Volet 2 concerne bien l'expiration liée à scheduled_pickup_time. Le rappel 24h est un mécanisme distinct, hors périmètre, affectation future non figée.
14. NOUVEAU (session 2.14 quinquies) — Nombre de profils DRIVER opérationnels : clarifié — un seul profil DRIVER est actif à la fois (le nouveau, créé en 2.14 quinquies), le profil historique 2ec2b439-... étant une donnée orpheline dormante, pas un second profil équivalent utilisable.
15. NOUVEAU (session 2.14 quinquies) — Statut CI comme garantie de fonctionnement du code : infirmé par l'incident du bug de duplication STATUS_FILTERS, passé inaperçu du linting TypeScript alors qu'il provoquait une erreur de compilation bloquante à l'exécution. Voir RÉSOLU 50 et règle consolidée Section 2.

Prochain timestamp migration disponible : 20260504000019 (consommé : 015 par session 2.14 ter, 016 par session 2.14 quater, 017 et 018 par session 2.14 quinquies)

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

[Contenu inchangé — reprise intégrale de la version du 20/08/2026 : correction RLS bucket Storage voice-messages, Partie 1 investigation, Partie 2 implémentation, 2 incidents (DROP hors circuit, échec réseau transitoire), synthèse finale. Voir RÉSOLU 43.]

## SESSION 2.14 quater — commits 0da3e07 + 829f31e

[Contenu inchangé — reprise intégrale de la version du 20/08/2026 : planification par date/heure, arbitrage Option B, composant DateTimeField.tsx, 3 bugs web corrigés, gap d'investigation méthodologique, tests de non-régression, points opérationnels. Voir RÉSOLU 44/45/46/47.]

## SESSION 2.14 quinquies — commits 3bf1c09 → 8941e0a

### Objectif et périmètre

**Objectif initial du prompt de mission** : brancher la RPC géospatiale existante find_nearby_drivers (catégorie VUL, rayon 60 km depuis pickup_location), traiter le Volet 1 (retrait d'une mission de la diffusion dès acceptation) et le Volet 2 (expiration d'une mission pending à scheduled_pickup_time dépassé), avec vérification préalable du contenu de la vue available_drivers.

**⚠️ Périmètre final réellement livré — différent de l'objectif initial, sur décisions explicites et tracées du porteur en cours de session :**
- Le branchement final de la diffusion géospatiale (filtrage réel par distance) est reporté à une session dédiée future (2.14 quinquies bis, créée durant cette session).
- Une faille de sécurité majeure, découverte fortuitement en cours d'investigation (Étape 1.3), a été traitée en priorité — élargissement conscient et documenté du périmètre initial.
- Les Volets 1 et 2 ont été intégralement réalisés, avec un complément (filtre admin pour le statut expired) intégré à cette même session car relevant directement de son périmètre d'origine.

« Le périmètre initial a été élargi en cours de Partie 1, sur décision explicite du porteur, pour intégrer la correction d'une faille de sécurité découverte fortuitement — hors de l'objet initial de la session. »

Session mixte investigation approfondie (Partie 1, très longue) + implémentation (Partie 2), avec plusieurs points de validation explicite du porteur tout au long du processus.

### Partie 1 — Investigation (synthèse)

Vérification préliminaire (Étape 1.0) : HEAD réel du dépôt confirmé e9a720c (écart avec HEAD CODE attendu 829f31e, expliqué par un commit ROADMAP antérieur à la session — non porteur d'information nouvelle pour la présente actualisation).

Diffusion géospatiale — investigation complète :

Vue available_drivers (CONFIRMÉ par lecture directe) : filtres is_verified = true, is_available = true, is_active = true déjà appliqués. Colonnes exposées incluant à l'origine phone_number (point critique découvert plus loin). Aucun chauffeur ne satisfaisait les filtres au moment de l'investigation (table vide).

RPC find_nearby_drivers (CONFIRMÉ) : paramètres client_point (WKT), radius_meters (mètres), p_vehicle_category (enum, valeur vul en minuscule confirmée). Filtre de fraîcheur last_location_update > NOW() - INTERVAL '5 minutes', non documenté auparavant. SECURITY DEFINER.

Wrapper findNearbyDrivers() (missionService.ts, CONFIRMÉ) : fonctionnel, jamais appelé (« code mort » confirmé par lecture intégrale). Rayon par défaut dans sa signature : 15 km, pas 60 — écart avec le paramètre validé, origine INCONNUE, à corriger au futur branchement (voir Section 16, bloc 2.14 quinquies bis).

Mécanisme de diffusion actuel cartographié intégralement : createMission() → trigger Realtime sur INSERT → subscribeToNewMissions(vehicleCategory, null, callback) (filtre catégorie uniquement) → DriverHomeScreen.tsx → NewMissionModal.tsx. Découverte clé : le paramètre _driverLocation de subscribeToNewMissions() existe dans la signature mais n'est jamais rempli ni utilisé — point d'insertion identifié pour un futur branchement (voir Section 16, bloc 2.14 quinquies bis).

Investigation du mécanisme de géolocalisation chauffeur (locationService.ts, lu en profondeur en cours de Partie 2) : startBackgroundTracking() utilise Location.watchPositionAsync — suivi continu (intervalle 15 secondes ou 50 mètres de déplacement, le premier atteint), écrivant current_location/last_location_update en base à chaque déclenchement. Cette découverte explique a posteriori le filtre de fraîcheur de 5 minutes de la RPC (marge de sécurité cohérente avec un rafraîchissement toutes les 15s).

### ⚠️ Découverte de sécurité majeure, hors périmètre initial

En investiguant l'exposition de phone_number par la RPC (Étape 1.3), une cartographie complète des permissions a révélé :

| Élément | Accès anon | Protection RLS |
|---|---|---|
| Fonction find_nearby_drivers | EXECUTE accordé | SECURITY DEFINER (contourne RLS) |
| Vue available_drivers | SELECT accordé | Aucune (vue simple) — expose phone_number |
| Vue driver_dashboard | SELECT accordé | Aucune (vue simple) — expose solde wallet, commissions, recharges |
| Vue public_parcel_tracking | SELECT accordé (voulu) | Téléphone tronqué à la conception — correctement conçue |
| Table drivers | GRANT large | Presque stricte, sauf drivers_select_available (aucune condition d'identité) |
| Tables profiles, wallet, transactions | GRANT large | Strictes (chaîne de propriété complète vers auth.uid()) |
| Autres fonctions SECURITY DEFINER (schéma public) | — | Aucune autre à risque (get_my_role() légitime, reste PostGIS interne) |

Conclusion de l'investigation : problème strictement circonscrit à deux vues (available_drivers, driver_dashboard), toutes deux non exploitées par le code applicatif actuel au moment de la découverte (sauf driver_dashboard, utilisée légitimement par walletService.ts avec un filtre côté application, non protégé côté base), mais accessibles depuis l'extérieur de l'application sans authentification. Les tables sous-jacentes correctement protégées ; le défaut localisé aux vues elles-mêmes.

### Ambiguïté documentaire levée — définition du « Volet 2 »

Deux formulations contradictoires existaient entre le prompt de passation (Volet 2 = expiration) et le prompt de mission 2.14 quater (Volet 2 = rappel 24h). Confirmé par lecture directe de la ROADMAP actuelle : le Volet 2 concerne bien l'expiration liée à scheduled_pickup_time. Le rappel 24h est un mécanisme distinct, hors périmètre de cette session, affectation future non figée.

### Confirmation de la pertinence de notifyNewMission

CONFIRMÉ par lecture directe (notificationTemplates.ts) : la fonction exige un driverProfileId individuel en premier paramètre, incompatible par construction avec le moment de création d'une mission (aucun chauffeur encore assigné). Décision d'exclusion (actée depuis session 2.14) reconfirmée sans réserve — fonction définie, aucun appelant dans tout le projet (grep global).

### Partie 2 — Implémentation

**2A — Correction de sécurité (priorité, traitée en premier)**

Arbitrage technique : CREATE OR REPLACE VIEW s'est révélé incapable de retirer une colonne existante (SQLSTATE 42P16 — cannot drop columns from view) — un premier déploiement a échoué (Deploy Supabase FTM #47). Correction : DROP FUNCTION + DROP VIEW puis CREATE (pas CREATE OR REPLACE), en respectant l'ordre des dépendances.

Contenu de la migration 20260504000017 (déployée avec succès après correction, commit 70b02f0) :
1. Suppression préalable de la RPC dépendante, puis de la vue available_drivers.
2. Recréation de la vue sans phone_number.
3. Recréation de la RPC sans phone_number.
4. Révocation SELECT anon/authenticated sur available_drivers.
5. Révocation SELECT anon sur driver_dashboard + ALTER VIEW ... SET (security_invoker = true) (PostgreSQL 17.6, confirmé compatible).
6. Révocation EXECUTE anon/PUBLIC sur la RPC, conservé pour authenticated uniquement.

Rollback (supabase/rollbacks/20260504000017_..._rollback.sql) : restauration complète documentée, avec avertissement explicite sur la réintroduction sciente de la faille en cas d'exécution.

Vérifications post-déploiement, toutes par lecture directe en production :
- pg_get_viewdef : phone_number absent de available_drivers ✅
- role_table_grants : SELECT absent pour anon/authenticated sur available_drivers ✅ (2/5 rôles, contre 4/5 avant)
- driver_dashboard : security_invoker=true confirmé, SELECT absent pour anon ✅
- pg_get_functiondef : phone_number absent de la RPC ✅
- routine_privileges : seuls postgres/authenticated/service_role conservent EXECUTE (contre 5 rôles avant) ✅

Validation fonctionnelle en conditions réelles (test DRIVER, Partie tests) : le nouveau chauffeur test ne voit que son propre solde wallet (0 DH puis 300 DH après recharge), jamais celui d'un autre profil — confirmation pratique, à l'appui du RÉSOLU 48, que security_invoker fonctionne correctement en production.

**2B — Volet 2, migration**

Migration 20260504000018 (commit ffd62e8) : ALTER TYPE mission_status ADD VALUE IF NOT EXISTS 'expired'; — fichier volontairement minimal, isolé dans sa propre transaction (contrainte PostgreSQL anticipée : impossibilité d'utiliser une nouvelle valeur d'enum dans la transaction qui l'a créée).

Rollback : documentaire uniquement — retrait d'une valeur d'enum non trivialement automatisable en toute sécurité par PostgreSQL, procédure manuelle documentée en cas de besoin réel.

Vérification post-déploiement : enum_range(NULL::mission_status) → {pending, accepted, in_progress, completed, cancelled_client, cancelled_driver, expired} — 6 valeurs d'origine intactes + expired ajoutée.

**Volet 1 — Fermeture automatique du modal (commit d1869e4)**

Fichier modifié : DriverHomeScreen.tsx (backup .bak.session2.14quinquies).

Modifications :
- Import de subscribeToMissionUpdates (canal déjà existant, déjà utilisé dans MissionTrackingScreen.tsx — aucune nouvelle infrastructure).
- Nouvelle ref pendingMissionUpdateChannelRef.
- Fonction clearPendingMissionWatch centralisant le désabonnement.
- Dans le callback de subscribeToNewMissions : abonnement immédiat à subscribeToMissionUpdates(mission.id, ...), fermeture automatique du modal (setPendingMission(null)) si le statut reçu n'est plus pending.
- Désabonnement systématique à chaque point de sortie (bascule hors service, acceptation, refus, démontage du composant).

Vérifications de fichier : taille, début/fin (Python), et présence exacte de la logique métier (grep ciblé, 13 occurrences réparties correctement).

**Volet 2 — Partie applicative (commit b1d2540)**

missionService.ts (backup créé) :
- Ajout de 'expired' au type MissionStatus.
- Nouvelle fonction expireMission(missionId), sur le modèle de cancelMission(), avec garde-fou .eq('status', 'pending').

MissionTrackingScreen.tsx (backup créé) :
- Import de expireMission.
- Constante EXPIRATION_CHECK_INTERVAL_MS = 30000.
- Nouveau useEffect : actif uniquement si status === 'pending' et scheduled_pickup_time renseigné, vérification locale (comparaison de dates, sans coût réseau) toutes les 30 secondes, écriture réelle en base uniquement si expiration détectée.
- Nouveau case 'expired' dans renderStatus() : message dédié + bouton de recréation de mission (réutilise le style existant).

Arbitrages techniques/métier, avec répartition explicite des responsabilités entre l'assistant et le porteur :
- Mécanisme sans CRON pour cette phase du projet (décision métier, porteur).
- Fréquence 30 secondes, après clarification que la vérification locale ne coûte rien en réseau — seule l'écriture en cas d'expiration détectée a un coût (décision métier, porteur, révisée après clarification technique de 1 heure vers 30 secondes).
- Écran d'implémentation (MissionTrackingScreen.tsx) : décision technique.
- Nouveau statut expired plutôt que réutilisation d'un statut existant : décision technique, pour ne pas déformer la sémantique de statuts déjà affichés ailleurs.

Limite assumée et documentée : une mission pending expirée reste techniquement en base tant qu'aucun écran client ne la consulte — compromis explicitement accepté pour cette phase (0 mission en base à ce jour), à réévaluer si le volume réel augmente.

**Volet 2 — Filtre admin (commits 69273c0 puis 8941e0a)**

Décision d'intégration à cette session : proposée par le porteur, validée après vérification technique que la modification était simple (constantes génériques, aucune logique conditionnelle spécifique dans le rendu).

AdminMissionsScreen.tsx (backup créé, fichier lu intégralement pour la première fois durant cette session, 195 lignes) : ajout de expired aux trois constantes STATUS_LABELS, STATUS_FILTERS, FILTER_LABELS.

### ⚠️ Incident critique — détecté et corrigé après la séquence de tests de non-régression

Découverte : lors d'un test fonctionnel tardif et ciblé du filtre expired (motivé par une relecture rigoureuse post-clôture), le serveur de développement a révélé une erreur de compilation bloquante :

SyntaxError: /workspaces/FAST-TRANS-MAROC-FTM/frontend/src/screens/admin/AdminMissionsScreen.tsx:
Identifier 'STATUS_FILTERS' has already been declared. (44:6)

Cause racine : une séquence de trois commandes sed appliquées successivement sur le fichier (une insertion, un remplacement de ligne, une seconde insertion) a provoqué un décalage de numérotation de lignes non anticipé après la première insertion ; le remplacement suivant, ciblant la ligne 43 avant recalcul, a produit une duplication de la déclaration STATUS_FILTERS (version correcte avec expired + résidu de l'ancienne version sans expired, jamais supprimé) plutôt qu'un remplacement propre.

⚠️ Point méthodologique majeur : le workflow CI Vérification Qualité Code était passé au vert sur le commit fautif (69273c0) — le linting TypeScript n'a pas détecté cette erreur de syntaxe pourtant bloquante à l'exécution. Seul un test d'exécution réelle (lancement effectif du serveur Metro Bundler) l'a révélée immédiatement et sans ambiguïté. Un statut CI vert ne constitue donc pas, dans ce projet, une garantie suffisante que le code compile et s'exécute réellement.

Correction (commit 8941e0a) : suppression de la ligne dupliquée (l'ancienne version, sans expired), conservation de la version correcte. Vérification par relecture complète (taille, grep ciblé confirmant une seule déclaration de chaque constante) puis validation par un vrai test d'exécution : serveur relancé avec succès, AdminMissionsScreen affichée avec les 7 filtres, "Expirées" visible et l'écran stable, sans erreur JavaScript.

Ce qui reste non testé, assumé comme limite : le filtrage réel avec au moins une mission au statut expired — impossible en pratique, la table missions étant restée vide (0 ligne) tout au long de cette session.

### Tests de non-régression

Méthode : serveur de développement lancé (2 incidents réseau transitoires vers api.expo.dev — Client network socket disconnected before secure TLS connection was established — résolus par simple relance, cohérent avec l'Incident 2 déjà documenté en session 2.14 ter). Ordre choisi pragmatiquement : CLIENT (déjà connecté sur le numéro de test partagé) → ADMIN → DRIVER (occasion de reconnecter le profil, accès Auth perdu depuis 2.14 quater) — exception assumée à l'ordre standard DRIVER → ADMIN → CLIENT, justifiée par l'efficacité pratique.

| Rôle | Résultat | Détail |
|---|---|---|
| CLIENT | ✅ Aucune régression | CreateMissionScreen (avec DateTimeField.tsx de 2.14 quater) fonctionnel. NotificationCenterScreen fonctionnel — Anomalie #1 déjà connue (bouton retour absent) reconfirmée en conditions réelles. GPS bloqué (limitation déjà documentée, confirmée : GPS - Client location permission denied). |
| ADMIN | ✅ Aucune régression | Dashboard, gestion missions, validation documents (4/4), gestion wallet (recharge 300 DH validée) — tous fonctionnels. |
| DRIVER | ✅ Aucune régression | Onboarding complet réalisé (nouveau profil créé, 4 documents soumis et validés). Validation admin réussie (erreur CORS sur send-push-notification confirmée — limitation déjà documentée, non liée à cette session). Recharge wallet fonctionnelle (0 → 300 DH). Accès à DriverHomeScreen (fichier modifié pour le Volet 1) réussi. Activation de disponibilité tentée : bloquée au niveau GPS comme attendu (GPS - Cannot start tracking: permissions denied) — le code réagit proprement à cet échec (if (trackResult.error) { Alert.alert(...); return; }), sans crash, mais empêche de tester le canal de diffusion jusqu'au bout. Vérification fonctionnelle croisée : le chauffeur test ne voit que son propre solde wallet, validant en conditions réelles security_invoker sur driver_dashboard. |

### État du numéro de test partagé

⚠️ Précision importante : il n'existe pas deux profils DRIVER équivalents. Un seul profil DRIVER est actif et opérationnel aujourd'hui — celui créé durant cette session, via un nouvel onboarding complet, sur le numéro de test partagé (+212600000000).

Caractéristiques du nouveau profil DRIVER actif :
- Créé et validé (is_verified = true) durant cette session.
- Wallet : 300.00 DH (recharge de 300 DH validée par l'admin).
- Catégorie véhicule : VUL.
- Documents légaux soumis et validés (Permis, Carte grise, Assurance, Visite technique).

Le profil DRIVER historique (2ec2b439-fcdb-443d-8de0-5bee268d30f6) reste orphelin d'accès Auth — données (wallet 800 DH, 4 transactions pending) intactes en base mais inaccessibles et inopérantes. Pas un second profil utilisable, seulement une donnée historique dormante. Décision sur son éventuelle réactivation ou son abandon toujours en attente d'arbitrage du porteur.

### Écarts de documentation corrigés

- Ambiguïté sur la définition du « Volet 2 » entre prompt de passation et prompt de mission 2.14 quater — levée par lecture directe de la ROADMAP.
- Nombre de profils DRIVER — un seul profil actif (le nouveau), l'ancien étant orphelin, non un second profil équivalent.
- Statut CI comme garantie de fonctionnement du code — infirmé par l'incident du bug de duplication non détecté par le linting.

### État final du dépôt et continuité inter-sessions

Commits de cette session, dans l'ordre chronologique :

| Commit | Objet |
|---|---|
| 3bf1c09 | Correction sécurité initiale (migration + rollback 20260504000017) |
| 70b02f0 | Correction de la migration précédente (SQLSTATE 42P16, DROP+CREATE) |
| ffd62e8 | Ajout du statut expired à l'enum mission_status (migration 20260504000018) |
| d1869e4 | Volet 1 — fermeture automatique du modal |
| b1d2540 | Volet 2 — partie applicative (détection + écriture) |
| 69273c0 | Volet 2 — filtre admin (contenait un bug critique) |
| 8941e0a | Correctif du bug critique, validé par test d'exécution réel |

HEAD final : 8941e0a, synchronisé avec origin/main, aucune modification en attente de commit hors des .bak* déjà identifiés.

Fichiers créés :
- supabase/migrations/20260504000017_fix_available_drivers_and_driver_dashboard_exposure.sql
- supabase/rollbacks/20260504000017_fix_available_drivers_and_driver_dashboard_exposure_rollback.sql
- supabase/migrations/20260504000018_add_expired_status_to_mission_status.sql
- supabase/rollbacks/20260504000018_add_expired_status_to_mission_status_rollback.sql

Fichiers modifiés : DriverHomeScreen.tsx, missionService.ts, MissionTrackingScreen.tsx, AdminMissionsScreen.tsx (modifié deux fois : ajout puis correctif du bug critique).

Backups créés (.bak.session2.14quinquies) : DriverHomeScreen.tsx, missionService.ts, MissionTrackingScreen.tsx, AdminMissionsScreen.tsx — cohérent avec la politique de traçabilité déjà établie du projet (~59+ fichiers .bak* au total).

⚠️ Timestamps de migration consommés durant cette session : 20260504000017, 20260504000018.

⚠️ PROCHAIN TIMESTAMP DE MIGRATION DISPONIBLE : 20260504000019.

### Synthèse finale de la session

| Élément | Statut |
|---|---|
| Partie 1 — Investigation | ✅ Complète, très approfondie, toutes vérifications par lecture directe |
| Faille de sécurité découverte et corrigée | ✅ Traitée en priorité, périmètre élargi tracé |
| Diffusion géospatiale — préparation | ✅ Infrastructure sécurisée et intégralement cartographiée |
| Diffusion géospatiale — branchement final | ⏸ Reportée à la session 2.14 quinquies bis (nouvelle, créée) |
| Volet 1 | ✅ Implémenté, déployé, testé dans la limite du GPS |
| Volet 2 (migration + applicatif + filtre admin) | ✅ Implémenté, déployé |
| Incident critique (filtre admin) | ✅ Détecté par test réel, corrigé, revalidé |
| Tests de non-régression 3 rôles | ✅ Réalisés, aucune régression fonctionnelle |
| État du dépôt | ✅ Propre, HEAD 8941e0a, synchronisé |

### Reste à faire (sessions futures)

1. 🆕 Session 2.14 quinquies bis (nouvelle, priorité immédiate suivante pour ce chantier) : étudier la faisabilité et concevoir un mécanisme de filtrage par distance réel (VUL, 60 km), couplé à la connexion effective de la géolocalisation côté diffusion — en s'appuyant sur l'infrastructure déjà sécurisée et cartographiée par cette session. Éviter le recoupement avec la future table mission_offers (2.14 sexies). Corriger le rayon par défaut du wrapper (15 km → 60 km). Brancher le résultat de la géolocalisation sur le paramètre _driverLocation de subscribeToNewMissions(), actuellement présent dans la signature mais jamais rempli.
2. 🆕 Audit des permissions par défaut (GRANT) sur l'ensemble du schéma public — constat récurrent de permissions larges pour anon/authenticated, protection reposant uniquement sur RLS.
3. 🆕 Méthodologique : après toute séquence de plusieurs sed sur un même fichier, effectuer systématiquement une relecture structurelle complète avant de committer ; ne jamais considérer un CI vert comme une garantie suffisante sans un test d'exécution réelle au moins une fois par session touchant du code applicatif.
4. Test fonctionnel complet du Volet 1, de la diffusion et du filtre expired, en environnement disposant d'une géolocalisation fonctionnelle et de données réelles (device physique, Phase 4.x) — non réalisable en Codespaces.
5. Décision sur la reconstitution ou l'abandon du profil DRIVER historique orphelin (2ec2b439-..., wallet 800 DH, 4 transactions pending).
6. Rappel 24h avant scheduled_pickup_time — hors périmètre, affectation à une session future non figée.
7. Volet 2 — limite assumée (pas de garantie de nettoyage si aucun écran client n'est consulté) à réévaluer si le volume de missions réelles augmente significativement.

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
   ✅ NOUVEAU (session 2.14 quinquies) — abonnement subscribeToMissionUpdates dès réception d'une nouvelle mission pending (Volet 1) : fermeture automatique du modal de proposition si le statut de la mission change avant acceptation par ce chauffeur ; désabonnement systématique à chaque point de sortie
   ✅ ACCÈS RÉTABLI (depuis session 2.14 quinquies) pour le numéro de test partagé — nouveau profil DRIVER créé via un nouvel onboarding complet, distinct du profil historique
TransactionHistoryScreen → ✅ Écoute Realtime branchée — session 2.14 (INSERT uniquement)

⚠️ is_verified = GENERATED ALWAYS AS — devient true quand driver_license_verified, vehicle_registration_verified, insurance_verified, technical_inspection_verified = 'verified'

# CHAÎNE DE NAVIGATION ADMIN

AdminDashboardScreen → Documents en attente → DocumentReviewScreen ✅ → Toutes les missions → AdminMissionsScreen ✅ → Gestion utilisateurs → AdminUsersScreen ✅ → Wallets & Transactions → WalletManagementScreen ✅ → ✅ NotificationBell montée — session 2.14 → NotificationBell → NotificationCenterScreen ⚠️ Anomalie #1

DocumentReviewScreen → Valider/Rejeter documents driver → Notification driver via insertNotification() → Driver fully verified → DriverHomeScreen (realtime)
   ⚠️ Bug d'affichage session 2.12 : modal ne se rafraîchit pas visuellement après validation du 4e/dernier document — non traité faute de temps, reporté à une session ultérieure à assigner

WalletManagementScreen → Liste drivers vérifiés avec solde → Recharger wallet → adminTopupDriverWallet() → Solde mis à jour en temps réel ✅
   ⚠️ Ne gère pas encore les 4 demandes de recharge chauffeur en statut pending (voir Section 3) — écran de traitement dédié prévu session 2.17

AdminMissionsScreen → Liste toutes missions avec 7 filtres (dont expired, ajouté session 2.14 quinquies, incident de duplication détecté et corrigé — voir RÉSOLU 50) → Enum : pending / accepted / in_progress / completed / cancelled_client / cancelled_driver / expired

AdminUsersScreen → Liste drivers avec statut actif/suspendu → Suspendre/Activer via toggleUserActive() ⚠️ sans distinction Platform.OS

# CHAÎNE DE NAVIGATION CLIENT

CreateMissionScreen → ✅ NotificationBell montée — session 2.14 → NotificationBell → NotificationCenterScreen ⚠️ Anomalie #1
   ✅ NOUVEAU (session 2.14 quater) — champ scheduled_pickup_time désormais OBLIGATOIRE (composant DateTimeField.tsx), bouton de soumission désactivé tant qu'une date/heure valide n'est pas sélectionnée, date passée rejetée, aucun délai minimum requis
   ⚠️ Volet Client non testé fonctionnellement de bout en bout à ce jour (contrainte GPS/Codespaces) — voir Section 15/16
   ⚠️ Le numéro de test partagé occupe désormais le rôle DRIVER (depuis session 2.14 quinquies) et non plus CLIENT — aucune mission n'a été insérée en base à ce jour

MissionTrackingScreen.tsx → ✅ NOUVEAU (session 2.14 quinquies, Volet 2) — nouveau useEffect actif uniquement si status === 'pending' et scheduled_pickup_time renseigné : vérification locale toutes les 30 secondes (EXPIRATION_CHECK_INTERVAL_MS), appel de expireMission() en base uniquement si expiration détectée ; nouveau case 'expired' dans renderStatus() (message dédié + bouton de recréation de mission)
   ⚠️ Non testable en conditions réelles à ce jour — table missions vide (0 ligne)

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

**RÉSOLU 48 — Exposition de données sensibles sans authentification via les vues available_drivers et driver_dashboard (session 2.14 quinquies)**
Cause : deux vues Supabase simples (non protégées par RLS, à la différence des tables sous-jacentes), accessibles en SELECT par les rôles anon/authenticated sans aucune restriction — available_drivers exposait phone_number de tout chauffeur disponible ; driver_dashboard exposait solde wallet, commissions et recharges de tout chauffeur, sans filtre d'identité côté base (seul un filtre côté application, non fiable, existait via walletService.ts). La RPC find_nearby_drivers, SECURITY DEFINER, contournait également toute protection RLS et exposait phone_number en sortie, avec EXECUTE ouvert à anon.
Correctif : suppression de la colonne phone_number des deux points d'exposition (vue et RPC) ; révocation SELECT anon/authenticated sur available_drivers ; révocation SELECT anon + activation de security_invoker = true sur driver_dashboard ; révocation EXECUTE anon/PUBLIC sur find_nearby_drivers, conservé pour authenticated uniquement.
Fichier : supabase/migrations/20260504000017_fix_available_drivers_and_driver_dashboard_exposure.sql
Commits : 3bf1c09 (version initiale), 70b02f0 (correction de déploiement, voir RÉSOLU 49)
Confirmé : par lecture directe post-déploiement (pg_get_viewdef, role_table_grants, pg_get_functiondef, routine_privileges — tous vérifiés) ✅, et par validation fonctionnelle croisée en conditions réelles (le nouveau chauffeur test ne voit que son propre solde wallet, 0 DH puis 300 DH, jamais celui d'un autre profil) ✅

**RÉSOLU 49 — Échec initial de déploiement de la migration de sécurité, SQLSTATE 42P16 (session 2.14 quinquies)**
Précision de formulation : il s'agit d'un bug de déploiement auto-corrigé en cours de session, et non un défaut resté actif en production — le premier déploiement a échoué avant toute mise en production effective de la correction, et la correction a été appliquée et déployée avec succès dans la même session.
Cause : CREATE OR REPLACE VIEW ne permet pas de retirer une colonne existante d'une vue (cannot drop columns from view) — le premier déploiement de la migration 20260504000017 (commit 3bf1c09) a échoué sur cette erreur (Deploy Supabase FTM #47).
Correctif : remplacement de CREATE OR REPLACE VIEW par une séquence DROP FUNCTION (RPC dépendante) + DROP VIEW puis CREATE, en respectant l'ordre des dépendances.
Fichier : supabase/migrations/20260504000017_fix_available_drivers_and_driver_dashboard_exposure.sql
Commit : 70b02f0
Confirmé : déploiement réussi après correction, vérifications post-déploiement listées au RÉSOLU 48 ✅

**RÉSOLU 50 — Duplication de la déclaration STATUS_FILTERS dans AdminMissionsScreen.tsx (session 2.14 quinquies)**
Cause : une séquence de trois commandes sed appliquées successivement sur le fichier (une insertion, un remplacement de ligne, une seconde insertion) a provoqué un décalage de numérotation de lignes non anticipé après la première insertion ; le remplacement suivant, ciblant la ligne 43 avant recalcul, a produit une duplication de la déclaration STATUS_FILTERS (version correcte avec expired + résidu de l'ancienne version sans expired, jamais supprimé) plutôt qu'un remplacement propre — provoquant une SyntaxError bloquante à l'exécution (Identifier 'STATUS_FILTERS' has already been declared). Point méthodologique majeur : le CI (Vérification Qualité Code) était passé au vert sur le commit fautif — le linting TypeScript n'a pas détecté cette erreur de syntaxe. Seul un test d'exécution réelle (lancement du serveur Metro Bundler) l'a révélée.
Correctif : suppression de la ligne dupliquée (ancienne version, sans expired), conservation de la version correcte.
Fichier : frontend/src/screens/admin/AdminMissionsScreen.tsx
Commit : 8941e0a
Confirmé : par relecture complète (grep ciblé, une seule déclaration de chaque constante) ET par test d'exécution réel (serveur relancé avec succès, 7 filtres affichés dont "Expirées", écran stable, sans erreur JavaScript) ✅

⚠️ Note de numérotation : RÉSOLU 43 (RLS voice-messages) précède chronologiquement RÉSOLU 44-47 (session 2.14 quater), lesquelles précèdent RÉSOLU 48-50 (session 2.14 quinquies), suivant l'ordre chronologique réel des découvertes au sein de chaque session.

# PISTES DÉFINITIVEMENT ÉCARTÉES

Ne pas retester : ❌ locationService import statique ❌ expo-haptics / expo-notifications ❌ expo-location fallback web ❌ missionService / realtimeService ❌ react-native-screens sans fallback web ❌ NativeStackScreenProps sans type ❌ Dépendance circulaire missionService ❌ audioService / expo-av (contexte débogage page blanche — n'implique pas l'abandon de la fonctionnalité messages vocaux) ❌ supabaseClient.ts ❌ showAuth logique incorrecte ❌ ErrorBoundary capture l'erreur ❌ --no-dev résout seul ❌ 'cancelled' comme valeur enum mission_status ❌ cron.run_job(integer) ❌ owner = auth.uid() comme clause RLS Storage simple (raccourci écarté au profit de la chaîne de propriété complète, RÉSOLU 36) ❌ Modification directe du solde wallet par le chauffeur (Option B écartée, session 2.13, RÉSOLU 38) ❌ python3 -c "..." en ligne directe pour tout texte contenant un caractère spécial bash (écarté au profit du heredoc quoté, session 2.14) ❌ notifyNewMission comme fonction notify* branchable isolément (incompatibilité structurelle confirmée, session 2.14, reconfirmée 2.14 bis et 2.14 quinquies) ❌ Correction d'initializeApp() pour distribuer systématiquement profiles.id (écartée au profit de getCurrentProfileId(), session 2.14) ❌ Remplacement du canal vocal (VoiceChatScreen.tsx) par un canal texte (décision de conservation actée session 2.14 bis)
❌ Accès admin dans la clause RLS voice-messages (session 2.14 ter) — écarté par le porteur : aucun besoin métier documenté ne justifie qu'un admin lise du contenu audio privé
❌ Factorisation SQL des 4 policies voice-messages via fonction partagée (session 2.14 ter) — écartée au profit de la duplication littérale, fidèle au pattern RÉSOLU 36
❌ Test symétrique de la contrainte scheduled_pickup_time NOT NULL par insertion SQL directe (session 2.14 quater) — décision explicite du porteur, pour éviter de polluer la base de production ; jugé non nécessaire, le code applicatif ayant été vérifié à trois reprises distinctes
❌ Modification de LegalDocumentsScreen.tsx ou import direct par DateTimeField.tsx (session 2.14 quater) — hors périmètre, aucune dérogation accordée ; composant dupliqué et réécrit indépendamment
❌ CREATE OR REPLACE VIEW pour retirer une colonne existante d'une vue (session 2.14 quinquies) — écarté après échec réel (SQLSTATE 42P16), au profit d'une séquence DROP + CREATE respectant l'ordre des dépendances — voir RÉSOLU 49
❌ Mécanisme CRON pour la détection d'expiration des missions pending (session 2.14 quinquies) — écarté au profit d'une vérification locale côté client toutes les 30 secondes, sans coût réseau hors écriture en cas d'expiration détectée — décision métier du porteur

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
20260504000017_fix_available_drivers_and_driver_dashboard_exposure.sql ✅ Session 2.14 quinquies
20260504000018_add_expired_status_to_mission_status.sql ✅ Session 2.14 quinquies

Aucune migration SQL déployée en session 2.14 (session applicative/service) ni en session 2.14 bis (session investigative).

Prochain timestamp disponible : 20260504000019

Note prospective : la migration mission_offers (session 2.14 sexies proposée) consommera ce timestamp et les suivants.

# EDGE FUNCTIONS DÉPLOYÉES

send-push-notification ✅ (CORS bloqué sur web — fonctionnel sur device)
register-push-token ✅
check-document-reminders ✅ (CRON opérationnel — session 2.9, 5 exécutions succeeded 18→22/06/2026)
   ⚠️ Lien avec notifyDocumentExpiry non vérifié — non traité en 2.14 bis, 2.14 ter, 2.14 quater, ni 2.14 quinquies (hors périmètre de chacune)
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
│       │   ├── DateTimeField.tsx ← créé session 2.14 quater (commits 0da3e07 + 829f31e)
│       │   └── VoiceMicButton.tsx ← lu intégralement session 2.14 bis, aucune modification
│       ├── constants/theme.ts ← BORDER_RADIUS ajouté
│       ├── lib/supabaseClient.ts
│       ├── navigation/
│       │   └── RootNavigator.tsx ← modifié session 2.14 ; ⚠️ ne déclare TOUJOURS PAS la route 'CreateParcel' (bug découvert session 2.14 quater, assigné session 2.20)
│       ├── screens/
│       │   ├── admin/
│       │   │   ├── AdminDashboardScreen.tsx ← modifié session 2.14
│       │   │   ├── AdminMissionsScreen.tsx ← créé session 2.7 ; modifié session 2.14 quinquies (ajout filtre expired aux 3 constantes STATUS_LABELS/STATUS_FILTERS/FILTER_LABELS, commits 69273c0 puis 8941e0a — incident de duplication corrigé, voir RÉSOLU 50)
│       │   │   ├── AdminUsersScreen.tsx ← créé session 2.7
│       │   │   ├── DocumentReviewScreen.tsx
│       │   │   └── WalletManagementScreen.tsx
│       │   ├── auth/
│       │   │   ├── OTPVerificationScreen.tsx
│       │   │   ├── PhoneInputScreen.tsx
│       │   │   └── ProfileSetupScreen.tsx ← INTOUCHABLE
│       │   ├── client/
│       │   │   ├── CreateMissionScreen.tsx ← modifié sessions 2.14 + 2.14 quater (scheduled_pickup_time obligatoire, DateTimeField)
│       │   │   ├── MissionTrackingScreen.tsx ← modifié session 2.14 quinquies (Volet 2 : détection expiration locale 30s + expireMission() + case 'expired' dans renderStatus(), commit b1d2540)
│       │   │   └── RatingScreen.tsx
│       │   ├── driver/
│       │   │   ├── DocumentStatusScreen.tsx
│       │   │   ├── DriverHomeScreen.tsx ← modifié session 2.14 ; modifié session 2.14 quinquies (Volet 1 : abonnement subscribeToMissionUpdates, fermeture auto du modal, commit d1869e4)
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
│       │   ├── locationService.ts ← lu en profondeur session 2.14 quinquies (Partie 2), non modifié — startBackgroundTracking() confirmé (intervalle 15s / 50m)
│       │   ├── missionService.ts ← modifié sessions 2.14 + 2.14 quater (scheduled_pickup_time) ; modifié session 2.14 quinquies (ajout 'expired' au type MissionStatus, nouvelle fonction expireMission(), commit b1d2540) ; wrapper findNearbyDrivers() confirmé toujours non appelé, rayon par défaut 15 km à corriger (voir Section 16, 2.14 quinquies bis)
│       │   ├── notificationTemplates.ts ← lu session 2.14 quinquies (confirmation notifyNewMission incompatible par construction)
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
│   │   ├── 20260221000000_add_rpc_nearby_drivers.sql ← RPC find_nearby_drivers, code mort confirmé session 2.14 bis, sécurisée (permissions restreintes, phone_number retiré) session 2.14 quinquies (voir migration 017)
│   │   ├── … (fichiers intermédiaires inchangés) …
│   │   ├── 20260504000013_fix_storage_transactions_rls_ownership.sql ← session 2.12
│   │   ├── 20260504000014_rename_revenue_to_recharges_driver_dashboard.sql ← session 2.13
│   │   ├── 20260504000015_fix_rls_voice_messages.sql ← session 2.14 ter
│   │   ├── 20260504000016_add_scheduled_pickup_time_not_null.sql ← session 2.14 quater
│   │   ├── 20260504000017_fix_available_drivers_and_driver_dashboard_exposure.sql ← session 2.14 quinquies
│   │   └── 20260504000018_add_expired_status_to_mission_status.sql ← session 2.14 quinquies
│   └── rollbacks/
│       ├── rollback_20260504000013.sql ← session 2.12
│       ├── 20260504000014_rename_revenue_to_recharges_driver_dashboard_rollback.sql ← session 2.13
│       ├── 20260504000015_fix_rls_voice_messages_rollback.sql ← session 2.14 ter
│       ├── 20260504000016_add_scheduled_pickup_time_not_null_rollback.sql ← session 2.14 quater
│       ├── 20260504000017_fix_available_drivers_and_driver_dashboard_exposure_rollback.sql ← session 2.14 quinquies
│       └── 20260504000018_add_expired_status_to_mission_status_rollback.sql ← session 2.14 quinquies (documentaire uniquement)
├── .env.example
├── .gitignore
├── ROADMAP_FTM.md
└── install_*.sh
```

Note : ~59+ fichiers untracked de type .bak* présents dans le dépôt (mécanisme de traçabilité délibéré), dont 4 nouveaux ajoutés en session 2.14 quater (suffixe .bak.session2.14quater) et 4 nouveaux ajoutés en session 2.14 quinquies (suffixe .bak.session2.14quinquies : DriverHomeScreen.tsx, missionService.ts, MissionTrackingScreen.tsx, AdminMissionsScreen.tsx) — non représentés dans l'arborescence ci-dessus par souci de lisibilité.

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

Wallet topup : ✅ Mécanisme honnête opérationnel — session 2.13 — reconfirmé intact (données) après sessions 2.14, 2.14 bis, 2.14 ter ; accès Auth du profil porteur historique supprimé en session 2.14 quater, désormais occupé par un nouveau profil DRIVER depuis session 2.14 quinquies (voir Section 3), données du profil historique inchangées

Realtime transactions/notifications : ✅ subscribeToNewTransactions branché — session 2.14 (INSERT uniquement) — ✅ NotificationBell/Center montés 3 rôles — mécanisme confirmé Realtime événementiel (pas polling, précision session 2.14 quater)
   ✅ NOUVEAU (session 2.14 quinquies) — subscribeToMissionUpdates désormais également exploité côté DriverHomeScreen.tsx (Volet 1, fermeture automatique du modal de proposition de mission)
   ⚠️ Anomalie #1 : bouton retour manquant sur NotificationCenterScreen

Sécurité des vues Supabase exposées : ✅ CORRIGÉE — session 2.14 quinquies (RÉSOLU 48/49) — available_drivers et driver_dashboard ne sont plus accessibles sans authentification (SELECT anon révoqué), phone_number retiré des points d'exposition (vue + RPC find_nearby_drivers), security_invoker activé sur driver_dashboard, EXECUTE de la RPC restreint à authenticated. 🆕 Recommandation ouverte : audit des permissions GRANT par défaut sur l'ensemble du schéma public (voir Section 17).

Géolocalisation avancée : 🔵 Infrastructure PostGIS complète (RPC find_nearby_drivers) confirmée existante, active et désormais SÉCURISÉE (session 2.14 quinquies), intégralement cartographiée (mécanisme de diffusion, filtre de fraîcheur 5 min, suivi position chauffeur 15s/50m) — le canal Realtime de diffusion exploite désormais subscribeToMissionUpdates côté DriverHomeScreen (Volet 1). ⚠️ Le filtrage réel par distance (branchement de la RPC dans le flux de diffusion) reste non exploité — réutilisation prévue session 2.14 quinquies bis (nouvelle), avec correction du rayon par défaut du wrapper (15 km → 60 km) et branchement du paramètre _driverLocation de subscribeToNewMissions().

Planification par date/heure : ✅ OPÉRATIONNELLE — session 2.14 quater — scheduled_pickup_time obligatoire (NOT NULL + UI), transport classique et e-commerce
   ✅ Volet 2 (expiration mission pending à scheduled_pickup_time dépassé) — implémenté session 2.14 quinquies : détection locale côté MissionTrackingScreen.tsx (30s), fonction expireMission(), nouveau statut expired, filtre admin correspondant
   ⚠️ Flux e-commerce non testable en pratique tant que le bug de navigation CreateParcel n'est pas corrigé (session 2.20)

# BUGS RÉSIDUELS

⚠️ CORS send-push-notification Edge Function bloquée par CORS policy sur web — non bloquant web, fonctionnel sur device physique — à corriger pour production

⚠️ Filtres AdminMissionsScreen — affichés mais aucune mission en base — cause confirmée (GPS bloqué environnement web/Codespaces) — reporté phase 4.x — 7 filtres désormais disponibles depuis session 2.14 quinquies (dont expired)

⚠️ Realtime driver end-to-end — flux avec 2 fenêtres simultanées non testé explicitement

⚠️ AdminMissions pagination — non testée (0 missions en base)

⚠️ DocumentReviewScreen.tsx — rafraîchissement modal (session 2.12) — non traité faute de temps, reporté à une session ultérieure à assigner

⚠️ Driver test historique (données intactes, accès Auth occupé par un nouveau profil depuis session 2.14 quinquies) — voir Section 3 pour l'état complet :
   driverId : 2ec2b439-fcdb-443d-8de0-5bee268d30f6 (données en base uniquement, aucun accès Auth actif depuis session 2.14 quater — le numéro partagé est occupé par un profil DRIVER distinct depuis session 2.14 quinquies)
   wallet_balance réel : 800.00 DH — 4 demandes en pending (50/200/500/1000 DH) — à ne pas altérer sans décision explicite (preuve de fonctionnement du correctif RÉSOLU 38)

⚠️ Dossiers Storage orphelins (session 2.12) — driver-documents : 8 orphelins + 1 actif — aucune session de nettoyage planifiée

⚠️ COMPORTEMENT NON EXPLIQUÉ — repr() vs terminal (session 2.9) — statut INCONNU, non bloquant

⚠️ Navigation cross-stack PendingVerification → DriverHome — navigation.replace('DriverHome') cible un écran absent du stack DriverPendingStack — NON traité à ce jour (2.13, 2.14, 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies) — bug entier, session à assigner

⚠️ subscribeToNewTransactions — limitation résiduelle : écoute INSERT uniquement, pas UPDATE

⚠️ AdminUsersScreen.tsx — Alert.alert sans Platform.OS — candidat audit session 2.19

⚠️ WalletTopupScreen.tsx ligne 66 — message d'erreur non vérifié — candidat audit session 2.19

⚠️ Coexistence total_commissions / commissions_current_month — à surveiller lors du chantier reporting financier (Section 17)

⚠️ Risque de pagination totalCredit/totalDebit (TransactionHistoryScreen.tsx) — à surveiller lors du chantier reporting financier (Section 17)

⚠️ Anomalie #1 — Absence de bouton "← Retour" sur NotificationCenterScreen.tsx — non bloquant, à corriger avant Phase 3, candidat audit session 2.19 — reconfirmée en conditions réelles session 2.14 quinquies (tests CLIENT)

⚠️ 4 fonctions notify* mission non testées fonctionnellement — nécessite un second numéro de test dédié au rôle client (voir Section 17). Point réactualisé session 2.14 quinquies : le numéro partagé étant redevenu DRIVER, ce test reste bloqué à la fois par l'absence de second numéro CLIENT et par l'environnement (GPS Codespaces).

⚠️ Cloche NotificationBell côté Client non testée en conditions réelles — reportée avec le test du Volet 4

⚠️ Chemin natif (hors web) non testé — Alert.alert/Platform.OS (RÉSOLU 42) — à vérifier Phase 4

⚠️ Point de sécurité cancelMission/userId — le renommage de paramètre (_userId → userId) est confirmé effectif dans le code (vérifié par lecture directe, session 2.14 quater), mais AUCUNE vérification d'autorisation n'a été ajoutée — le point de sécurité de fond reste entier, rattaché à la session 2.17 (décision actée session 2.14, reconfirmée pertinente session 2.14 quater)

⚠️ notifyDocumentExpiry — en attente, lien check-document-reminders non vérifié — non traité en 2.14 bis, 2.14 ter, 2.14 quater, ni 2.14 quinquies

⚠️ Bug de reconnexion clientProfileId vide (RootNavigator.tsx) — découverte annexe session 2.14, hors périmètre, session future non assignée

⚠️ Robustesse topupWallet/refundWallet (échec silencieux insertion transaction) — découverte annexe session 2.14, à vérifier lecture directe début session 2.17

⚠️ VoiceChatScreen.tsx orphelin + dossier ecommerce/ (approfondi 2.14 bis) — canal conservé, activation planifiée session 2.14 septies ; dossier ecommerce/ désormais partiellement exploré (session 2.14 quater : CreateParcelScreen.tsx et parcelService.ts modifiés pour scheduled_pickup_time, bug de navigation découvert), reste non exploré en profondeur au-delà de ce périmètre strict

🔵 Points ouverts non tranchés (Piste 2, négociation de prix, session 2.14 bis) : devenir sémantique de negotiated_price ; extension éventuelle au flux ecommerce_parcels — décisions renvoyées à la session 2.14 sexies

⚠️ Countdown par tour non contraignant sans vérification serveur (Piste 2, session 2.14 bis) — point de conception à traiter en session 2.14 sexies

⚠️ NOUVEAU (session 2.14 ter) — Correction de cohérence documentaire, décompte transactions pending : le présent document mentionnait auparavant "3 demandes de recharge en pending (200/500/1000 DH)" pour le driver test 2ec2b439-... — décompte corrigé en 4 demandes (50/200/500/1000 DH), confirmé par lecture directe des dates de création. La transaction de 50 DH (14/07/2026) est une donnée de test antérieure à la session 2.12, non anormale. Cette correction a été répercutée dans toutes les sections concernées du présent document (Section 3, Section 6).

⚠️ NOUVEAU (session 2.14 quater) — Route de navigation CreateParcel manquante : la route 'CreateParcel', appelée par ParcelHistoryScreen.tsx (navigation.navigate('CreateParcel')), n'est déclarée dans aucun fichier de frontend/src/navigation/ — l'écran CreateParcelScreen.tsx (pourtant modifié cette même session pour intégrer scheduled_pickup_time) reste inaccessible depuis l'UI normale. Bug préexistant, sans rapport avec la session 2.14 quater. Assigné à la session 2.20.

⚠️ NOUVEAU (session 2.14 quater) — Points d'enrichissement fonctionnel non traités liés à scheduled_pickup_time : notifyRecipientBySMS (SMS destinataire colis) et getClientParcels (historique client) pourraient à l'avenir inclure scheduled_pickup_time dans leur contenu/sélection — hors périmètre strict de la dérogation accordée en session 2.14 quater, consigné pour référence future, aucune session assignée à ce stade.

⚠️ NOUVEAU (session 2.14 quater) — Points techniques mineurs DateTimeField.tsx : décalage de fuseau horaire (toISOString() en UTC, hérité de LegalDocumentsScreen.tsx) ; borne min de <input type="date"> figée au rendu initial (cas limite formulaire ouvert plusieurs heures) ; cas limite '' vs null sur localDateStr/localTimeStr ; comportement iOS display="spinner" fermant le picker au premier onChange (hérité de DateField d'origine). Aucun jugé bloquant ni prioritaire, consignés pour référence future.

⚠️ NOUVEAU (session 2.14 quinquies) — Volet 2, limite assumée : une mission pending expirée reste techniquement en base tant qu'aucun écran client ne la consulte (pas de mécanisme de nettoyage automatique côté serveur) — compromis explicitement accepté pour cette phase (0 mission en base à ce jour), à réévaluer si le volume réel de missions augmente.

⚠️ NOUVEAU (session 2.14 quinquies) — Wrapper findNearbyDrivers() (missionService.ts) : rayon par défaut de 15 km dans sa signature, alors que le paramètre validé pour le projet est 60 km — origine de cet écart INCONNUE, à corriger lors du futur branchement (session 2.14 quinquies bis, voir Section 16).

# TESTS DE NON-RÉGRESSION

[Sessions 2.7 à 2.14 bis — inchangées, reprises intégralement à l'identique de la version du 11/08/2026. Voir document source. Ajout des sessions 2.14 ter, 2.14 quater et 2.14 quinquies ci-dessous.]

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

**SESSION 2.14 quinquies — TESTS EFFECTUÉS ET CONFIRMÉS ✅ :**

Méthode : serveur de développement lancé (2 incidents réseau transitoires vers api.expo.dev — "Client network socket disconnected before secure TLS connection was established" — résolus par simple relance, cohérent avec l'Incident 2 déjà documenté en session 2.14 ter). Ordre pragmatique CLIENT → ADMIN → DRIVER (exception assumée à l'ordre standard, justifiée par l'efficacité pratique — occasion de reconnecter le profil DRIVER).

| Rôle | Résultat | Détail |
|---|---|---|
| CLIENT | ✅ Aucune régression | CreateMissionScreen (avec DateTimeField.tsx de 2.14 quater) fonctionnel. NotificationCenterScreen fonctionnel — Anomalie #1 reconfirmée en conditions réelles. GPS bloqué (confirmé : GPS - Client location permission denied). |
| ADMIN | ✅ Aucune régression | Dashboard, gestion missions (7 filtres dont expired), validation documents (4/4), gestion wallet (recharge 300 DH validée) — tous fonctionnels. |
| DRIVER | ✅ Aucune régression | Onboarding complet réalisé (nouveau profil créé, 4 documents soumis et validés). Validation admin réussie (CORS send-push-notification confirmée, limitation déjà documentée). Recharge wallet fonctionnelle (0 → 300 DH). Accès à DriverHomeScreen (modifié pour Volet 1) réussi. Activation de disponibilité bloquée au niveau GPS comme attendu, gestion propre de l'échec (sans crash), empêchant le test du canal de diffusion jusqu'au bout. Vérification fonctionnelle croisée : le chauffeur test ne voit que son propre solde wallet — validation pratique de RÉSOLU 48 (security_invoker). |

**SESSION 2.14 quinquies — TESTS NON EFFECTUÉS (justifiés) :**
- Filtrage réel avec au moins une mission au statut expired — impossible en pratique, table missions restée vide (0 ligne) tout au long de la session.
- Activation complète de la disponibilité chauffeur et diffusion géospatiale de bout en bout — bloquée par le GPS (Codespaces/iframe), limitation déjà documentée.

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

2.14 quinquies ✅ COMPLET (avec réserves) — Piste 1, sécurisation de l'infrastructure de diffusion + Volets 1/2 expiration
   → Périmètre initial élargi sur décision explicite du porteur pour traiter une faille de sécurité découverte fortuitement (Étape 1.3) : exposition sans authentification de available_drivers et driver_dashboard (phone_number, solde wallet, commissions) — corrigée et vérifiée ✅ (RÉSOLU 48/49)
   → Volet 1 implémenté et déployé : fermeture automatique du modal de proposition de mission via subscribeToMissionUpdates (commit d1869e4) ✅
   → Volet 2 implémenté et déployé : migration enum expired (commit ffd62e8), fonction expireMission() + détection locale 30s (commit b1d2540), filtre admin (commits 69273c0 → 8941e0a) ✅
   → Incident critique détecté et corrigé : duplication STATUS_FILTERS, non détectée par le CI, révélée par test d'exécution réel — RÉSOLU 50, leçon méthodologique consolidée Section 2
   → Tests de non-régression 3 rôles (CLIENT/ADMIN/DRIVER) : ✅ aucune régression, ordre CLIENT→ADMIN→DRIVER justifié par l'efficacité pratique
   → ⚠️ Branchement final du filtrage géospatial réel par distance NON réalisé — reporté à la nouvelle session 2.14 quinquies bis
   → ⚠️ Filtrage effectif du statut expired NON testé (table missions vide)
   → Rotation du numéro de test partagé : CLIENT → DRIVER (nouvel onboarding complet, nouveau profil distinct du profil historique)
   → Nouvelle recommandation : audit des permissions GRANT par défaut sur le schéma public (Section 17)

**2.14 quinquies bis ⏳ NOUVELLE SESSION — Branchement effectif de la diffusion géospatiale**
   → Concevoir et implémenter le filtrage réel par distance (catégorie VUL, rayon 60 km depuis pickup_location), en s'appuyant sur l'infrastructure sécurisée et cartographiée en session 2.14 quinquies
   → Corriger le rayon par défaut du wrapper findNearbyDrivers() (15 km → 60 km, origine de l'écart INCONNUE)
   → Brancher le résultat de la géolocalisation sur le paramètre _driverLocation de subscribeToNewMissions(), actuellement présent dans la signature mais jamais rempli
   → Éviter le recoupement avec la future table mission_offers (session 2.14 sexies)
   → Priorité immédiate suivante pour ce chantier, positionnée juste après 2.14 quinquies dans l'ordre logique

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
   → Positionnée en fin de séquence du chantier processus de mission, sans dépendance avec les pistes 2.14 quinquies/quinquies bis/sexies/septies

PHASE 3 — SERVICES EXTERNES
3.1 ⏳ Twilio SMS / 3.2 ⏳ FCM Android / 3.3 ⏳ APNs iOS

PHASE 4 — TESTS DEVICE PHYSIQUE
4.1 ⏳ Tests Expo Go Android / 4.2 ⏳ Tests Expo Go iOS
4.3 ⏳ Tests utilisateurs réels — inclut désormais : chemin natif Alert.alert() (RÉSOLU 42), test complet Volet 4 (4 notify* mission) + cloche Client, soumission complète du flux transport avec scheduled_pickup_time (bloquée par GPS en environnement Codespaces), ET (nouveau, session 2.14 quinquies) test fonctionnel complet du Volet 1 (fermeture auto du modal), de la diffusion géospatiale réelle (une fois branchée en 2.14 quinquies bis) et du filtre admin expired, en environnement disposant d'une géolocalisation fonctionnelle et de données réelles — non réalisable en Codespaces
4.4 ⏳ Intégrer messages vocaux dans MissionTrackingScreen (audioService.ts + bucket voice-messages prêts, RLS désormais sécurisée depuis 2.14 ter) — UI à construire — inclut le test fonctionnel complet de la clause RLS voice-messages en conditions réelles (report actée session 2.14 ter)

PHASE 5 — BUILD EAS
5.1 à 5.3 ⏳ — Environnement de staging à évaluer avant cette phase (proposé session 2.13), non déclenché

PHASE 6 — AMÉLIORATIONS POST-TESTS
6.1 à 6.5 ⏳/✅ [statuts inchangés, voir Section 6]
6.6 ✅/✅ SÉCURITÉ — RLS Storage : driver-documents ✅ (2.12), voice-messages ✅ CORRIGÉE (2.14 ter) — reste test fonctionnel Phase 4.4

PHASE 7 — PUBLICATION
7.1 ⏳ Google Play Store / 7.2 ⏳ Apple App Store

# RECOMMANDATIONS STRATÉGIQUES EN ATTENTE D'ARBITRAGE PORTEUR

(issues des sessions 2.13, 2.14, 2.14 bis, 2.14 ter, 2.14 quater et 2.14 quinquies, non déclenchées dans l'immédiat)

✅ RÉSOLUE — Correction de sécurité RLS voice-messages : traitée en session 2.14 ter (RÉSOLU 43). Reste seulement le test fonctionnel en Phase 4.4/session 2.18.
✅ RÉSOLUE — Correction de sécurité vues available_drivers/driver_dashboard : traitée en session 2.14 quinquies (RÉSOLU 48/49).
Audit systématique Alert.alert() — tous les usages du projet — idéalement session 2.19, avant Phase 3 active. Portée élargie : chemin natif non testé pour 3 fichiers déjà corrigés.
Environnement de staging — à évaluer avant Phase 5 (Build EAS) — décision et calendrier à trancher par le porteur.
Refonte du reporting financier — trois mécanismes de calcul non harmonisés — étude de faisabilité à programmer, hors périmètre 2.13.
Notification admin en temps réel sur nouvelle demande de recharge — renvoyée à la session 2.17.
Second numéro de test dédié au rôle client — nécessaire pour le test complet du Volet 4 et de la cloche côté client. Point réactualisé session 2.14 quinquies : le numéro partagé étant redevenu DRIVER, cette recommandation reste pleinement d'actualité — aucun profil CLIENT n'est aujourd'hui disponible en parallèle d'un profil DRIVER.
Anomalie #1 — bouton "← Retour" manquant NotificationCenterScreen.tsx — non bloquante, rattachement session 2.19 ou point autonome, décision du porteur.
notifyDocumentExpiry — lien check-document-reminders non vérifié — à statuer isolément, session future.
Bug de reconnexion clientProfileId vide (RootNavigator.tsx) — à documenter, session future non assignée.
Robustesse topupWallet/refundWallet — à vérifier par lecture directe en tout début de session 2.17.
subscribeToDriverLocation (realtimeService.ts) — suivi de position en temps réel, non exploité, aucune session dédiée proposée à ce stade.
NOUVELLE (session 2.14 quater) — Décision sur la reconstitution du profil DRIVER historique (2ec2b439-..., wallet 800 DH, 4 transactions pending) pour le numéro de test partagé, actuellement orphelin d'accès Auth — décision et calendrier à trancher par le porteur. Point inchangé à l'issue de la session 2.14 quinquies : ce profil reste orphelin, distinct du nouveau profil DRIVER désormais actif sur le numéro partagé.
NOUVELLE (session 2.14 quater) — Enrichissement fonctionnel scheduled_pickup_time : notifyRecipientBySMS et getClientParcels pourraient à l'avenir inclure ce champ — piste non assignée, à arbitrer.
NOUVELLE (session 2.14 quater) — Correction route CreateParcel — voir session 2.20 déjà créée pour ce traitement (Section 16).
NOUVELLE (session 2.14 quater) — Point de sécurité cancelMission/userId — le renommage de paramètre est en place mais la vérification d'autorisation elle-même reste absente ; recommandation reconfirmée pour la session 2.17 (déjà actée session 2.14, reconfirmée pertinente et non résolue par le renommage de paramètre observé en 2.14 quater).
🆕 NOUVELLE (session 2.14 quinquies) — Audit des permissions par défaut (GRANT) sur l'ensemble du schéma public : constat récurrent, lors de l'investigation de la faille de sécurité, de permissions larges accordées à anon/authenticated sur des objets autres que les deux vues déjà corrigées, la protection reposant alors uniquement sur RLS — à programmer, aucune session dédiée assignée à ce stade.
🆕 NOUVELLE (session 2.14 quinquies) — Renforcement méthodologique CI/exécution réelle : après toute séquence de plusieurs commandes sed sur un même fichier, effectuer systématiquement une relecture structurelle complète avant de committer ; ne jamais considérer un statut CI vert comme une garantie suffisante sans un test d'exécution réelle au moins une fois par session touchant du code applicatif — règle déjà consolidée en Section 2, recommandation de vigilance continue pour toutes les sessions futures.

# 18. ANNEXE — INVESTIGATION SESSION 2.14 — PROCESSUS DE CRÉATION DE MISSION : ÉTAT ACTUEL ET PISTES D'AMÉLIORATION

[Contenu inchangé — reprise intégrale du point zéro de l'investigation, préservé tel quel sans réécriture, y compris l'avertissement de numérotation entre les deux systèmes Piste 1-4. Voir version du 11/08/2026 pour le texte complet des sections § 1 à § 5 et du § TRI.]

Mise à jour de statut (session 2.14 quater) : la Piste "Planification par date/heure" (§ TRI, Piste 2 dans la numérotation de cette section / Piste 3 dans la numérotation de la Section 18 bis et du corps du document) est désormais **traitée** — voir Section 6, bloc "SESSION 2.14 quater", et RÉSOLU 47.

Mise à jour de statut (session 2.14 quinquies) : la Piste "Diffusion optimisée" (§ TRI, Piste 1) est **partiellement traitée** — l'infrastructure de diffusion (RPC find_nearby_drivers, vue available_drivers) a été sécurisée (faille corrigée, voir RÉSOLU 48/49) et intégralement cartographiée, et les Volets 1 (retrait de la diffusion à l'acceptation) et 2 (expiration) ont été implémentés et déployés — voir Section 6, bloc "SESSION 2.14 quinquies". Le branchement du filtrage réel par distance reste en attente, reporté à la session 2.14 quinquies bis (nouvelle).

# 18 bis. ANNEXE — SESSION 2.14 bis — SYNTHÈSE DE L'INVESTIGATION ET PLAN D'ACTION (PROCESSUS DE CRÉATION DE MISSION)

[Contenu inchangé — reprise intégrale.]

Synthèse ultra-condensée pour navigation rapide — MISE À JOUR :
Piste 1 (diffusion) : 🔵 Infrastructure sécurisée, Volets 1 et 2 traités — session 2.14 quinquies (voir RÉSOLU 48/49/50) ; branchement du filtrage réel par distance — ⏳ 2.14 quinquies bis (nouvelle)
Piste 2 (négociation) : nouvelle table + refonte du verrou — ⏳ 2.14 sexies, la plus lourde
Piste 3 (planification) : champ obligatoire — ✅ TRAITÉE, session 2.14 quater (voir RÉSOLU 47)
Piste 4 (canal vocal) : conservé, activation en dernier — ⏳ 2.14 septies, dépendance double (2.14 quater livrée, 2.14 sexies restante)
Hors piste : sécurité voice-messages — ✅ TRAITÉE, session 2.14 ter (voir RÉSOLU 43) ; sécurité available_drivers/driver_dashboard — ✅ TRAITÉE, session 2.14 quinquies (voir RÉSOLU 48/49)

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
NOUVEAU — Un CI vert (Vérification Qualité Code) ne garantit pas que le code compile/s'exécute réellement : après toute séquence de plusieurs sed sur un même fichier, relecture structurelle complète + test d'exécution réel obligatoires (règle consolidée session 2.14 quinquies, suite au bug de duplication STATUS_FILTERS)
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
✅ Vues available_drivers / driver_dashboard SÉCURISÉES (session 2.14 quinquies) — phone_number retiré, SELECT anon révoqué, security_invoker activé sur driver_dashboard — voir RÉSOLU 48/49
⚠️ Numéro de test partagé +212600000000 : ACTUELLEMENT EN RÔLE DRIVER depuis session 2.14 quinquies — nouveau profil créé via nouvel onboarding complet (is_verified = true, wallet 300 DH, catégorie VUL, 4 documents validés). Le profil DRIVER historique (2ec2b439-..., wallet 800 DH, 4 transactions pending) reste orphelin d'accès Auth, données intactes en base — ce n'est pas un second profil équivalent utilisable. Un seul rôle actif à la fois — envisager un second numéro dédié au rôle Client avant toute session nécessitant un parcours de mission complet (Client + Driver simultanés).
✅ RLS voice-messages CORRIGÉE (session 2.14 ter) — reste le test fonctionnel en Phase 4.4/session 2.18
✅ scheduled_pickup_time OBLIGATOIRE (NOT NULL) depuis session 2.14 quater — transport ET e-commerce
✅ Volets 1 (fermeture auto modal) et 2 (expiration mission pending) OPÉRATIONNELS depuis session 2.14 quinquies — nouveau statut mission_status = 'expired'
⚠️ Bug découvert : route 'CreateParcel' non déclarée en navigation — session 2.20 à traiter
Chantier "amélioration processus de création de mission" : 2.14 ter ✅, 2.14 quater ✅, 2.14 quinquies ✅ (avec réserves) — restent 2.14 quinquies bis (priorité immédiate, branchement diffusion réelle), 2.14 sexies, 2.14 septies — voir Section 6/17/18 bis pour dépendances
Prochain timestamp migration : 20260504000019

OBJECTIF SESSION : [Décrire précisément]

ERREUR ACTUELLE : [Coller l'erreur si applicable]
