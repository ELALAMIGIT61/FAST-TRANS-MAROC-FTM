ROADMAP-DOCUMENT DE REFERENCE SESSION CLAUDE — FAST TRANS MAROC — VERSION 09/09/2026

Fast Trans Maroc — Application Mobile Marocaine
Dernière mise à jour : 09/09/2026

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
   Prochain timestamp ≥ 20260504000024
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
✅ NOUVEAU — Vérification systématique de `git status` avant tout commit — règle consolidée session 2.14 sexies : appliquée avec constance tout au long de la session, elle a permis de détecter concrètement une omission réelle (fonction `getMissionById()` conçue et validée par relecture croisée, mais omise lors de la première transmission de commande d'écriture — un seul fichier modifié au lieu de deux attendus, corrigé avant tout commit grâce à cette vérification). À appliquer systématiquement avant chaque commit, en complément (et non en remplacement) de la règle CI vert/test d'exécution réel ci-dessus.
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
⚠️ NOTE DE VOCABULAIRE (session 2.14 sexies) : le compte-rendu de cette session qualifie RootNavigator.tsx de "fichier protégé" en raison du volume de modifications qu'il y a subies (9 modifications cumulées dans la seule session 2.14 sexies). Cette qualification est propre au vocabulaire de ce compte-rendu — RootNavigator.tsx NE figure PAS dans la liste ⛔ officielle ci-dessus, et rien dans les documents reçus ne documente une décision explicite du porteur de l'y ajouter. Il ne s'agit donc pas d'une règle ⛔ nouvelle, mais d'un simple rappel de vigilance vu le nombre de sessions ayant modifié ce fichier (2.14, 2.14 quater [import DateTimeField non concerné], 2.14 sexies) — voir Section 6, bloc session 2.14 sexies, pour le détail des modifications.
⚠️ COMPTE ADMIN +212600000001
   NE JAMAIS SUPPRIMER CE PROFIL
   Même entre les tests
⚠️ NUMÉRO PARTAGÉ +212600000000 — CLIENT OU DRIVER (exclusif)
   Le même numéro ne peut avoir qu'UN profil actif à la fois (recherche par user_id, suppression Auth = cascade profil/driver)
   ⚠️ ÉTAT ACTUEL (depuis session 2.14 sexies) : rôle DRIVER — nouveau profil créé via un nouvel onboarding complet durant la session 2.14 sexies, driverId a53521ca-c776-4b57-8370-5d934f2bb416, is_verified = true, wallet 1000.00 DH (recharge admin validée), catégorie véhicule VUL, 4 documents légaux soumis et validés. Ce nouveau profil est distinct de tous les profils DRIVER antérieurs (2ec2b439-... historique, et celui créé en session 2.14 quinquies) : il ne s'agit PAS d'une reconstitution de l'un de ces profils, mais d'un profil entièrement nouveau. Les profils antérieurs restent orphelins de tout accès Auth, leurs données restant intactes en base — voir bloc dédié Section 3.
   ⚠️ CHAÎNON DE ROTATION NON DOCUMENTÉ (signalé lors de l'actualisation du 09/09/2026) : le compte-rendu de la session 2.14 sexies indique que le numéro partagé était "déjà en CLIENT" au moment de démarrer sa séquence de tests de non-régression, alors que l'état documenté à l'issue de la session 2.14 quinquies bis (28/08/2026) était DRIVER, sans rotation décidée durant cette session (le porteur ayant explicitement choisi de préserver le profil DRIVER actif plutôt que d'effectuer une rotation). Aucun des trois documents reçus pour la présente actualisation ne documente l'événement de rotation DRIVER→CLIENT qui a dû se produire entre le 28/08/2026 et le 09/09/2026. Ce chaînon est donc explicitement signalé comme une lacune de traçabilité plutôt que reconstitué par déduction — les caractéristiques de ce profil CLIENT intermédiaire (s'il a existé) sont INCONNUES.
   ⚠️ Limitation confirmée à nouveau sessions 2.14, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis et 2.14 sexies : absence de second numéro de test dédié au rôle client — a empêché tout test de bout en bout nécessitant simultanément un profil CLIENT et un profil DRIVER distincts, y compris désormais le test complet du parcours de négociation de prix (offre → contre-offre → double acceptation) introduit en session 2.14 sexies — recommandation transmise en Section 17.

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
Session 2.14 quinquies : ROTATION — le compte Auth CLIENT ("TEST CLIENT FTM") a été supprimé dans le cadre des tests de non-régression, et un nouvel onboarding DRIVER complet a été réalisé sur le numéro partagé. Nouveau profil DRIVER créé et validé (is_verified = true, wallet 300 DH, catégorie VUL, 4 documents validés) — distinct du profil DRIVER historique 2ec2b439-..., toujours orphelin d'accès Auth et inchangé.
Session 2.14 quinquies bis : AUCUNE ROTATION — le profil DRIVER créé en session 2.14 quinquies a été conservé et réutilisé tel quel. Décision explicite du porteur de préserver ce profil DRIVER actif plutôt que d'effectuer une rotation pour tester le rôle CLIENT (CreateMissionScreen.tsx n'étant pas modifié dans cette session, le risque de régression côté Client a été jugé nul) — voir Section 6, bloc session 2.14 quinquies bis.
Session 2.14 sexies : ⚠️ CHAÎNON NON DOCUMENTÉ, PUIS ROTATION FINALE — le compte-rendu de cette session indique le numéro partagé "déjà en CLIENT" au démarrage de sa séquence de tests, sans qu'aucun document reçu ne documente l'événement de rotation DRIVER→CLIENT correspondant (voir avertissement ci-dessus). En fin de session, ROTATION vers DRIVER : nouvel onboarding complet réalisé (VehicleInfo → LegalDocuments → DocumentUpload → PendingVerification), nouveau profil créé et validé (driverId a53521ca-c776-4b57-8370-5d934f2bb416, is_verified = true, wallet 1000 DH, catégorie VUL, 4 documents validés) — distinct de tous les profils antérieurs. Le compte-rendu précise que "les profils CLIENT et DRIVER antérieurs à cette session (créés lors de rotations précédentes, dont un profil client sans historique de mission) restent orphelins en base, données intactes mais sans accès Auth actif" — confirmation indirecte qu'un profil CLIENT est bien passé par ce numéro entre les deux sessions, sans que ses caractéristiques précises (identifiant, éventuelles données) ne soient documentées dans les sources reçues.

Si un test DRIVER est à nouveau nécessaire (depuis un état CLIENT) :
   Supprimer +212600000000 dans Supabase Auth
   Reconnexion → ProfileSetupScreen → sélectionner "Driver"
   Remplir à nouveau les 4 pages onboarding : VehicleInfo → LegalDocuments → DocumentUpload → PendingVerification
   Validation admin requise pour is_verified=true
   Wallet à recréditer manuellement si besoin — NOTE : les profils historiques (2ec2b439-..., wallet 800 DH ; profil de session 2.14 quinquies) ne seront pas automatiquement récupérés par cette procédure (nouvel onboarding = nouveau driverId), sauf action explicite de récupération des données existantes

Si un test CLIENT est à nouveau nécessaire depuis un état DRIVER :
   Supprimer +212600000000 dans Supabase Auth
   Reconnexion → ProfileSetupScreen → sélectionner "Client"
   ⚠️ Depuis session 2.14 sexies, l'état actuel du numéro partagé est DRIVER (nouveau profil a53521ca-...) — cette procédure sera nécessaire pour tout futur test CLIENT, y compris pour tester enfin le parcours de négociation de prix de bout en bout (nécessite CLIENT + DRIVER simultanés — voir Section 15/17, limitation confirmée non résolue).

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
   Privilégier la chaîne de propriété complète (storage.foldername(name)[n]::uuid = <table pivot>.id → ... → profiles.user_id = auth.uid()) plutôt qu'un raccourci type owner = auth.uid() — session 2.12, confirmé et étendu session 2.14 ter (double chaîne client + chauffeur via UNION, voir Section 6). Ce même modèle de chaîne double a servi de référence directe pour la conception des policies de la nouvelle table mission_offers en session 2.14 sexies (voir Section 6, bloc session 2.14 sexies), avec une adaptation notable : côté chauffeur, accès direct via driver_id porté par la ligne d'offre elle-même, sans jointure vers missions.driver_id (qui reste NULL pendant toute la durée de la négociation).
✅ Fichier de rollback obligatoire pour toute migration RLS sensible : à placer dans supabase/rollbacks/ (hors du dossier migrations/, pour éviter toute exécution automatique non désirée) — convention introduite session 2.12, reconduite systématiquement depuis (2.13, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, 2.14 sexies).
✅ Convention étendue session 2.13 : rollback créé par précaution même pour une migration non-RLS (renommage de vue, contrainte NOT NULL), avec commentaire explicite précisant qu'un rollback SQL seul est insuffisant en cas de déploiement partiel et nécessite un git revert coordonné du code applicatif. Précision session 2.14 quater : pour une contrainte NOT NULL, l'ordre des opérations en cas de rollback complet est impératif — SQL d'abord (retrait de la contrainte), git revert du code applicatif ensuite, jamais l'inverse, sous peine de bloquer toute création de mission. Précision session 2.14 quinquies : pour un ajout de valeur d'enum (ALTER TYPE ... ADD VALUE), un rollback complet (retrait de la valeur) n'est pas trivialement automatisable en toute sécurité par PostgreSQL — rollback documentaire uniquement, procédure manuelle à documenter en cas de besoin réel.
⚠️ Isoler une clause RLS via fetch() authentifié direct (sans passer par le code applicatif, ex. topupWallet()) peut produire des valeurs déclaratives trompeuses (ex. balance_after renseigné manuellement dans une ligne de test) — toujours vérifier la valeur réelle en base (ex. wallet.balance) plutôt que de se fier au contenu de la ligne insérée manuellement — session 2.12
⚠️ Alert.alert() (React Native) ne s'affiche pas sur web
   Toujours prévoir Platform.OS === 'web' ? window.alert(...) : Alert.alert(...) pour tout message destiné à s'afficher aussi sur web — bug redécouvert session 2.13 (WalletTopupScreen.tsx ligne 70, cf. RÉSOLU 41) après un premier correctif partiel en session 2.8 (AdminUsersScreen.tsx, sans généralisation Platform.OS) — voir audit recommandé section 17
✅ Pattern réappliqué avec succès session 2.14 sur PendingVerificationScreen.tsx (alerte Realtime) — voir RÉSOLU 42.
⚠️ Chemin natif (hors web) toujours non testé à ce jour sur aucun des fichiers concernés — environnement de développement limité au web (Codespaces) — audit systématique proposé (session 2.19) reste pertinent
⚠️ CLARIFICATION MÉTIER FONDAMENTALE (rappelée sessions 2.13, 2.14, 2.14 bis, à ne jamais perdre) : le paiement de la course est TOUJOURS hors application — le client paie directement le chauffeur (espèces ou autre moyen), sans jamais transiter par FTM. Seule la COMMISSION (montant fixe selon catégorie de véhicule) est prélevée automatiquement sur le wallet du chauffeur à chaque mission terminée (trigger process_commission_payment). Le wallet n'est donc alimenté QUE par les recharges (jamais par un paiement client), et diminué QUE par les commissions. Cette clarification est la raison structurelle du renommage revenue_current_month → recharges_current_month (RÉSOLU 39) — à garder impérativement en tête pour toute session touchant au workflow financier (notamment 2.17), pour éviter de reproduire la même confusion de nommage ou de conception ailleurs.
⚠️ negotiated_price (CreateMissionScreen.tsx) ne représente jamais un montant transitant par FTM, uniquement une base d'accord hors app entre client et chauffeur — principe reconfirmé session 2.14 bis (Piste 2, négociation de prix structurée). MISE À JOUR (session 2.14 sexies) : le mécanisme de négociation structurée est désormais tranché et implémenté — table mission_offers, schéma en 2 tours avec double acceptation symétrique (voir Section 6, bloc session 2.14 sexies). Le devenir sémantique de negotiated_price est concrètement fixé par le trigger sync_mission_on_offer_accepted() : à l'acceptation finale d'une offre, missions.negotiated_price est mis à jour avec la valeur réellement négociée (offered_price de l'offre acceptée). negotiated_price reste, comme toujours, une base d'accord hors app — ce principe demeure inchangé, seul le mécanisme qui alimente ce champ est désormais structuré plutôt que déclaratif au moment de la création de mission.
✅ Composant DateTimeField.tsx (session 2.14 quater) : sur le modèle des composants Alert.alert()/Platform.OS, ce composant nécessite lui aussi un traitement différencié web/natif (@react-native-community/datetimepicker strictement natif, aucun support web). Toujours vérifier avant tout usage : (1) mémoïsation React.memo si le composant contrôle un champ de saisie texte, pour éviter la corruption de saisie par re-rendu en boucle ; (2) séparation onChange (état local) / onBlur (validation finale) pour tout <input type="date"/"time"> HTML, le navigateur déclenchant onChange dès qu'une valeur techniquement complète est formée, avant la fin de la saisie utilisateur — voir RÉSOLU 44/45/46, session 2.14 quater.
✅ NOUVEAU — Vues Supabase exposées sans authentification (session 2.14 quinquies) : toute vue simple (non protégée par RLS, à la différence des tables) accessible en SELECT par les rôles anon/authenticated expose intégralement son contenu, y compris des colonnes sensibles (ex. phone_number sur available_drivers, solde wallet et commissions sur driver_dashboard) — une vue n'hérite pas automatiquement des protections RLS des tables sous-jacentes sauf activation explicite de security_invoker = true (PostgreSQL 17.6, confirmé compatible sur ce projet). Toute nouvelle vue exposant des données issues de tables protégées par RLS doit systématiquement faire l'objet d'une revue de permissions (GRANT) et d'une activation de security_invoker si applicable — voir RÉSOLU 48, session 2.14 quinquies.
✅ NOUVEAU — CREATE OR REPLACE VIEW ne permet pas de retirer une colonne existante (SQLSTATE 42P16 — cannot drop columns from view) — pour retirer une colonne d'une vue, procéder par DROP (et DROP des objets dépendants dans l'ordre, ex. RPC SECURITY DEFINER s'appuyant sur la vue) puis CREATE — session 2.14 quinquies, RÉSOLU 49.
✅ NOUVEAU — Le principe de vigilance sur les GRANT larges par défaut (anon/authenticated) s'étend au-delà des vues : la table drivers elle-même était accessible en SELECT au rôle anon (combiné à une policy RLS drivers_select_available sans filtre d'identité), découverte fortuitement en investigation de la session 2.14 quinquies bis — un audit des permissions GRANT par défaut sur l'ensemble du schéma public reste une recommandation ouverte (voir Section 17), le perimètre du cas authenticated de cette même policy restant également non traité — voir RÉSOLU 52.
✅ NOUVEAU — Le payload Realtime Supabase transmet les colonnes de type geography sous forme de chaîne hexadécimale EWKB (format canonique PostgreSQL/PostGIS), et non en texte lisible de type POINT(...) — confirmé par recherche documentaire officielle et vérification SQL directe, session 2.14 quinquies bis. Toute lecture applicative d'une colonne geography reçue via un canal Realtime doit tenir compte de cet encodage. Le cast SQL natif ::geography accepte indifféremment WKT et HEXEWKB en entrée de fonction — voir RÉSOLU 51.
✅ NOUVEAU — Diffusion géospatiale par distance réelle branchée et opérationnelle depuis session 2.14 quinquies bis (fail-open : en cas d'échec de la vérification de distance, la mission reste affichée par défaut, décision validée par le porteur pour ne jamais priver un chauffeur de mission à cause d'un incident technique passager) — voir RÉSOLU 51, Section 6 et Section 15.
✅ NOUVEAU — Mécanisme de négociation de prix structuré (table mission_offers, 2 tours maximum, double acceptation symétrique obligatoire dans tous les cas — quel que soit l'ordre d'acceptation entre client et chauffeur) opérationnel depuis session 2.14 sexies — voir Section 6, Section 7, Section 9, Section 15.

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
   ⚠️ Non re-testé sessions 2.13, 2.14, 2.14 bis, 2.14 ter, 2.14 quinquies bis (contrainte numéro partagé, occupé par DRIVER durant ces sessions)
   ⚠️ Session 2.14 quater : test complet resté bloqué (GPS Codespaces/iframe), table missions confirmée vide à l'issue de la session
   ⚠️ Session 2.14 quinquies : le compte Auth CLIENT ("TEST CLIENT FTM") a été supprimé en cours de session pour permettre un nouvel onboarding DRIVER
   ✅ Session 2.14 sexies : re-testé en conditions réelles (ClientHome/CreateMissionScreen fonctionnel avec le nouveau typage élargi, aucune régression sur le premier montage via initialParams) — voir Section 17. Chaîne de navigation client réparée (routes MissionTracking/Rating manquantes, ClientHome mal paramétrée — voir RÉSOLU 53, Section 6).

Auth ADMIN : ✅ confirmé — session 2.7
   Navigation → AdminDashboardScreen
   5 écrans dans AdminNavigator : AdminHome ✅ DocumentReview ✅ WalletManagement ✅ AdminMissions ✅ AdminUsers ✅
   ✅ Reconfirmé en conditions réelles session 2.14 quinquies (tests de non-régression) : dashboard, gestion missions, validation documents 4/4, gestion wallet (recharge 300 DH validée)
   ✅ Reconfirmé sans régression sessions 2.14 quinquies bis et 2.14 sexies (dashboard, AdminMissionsScreen 7 filtres intacts dont "Expirées", malgré 9 modifications cumulées de RootNavigator.tsx en session 2.14 sexies)

Auth DRIVER : ✅ OPÉRATIONNEL — profil actuel créé session 2.14 sexies
   Flux complet historique testé et validé à l'époque (session 2.4 suite) : Étape 1 → VehicleInfoScreen ✅ / Étape 2 → LegalDocumentsScreen ✅ / Étape 3 → DocumentUploadScreen ✅ / Étape 4 → PendingVerification ✅ / Validation admin → DriverHome ✅
   Realtime Supabase ✅
   ⚠️ ÉTAT ACTUEL (depuis session 2.14 sexies) : le rôle DRIVER est accessible sur le numéro partagé via un nouveau profil (a53521ca-c776-4b57-8370-5d934f2bb416), créé et validé durant cette session. Voir Section 2, bloc "numéro partagé", et Section 3.
   ⚠️ Alerte Realtime de validation sur PendingVerificationScreen.tsx : ✅ CORRIGÉE session 2.14 (RÉSOLU 42) — chemin web uniquement, chemin natif non testé
   ✅ Reconfirmé fonctionnel session 2.14 sexies : nouvelle rotation complète effectuée (onboarding 4 étapes, validation admin, recharge wallet 1000 DH validée), DriverHomeScreen avec le code modifié (bouton d'offre de prix onOfferCreated) affiché sans erreur — chemin le plus modifié de la session, validé en dernier sur demande explicite du porteur

Bugs session 2.5 : ✅ 3 bugs corrigés (BUG 1 SIGNED_IN onboarding, BUG 2 wallet 404, BUG 3 document_reminders)
Bugs session 2.7 : ✅ 5 bugs corrigés (BUG A wallet RLS récursion, navigation admin 4 menus, SIGNED_IN loop admin, 403 notifications, enum mission_status) — BUG 4 → INFIRMÉ ✅

Packages ajoutés : expo-image-picker ~14.7.1 ✅ expo-document-picker ~11.10.1 ✅ — commit c318a92

Storage :
✅ Bucket driver-documents créé — 5 MB max — jpeg/png/pdf — RLS policies configurées — commits 7222601 + c39cafb
✅ RLS ownership chain corrigée — session 2.12 (commit 67e9e65) — voir item 6.6 / RÉSOLU 36
✅ Bucket voice-messages créé — session 2.8 — 5 MB max — audio/m4a, mp4, mpeg, wav, x-m4a — RLS policies configurées (4) — commit 5ee383e
   ⚠️ Infrastructure créée mais NON testée fonctionnellement (audioService.ts non référencé dans aucun screen — voir item 4.4)
   ✅ RLS ownership CORRIGÉE — session 2.14 ter (commit 9c36d84) — voir RÉSOLU 46. Chaîne de propriété double (client + chauffeur de la mission) via UNION, indice storage.foldername()[2] (convention de chemin missions/{missionId}/...). Fichier applicatif réel confirmé : frontend/src/services/audioService.ts.
   ⚠️ Test fonctionnel en conditions réelles reporté à la Phase 4.4 / session 2.18 — décision motivée session 2.14 ter

Connexion Supabase : ✅ .env configuré dans frontend/
Token Supabase : ✅ Renouvelé le 29/04/2026 — Nom : FTM_GITHUB_ACTIONS — Expiration : Never
Mode test OTP : ✅ configuré (MessageBird fictif) — Numéro test : +212600000000 — Code fixe : 123456 — Valide jusqu'au : 31/12/2026

Extensions Supabase : ✅ pg_cron 1.6.4 — installée session 2.9 / ✅ pg_net 0.19.5 — installée session 2.9

CRON reminders : ✅ OPÉRATIONNEL — session 2.9
   jobid=2, 0 8 * * *, active=true — timeout_milliseconds := 30000
   5 exécutions succeeded : 18→22/06/2026 — check-document-reminders appelée quotidiennement
   ⚠️ Lien avec notifyDocumentExpiry non vérifié — voir Section 15/17 (en attente depuis session 2.14, non traité en 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, ni 2.14 sexies — hors périmètre de chacune)

Vault Supabase : ✅ Secret supabase_service_role_key — 219 caractères — identique Dashboard — Créé session 2.9

Realtime Supabase : ✅ OPÉRATIONNEL — session 2.10
   5 tables activées initialement : drivers, missions, wallet, transactions, notifications — Migration 20260504000012 déployée
   WalletDashboardScreen SUBSCRIBED ✅
   transactions ✅ écoute branchée — session 2.14
   notifications : Realtime actif — non branché UI directement, remplacé par NotificationBell/Center (résolution du profil via getCurrentProfileId(), déclenché par événement Realtime)
   ✅ (session 2.14 quinquies) — canal subscribeToMissionUpdates exploité côté DriverHomeScreen.tsx : abonnement immédiat dès réception d'une nouvelle mission (Volet 1 diffusion), fermeture automatique du modal de proposition si le statut de la mission change avant acceptation.
   ⚠️ PRÉCISION IMPORTANTE (session 2.14 sexies) — RÔLE DU VOLET 1 REQUALIFIÉ : depuis l'introduction du mécanisme de négociation de prix structuré (mission_offers, 2.14 sexies), une mission reste au statut pending pendant toute la durée de la négociation (jusqu'à 2 tours), et non plus jusqu'à une acceptation immédiate de type "premier arrivé, premier servi". Le canal subscribeToMissionUpdates (Volet 1) reste pertinent et actif, mais son rôle se restreint désormais à la fermeture du modal en cas d'annulation ou d'expiration de la mission — il ne gère plus un cas de "changement de chauffeur retenu" au sens où ce cas n'existe plus de la même façon pendant la phase de négociation. Voir aussi Section 7 (Chaîne de navigation Driver) pour la même précision appliquée à la description fonctionnelle du parcours, et Section 6 (bloc session 2.14 sexies, § 4.1 point c) pour le détail complet de cette découverte.
   ✅ NOUVEAU (session 2.14 sexies) — 2 nouveaux canaux ajoutés : subscribeToMissionOffers(missionId, onOfferChange) côté client (écoute INSERT + UPDATE sur mission_offers filtré par mission_id) et subscribeToDriverOffers(driverId, onOfferChange) côté chauffeur (écoute UPDATE uniquement sur mission_offers filtré par driver_id) — voir Section 6, bloc session 2.14 sexies.

RLS transactions : ✅ transactions_insert_own corrigée — session 2.12 (commit 67e9e65) — voir RÉSOLU 37
   ✅ Fondation confirmée fonctionnelle en usage réel session 2.13 : requestWalletTopup() insère des transactions status: 'pending' via cette même politique — RÉSOLU 38
   ✅ Confirmée compatible avec le listener Realtime (Volet 2, session 2.14)
   🔵 Pattern RLS de transactions_select_own / notifications_select_own identifié — session 2.14 bis — réutilisé avec succès comme référence pour voice-messages (session 2.14 ter, via jointure adaptée à un double accès), puis pour mission_offers (session 2.14 sexies, avec une adaptation notable — voir Section 2, bloc "RLS Storage / conception ownership").

Wallet topup : ✅ Mécanisme honnête — session 2.13 (commit 2e76429) — requestWalletTopup() — voir RÉSOLU 38
   ⛔ wallet_update_admin non modifiée — reste privilège admin exclusif
   ⚠️ Robustesse topupWallet/refundWallet (échec silencieux possible de l'insertion de la transaction après UPDATE du solde) — découverte annexe session 2.14, préexistante, hors périmètre — à documenter pour session future (voir Section 15/17)
   ✅ Session 2.14 quinquies : validation fonctionnelle croisée obtenue en conditions réelles sur le nouveau profil DRIVER — recharge admin de 300 DH testée et confirmée (0 → 300 DH), et le chauffeur ne voit que son propre solde (jamais celui d'un autre profil), confirmant au passage le bon fonctionnement de security_invoker sur driver_dashboard (voir RÉSOLU 48)
   ✅ Session 2.14 sexies : recharge admin de 1000 DH testée et confirmée sur le nouveau profil DRIVER (a53521ca-...), sans régression

Dashboard driver : ✅ recharges_current_month — session 2.13 (commit 2e76429, migration 20260504000014) — voir RÉSOLU 39
   ✅ Vue driver_dashboard désormais protégée : SELECT anon révoqué, security_invoker = true activé — session 2.14 quinquies (voir RÉSOLU 48)

Bug Alert.alert/web : ⚠️ Statut par fichier — mis à jour session 2.14 :
   WalletTopupScreen.tsx ligne 70 (succès) → ✅ CORRIGÉ (commit 480130d, session 2.13) — RÉSOLU 41
   WalletTopupScreen.tsx ligne 66 (erreur) → ⚠️ NON VÉRIFIÉ, laissé inchangé (Option A) — voir bug résiduel Section 16
   AdminUsersScreen.tsx (session 2.8) → ⚠️ fonctionne web, sans distinction Platform.OS — risque mobile natif — voir bug résiduel Section 16
   PendingVerificationScreen.tsx (alerte Realtime) → ✅ CORRIGÉ session 2.14 — RÉSOLU 42 — ⚠️ chemin natif non testé
   Audit systématique recommandé — session 2.19 suggérée (voir Section 17)

Realtime transactions/notifications (Volets 2-3, session 2.14) :
   ✅ subscribeToNewTransactions branché — TransactionHistoryScreen.tsx — écoute INSERT uniquement (limitation assumée, documentée)
   ✅ NotificationBell/NotificationCenterScreen montés sur les 3 rôles (Driver, Client, Admin)
   ⚠️ Anomalie #1 : NotificationCenterScreen.tsx sans bouton "← Retour" — voir Section 16

Fonctions notify mission : 13 fonctions notify* inventoriées au total à ce jour
   2 déjà branchées avant 2.14 (notifyDocumentVerified, notifyDocumentRejected)
   4 branchées session 2.14 : notifyMissionStarted, notifyMissionAccepted, notifyMissionCompleted (Option C), notifyMissionCancelled
   ✅ NOUVEAU (session 2.14 sexies) — 4 nouvelles fonctions branchées, dédiées au mécanisme de négociation, mutualisées sous un seul type 'offer_update' (icône et canal Android partagés) : notifyClientOfferUpdate, notifyDriverCounterOffer, notifyOfferAcceptancePending, notifyDriverOfferNotSelected. Table de couverture complète établie avant écriture, mappant chaque transition d'état du processus en 2 tours à son appelant exact dans missionService.ts.
   ⛔ 3 non retenues : notifyNewMission (incompatibilité structurelle, exclusion reconfirmée sans réserve session 2.14 quinquies — aucun appelant dans tout le projet, confirmé par grep global), notifyDocumentExpiry (en attente), notifyWalletLowBalance (écartée)
   ⚠️ NON TESTÉES fonctionnellement à ce jour, pour les 4 fonctions branchées en session 2.14 — le numéro partagé étant actuellement en rôle DRIVER, ceci ne permet toujours pas de test de bout en bout côté Client (absence de second numéro dédié CLIENT) — voir Section 16/17. Les 4 nouvelles fonctions liées à la négociation (session 2.14 sexies) sont également non testées fonctionnellement de bout en bout, pour la même raison structurelle.
   ⚠️ Doublon mort découvert, non corrigé (session 2.14 sexies) : constante NOT_ICONS (NOTIF_ICONS) dupliquée dans pushNotificationService.ts, jamais importée nulle part (confirmé par grep global) — préexistant à cette session, hors périmètre, documenté pour transparence — voir Section 16/17.

⚠️ Compte ADMIN test :
   Numéro : +212600000001 — Rôle admin défini via SQL Editor — NE PAS SUPPRIMER CE PROFIL
   Reconfirmé intact — sessions 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, 2.14 sexies (aucune modification, jamais touché)

⚠️ DRIVER TEST HISTORIQUE — état à date de la session 2.14 ter (dernière vérification par lecture directe avant la rotation de 2.14 quater), TOUJOURS ORPHELIN D'ACCÈS AUTH :
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
     42b73573-... | pending | 50 DH | 0→50 | 14/07 (donnée de test antérieure à la session 2.12)
   ⚠️ Ce profil DRIVER historique et l'intégralité de ses données restent en base, toujours orphelines de tout accès Auth, récupérables sur décision future (voir Section 17). Décision toujours en attente d'arbitrage.

⚠️ AUTRES PROFILS DRIVER/CLIENT ANTÉRIEURS, ORPHELINS EN BASE (état à l'issue de la session 2.14 sexies) :
   - Profil DRIVER créé en session 2.14 quinquies (300 DH, VUL, 4/4 documents) : driverId non communiqué dans le compte-rendu source à l'époque — INCONNU. Devenu orphelin d'accès Auth suite à la/aux rotation(s) ultérieure(s) (chaînon non documenté — voir avertissement Section 2).
   - Un profil CLIENT serait passé sur le numéro partagé entre la session 2.14 quinquies bis et la session 2.14 sexies, d'après la mention du compte-rendu 2.14 sexies ("les profils CLIENT et DRIVER antérieurs à cette session [...] dont un profil client sans historique de mission") — ses caractéristiques précises (identifiant, date de création) sont INCONNUES, ce document ne les précisant pas. Ce profil, comme les précédents, n'a créé aucune mission (aucune mission en base à ce jour selon l'ensemble des sources reçues).

⚠️ NOUVEAU PROFIL DRIVER ACTIF — depuis session 2.14 sexies :
   Numéro : +212600000000
   driverId : a53521ca-c776-4b57-8370-5d934f2bb416
   Créé via un nouvel onboarding complet, dans le cadre des tests de non-régression de fin de session 2.14 sexies
   role : 'driver'
   is_verified : true (validation admin réalisée durant la session)
   Catégorie véhicule : VUL
   wallet_balance : 1000.00 DH (recharge admin validée durant la session)
   Documents légaux : 4/4 soumis et validés

⚠️ SIGNED_IN répétés en console admin : Comportement normal Supabase web via refresh token périodique — Non bloquant

⚠️ État du dépôt — HEAD : c886722 (fin de session 2.14 sexies), synchronisé avec origin/main d'après lecture directe réalisée au sein de cette même session (information qui me parvient ici en relais document, ma propre vérification par lecture directe du dépôt reste à faire en tout début de la prochaine session de supervision). ~59+ fichiers untracked de type .bak* identifiés comme mécanisme de traçabilité délibéré, avec deux précisions : (1) AUCUN nouveau .bak* n'a été créé en session 2.14 quinquies bis — écart explicitement noté dans le compte-rendu source par rapport à la convention habituelle du projet (modifications faites directement via str_replace/Python, sans backup manuel préalable) ; (2) la convention .bak.session2.14sexies a été reprise pour chaque fichier modifié en session 2.14 sexies, avec des suffixes supplémentaires .v2/.v3/.v4 lorsqu'un même fichier a été rouvert plusieurs fois dans cette session (traçabilité intégrale, tous les backups intermédiaires préservés) — cette nuance de la convention (versionnement des backups) est nouvelle et n'existait pas dans les sessions précédentes.

# GITHUB SECRETS CONFIGURÉS

SUPABASE_ACCESS_TOKEN ✅ renouvelé 29/04/2026 — Token : FTM_GITHUB_ACTIONS — Expiration : Never
SUPABASE_PROJECT_ID ✅ (ustckqnecsilxqlyjute)
SUPABASE_DB_PASSWORD ✅
SUPABASE_ANON_KEY ✅
SUPABASE_URL ✅

# HISTORIQUE COMMITS CLÉS

c886722 feat: add DriverMissionOfferScreen and ClientMissionOfferScreen wrappers, wire them into RootNavigator — session 2.14 sexies ✅
7cf6fd7 feat: add getMissionById and wire full mission data into MissionOfferScreen resolution flow — session 2.14 sexies ✅
345b0a3 feat: widen acceptMissionOffer join and return to include full mission data for downstream navigation — session 2.14 sexies ✅
aff38a2 fix: add missing MissionActive route to DriverStackParamList and DriverNavigator — session 2.14 sexies ✅ — voir RÉSOLU 54
3d6717e feat: replace direct accept with price offer submission in NewMissionModal — session 2.14 sexies ✅
3198c4a fix: repair broken client navigation chain (MissionTracking, Rating routes missing; ClientHome route name and params mismatch) — session 2.14 sexies ✅ — voir RÉSOLU 53
b656cbe feat: add MissionOffer route to Driver and Client navigators (additive, no changes to initializeApp) — session 2.14 sexies ✅
be13041 feat: add MissionOfferScreen with client/driver offer negotiation UI — session 2.14 sexies ✅
d163825 feat: add rejectOfferAcceptance to allow either party to withdraw a pending acceptance — session 2.14 sexies ✅
2fc0e29 feat: integrate offer notifications into missionService (create/counter/accept) and add submitClientCounterOffer — session 2.14 sexies ✅
3e2a07a feat: add subscribeToMissionOffers and subscribeToDriverOffers realtime channels — session 2.14 sexies ✅
263c287 feat: add createMissionOffer, counterMissionOffer, acceptMissionOffer to missionService — session 2.14 sexies ✅
ed5dcda feat: add unique partial index on mission_offers to prevent duplicate pending offers per driver — session 2.14 sexies ✅
c13206e feat: auto-sync missions and close competing offers on acceptance — session 2.14 sexies ✅
5e8f0bd feat: create mission_offers table for structured price negotiation — session 2.14 sexies ✅
7fde087 fix: revoke anon SELECT access on drivers table — session 2.14 quinquies bis ✅ — voir RÉSOLU 52
26ebe20 feat: wire geospatial distance filtering into onNewMission callback (DriverHomeScreen.tsx) — session 2.14 quinquies bis ✅
c6a55eb fix: correct findNearbyDrivers default radius (15→60km) + geography cast in find_nearby_drivers RPC — session 2.14 quinquies bis ✅ — voir RÉSOLU 51
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

[Sections SESSION 2.4 INITIALE à SESSION 2.14 quinquies — inchangées, reprises intégralement à l'identique de la version du 25/08/2026. Voir blocs détaillés ci-dessous pour les nouvelles sessions 2.14 quinquies bis et 2.14 sexies.]

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

PLANIFICATION DES SESSIONS (historique, mise à jour continue — voir Section 16/18 pour le statut courant complet) :
2.12 ✅ RLS Storage + transactions_insert_own
2.13 ✅ Cause racine RLS wallet + recharge honnête
2.14 ✅ Realtime + Notifications (avec réserves)
2.14 bis ✅ Investigation/planification processus de mission
2.14 ter ✅ Correction sécurité RLS voice-messages
2.14 quater ✅ Piste 3 — planification par date/heure (avec réserves)
2.14 quinquies ✅ Piste 1 — sécurisation infrastructure diffusion + Volets 1/2 expiration (avec réserves)
2.14 quinquies bis ✅ Piste 1 (suite) — branchement effectif de la diffusion géospatiale par distance réelle (avec réserves)
2.14 sexies ✅ Piste 2 — négociation de prix structurée (avec réserves)
2.14 septies ⏳ Piste 4 — activation canal vocal sécurisé — DÉPENDANCE DÉSORMAIS LEVÉE (2.14 sexies clôturée) — prête à démarrer
2.15 ⏳ TrackingDetailScreen
2.16 ⏳ Bouton déconnexion 3 rôles
2.17 ⏳ Réforme timing commission + workflow financier générique
2.18 ⏳ Test fonctionnel complet voice-messages (Phase 4.4, RLS déjà déployée depuis 2.14 ter)
2.19 ⏳ Audit systématique Alert.alert()
2.20 ⏳ Correction route CreateParcel manquante + test flux e-commerce complet (voir Section 6, bloc 2.14 quater)

Ordre logique actualisé : 2.12 → 2.13 → 2.14 → 2.14 bis → 2.14 ter → 2.14 quater → 2.14 quinquies → 2.14 quinquies bis → 2.14 sexies (chantier "processus de mission" désormais complet sur ces 8 sessions) → 2.14 septies (peut démarrer immédiatement) → 2.15 (parallélisable) → 2.16 (glissable) → 2.17 (dernière du chantier wallet) → 2.18 (test fonctionnel voice-messages, Phase 4.4) → 2.19 (glissable, avant Phase 3) → 2.20 (fin de séquence chantier processus de mission au sens large, sans dépendance avec 2.14 septies)

LISTE DE SUIVI — ANOMALIES/OBSERVATIONS DOCUMENTAIRES (à corriger dans le présent document) :
1. ID driver test coquille → CORRIGÉ session 2.12
2-3. Chemins onboarding → confirmés sous frontend/src/screens/driver/onboarding/
4. Bug WalletRecharge → CORRIGÉ session 2.13 (RÉSOLU 40)
5. Filtrage géographique absent → RPC find_nearby_drivers identifiée session 2.14 bis, infrastructure sécurisée session 2.14 quinquies, branchement réel réalisé et déployé session 2.14 quinquies bis (voir RÉSOLU 51) — test d'exécution complet en conditions réelles (GPS) toujours en attente, Phase 4.x
6. Convention de chemins non documentée (sous-dossiers thématiques)
7. RLS transactions INSERT sans restriction → CORRIGÉ session 2.12 (RÉSOLU 37)
8. RLS voice-messages sans clause de propriété → CORRIGÉ session 2.14 ter (RÉSOLU 46)
9. Décompte transactions pending driver test → corrigé session 2.14 ter, voir Section 3
10. Divergence documentaire NotificationBell (Realtime événementiel, pas polling) → corrigée session 2.14 quater
11. Fichier applicatif du canal vocal confirmé frontend/src/services/audioService.ts → session 2.14 ter/quater
12. Route de navigation CreateParcel manquante (bug préexistant découvert, sans rapport avec la session) → session 2.20 assignée
13. Ambiguïté définition « Volet 2 » (expiration vs rappel 24h) → levée session 2.14 quinquies, confirmée par lecture directe de la ROADMAP
14. Nombre de profils DRIVER opérationnels → clarifié session 2.14 quinquies : un seul profil actif à la fois
15. Statut CI comme garantie de fonctionnement du code → infirmé par l'incident STATUS_FILTERS, RÉSOLU 50, règle consolidée Section 2
16. NOUVEAU (actualisation du 09/09/2026) — Chaînon de rotation du numéro de test partagé non documenté entre la session 2.14 quinquies bis (état DRIVER confirmé, sans rotation) et la session 2.14 sexies (compte-rendu mentionnant un état CLIENT en tout début de sa séquence de tests, sans événement de rotation documenté dans aucune des trois sources reçues pour cette actualisation) — signalé comme lacune de traçabilité, non reconstitué. Voir Section 2.
17. NOUVEAU (actualisation du 09/09/2026) — Nuance de formulation relevée dans le compte-rendu de la session 2.14 quinquies bis, entre sa section 2 (« Déploiement : CI vert [...] vérifié par lecture directe de l'état réel de production [...] conformément à la règle méthodologique post-RÉSOLU 50 ») et sa section 5 (« sans test d'exécution réel du nouveau code [du Volet A], contrairement à la règle stricte post-RÉSOLU 50, appliquée ici avec une dérogation assumée »). Une hypothèse de lecture a été transmise séparément lors de la préparation de cette actualisation, suggérant que ces deux phrases porteraient sur deux objets distincts (vérification de la migration SQL en base vs test d'exécution réelle du code applicatif TypeScript), ce qui dissoudrait l'apparente contradiction — cette hypothèse n'a toutefois pas pu être vérifiée par une lecture directe et exhaustive du document source par la présente conversation, et n'est donc pas retenue comme fait établi. Point signalé pour vérification par le lecteur du présent document, avec le detail exact des deux formulations disponible dans le compte-rendu original de la session 2.14 quinquies bis. Voir Section 6, bloc session 2.14 quinquies bis.
18. NOUVEAU (actualisation du 09/09/2026) — Référent « Bloc A » mentionné dans le compte-rendu de la session 2.14 quinquies bis (« texte complet de l'annexe ROADMAP (Bloc A) non consulté dans cette conversation »), au sujet d'une réserve de la Partie 1 jamais levée. Une correspondance a été suggérée lors de la préparation de cette actualisation avec la distinction « Bloc A »/« Bloc B » qui existerait dans le « § TRI » de l'Annexe § 18 de la présente ROADMAP — mais le texte réel de ce § TRI n'a pas été transmis à la présente conversation (la version reçue de la ROADMAP du 25/08/2026 renvoie elle-même, pour ce passage, à « la version du 11/08/2026 » pour son texte complet). Cette correspondance n'a donc pas pu être vérifiée par lecture directe et n'est pas retenue comme fait établi dans le présent document. Voir Annexe § 18 bis.

Prochain timestamp migration disponible : 20260504000024 (consommé : 019 et 020 par session 2.14 quinquies bis, 021 à 023 par session 2.14 sexies)

## REQUALIFICATION PHASE 6 — AMÉLIORATIONS POST-TESTS

[Contenu inchangé depuis la version du 25/08/2026 — items 6.1 à 6.6 repris à l'identique, voir Section 17/18 pour statuts courants.]
6.1 ⏳ Modes de paiement multiples wallet → session 2.17
6.2 ⏳ Workflow validation recharge admin → session 2.17 (fondation posée 2.13)
6.3 ⏳ Remboursements flux dédié → session 2.17
6.4 ⏳ Bouton déconnexion 3 rôles → session 2.16
6.5 ✅/⏳ Refonte WalletTopupScreen — Partie 1 ✅ (2.13), Partie 2 ⏳ → session 2.17
6.6 ✅/✅ SÉCURITÉ — RLS Storage : driver-documents ✅ (2.12), voice-messages ✅ CORRIGÉE (2.14 ter, RÉSOLU 46) — reste le test fonctionnel en Phase 4.4/session 2.18

⚠️ DÉPENDANCE CROISÉE À NOTER — Phase 3 / Session 2.14 : les fonctions notify* mission (y compris les 4 nouvelles de 2.14 sexies) dépendent de l'infrastructure FCM/APNs non réalisée à ce jour (voir Section 15).

## SESSION 2.12 — commit 67e9e65

[Contenu inchangé — reprise intégrale du détail de la version du 25/08/2026. Voir RÉSOLU 36/37.]

## SESSION 2.13 — commits 2e76429 + 480130d

[Contenu inchangé — reprise intégrale. Voir RÉSOLU 38/39/40/41.]

## SESSION 2.14 — commit afba878

[Contenu inchangé — reprise intégrale. Voir RÉSOLU 42.]

## SESSION 2.14 bis — 07/08/2026 (aucun commit)

[Contenu inchangé — reprise intégrale.]

## SESSION 2.14 ter — commit 9c36d84

[Contenu inchangé — reprise intégrale. Voir RÉSOLU 43.]

## SESSION 2.14 quater — commits 0da3e07 + 829f31e

[Contenu inchangé — reprise intégrale. Voir RÉSOLU 44/45/46/47.]

## SESSION 2.14 quinquies — commits 3bf1c09 → 8941e0a

[Contenu inchangé — reprise intégrale de la version du 25/08/2026 (objectif/périmètre, Partie 1 investigation, découverte de sécurité majeure, Partie 2 implémentation 2A/2B, Volets 1/2, incident critique STATUS_FILTERS, tests de non-régression, état du numéro partagé, état final du dépôt, synthèse finale, reste à faire). Voir RÉSOLU 48/49/50.]

## SESSION 2.14 quinquies bis — commits c6a55eb → 7fde087

**Date** : 28/08/2026 — **Statut** : CLÔTURÉE ✅ (avec réserves)

### Objectif et périmètre

Objectif du prompt de mission : brancher effectivement le filtrage géospatial réel (catégorie VUL, rayon 60 km) dans le flux de diffusion existant, corriger le rayon par défaut du wrapper findNearbyDrivers() (15→60 km), remplir le paramètre _driverLocation de subscribeToNewMissions(). Périmètre réellement livré : conforme à l'objectif initial, élargi consciemment et documenté durant la Partie 1 pour intégrer un correctif de sécurité découvert fortuitement — même schéma méthodologique qu'en session 2.14 quinquies. Aucun report de sous-objectif à une session ultérieure : les deux volets ont été intégralement réalisés et déployés dans cette même session.

### Partie 1 — Investigation (close et validée)

7 points de synthèse validés par le porteur : (1) origine du rayon 15 km — valeur par défaut non documentée, sans risque à la remplacer ; (2) filtrage géospatial impossible au niveau du canal Realtime lui-même (limitation Supabase), point d'insertion identifié dans le callback onNewMission, avant setPendingMission ; (3) fiabilité/sécurité de find_nearby_drivers confirmée saine (RÉSOLU 48/49 toujours effectifs), vérifiée jusqu'à l'état réel de production ; (4) source de la position chauffeur : drivers.current_location, type geography, filtre de fraîcheur 5 minutes déjà protecteur ; (5) recoupement avec mission_offers (2.14 sexies, alors future) : aucune collision de code actuelle, recommandation de garder la logique isolée ; (6) méthode de test sans GPS réel : aucun mécanisme existant, trois options identifiées pour arbitrage en Partie 2 ; (7) impact sur Volets 1/2 de 2.14 quinquies : aucune régression anticipée, Volet 2 identifié comme filet de sécurité naturel.

Découverte annexe (sécurité) : exposition en lecture non authentifiée de la table drivers (GRANT SELECT à anon combiné à la policy RLS drivers_select_available sans filtre d'identité). Investigation approfondie confirmant que seul SELECT était concerné (UPDATE/DELETE/INSERT sains). Élargissement de périmètre validé par le porteur, limité au retrait de l'accès anon — le cas authenticated documenté comme recommandation séparée (voir Section 18).

### Partie 2 — Implémentation (close, déployée, vérifiée)

**Volet A — Branchement géospatial**

Correction du rayon par défaut : findNearbyDrivers() dans missionService.ts, radiusKm = 15 → radiusKm = 60.

Découverte technique en cours d'implémentation (non anticipée en Partie 1) : le type Mission (TypeScript) ne porte pas pickup_location, bien que la colonne existe réellement en base — omission de typage, contournée par accès via Record<string, unknown>.

Découverte technique majeure : le payload Realtime transmet les colonnes geography sous forme de chaîne hexadécimale EWKB (format canonique PostgreSQL/PostGIS), et non en texte lisible POINT(...) — confirmé par recherche documentaire officielle et vérification SQL concrète (sans création de données de test), avant toute écriture de code.

Adaptation de la RPC find_nearby_drivers : remplacement de ST_GeographyFromText(client_point) par client_point::geography — cast natif acceptant indifféremment WKT et HEXEWKB, confirmé rétrocompatible avec l'usage existant du wrapper.

Choix de conception (Option 3 validée par le porteur) : réutilisation directe de la RPC existante (appel supabase.rpc('find_nearby_drivers', ...) directement dans le callback onNewMission de DriverHomeScreen.tsx), plutôt que de dupliquer un calcul géospatial côté client ou de modifier le service de localisation stable (locationService.ts).

Comportement en cas d'erreur : fail-open validé par le porteur — en cas d'échec de la vérification de distance, la mission est affichée par défaut, pour ne jamais priver un chauffeur de mission à cause d'un incident technique passager.

Migration : 20260504000019_fix_find_nearby_drivers_geography_cast.sql + rollback. Commits : c6a55eb (rayon + RPC), 26ebe20 (callback DriverHomeScreen.tsx).

Déploiement : CI vert sur les deux commits, vérifié par lecture directe de l'état réel de production (définition de fonction + droits d'exécution inchangés).

⚠️ NOTE — voir liste de suivi anomalie #17 (Section 6, ci-dessus) au sujet d'une nuance de formulation entre la section 2 et la section 5 du compte-rendu source concernant l'application exacte de la règle post-RÉSOLU 50 à cette implémentation — signalée sans être tranchée dans le présent document.

**Volet B — Correction de sécurité (accès anon/drivers)**

REVOKE SELECT ON drivers FROM anon — portée strictement limitée au rôle anon, aucun autre privilège affecté.

Migration : 20260504000020_revoke_anon_select_drivers.sql + rollback (avec avertissement explicite sur la réintroduction de la faille en cas d'exécution). Commit : 7fde087.

Déploiement : CI vert, vérifié par lecture directe : SELECT bien retiré pour anon, INSERT/UPDATE/DELETE inchangés.

### Tests de non-régression

Ordre pragmatique ADMIN → DRIVER (porteur déjà connecté en admin au moment du test ; CLIENT non testé, décision assumée).

| Rôle | Résultat | Détail |
|---|---|---|
| ADMIN | ✅ Aucune régression | Dashboard, AdminMissionsScreen (7 filtres intacts dont "Expirées"), notifications, gestion utilisateurs — accès aux données chauffeurs confirmé fonctionnel pour authenticated malgré le retrait de l'accès anon (Volet B). Console propre. |
| DRIVER | ✅ (partiel) | Écran principal, wallet, notifications — aucune régression. Blocage GPS (Codespaces) confirmé géré proprement, comportement identique à avant modification. Le code de filtrage par distance (Volet A) n'a pas pu être exécuté — startBackgroundTracking() échoue avant d'atteindre subscribeToNewMissions, comme attendu et déjà documenté depuis 2.14 quinquies. |
| CLIENT | Non testé | CreateMissionScreen.tsx non modifié dans cette session, risque de régression jugé nul, décision du porteur de préserver le profil DRIVER de test actif plutôt que d'effectuer une rotation. |

### État final

HEAD : 7fde087, synchronisé origin/main, confirmé par lecture directe (au sein de cette session — relayé ici en relais document). Fichiers créés : 2 migrations + 2 rollbacks (20260504000019, 20260504000020). Fichiers modifiés : missionService.ts, DriverHomeScreen.tsx.

⚠️ Backups : AUCUN nouveau .bak* créé cette session — les modifications ont été faites directement via str_replace/Python, sans backup manuel préalable — écart mineur explicitement noté par rapport à la convention habituelle du projet.

Prochain timestamp de migration disponible à l'issue de cette session : 20260504000021.

### Limites et réserves

- Test d'exécution complet du Volet A en conditions réelles : impossible en environnement Codespaces (GPS bloqué), reporté à Phase 4.x.
- Test CLIENT : non réalisé, décision assumée.
- Cas authenticated de la faille drivers (policy drivers_select_available) : non traité, documenté comme nouvelle recommandation (voir Section 18).
- Réserve de la Partie 1, jamais levée : contenu de initializeApp() (RootNavigator.tsx) jamais lu directement ; « texte complet de l'annexe ROADMAP (Bloc A) » non consulté dans cette conversation — voir liste de suivi anomalie #18 (Section 6, ci-dessus) : ce référent n'a pas pu être vérifié par lecture directe dans le cadre de la présente actualisation.

### Recommandations en attente d'arbitrage (issues de cette session)

- Portée de la policy drivers_select_available pour le rôle authenticated : reste permissive pour tout utilisateur connecté, sans filtre sur le chauffeur concerné — décision produit à trancher.
- Test d'exécution réel du Volet A : à réaliser en priorité dès qu'un environnement avec GPS fonctionnel sera disponible (device physique, Phase 4.x).
- Test CLIENT complet : à intégrer dans un test de non-régression futur si une session ultérieure touche à nouveau au flux de création de mission.

## SESSION 2.14 sexies — commits 5e8f0bd → c886722

**Date** : 09/09/2026 — **Statut** : CLÔTURÉE ✅ (avec réserves) — compte-rendu source autonome et autosuffisant

### Contexte dans le chantier

Piste 2 du chantier "processus de mission". Chaîne : 2.14 ter ✅ → 2.14 quater ✅ → 2.14 quinquies ✅ → 2.14 quinquies bis ✅ → 2.14 sexies (cette session, CLÔTURÉE) → 2.14 septies (dépendance désormais levée).

Objectif du prompt de mission : nouvelle table mission_offers pour un mécanisme de négociation de prix structuré, RLS sur le pattern déjà éprouvé transactions_select_own/notifications_select_own (voice-messages, session 2.14 ter), refonte du verrou de concurrence, vérification préalable de la structure réelle des fonctions notify*, countdown serveur à concevoir, décisions à trancher sur le devenir sémantique de negotiated_price et l'extension e-commerce.

### Structure et méthode

Prompt de mission en 2 parties, validé par le porteur avant ouverture : Partie 1 — Investigation ciblée (lecture seule) → rapport complet → validation explicite → arrêt obligatoire → Partie 2 — Implémentation (étape par étape, 1 étape à la fois, chaque résultat vérifié avant de continuer).

Règles de méthode appliquées : 1 commande à la fois avec vérification systématique après toute modification ; CI vert jugé insuffisant, vérification obligatoire par lecture directe SQL + test d'exécution réel après chaque modification de code ; répartition stricte des rôles (assistant tranche le technique, porteur tranche le métier — un glissement corrigé en cours de session) ; migration déjà déployée jamais modifiée rétroactivement ; rollback obligatoire pour toute migration RLS/fonction/trigger ; vérification git status avant et après chaque pause et avant tout commit (a permis de détecter une omission réelle, voir § Implémentation ci-dessous, fonction getMissionById).

### Partie 1 — Rapport de synthèse de l'investigation (close et validée)

**Découvertes techniques confirmées par lecture directe** : cycle de vie mission strictement binaire à l'acceptation (pending → accepted/expired/cancelled_*), confirmé par lecture intégrale de missionService.ts (461 lignes) avant toute modification.

**DÉCOUVERTE MAJEURE DE SÉCURITÉ** : absence de WITH CHECK sur la policy UPDATE de la table missions, confirmée NULL par lecture directe (pg_policies). missions_update_admin également NULL. Aucun précédent de "contrôle de transition" n'existait dans le projet pour missions (seules notifications et profiles ont un WITH CHECK sur UPDATE, limité à la propriété). ⚠️ DÉCISION DU PORTEUR : non corrigée dans cette session, reportée à une session future d'audit sécurité — à rattacher à la recommandation déjà existante "audit des permissions GRANT par défaut sur l'ensemble du schéma public" (voir Section 18). En contrepartie explicite, la nouvelle table mission_offers a été conçue avec un WITH CHECK solide dès sa création.

Modèle RLS de référence : policies voice-messages (chaîne de propriété double client+chauffeur via UNION) adaptées pour mission_offers, avec une différence notable — accès chauffeur direct via driver_id porté par la ligne d'offre elle-même, sans jointure vers missions.driver_id (NULL pendant toute la négociation).

Recoupement confirmé sans collision avec le filtre géospatial de 2.14 quinquies bis (s'exécute entièrement avant setPendingMission). Trois conséquences identifiées : (a) le Volet 1 de 2.14 quinquies (subscribeToMissionUpdates) reste pertinent mais son rôle se restreint à l'annulation/expiration de la mission, plus au "changement de chauffeur retenu", la mission restant pending pendant toute la négociation — voir Section 2 et Section 7 pour cette même précision reportée ailleurs dans le document ; (b) le futur écran du tour 2 nécessite une donnée supplémentaire (prix de contre-offre) non portée par NewMissionModal.tsx en l'état ; (c) un nouveau canal Realtime nécessaire sur mission_offers, confirmé faisable sur le modèle de subscribeToDriverLocation.

Fonctions notify* toutes conçues pour un destinataire unique — boucle d'appels individuels nécessaire pour notifier plusieurs chauffeurs (modèle déjà utilisé dans notifyMissionCompleted).

Extension e-commerce : décision du porteur — hors périmètre, reportée à la session 2.20.

Countdown serveur par tour : faisabilité réévaluée — le mécanisme d'expiration existant (30s, sans CRON) directement transposable, moins coûteux que redouté, mais nécessiterait une duplication sur au moins deux écrans. DÉCISION DU PORTEUR : arbitrage volontairement laissé ouvert, ni réintégré ni définitivement écarté. Complément : le risque d'une négociation bloquée indéfiniment n'est pas un trou fonctionnel — cancelMission() permet déjà au client de sortir à tout moment.

**Schéma de négociation en 9 points, arbitrage métier du porteur** : (1) diffusion normale avec ciblage géographique de la Piste 1 (VUL, 60 km, infrastructure de 2.14 quinquies bis, inchangée) ; (2) n'importe quel chauffeur intéressé peut faire une offre, plusieurs simultanément possibles, aucune réservation au premier ; (3) le client peut faire une contre-offre, uniquement aux chauffeurs ayant déjà fait une offre ; (4) allers-retours plafonnés à 2 ; (5) countdown par tour reporté, arbitrage laissé ouvert ; (6) accord conclu en deux étapes — précisé et généralisé ensuite en règle de double acceptation symétrique (voir ci-dessous) ; (7) le mécanisme "premier arrivé, premier servi" (acceptMission() existant) disparaît, remplacé par le mécanisme du point 6 ; (8) si le client n'accepte aucune offre, il peut annuler et recréer la mission — réutilise cancelMission() existant ; (9) le countdown visuel existant côté chauffeur (30s, NewMissionModal.tsx, purement affiché) reste inchangé, sans lien avec le nouveau mécanisme.

**Processus détaillé en 2 tours, précision apportée par le porteur** (le porteur a corrigé une interprétation initialement erronée de l'assistant sur le caractère "collectif vs individualisé" de la contre-offre) : (1) création — client crée une mission avec prix optionnel (negotiated_price initial, mécanisme existant inchangé) ; (2) offre du chauffeur (tour 1) — ligne mission_offers créée, round_number = 1 ; (3) réponse du client — accepte tel quel, ou fait UNE seule contre-proposition collective, envoyée à TOUS les chauffeurs du tour 1 (offered_price de la ligne existante modifié, pas de nouvelle ligne, pas de dialogue individualisé — confirmé explicitement par le porteur) ; (4) réponse du chauffeur (tour 2) — parmi les chauffeurs du tour 1, seuls les encore intéressés répondent, acceptent ou reproposent (round_number = 2), les non-intéressés sortent naturellement sans rejet explicite ; (5) décision finale du client, pas de nouveau tour possible.

**RÈGLE DE DOUBLE ACCEPTATION SYMÉTRIQUE (précision capitale)** : arbitrée en deux temps par le porteur — d'abord confirmé que l'acceptation du client seule ne suffit pas, puis généralisée par principe de parallélisme (règle symétrique dans les deux sens, quel que soit qui accepte en premier). Formulation finale et définitive du porteur : « il faut dans tous les cas, l'acceptation des 2 parties ». Conséquence technique directe : offered_price modifié alternativement par le chauffeur et le client, jamais figé côté d'une seule partie.

### Partie 2 — Ce qui était déjà déployé au moment de la reprise de l'implémentation

**Migration 20260504000021_create_mission_offers.sql — commit 5e8f0bd** : table public.mission_offers (11 colonnes) —

| Colonne | Type | Nullable | Défaut |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| mission_id | uuid | NO | — (FK missions(id), ON DELETE CASCADE) |
| driver_id | uuid | NO | — (FK drivers(id), ON DELETE CASCADE) |
| round_number | integer | NO | 1 — CHECK IN (1, 2) |
| offered_price | numeric | NO | — |
| client_accepted | boolean | NO | false |
| driver_accepted | boolean | NO | false |
| status | text | NO | 'pending' — CHECK IN ('pending', 'accepted', 'not_selected') |
| message | text | YES | — (note optionnelle) |
| created_at | timestamptz | NO | now() |
| updated_at | timestamptz | NO | now() |

RLS activée, 3 policies symétriques : mission_offers_select_participants (SELECT), mission_offers_insert_driver (INSERT, limité au chauffeur correspondant), mission_offers_update_participants (UPDATE, USING/WITH CHECK identiques et symétriques). Trigger update_mission_offers_updated_at (horodatage, fonction existante). Fonction check_mission_offer_transition() + trigger BEFORE UPDATE, 4 garde-fous : (1) rien ne bouge après status='accepted' ; (2) prix figé après accepted ; (3) impossible de changer le prix si une acceptation partielle est en attente ; (4) impossible de changer le prix ET accepter dans la même requête. Puis passage automatique à accepted si les deux acceptations sont réunies. Rollback disponible, jamais exécuté.

**Migration 20260504000022_mission_offer_acceptance_sync.sql — commit c13206e** : fonction sync_mission_on_offer_accepted() + trigger AFTER UPDATE, modelée sur update_driver_rating(). Quand une offre passe à accepted : (1) UPDATE missions SET driver_id, status='accepted', negotiated_price=NEW.offered_price WHERE id=NEW.mission_id AND status='pending' — c'est ici que le devenir sémantique de negotiated_price est concrètement tranché (voir Section 2, RÉSOLUE en Section 18) ; (2) garde-fou IF NOT FOUND THEN RAISE EXCEPTION (protège contre une mission expirée entre-temps via le Volet 2 de 2.14 quinquies) ; (3) clôture automatique de toutes les offres concurrentes (status='not_selected'). Rollback disponible, jamais exécuté.

HEAD au moment de la reprise de l'implémentation : c13206e. Prochain timestamp alors disponible : 20260504000023.

### Partie 2 (suite) — Implémentation complète, clôture de la session

**Deux extensions de périmètre, validées explicitement par le porteur, même schéma méthodologique que les failles découvertes en 2.14 quinquies et 2.14 quinquies bis** :

- **Extension 1 — Réparation de la navigation client cassée** (MissionTracking, Rating, ClientHome) : découverte en intégrant MissionOfferScreen qu'un pan entier du parcours client post-mission reposait sur des routes jamais déclarées dans RootNavigator.tsx — défaut préexistant, jamais détecté faute de mission jamais créée avec succès en test. Investigation bornée en 3 points + 3 vérifications complémentaires (disponibilité clientProfileId, comportement initialParams/navigation.replace confirmé par documentation officielle React Navigation, cascade des 4 points d'appel réels). Validation explicite du porteur (nécessité fonctionnelle + capitalisation stratégique). Traitée intégralement. Voir RÉSOLU 53.
- **Extension 2 — Réparation de la route MissionActive** : découverte symétrique côté chauffeur, un seul point d'appel réel, aucune cascade. Validation explicite du porteur. Traitée intégralement. Voir RÉSOLU 54.

L'ensemble du périmètre technique initial (table, RLS, service, Realtime, notifications, écran) a également été livré intégralement, sans report.

**Migration 20260504000023_add_unique_pending_offer_constraint.sql — commit ed5dcda** : index unique partiel mission_offers_unique_pending_offer_per_driver sur (mission_id, driver_id) WHERE status='pending' — empêche un chauffeur d'avoir plusieurs offres actives simultanées sur une même mission, sans interdire une nouvelle tentative future (offre not_selected réactivable par une nouvelle ligne). Décision technique corrigée en cours de conception (contrainte absolue → index partiel) suite à relecture croisée. Vérifiée en production (pg_indexes).

**missionService.ts — 6 nouvelles fonctions (commits 263c287, 345b0a3, d163825, 7cf6fd7)** :
- createMissionOffer(missionId, driverId, offeredPrice, message?) : vérifie mission pending avant insertion, gère le code 23505 (violation d'unicité) avec message métier dédié, notifie le client.
- counterMissionOffer(offerId, newPrice, actor) : corrigée lors de la relecture croisée pour garantir l'atomicité complète via .eq('round_number', 1) dans la clause de requête ; passage à round_number=2 uniquement si actor==='driver'.
- acceptMissionOffer(offerId, acceptedBy) : élargie 3 fois en fin de session (commit 345b0a3) — jointure vers missions élargie pour inclure les champs nécessaires à MissionActiveScreen (status, pickup_address, pickup_city, dropoff_address, dropoff_city, driver_id, vehicle_category, actual_pickup_time), typage et signature de retour mis à jour.
- rejectOfferAcceptance(offerId, rejectedBy) : mécanisme de refus localisé et symétrique — GAP ABSENT DU SCHÉMA INITIAL EN 9 POINTS, identifié et comblé en cours de session (voir ci-dessous). Remet client_accepted/driver_accepted à false et le statut à not_selected (définitif, pas de retour à pending, confirmé explicitement par le porteur, cohérent avec l'index unique partiel).
- submitClientCounterOffer(missionId, newPrice) : orchestration en boucle, contre-offre collective appliquée à toutes les offres pending/round_number=1 d'une mission. Chaque itération isolée par try/catch, échecs accumulés dans failedOfferIds, jamais d'arrêt global.
- getMissionById(missionId) : lecture simple, ajoutée pour résoudre un problème de câblage découvert tardivement (voir plus bas). Note méthodologique : conçue et validée par relecture croisée, puis omise lors de la première transmission de commande d'écriture — omission détectée uniquement grâce à la vérification git status avant commit (un seul fichier modifié au lieu de deux attendus), corrigée avant tout commit. Voir Section 2, règle de méthode consolidée.

**realtimeService.ts — 2 nouveaux canaux (commit 3e2a07a)** : subscribeToMissionOffers(missionId, onOfferChange) côté client (INSERT+UPDATE filtré mission_id) ; subscribeToDriverOffers(driverId, onOfferChange) côté chauffeur (UPDATE uniquement, filtré driver_id). Couverture du cas not_selected (déclenché par trigger, indiscernable d'un UPDATE applicatif, capté par le même filtre) vérifiée consciemment.

**notificationTemplates.ts / pushNotificationService.ts — notifications (commits 2fc0e29, d163825)** : 4 nouvelles fonctions (notifyClientOfferUpdate, notifyDriverCounterOffer, notifyOfferAcceptancePending, notifyDriverOfferNotSelected), mutualisées sous un seul type 'offer_update'. Table de couverture complète établie avant écriture. Découverte annexe non corrigée, documentée pour transparence : doublon mort de NOTIF_ICONS dans pushNotificationService.ts (jamais importé nulle part, confirmé par grep global) — préexistant, hors périmètre, non traité.

**MissionOfferScreen.tsx — nouveau composant (426 lignes, commits be13041 puis 7cf6fd7)** : composant partagé client/chauffeur (chemin frontend/src/screens/driver/MissionOfferScreen.tsx — précision reçue directement de l'assistant ayant conduit la session, non présente dans le compte-rendu écrit initial), construit en 3 blocs relus séparément avant assemblage. Machine à états dérivée des colonnes réelles (round_number, client_accepted, driver_accepted, status) — 4 états côté client, 5 côté chauffeur.

Règles métier validées explicitement par le porteur en cours de conception : les autres offres restent visibles mais leur bouton "Accepter" est désactivé dès qu'une acceptation est en cours ailleurs sur la mission ; aucune désactivation du bouton "Refuser" (asymétrie assumée : accepter engage, refuser défait) ; une offre refusée reste définitivement not_selected.

**Gap identifié en cours de conception — absence de mécanisme de refus** : le schéma en 9 points ne prévoyait aucun moyen pour une partie de se retirer d'une acceptation déjà en cours de l'autre côté. Porté à l'arbitrage du porteur (mécanisme localisé vs recours au filet de sécurité global cancelMission), tranché en faveur d'un mécanisme localisé et symétrique — d'où rejectOfferAcceptance.

Résolution du câblage onMissionResolved (commit 7cf6fd7) : signature élargie de () => void à (mission: Record<string, unknown>) => void. Récupération de la mission complète via getMissionById() dans le useEffect d'observation d'état (pas dans les handlers locaux), pour fonctionner indépendamment de qui déclenche la résolution. Protection par useRef (hasResolvedRef) posée immédiatement à la détection, contre les appels redondants.

**NewMissionModal.tsx — remplacement du mécanisme d'acceptation directe (commit 3d6717e)** : bouton "✅ Accepter" (acceptMission direct, mécanisme "premier arrivé premier servi") remplacé par champ de saisie de prix + bouton "💰 Proposer ce prix" (createMissionOffer). Countdown 30s et bouton "❌ Refuser" strictement inchangés. Prop onAccepted renommée onOfferCreated — décision d'architecture délibérée pour ne pas introduire de dépendance à navigation dans un composant qui n'en a jamais eu.

Découverte de câblage tardive : en concevant les wrappers, découverte que MissionOfferScreen ne pouvait transmettre à son parent que l'existence d'une résolution, jamais la donnée mission elle-même — a nécessité de rouvrir acceptMissionOffer() pour élargir sa jointure et son retour.

**Deux composants wrapper (commit c886722)** : DriverMissionOfferScreen.tsx (chemin frontend/src/screens/driver/DriverMissionOfferScreen.tsx) et ClientMissionOfferScreen.tsx (chemin frontend/src/screens/client/ClientMissionOfferScreen.tsx) — précisions de chemin reçues directement de l'assistant ayant conduit la session, absentes du compte-rendu écrit initial. Adaptent route.params/navigation vers les props directes attendues par MissionOfferScreen (missionId, role, driverId?, onMissionResolved). Résolvent une incohérence de typage réelle identifiée tardivement (component={MissionOfferScreen as any} masquait que le composant ne recevait jamais les props attendues). navigation.replace utilisé pour la transition finale, cohérent avec le pattern déjà en place.

**RootNavigator.tsx — 9 modifications cumulées dans cette session** :

| # | Commit | Contenu |
|---|---|---|
| 1-4 | b656cbe | Ajout additif de la route MissionOffer dans DriverStackParamList/ClientStackParamList et déclaration des écrans (import, type, 2 déclarations) |
| 5-6 | 3198c4a | Ajout des routes MissionTracking/Rating à ClientStackParamList + déclaration des écrans ; élargissement de ClientHome: undefined → { clientProfileId?: string } |
| 7 | aff38a2 | Ajout de la route MissionActive à DriverStackParamList + déclaration de l'écran |
| 8-9 | c886722 | Remplacement des références directes à MissionOfferScreen par les deux wrappers spécialisés, avec nettoyage de l'import devenu inutilisé |

Toutes strictement additives sauf l'élargissement de ClientHome (seule modification touchant une route existante et fonctionnelle dans toute cette session — validée explicitement par le porteur après diagnostic complet, incluant une vérification par recherche web du comportement réel de initialParams avec navigation.replace).

⚠️ NOTE DE VOCABULAIRE : voir Section 2 pour la précision sur la qualification de RootNavigator.tsx comme "fichier protégé" dans le compte-rendu source de cette session — terme propre au compte-rendu, non repris comme règle ⛔ officielle.

**Corrections associées (commit 3198c4a)** : MissionTrackingScreen.tsx (type local RootStackParamList corrigé CreateMission→ClientHome, 2 appels navigation.replace corrigés avec clientProfileId: mission.client_id ?? '') ; RatingScreen.tsx (type local corrigé, 2 appels navigation.replace('ClientHome') désormais alimentés avec clientProfileId).

### Incidents et découvertes significatifs

- Incident de manipulation réseau — tunnel Codespaces cessant de répondre (404 persistant) après une simulation GPS via Chrome DevTools, indépendamment du serveur applicatif (confirmé actif, port et visibilité Public vérifiés). Cause non résolue avec certitude, contournée par redémarrage complet de la machine du porteur.
- Cascade de découvertes de navigation cassée côté client (voir Extension 1) — ampleur réévaluée à la hausse à trois reprises avant diagnostic définitif, jamais sous-estimée délibérément.
- Gap identifié dans le schéma métier initial — absence de mécanisme de refus (voir ci-dessus).
- Découverte tardive — onMissionResolved jamais câblée pour transmettre la mission complète (voir ci-dessus).
- Découverte symétrique — route MissionActive jamais déclarée (voir Extension 2).

### Tests de non-régression

Tests d'exécution réels systématiques après chaque écriture (npx expo start --web, console DevTools) — aucune SyntaxError ni erreur de compilation détectée sur l'ensemble de la session, malgré 9 modifications cumulées de RootNavigator.tsx.

Test complet des 3 rôles en fin de session, ordre pragmatique ADMIN → CLIENT → DRIVER (minimisant les rotations, le compte partagé étant déjà en CLIENT au moment de démarrer cette séquence — voir Section 2 et liste de suivi anomalie #16 pour le chaînon de rotation non documenté correspondant) :

| Rôle | Résultat | Détail |
|---|---|---|
| ADMIN | ✅ Aucune régression | Dashboard (KPIs cohérents), AdminMissionsScreen avec les 7 filtres intacts (dont "Expirées"), malgré les 9 modifications de RootNavigator.tsx. |
| CLIENT | ✅ Aucune régression | ClientHome/CreateMissionScreen fonctionnel avec le nouveau typage élargi, aucune régression sur le premier montage via initialParams. 13 avertissements d'accessibilité HTML confirmés préexistants et sans lien avec cette session. |
| DRIVER | ✅ Aucune régression | Nouvelle rotation complète effectuée (onboarding 4 étapes, validation admin, recharge wallet 1000 DH validée), DriverHomeScreen avec le code modifié (onOfferCreated) affiché sans erreur — chemin le plus modifié de la session, validé en dernier sur demande explicite du porteur après signalement honnête d'un risque résiduel. |

**Non testé, limite assumée** : le parcours complet de négociation de bout en bout (offre → contre-offre → double acceptation → MissionActive/MissionTracking) n'a pas pu être exercé en conditions réelles, faute de client et chauffeur actifs simultanément avec GPS fonctionnel dans cet environnement Codespaces. Une tentative de contournement par simulation GPS a été interrompue par l'incident réseau documenté ci-dessus, jamais reprise après résolution.

### État final

HEAD : c886722, synchronisé origin/main, confirmé par lecture directe (au sein de cette session — relayé ici en relais document, vérification par lecture directe de ma part restant à faire en début de prochaine session).

Prochain timestamp de migration disponible à l'issue de cette session : 20260504000024.

Fichiers créés : 3 migrations + 3 rollbacks (021 à 023, dont 021/022 avant reprise) ; MissionOfferScreen.tsx, DriverMissionOfferScreen.tsx, ClientMissionOfferScreen.tsx.

Fichiers modifiés : missionService.ts, realtimeService.ts, notificationTemplates.ts, pushNotificationService.ts, NewMissionModal.tsx, RootNavigator.tsx, MissionTrackingScreen.tsx, RatingScreen.tsx.

Backups : convention .bak.session2.14sexies reprise pour chaque fichier modifié, avec suffixes .v2/.v3/.v4 lorsqu'un fichier a été rouvert plusieurs fois dans la même session (traçabilité intégrale, tous les backups intermédiaires préservés) — nuance de convention nouvelle par rapport aux sessions précédentes.

État du numéro de test partagé à l'issue de cette session : voir Section 2 et Section 3 (profil DRIVER actif a53521ca-..., wallet 1000 DH).

Compte ADMIN +212600000001 : reconfirmé intact, jamais touché.

### Limites et réserves

- Test de bout en bout du parcours de négociation complet : jamais réalisé en conditions réelles. À réaliser en priorité dès qu'un environnement avec GPS fonctionnel et plusieurs comptes actifs simultanément sera disponible (device physique, Phase 4.x).
- Cause exacte de l'incident réseau Codespaces : non identifiée, contournée par redémarrage machine. À surveiller si le problème se reproduit.
- Countdown serveur par tour : arbitrage resté explicitement ouvert depuis la Partie 1, jamais retraité dans cette suite.
- WITH CHECK absent sur missions : documenté et reporté à une session future d'audit sécurité dès la Partie 1, non retraité.
- Extension au flux e-commerce : hors périmètre, reportée à la session 2.20 comme prévu dès la Partie 1.
- Cas authenticated de la policy drivers_select_available (découvert en 2.14 quinquies bis) : non retraité dans cette session.
- Doublon mort NOTIF_ICONS : documenté, non corrigé, hors périmètre strict.
- Erreur CORS sur send-push-notification (observée lors du test DRIVER) : probablement liée à l'infrastructure Codespaces, non bloquante, non investiguée plus avant.
- Avertissement gotrue-js "Lock ... was not released" observé lors du test DRIVER : comportement interne de la bibliothèque Supabase, récupération automatique documentée, sans impact observé, non investigué plus avant.

### Recommandations en attente d'arbitrage (issues de cette session)

- Test de bout en bout du parcours de négociation : à programmer dès que possible, environnement GPS fonctionnel + plusieurs comptes simultanés.
- Countdown serveur par tour : arbitrage à trancher (mécanisme existant confirmé transposable si le porteur souhaite le réintégrer).
- Cas authenticated de drivers_select_available : décision produit à trancher (voulu ou oubli).
- Doublon mort NOTIF_ICONS : nettoyage possible dans une session future touchant pushNotificationService.ts.
- Cause de l'incident réseau Codespaces : à surveiller, documenter précisément si récurrent.
- Erreur CORS send-push-notification : à vérifier hors environnement Codespaces (device physique).
- Contrainte d'unicité mission_id + driver_id : tranchée dans cette session (index unique partiel) — ne nécessite plus d'arbitrage.

### Chaîne de dépendance du chantier — mise à jour

```
2.14 ter ✅ → 2.14 quater ✅ → 2.14 quinquies ✅ → 2.14 quinquies bis ✅
→ 2.14 sexies ✅ (cette session, CLÔTURÉE avec réserves)
→ 2.14 septies (dépendance stricte : 2.14 sexies désormais livrée intégralement — peut démarrer)
→ 2.15 à 2.20 (inchangé)
```

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
   ⚠️ navigation.replace('DriverHome') cible toujours un écran absent du stack DriverPendingStack — bug distinct, non traité (voir Section 16)
DriverHomeScreen → attend driverId + vehicleCategory obligatoires → affiche solde wallet (table wallet sans 's') → carte Wallet → WalletDashboard { driverId } → bouton Mes documents → DocumentStatus → ✅ NotificationBell montée — session 2.14 → NotificationBell → NotificationCenterScreen ⚠️ Aucun bouton "← Retour" — Anomalie #1
   ✅ (session 2.14 quinquies) — abonnement subscribeToMissionUpdates dès réception d'une nouvelle mission pending (Volet 1) : fermeture automatique du modal de proposition si le statut de la mission change avant acceptation par ce chauffeur ; désabonnement systématique à chaque point de sortie
   ⚠️ PRÉCISION IMPORTANTE (session 2.14 sexies) — RÔLE DU VOLET 1 REQUALIFIÉ : ce mécanisme reste actif, mais avec le mécanisme de négociation à 2 tours désormais en place, une mission reste pending pendant toute la durée de la négociation. Le rôle du Volet 1 se restreint donc à la fermeture du modal en cas d'annulation/expiration de la mission — il ne couvre plus un scénario de "changement de chauffeur retenu" au sens où ce scénario n'existe plus de la même façon durant la phase de négociation (plusieurs chauffeurs peuvent avoir une offre active simultanément). Voir Section 2 et Section 6 (bloc session 2.14 sexies, § Partie 1) pour le détail complet.
   ✅ NOUVEAU (session 2.14 quinquies bis) — filtrage géospatial réel branché : dans le callback onNewMission, appel direct à la RPC find_nearby_drivers (Option 3) avant setPendingMission, catégorie VUL, rayon 60 km, comportement fail-open en cas d'échec de la vérification (voir RÉSOLU 51). Test d'exécution en conditions réelles (GPS) toujours en attente, Phase 4.x.
   ✅ NOUVEAU (session 2.14 sexies) — le bouton "✅ Accepter" de NewMissionModal.tsx, qui appelait directement acceptMission() (mécanisme "premier arrivé, premier servi"), est remplacé par un champ de saisie de prix + bouton "💰 Proposer ce prix" (appelant createMissionOffer()). Countdown 30s et bouton "❌ Refuser" inchangés. → navigation vers MissionOfferScreen (via DriverMissionOfferScreen wrapper) pour le suivi de la négociation (offre, contre-offre éventuelle, acceptation, ou retrait via rejectOfferAcceptance) → à la double acceptation, navigation vers MissionActiveScreen (route désormais déclarée, RÉSOLU 54).
   ✅ ACCÈS RÉTABLI (depuis session 2.14 sexies) pour le numéro de test partagé — nouveau profil DRIVER créé via un nouvel onboarding complet (a53521ca-...), distinct de tous les profils antérieurs.
TransactionHistoryScreen → ✅ Écoute Realtime branchée — session 2.14 (INSERT uniquement)

⚠️ is_verified = GENERATED ALWAYS AS — devient true quand driver_license_verified, vehicle_registration_verified, insurance_verified, technical_inspection_verified = 'verified'

# CHAÎNE DE NAVIGATION ADMIN

AdminDashboardScreen → Documents en attente → DocumentReviewScreen ✅ → Toutes les missions → AdminMissionsScreen ✅ → Gestion utilisateurs → AdminUsersScreen ✅ → Wallets & Transactions → WalletManagementScreen ✅ → ✅ NotificationBell montée — session 2.14 → NotificationBell → NotificationCenterScreen ⚠️ Anomalie #1

DocumentReviewScreen → Valider/Rejeter documents driver → Notification driver via insertNotification() → Driver fully verified → DriverHomeScreen (realtime)
   ⚠️ Bug d'affichage session 2.12 : modal ne se rafraîchit pas visuellement après validation du 4e/dernier document — non traité faute de temps, reporté à une session ultérieure à assigner

WalletManagementScreen → Liste drivers vérifiés avec solde → Recharger wallet → adminTopupDriverWallet() → Solde mis à jour en temps réel ✅
   ⚠️ Ne gère pas encore les demandes de recharge chauffeur en statut pending (voir Section 3) — écran de traitement dédié prévu session 2.17

AdminMissionsScreen → Liste toutes missions avec 7 filtres (dont expired, ajouté session 2.14 quinquies, incident de duplication détecté et corrigé — voir RÉSOLU 50) → Enum : pending / accepted / in_progress / completed / cancelled_client / cancelled_driver / expired
   ✅ Reconfirmé fonctionnel sans régression sessions 2.14 quinquies bis et 2.14 sexies

AdminUsersScreen → Liste drivers avec statut actif/suspendu → Suspendre/Activer via toggleUserActive() ⚠️ sans distinction Platform.OS

# CHAÎNE DE NAVIGATION CLIENT

CreateMissionScreen → ✅ NotificationBell montée — session 2.14 → NotificationBell → NotificationCenterScreen ⚠️ Anomalie #1
   ✅ (session 2.14 quater) — champ scheduled_pickup_time désormais OBLIGATOIRE (composant DateTimeField.tsx), bouton de soumission désactivé tant qu'une date/heure valide n'est pas sélectionnée, date passée rejetée, aucun délai minimum requis
   ✅ RECONFIRMÉ SANS RÉGRESSION (session 2.14 sexies) — fonctionnel avec le nouveau typage élargi de ClientHome ({ clientProfileId?: string })
   ⚠️ Le numéro de test partagé occupe actuellement le rôle DRIVER (depuis session 2.14 sexies) et non plus CLIENT — aucune mission n'a été insérée en base à ce jour, d'après l'ensemble des documents reçus pour la présente actualisation

MissionOfferScreen (nouveau, session 2.14 sexies, accessible via ClientMissionOfferScreen wrapper) → écran partagé client/chauffeur (voir Section 6, bloc session 2.14 sexies) → suivi du processus de négociation en 2 tours : réception des offres, envoi d'une contre-offre collective unique (submitClientCounterOffer), acceptation finale ou retrait (rejectOfferAcceptance) → à la double acceptation, navigation vers MissionActiveScreen/MissionTrackingScreen (routes réparées, RÉSOLU 53)
   ⚠️ Test de bout en bout non réalisé (nécessite CLIENT + DRIVER simultanés) — voir Section 15/16/17

MissionTrackingScreen.tsx → ✅ (session 2.14 quinquies, Volet 2) — nouveau useEffect actif uniquement si status === 'pending' et scheduled_pickup_time renseigné : vérification locale toutes les 30 secondes (EXPIRATION_CHECK_INTERVAL_MS), appel de expireMission() en base uniquement si expiration détectée ; nouveau case 'expired' dans renderStatus() (message dédié + bouton de recréation de mission)
   ✅ (session 2.14 sexies) — type local RootStackParamList corrigé (CreateMission → ClientHome), navigation.replace corrigés avec clientProfileId (RÉSOLU 53)
   ⚠️ Non testable en conditions réelles à ce jour — table missions vide (0 ligne), d'après l'ensemble des documents reçus

RatingScreen.tsx → ✅ (session 2.14 sexies) — type local corrigé, navigation.replace('ClientHome') désormais alimentés avec clientProfileId (RÉSOLU 53)

CreateParcelScreen (flux e-commerce) → ⚠️ Route 'CreateParcel' non déclarée dans frontend/src/navigation/, écran inaccessible depuis l'UI normale — correction assignée à la session 2.20 ; reconfirmé hors périmètre en session 2.14 sexies (extension e-commerce du mécanisme de négociation également reportée à 2.20)
   ✅ Champ scheduled_pickup_time intégré au titre de la dérogation Bloc 6 (session 2.14 quater) — non testable tant que le bug de navigation n'est pas corrigé

# PROBLÈMES RENCONTRÉS ET RÉSOLUS

[RÉSOLU 1 à 50 — inchangés, repris intégralement à l'identique de la version du 25/08/2026. Voir document source pour le détail complet de chaque entrée.]

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
[Contenu inchangé — reprise intégrale de la version du 25/08/2026.]

**RÉSOLU 44 — Absence de support web de DateTimeField.tsx (session 2.14 quater)**
[Contenu inchangé.]

**RÉSOLU 45 — Re-rendu en boucle corrompant la saisie clavier, DateTimeField.tsx (session 2.14 quater)**
[Contenu inchangé.]

**RÉSOLU 46 — Validation prématurée à la frappe, DateTimeField.tsx (session 2.14 quater)**
[Contenu inchangé.]

**RÉSOLU 47 — scheduled_pickup_time absent de tout point de création de mission (session 2.14 quater)**
[Contenu inchangé.]

**RÉSOLU 48 — Exposition de données sensibles sans authentification via les vues available_drivers et driver_dashboard (session 2.14 quinquies)**
[Contenu inchangé.]

**RÉSOLU 49 — Échec initial de déploiement de la migration de sécurité, SQLSTATE 42P16 (session 2.14 quinquies)**
[Contenu inchangé.]

**RÉSOLU 50 — Duplication de la déclaration STATUS_FILTERS dans AdminMissionsScreen.tsx (session 2.14 quinquies)**
[Contenu inchangé.]

**RÉSOLU 51 — Rayon par défaut incorrect (15 km au lieu de 60 km) et incompatibilité de format geography dans le mécanisme de diffusion géospatiale (session 2.14 quinquies bis)**
Cause : le wrapper findNearbyDrivers() (missionService.ts) portait un rayon par défaut de 15 km dans sa signature, alors que le paramètre validé pour le projet est 60 km — origine de cet écart restée inconnue (déjà signalée en session 2.14 quinquies). Par ailleurs, découverte en cours d'implémentation que le payload Realtime transmet les colonnes de type geography sous forme de chaîne hexadécimale EWKB, et non en texte lisible WKT — la RPC find_nearby_drivers utilisait ST_GeographyFromText(client_point), incompatible avec cet encodage tel que reçu depuis le canal Realtime.
Correctif : radiusKm par défaut corrigé à 60 dans findNearbyDrivers() ; remplacement de ST_GeographyFromText(client_point) par le cast natif client_point::geography, acceptant indifféremment WKT et HEXEWKB en entrée, confirmé rétrocompatible avec l'usage existant. Choix de conception (Option 3, validée par le porteur) : réutilisation directe de la RPC existante via appel supabase.rpc(...) dans le callback onNewMission de DriverHomeScreen.tsx, plutôt que duplication du calcul côté client. Comportement fail-open validé par le porteur en cas d'échec de la vérification de distance.
Fichiers : frontend/src/services/missionService.ts, frontend/src/screens/driver/DriverHomeScreen.tsx
Migration : supabase/migrations/20260504000019_fix_find_nearby_drivers_geography_cast.sql
Commits : c6a55eb (rayon + RPC), 26ebe20 (callback DriverHomeScreen.tsx)
Confirmé : CI vert sur les deux commits, vérifié par lecture directe de l'état réel de production (définition de fonction + droits d'exécution) — ⚠️ voir liste de suivi anomalie #17 (Section 6) pour une nuance de formulation relevée dans le compte-rendu source quant à la portée exacte de cette vérification par rapport à un test d'exécution réel du code applicatif, non tranchée dans le présent document. Test d'exécution complet en conditions réelles (GPS) toujours en attente, Phase 4.x ✅ (partiel)

**RÉSOLU 52 — Exposition en lecture non authentifiée de la table drivers (session 2.14 quinquies bis)**
Cause : GRANT SELECT accordé au rôle anon sur la table drivers, combiné à la policy RLS drivers_select_available sans filtre d'identité — découverte fortuitement en investiguant l'exposition de phone_number par la RPC find_nearby_drivers. Investigation confirmant que seul SELECT était concerné (INSERT/UPDATE/DELETE sains).
Correctif : REVOKE SELECT ON drivers FROM anon — portée strictement limitée au rôle anon, aucun autre privilège affecté. Le cas authenticated de la même policy (restant permissif pour tout utilisateur connecté) documenté séparément comme recommandation ouverte, non traité dans cette même correction (voir Section 18).
Fichier : supabase/migrations/20260504000020_revoke_anon_select_drivers.sql
Commit : 7fde087
Confirmé : CI vert, vérifié par lecture directe : SELECT bien retiré pour anon, INSERT/UPDATE/DELETE inchangés ✅

**RÉSOLU 53 — Routes de navigation client manquantes : MissionTracking, Rating absentes, ClientHome mal paramétrée (session 2.14 sexies)**
Cause : découverte en intégrant MissionOfferScreen au flux applicatif qu'un pan entier du parcours client post-mission (suivi de mission, notation du chauffeur) reposait sur des routes (MissionTracking, Rating) jamais déclarées dans RootNavigator.tsx — défaut préexistant, jamais détecté auparavant faute de mission jamais créée avec succès en test. Par ailleurs, la route ClientHome était typée undefined alors que la navigation vers cet écran nécessite de transmettre clientProfileId. Investigation bornée en 3 points, puis 3 vérifications complémentaires (disponibilité de clientProfileId, comportement initialParams/navigation.replace confirmé par la documentation officielle React Navigation, cascade complète des 4 points d'appel réels dans le code).
Correctif : ajout additif des routes MissionTracking/Rating à ClientStackParamList et déclaration des écrans dans ClientNavigator ; élargissement du typage ClientHome: undefined → { clientProfileId?: string } ; correction des appels navigation.replace dans MissionTrackingScreen.tsx et RatingScreen.tsx pour cibler le bon nom de route avec le bon paramètre (clientProfileId: mission.client_id ?? '').
Fichiers : frontend/src/navigation/RootNavigator.tsx, frontend/src/screens/client/MissionTrackingScreen.tsx, frontend/src/screens/client/RatingScreen.tsx
Commit : 3198c4a
Confirmé : validation explicite du porteur (double justification — nécessité fonctionnelle, sans laquelle le système de négociation serait inutilisable côté client ; considération stratégique de capitalisation sur l'investigation déjà menée) ; test de non-régression CLIENT réussi en fin de session, aucune erreur JavaScript ✅
⚠️ NOTE DE RAPPROCHEMENT (signalée, non tranchée — actualisation du 09/09/2026) : une entrée préexistante de la ROADMAP, issue de la session 2.14 d'origine ("Bug de reconnexion clientProfileId vide, RootNavigator.tsx" — voir Section 16 et Section 18), décrit un défaut touchant le même fichier et la même donnée (clientProfileId) que celui corrigé ici. Il est possible qu'il s'agisse du même défaut structurel, auquel cas cette entrée antérieure devrait être requalifiée en résolue par le présent RÉSOLU 53 ; il est tout aussi possible qu'il s'agisse d'un problème distinct, le mécanisme de découverte documenté ici ne faisant état d'aucun scénario de reconnexion. Ce rapprochement n'a pas pu être vérifié faute d'accès au compte-rendu original de la session 2.14.

**RÉSOLU 54 — Route de navigation MissionActive manquante côté chauffeur (session 2.14 sexies)**
Cause : découverte symétrique à RÉSOLU 53, lors de l'intégration finale de NewMissionModal.tsx — la route MissionActive n'était déclarée ni dans DriverStackParamList ni dans DriverNavigator, empêchant la navigation du chauffeur vers cet écran à l'issue d'une négociation conclue. Périmètre plus simple que RÉSOLU 53 : un seul point d'appel réel, aucune cascade, confirmé par investigation bornée en 3 points.
Correctif : ajout de la route MissionActive à DriverStackParamList et déclaration de l'écran dans DriverNavigator.
Fichier : frontend/src/navigation/RootNavigator.tsx
Commit : aff38a2
Confirmé : validation explicite du porteur ; test de non-régression DRIVER réussi en fin de session, DriverHomeScreen affiché sans erreur ✅

⚠️ Note de numérotation : RÉSOLU 43 (RLS voice-messages) précède chronologiquement RÉSOLU 44-47 (session 2.14 quater), lesquelles précèdent RÉSOLU 48-50 (session 2.14 quinquies), lesquelles précèdent RÉSOLU 51-52 (session 2.14 quinquies bis), lesquelles précèdent RÉSOLU 53-54 (session 2.14 sexies) — suivant l'ordre chronologique réel des découvertes au sein de chaque session.

⚠️ Point non attribué à un RÉSOLU, par choix méthodologique explicite (voir arbitrage du porteur lors de la préparation de cette actualisation) : le WITH CHECK ajouté dès la conception de la table mission_offers (session 2.14 sexies, migration 20260504000021) n'est pas documenté comme un RÉSOLU — il s'agit d'une mesure préventive prise dès la création d'une table nouvelle, en contrepartie explicite du report de la correction du WITH CHECK manquant sur la table missions (voir Section 6, bloc session 2.14 sexies, et Section 18), et non de la correction d'un défaut préexistant sur mission_offers elle-même.

# PISTES DÉFINITIVEMENT ÉCARTÉES

Ne pas retester : ❌ locationService import statique ❌ expo-haptics / expo-notifications ❌ expo-location fallback web ❌ missionService / realtimeService ❌ react-native-screens sans fallback web ❌ NativeStackScreenProps sans type ❌ Dépendance circulaire missionService ❌ audioService / expo-av (contexte débogage page blanche — n'implique pas l'abandon de la fonctionnalité messages vocaux) ❌ supabaseClient.ts ❌ showAuth logique incorrecte ❌ ErrorBoundary capture l'erreur ❌ --no-dev résout seul ❌ 'cancelled' comme valeur enum mission_status ❌ cron.run_job(integer) ❌ owner = auth.uid() comme clause RLS Storage simple (raccourci écarté au profit de la chaîne de propriété complète, RÉSOLU 36) ❌ Modification directe du solde wallet par le chauffeur (Option B écartée, session 2.13, RÉSOLU 38) ❌ python3 -c "..." en ligne directe pour tout texte contenant un caractère spécial bash (écarté au profit du heredoc quoté, session 2.14) ❌ notifyNewMission comme fonction notify* branchable isolément (incompatibilité structurelle confirmée, session 2.14, reconfirmée 2.14 bis et 2.14 quinquies) ❌ Correction d'initializeApp() pour distribuer systématiquement profiles.id (écartée au profit de getCurrentProfileId(), session 2.14) ❌ Remplacement du canal vocal (VoiceChatScreen.tsx) par un canal texte (décision de conservation actée session 2.14 bis)
❌ Accès admin dans la clause RLS voice-messages (session 2.14 ter) — écarté par le porteur : aucun besoin métier documenté ne justifie qu'un admin lise du contenu audio privé
❌ Factorisation SQL des 4 policies voice-messages via fonction partagée (session 2.14 ter) — écartée au profit de la duplication littérale, fidèle au pattern RÉSOLU 36
❌ Test symétrique de la contrainte scheduled_pickup_time NOT NULL par insertion SQL directe (session 2.14 quater) — décision explicite du porteur, pour éviter de polluer la base de production
❌ Modification de LegalDocumentsScreen.tsx ou import direct par DateTimeField.tsx (session 2.14 quater) — hors périmètre, aucune dérogation accordée
❌ CREATE OR REPLACE VIEW pour retirer une colonne existante d'une vue (session 2.14 quinquies) — écarté après échec réel (SQLSTATE 42P16), au profit d'une séquence DROP + CREATE — voir RÉSOLU 49
❌ Mécanisme CRON pour la détection d'expiration des missions pending (session 2.14 quinquies) — écarté au profit d'une vérification locale côté client toutes les 30 secondes — décision métier du porteur
❌ Duplication du calcul géospatial côté client, ou modification de locationService.ts (fichier stable) (session 2.14 quinquies bis) — écartées au profit de la réutilisation directe de la RPC find_nearby_drivers existante (Option 3), appelée depuis le callback onNewMission
❌ Contrainte absolue (non partielle) sur mission_offers (mission_id, driver_id) (session 2.14 sexies) — écartée au profit d'un index unique partiel WHERE status='pending', après relecture croisée ayant identifié un cas limite non voulu (une offre not_selected doit rester réactivable par une nouvelle ligne)
❌ Retour au statut pending après un refus d'acceptation via rejectOfferAcceptance (session 2.14 sexies) — écarté au profit d'un statut not_selected définitif, confirmé explicitement par le porteur, cohérent avec l'index unique partiel
❌ Dialogue de contre-offre individualisé par chauffeur (session 2.14 sexies) — écarté au profit d'une contre-offre unique et collective, envoyée à tous les chauffeurs du tour 1 — décision explicite du porteur ("le client ne va pas s'amuser à faire des contre-offres différentes d'un chauffeur à l'autre")
❌ Recours exclusif au filet de sécurité global cancelMission() pour gérer le retrait d'une acceptation en cours (session 2.14 sexies) — écarté au profit d'un mécanisme localisé et symétrique (rejectOfferAcceptance), à l'arbitrage explicite du porteur

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
20260504000019_fix_find_nearby_drivers_geography_cast.sql ✅ Session 2.14 quinquies bis
20260504000020_revoke_anon_select_drivers.sql ✅ Session 2.14 quinquies bis
20260504000021_create_mission_offers.sql ✅ Session 2.14 sexies
20260504000022_mission_offer_acceptance_sync.sql ✅ Session 2.14 sexies
20260504000023_add_unique_pending_offer_constraint.sql ✅ Session 2.14 sexies

Aucune migration SQL déployée en session 2.14 (session applicative/service) ni en session 2.14 bis (session investigative).

Prochain timestamp disponible : 20260504000024

# EDGE FUNCTIONS DÉPLOYÉES

send-push-notification ✅ (CORS bloqué sur web — fonctionnel sur device ; erreur CORS reconfirmée observée lors des tests de la session 2.14 sexies, non investiguée plus avant)
register-push-token ✅
check-document-reminders ✅ (CRON opérationnel — session 2.9, 5 exécutions succeeded 18→22/06/2026)
   ⚠️ Lien avec notifyDocumentExpiry non vérifié — non traité en 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, ni 2.14 sexies (hors périmètre de chacune)
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
│       │   └── RootNavigator.tsx ← modifié sessions 2.14, 2.14 sexies (9 modifications cumulées : routes MissionOffer/MissionTracking/Rating/MissionActive ajoutées, ClientHome élargie, wrappers substitués — voir Section 6, RÉSOLU 53/54) ; ⚠️ ne déclare TOUJOURS PAS la route 'CreateParcel' (bug découvert session 2.14 quater, assigné session 2.20)
│       ├── screens/
│       │   ├── admin/
│       │   │   ├── AdminDashboardScreen.tsx ← modifié session 2.14
│       │   │   ├── AdminMissionsScreen.tsx ← créé session 2.7 ; modifié session 2.14 quinquies (ajout filtre expired, RÉSOLU 50)
│       │   │   ├── AdminUsersScreen.tsx ← créé session 2.7
│       │   │   ├── DocumentReviewScreen.tsx
│       │   │   └── WalletManagementScreen.tsx
│       │   ├── auth/
│       │   │   ├── OTPVerificationScreen.tsx
│       │   │   ├── PhoneInputScreen.tsx
│       │   │   └── ProfileSetupScreen.tsx ← INTOUCHABLE
│       │   ├── client/
│       │   │   ├── CreateMissionScreen.tsx ← modifié sessions 2.14 + 2.14 quater (scheduled_pickup_time obligatoire, DateTimeField)
│       │   │   ├── MissionTrackingScreen.tsx ← modifié session 2.14 quinquies (Volet 2) ; modifié session 2.14 sexies (correction type local + navigation.replace, RÉSOLU 53)
│       │   │   ├── RatingScreen.tsx ← modifié session 2.14 sexies (correction type local + navigation.replace, RÉSOLU 53)
│       │   │   └── ClientMissionOfferScreen.tsx ← NOUVEAU, créé session 2.14 sexies (commit c886722) — wrapper adaptant route.params/navigation vers les props de MissionOfferScreen
│       │   ├── driver/
│       │   │   ├── DocumentStatusScreen.tsx
│       │   │   ├── DriverHomeScreen.tsx ← modifié session 2.14 ; modifié session 2.14 quinquies (Volet 1, commit d1869e4) ; modifié session 2.14 quinquies bis (branchement géospatial, commit 26ebe20)
│       │   │   ├── MissionActiveScreen.tsx ← route désormais déclarée dans RootNavigator (session 2.14 sexies, RÉSOLU 54)
│       │   │   ├── MissionOfferScreen.tsx ← NOUVEAU, créé session 2.14 sexies (426 lignes, commits be13041 puis 7cf6fd7) — composant PARTAGÉ client/chauffeur, rangé sous driver/ par convention historique du fichier (précision reçue directement de l'assistant de session, information absente du compte-rendu écrit initial)
│       │   │   ├── DriverMissionOfferScreen.tsx ← NOUVEAU, créé session 2.14 sexies (commit c886722) — wrapper adaptant route.params/navigation vers les props de MissionOfferScreen
│       │   │   ├── NewMissionModal.tsx ← lu intégralement session 2.14 bis ; modifié session 2.14 sexies (bouton Accepter → champ prix + Proposer ce prix, commit 3d6717e)
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
│       │   │   └── VoiceChatScreen.tsx ← confirmé orphelin session 2.14 ; canal conservé, activation désormais possible (dépendance envers 2.14 sexies levée — voir Section 18)
│       │   ├── notifications/
│       │   │   └── NotificationCenterScreen.tsx ← modifié session 2.14
│       │   └── tracking/
│       │       ├── TrackingDetailScreen.tsx
│       │       └── TrackingInputScreen.tsx
│       ├── services/
│       │   ├── adminService.ts
│       │   ├── audioService.ts ← CONFIRMÉ fichier réel du canal vocal, lu intégralement, non modifié
│       │   ├── authService.ts ← INTOUCHABLE
│       │   ├── documentService.ts
│       │   ├── driverService.ts ← STABLE INTOUCHABLE
│       │   ├── i18nService.ts
│       │   ├── locationService.ts ← lu en profondeur session 2.14 quinquies, non modifié — startBackgroundTracking() confirmé (intervalle 15s / 50m) ; non modifié non plus en 2.14 quinquies bis (décision explicite de réutiliser la RPC existante plutôt que ce fichier)
│       │   ├── missionService.ts ← modifié sessions 2.14, 2.14 quater, 2.14 quinquies ; modifié session 2.14 quinquies bis (rayon 60km, commit c6a55eb) ; modifié session 2.14 sexies (6 nouvelles fonctions liées aux offres — createMissionOffer, counterMissionOffer, acceptMissionOffer, rejectOfferAcceptance, submitClientCounterOffer, getMissionById — commits 263c287/345b0a3/d163825/7cf6fd7)
│       │   ├── notificationTemplates.ts ← lu session 2.14 quinquies ; modifié session 2.14 sexies (4 nouvelles fonctions offer_update, commits 2fc0e29/d163825)
│       │   ├── parcelService.ts ← modifié session 2.14 quater (scheduled_pickup_time)
│       │   ├── pushNotificationService.ts ← modifié session 2.14 ; modifié session 2.14 sexies (4 nouvelles fonctions offer_update) ; ⚠️ doublon mort NOTIF_ICONS non corrigé, découvert session 2.14 sexies
│       │   ├── realtimeService.ts ← lu session 2.14 bis ; modifié session 2.14 sexies (2 nouveaux canaux subscribeToMissionOffers/subscribeToDriverOffers, commit 3e2a07a)
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
│   │   ├── 20260221000000_add_rpc_nearby_drivers.sql ← RPC find_nearby_drivers, code mort confirmé session 2.14 bis, sécurisée session 2.14 quinquies (migration 017), cast geography corrigé + branchée réellement session 2.14 quinquies bis (migration 019, voir RÉSOLU 51)
│       │   ├── … (fichiers intermédiaires inchangés) …
│   │   │   ├── 20260504000013_fix_storage_transactions_rls_ownership.sql ← session 2.12
│   │   ├── 20260504000014_rename_revenue_to_recharges_driver_dashboard.sql ← session 2.13
│   │   ├── 20260504000015_fix_rls_voice_messages.sql ← session 2.14 ter
│   │   ├── 20260504000016_add_scheduled_pickup_time_not_null.sql ← session 2.14 quater
│   │   ├── 20260504000017_fix_available_drivers_and_driver_dashboard_exposure.sql ← session 2.14 quinquies
│   │   ├── 20260504000018_add_expired_status_to_mission_status.sql ← session 2.14 quinquies
│   │   ├── 20260504000019_fix_find_nearby_drivers_geography_cast.sql ← session 2.14 quinquies bis
│   │   ├── 20260504000020_revoke_anon_select_drivers.sql ← session 2.14 quinquies bis
│   │   ├── 20260504000021_create_mission_offers.sql ← session 2.14 sexies
│   │   ├── 20260504000022_mission_offer_acceptance_sync.sql ← session 2.14 sexies
│   │   └── 20260504000023_add_unique_pending_offer_constraint.sql ← session 2.14 sexies
│   └── rollbacks/
│       ├── rollback_20260504000013.sql ← session 2.12
│       ├── 20260504000014_rename_revenue_to_recharges_driver_dashboard_rollback.sql ← session 2.13
│       ├── 20260504000015_fix_rls_voice_messages_rollback.sql ← session 2.14 ter
│       ├── 20260504000016_add_scheduled_pickup_time_not_null_rollback.sql ← session 2.14 quater
│       ├── 20260504000017_fix_available_drivers_and_driver_dashboard_exposure_rollback.sql ← session 2.14 quinquies
│       ├── 20260504000018_add_expired_status_to_mission_status_rollback.sql ← session 2.14 quinquies (documentaire uniquement)
│       ├── 20260504000019_fix_find_nearby_drivers_geography_cast_rollback.sql ← session 2.14 quinquies bis
│       ├── 20260504000020_revoke_anon_select_drivers_rollback.sql ← session 2.14 quinquies bis (avec avertissement explicite sur la réintroduction de la faille en cas d'exécution)
│       ├── 20260504000021_create_mission_offers_rollback.sql ← session 2.14 sexies (jamais exécuté)
│       ├── 20260504000022_mission_offer_acceptance_sync_rollback.sql ← session 2.14 sexies (jamais exécuté)
│       └── 20260504000023_add_unique_pending_offer_constraint_rollback.sql ← session 2.14 sexies
├── .env.example
├── .gitignore
├── ROADMAP_FTM.md
└── install_*.sh
```

⚠️ Note sur les chemins de MissionOfferScreen.tsx et de ses deux wrappers : ces trois chemins ont été communiqués directement à la présente conversation par l'assistant ayant conduit la session 2.14 sexies, en réponse à une lacune identifiée dans son compte-rendu écrit initial (qui ne les précisait pas). Il s'agit d'une information de première main (l'assistant ayant lui-même créé ces fichiers dans sa session), acceptée comme fait confirmé pour la présente actualisation.

Note : ~59+ fichiers untracked de type .bak* présents dans le dépôt (mécanisme de traçabilité délibéré), dont 4 nouveaux ajoutés en session 2.14 quater, 4 nouveaux ajoutés en session 2.14 quinquies (suffixe .bak.session2.14quinquies), AUCUN nouveau en session 2.14 quinquies bis (écart noté, voir Section 2 et Section 6), et plusieurs nouveaux (avec versionnement .v2/.v3/.v4) en session 2.14 sexies (suffixe .bak.session2.14sexies) — non représentés dans l'arborescence ci-dessus par souci de lisibilité.

# SERVICES EXTERNES — ÉTAT

Twilio SMS : ⏳ pas encore configuré
FCM Android : ⏳ pas encore configuré
   ⚠️ send-push-notification bloquée par CORS sur web — fonctionnel sur device physique uniquement
   ⚠️ Dépendance croisée confirmée session 2.14 : les fonctions notify* mission (dont les 4 nouvelles de 2.14 sexies) appellent dispatchPushNotification() → push mobile réel non pleinement opérationnel tant que FCM/APNs non configurés
APNs iOS : ⏳ pas encore configuré

Storage buckets :
   ✅ driver-documents créé — ✅ RLS ownership chain — session 2.12
   ✅ voice-messages créé — session 2.8
   ✅ RLS ownership CORRIGÉE — session 2.14 ter (RÉSOLU 46) — double chaîne client + chauffeur, indice [2]
   ⚠️ voice-messages non testé fonctionnellement (audioService.ts non intégré UI côté screen — canal orphelin) — test complet reporté Phase 4.4 / session 2.18. Activation planifiée session 2.14 septies, dont la dépendance envers 2.14 sexies est désormais levée (voir Section 18).

CRON reminders : ✅ OPÉRATIONNEL — session 2.9 — 5 exécutions succeeded 18→22/06/2026
   ⚠️ Lien avec notifyDocumentExpiry non vérifié

Wallet topup : ✅ Mécanisme honnête opérationnel — session 2.13 — reconfirmé intact (données) après sessions 2.14, 2.14 bis, 2.14 ter, 2.14 quinquies, 2.14 quinquies bis ; accès Auth du profil porteur historique supprimé en session 2.14 quater, occupé successivement par différents profils DRIVER depuis (voir Section 3), données du profil historique inchangées. Recharge de 1000 DH testée et confirmée session 2.14 sexies sur le profil DRIVER actif actuel.

Realtime transactions/notifications : ✅ subscribeToNewTransactions branché — session 2.14 (INSERT uniquement) — ✅ NotificationBell/Center montés 3 rôles
   ✅ (session 2.14 quinquies) — subscribeToMissionUpdates exploité côté DriverHomeScreen.tsx (Volet 1) — rôle requalifié depuis 2.14 sexies (voir Section 2/3/7)
   ✅ NOUVEAU (session 2.14 sexies) — subscribeToMissionOffers (client) et subscribeToDriverOffers (chauffeur) sur la table mission_offers
   ⚠️ Anomalie #1 : bouton retour manquant sur NotificationCenterScreen

Sécurité des vues Supabase exposées : ✅ CORRIGÉE — session 2.14 quinquies (RÉSOLU 48/49) — available_drivers et driver_dashboard ne sont plus accessibles sans authentification. 🆕 Sécurité étendue à la table drivers (SELECT anon révoqué) — session 2.14 quinquies bis (RÉSOLU 52). Recommandation ouverte : audit des permissions GRANT par défaut sur l'ensemble du schéma public (voir Section 18), désormais également motivé par la découverte de l'absence de WITH CHECK sur missions (session 2.14 sexies).

Géolocalisation avancée : ✅ Infrastructure PostGIS complète (RPC find_nearby_drivers) confirmée existante, active, sécurisée (session 2.14 quinquies) et désormais BRANCHÉE ET DÉPLOYÉE dans le flux de diffusion réel (session 2.14 quinquies bis, RÉSOLU 51) — rayon corrigé à 60 km, cast geography corrigé pour l'encodage HEXEWKB du payload Realtime, comportement fail-open. ⚠️ Test d'exécution complet en conditions réelles (GPS fonctionnel) toujours en attente, non réalisable en Codespaces — Phase 4.x.

Négociation de prix structurée : ✅ NOUVEAU (session 2.14 sexies) — table mission_offers, RLS (3 policies symétriques + WITH CHECK dès conception), 2 triggers (transition, synchronisation missions), index unique partiel, 6 fonctions de service, 2 canaux Realtime, 4 notifications, écran partagé MissionOfferScreen + 2 wrappers de navigation, mécanisme "premier arrivé premier servi" remplacé. Schéma en 2 tours maximum avec double acceptation symétrique obligatoire. ⚠️ Test de bout en bout non réalisé en conditions réelles (nécessite CLIENT + DRIVER simultanés avec GPS fonctionnel) — voir Section 16/17/18.

Planification par date/heure : ✅ OPÉRATIONNELLE — session 2.14 quater — scheduled_pickup_time obligatoire (NOT NULL + UI), transport classique et e-commerce
   ✅ Volet 2 (expiration mission pending à scheduled_pickup_time dépassé) — implémenté session 2.14 quinquies
   ⚠️ Flux e-commerce non testable en pratique tant que le bug de navigation CreateParcel n'est pas corrigé (session 2.20)

# BUGS RÉSIDUELS

⚠️ CORS send-push-notification Edge Function bloquée par CORS policy sur web — non bloquant web, fonctionnel sur device physique — à corriger pour production. Reconfirmée observée lors des tests DRIVER de la session 2.14 sexies, non investiguée plus avant — à vérifier hors environnement Codespaces (voir Section 18).

⚠️ Filtres AdminMissionsScreen — affichés mais aucune mission en base — cause confirmée (GPS bloqué environnement web/Codespaces) — reporté phase 4.x — 7 filtres disponibles depuis session 2.14 quinquies (dont expired), reconfirmés intacts sessions 2.14 quinquies bis et 2.14 sexies

⚠️ Realtime driver end-to-end — flux avec 2 fenêtres simultanées non testé explicitement — désormais également pertinent pour le test de bout en bout du parcours de négociation de prix (session 2.14 sexies)

⚠️ AdminMissions pagination — non testée (0 missions en base)

⚠️ DocumentReviewScreen.tsx — rafraîchissement modal (session 2.12) — non traité faute de temps, reporté à une session ultérieure à assigner

⚠️ Profils DRIVER/CLIENT antérieurs orphelins (données intactes, accès Auth occupé par le profil DRIVER actif a53521ca-... depuis session 2.14 sexies) — voir Section 3 pour l'état complet :
   driverId : 2ec2b439-fcdb-443d-8de0-5bee268d30f6 (données en base uniquement, aucun accès Auth actif depuis session 2.14 quater)
   wallet_balance réel : 800.00 DH — 4 demandes en pending (50/200/500/1000 DH) — à ne pas altérer sans décision explicite (preuve de fonctionnement du correctif RÉSOLU 38)
   Profil DRIVER créé en session 2.14 quinquies (300 DH, VUL) — driverId inconnu, orphelin depuis une rotation ultérieure non précisément documentée (voir liste de suivi anomalie #16)
   Profil(s) CLIENT intermédiaire(s) — existence indirectement confirmée par la mention "dont un profil client sans historique de mission" du compte-rendu 2.14 sexies, caractéristiques précises INCONNUES

⚠️ Dossiers Storage orphelins (session 2.12) — driver-documents : 8 orphelins + 1 actif — aucune session de nettoyage planifiée

⚠️ COMPORTEMENT NON EXPLIQUÉ — repr() vs terminal (session 2.9) — statut INCONNU, non bloquant

⚠️ Navigation cross-stack PendingVerification → DriverHome — navigation.replace('DriverHome') cible un écran absent du stack DriverPendingStack — NON traité à ce jour (2.13, 2.14, 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, 2.14 sexies) — bug entier, session à assigner

⚠️ subscribeToNewTransactions — limitation résiduelle : écoute INSERT uniquement, pas UPDATE

⚠️ AdminUsersScreen.tsx — Alert.alert sans Platform.OS — candidat audit session 2.19

⚠️ WalletTopupScreen.tsx ligne 66 — message d'erreur non vérifié — candidat audit session 2.19

⚠️ Coexistence total_commissions / commissions_current_month — à surveiller lors du chantier reporting financier (Section 18)

⚠️ Risque de pagination totalCredit/totalDebit (TransactionHistoryScreen.tsx) — à surveiller lors du chantier reporting financier (Section 18)

⚠️ Anomalie #1 — Absence de bouton "← Retour" sur NotificationCenterScreen.tsx — non bloquant, à corriger avant Phase 3, candidat audit session 2.19 — reconfirmée en conditions réelles session 2.14 quinquies

⚠️ Fonctions notify* mission non testées fonctionnellement de bout en bout — nécessite un second numéro de test dédié au rôle client (voir Section 18). Point réactualisé session 2.14 sexies : ceci concerne désormais également les 4 nouvelles fonctions notify* liées à la négociation de prix, ainsi que le test complet du parcours de négociation lui-même.

⚠️ Cloche NotificationBell côté Client non testée en conditions réelles — reportée avec le test des fonctions notify* mission

⚠️ Chemin natif (hors web) non testé — Alert.alert/Platform.OS (RÉSOLU 42) — à vérifier Phase 4

⚠️ Point de sécurité cancelMission/userId — le renommage de paramètre (_userId → userId) est confirmé effectif dans le code, mais AUCUNE vérification d'autorisation n'a été ajoutée — le point de sécurité de fond reste entier, rattaché à la session 2.17 (décision actée session 2.14, reconfirmée pertinente session 2.14 quater, RECONFIRMÉE PRÉEXISTANTE ET NON AGGRAVÉE session 2.14 sexies — lecture directe de missionService.ts, § Partie 1 investigation).

⚠️ notifyDocumentExpiry — en attente, lien check-document-reminders non vérifié — non traité en 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, ni 2.14 sexies

⚠️ Bug de reconnexion clientProfileId vide (RootNavigator.tsx) — découverte annexe session 2.14, hors périmètre, session future non assignée
⚠️ NOTE DE RAPPROCHEMENT (signalée, non tranchée — actualisation du 09/09/2026) : cette entrée, issue de la session 2.14 d'origine et décrivant un "bug de reconnexion", touche le même fichier (RootNavigator.tsx) et la même donnée (clientProfileId) que le défaut corrigé par RÉSOLU 53 (session 2.14 sexies — routes MissionTracking/Rating jamais déclarées, ClientHome typée undefined sans clientProfileId). Il est possible qu'il s'agisse du même défaut structurel, auquel cas cette entrée devrait être requalifiée en résolue ; il est tout aussi possible qu'il s'agisse d'un problème distinct (le mécanisme de découverte documenté pour RÉSOLU 53 ne mentionne aucun scénario de reconnexion). Ce rapprochement n'a pas pu être vérifié faute d'accès au compte-rendu original de la session 2.14 — voir RÉSOLU 53, Section 10, pour la note symétrique.

⚠️ Robustesse topupWallet/refundWallet (échec silencieux insertion transaction) — découverte annexe session 2.14, à vérifier lecture directe début session 2.17

⚠️ VoiceChatScreen.tsx orphelin + dossier ecommerce/ — canal conservé, activation désormais possible : la dépendance de la session 2.14 septies envers la clôture de 2.14 sexies est levée (voir Section 18) ; dossier ecommerce/ reste non exploré en profondeur au-delà du périmètre strict de 2.14 quater

⚠️ NOUVEAU (session 2.14 ter) — Correction de cohérence documentaire, décompte transactions pending driver test historique : corrigé en 4 demandes (50/200/500/1000 DH), confirmé par lecture directe des dates de création.

⚠️ NOUVEAU (session 2.14 quater) — Route de navigation CreateParcel manquante : assignée à la session 2.20. Reconfirmée hors périmètre en session 2.14 sexies (extension e-commerce du mécanisme de négociation également reportée à cette même session 2.20).

⚠️ NOUVEAU (session 2.14 quater) — Points d'enrichissement fonctionnel non traités liés à scheduled_pickup_time : notifyRecipientBySMS et getClientParcels — piste non assignée, à arbitrer.

⚠️ NOUVEAU (session 2.14 quater) — Points techniques mineurs DateTimeField.tsx (décalage fuseau horaire, borne min figée, cas limite '' vs null, comportement iOS spinner) — non bloquants, consignés pour référence future.

⚠️ NOUVEAU (session 2.14 quinquies) — Volet 2, limite assumée : une mission pending expirée reste techniquement en base tant qu'aucun écran client ne la consulte — compromis explicitement accepté, à réévaluer si le volume réel augmente.

⚠️ NOUVEAU (session 2.14 quinquies bis) — Cas authenticated de la policy drivers_select_available : reste permissive pour tout utilisateur connecté, sans filtre sur le chauffeur concerné — décision produit à trancher (voulu ou oubli), non traité en session 2.14 sexies.

⚠️ NOUVEAU (session 2.14 quinquies bis) — Cause de l'incident réseau/tunnel Codespaces observé lors des tests de la session 2.14 sexies (7.1 du compte-rendu source) : non identifiée avec certitude, contournée par redémarrage complet de la machine du porteur — à surveiller si le problème se reproduit. [Précision : cet incident est bien survenu au cours de la session 2.14 sexies, et non 2.14 quinquies bis — vérifié lors de la rédaction du présent document par relecture directe des trois sources reçues.]

⚠️ NOUVEAU (session 2.14 sexies) — Countdown serveur par tour (négociation de prix) : arbitrage explicitement laissé ouvert par le porteur, ni intégré ni définitivement écarté — mécanisme d'expiration existant (30s, sans CRON) confirmé transposable si besoin futur.

⚠️ NOUVEAU (session 2.14 sexies) — WITH CHECK absent sur la policy UPDATE de la table missions (et missions_update_admin) : confirmé NULL par lecture directe (pg_policies). Décision explicite du porteur de reporter la correction à une session future d'audit sécurité — à rattacher à la recommandation déjà existante "audit des permissions GRANT par défaut sur le schéma public" (voir Section 18).

⚠️ NOUVEAU (session 2.14 sexies) — Doublon mort NOTIF_ICONS dans pushNotificationService.ts, jamais importé nulle part (confirmé par grep global) — préexistant, hors périmètre, non corrigé.

⚠️ NOUVEAU (session 2.14 sexies) — Avertissement gotrue-js "Lock ... was not released" observé lors du test DRIVER — comportement interne de la bibliothèque Supabase, récupération automatique documentée, sans impact observé, non investigué plus avant.

⚠️ NOUVEAU (actualisation du 09/09/2026) — Chaînon de rotation du numéro de test partagé non documenté entre les sessions 2.14 quinquies bis et 2.14 sexies — voir Section 2 et liste de suivi anomalie #16 (Section 6).

# TESTS DE NON-RÉGRESSION

[Sessions 2.7 à 2.14 quinquies — inchangées, reprises intégralement à l'identique de la version du 25/08/2026. Voir document source. Ajout des sessions 2.14 quinquies bis et 2.14 sexies ci-dessous.]

EFFECTUÉS ET CONFIRMÉS ✅ — SESSIONS 2.7 à 2.14 quinquies : [contenu inchangé, voir historique complet ci-dessus dans les blocs "Modifications commitées"]

**SESSION 2.14 quinquies bis — TESTS EFFECTUÉS ET CONFIRMÉS ✅ :**

Ordre pragmatique ADMIN → DRIVER (porteur déjà connecté en admin au moment du test).

| Rôle | Résultat | Détail |
|---|---|---|
| ADMIN | ✅ Aucune régression | Dashboard, AdminMissionsScreen (7 filtres intacts dont "Expirées"), notifications, gestion utilisateurs — accès aux données chauffeurs confirmé fonctionnel pour authenticated malgré le retrait de l'accès anon. Console propre. |
| DRIVER | ✅ (partiel) | Écran principal, wallet, notifications sans régression. Blocage GPS confirmé géré proprement. Le code de filtrage par distance (Volet A) n'a pas pu être exécuté (startBackgroundTracking() échoue avant subscribeToNewMissions). |

**SESSION 2.14 quinquies bis — TESTS NON EFFECTUÉS (justifiés) :**
- CLIENT : CreateMissionScreen.tsx non modifié, risque jugé nul, décision du porteur de préserver le profil DRIVER de test actif plutôt qu'une rotation.
- Test d'exécution complet du Volet A en conditions réelles (GPS) : impossible en Codespaces, reporté Phase 4.x.

**SESSION 2.14 sexies — TESTS EFFECTUÉS ET CONFIRMÉS ✅ :**

Tests d'exécution réels systématiques après chaque écriture (serveur relancé, console DevTools) tout au long de la session — aucune SyntaxError ni erreur de compilation détectée, malgré 9 modifications cumulées de RootNavigator.tsx.

Test complet des 3 rôles en fin de session, ordre pragmatique ADMIN → CLIENT → DRIVER :

| Rôle | Résultat | Détail |
|---|---|---|
| ADMIN | ✅ Aucune régression | Dashboard (KPIs cohérents), AdminMissionsScreen (7 filtres intacts dont "Expirées"), malgré les 9 modifications de RootNavigator.tsx. |
| CLIENT | ✅ Aucune régression | ClientHome/CreateMissionScreen fonctionnel avec le nouveau typage élargi, aucune régression sur le premier montage via initialParams. 13 avertissements d'accessibilité HTML confirmés préexistants et sans lien avec cette session. |
| DRIVER | ✅ Aucune régression | Nouvelle rotation complète effectuée (onboarding 4 étapes, validation admin, recharge wallet 1000 DH validée), DriverHomeScreen avec le code modifié (onOfferCreated) affiché sans erreur — chemin le plus modifié de la session, validé en dernier sur demande explicite du porteur. |

**SESSION 2.14 sexies — TESTS NON EFFECTUÉS (justifiés) :**
- Parcours complet de négociation de bout en bout (offre → contre-offre → double acceptation → MissionActive/MissionTracking) — non exercé en conditions réelles, faute de client et chauffeur actifs simultanément avec GPS fonctionnel. Tentative de contournement par simulation GPS interrompue par l'incident réseau Codespaces, jamais reprise après résolution.

# ÉTAPES RESTANTES

PHASE 2 — TESTS & DEBUGGING
2.1 à 2.11 ✅ COMPLET [inchangé, voir détail Section 6]
2.12 ✅ COMPLET — RLS Storage (driver-documents) + transactions_insert_own
2.13 ✅ COMPLET — Cause racine RLS wallet + recharge honnête + correction nommage + navigation
2.14 ✅ COMPLET (avec réserves) — Realtime + Notification Center + notify mission
2.14 bis ✅ COMPLET — Investigation/planification processus de mission
2.14 ter ✅ COMPLET — Correction sécurité RLS voice-messages
2.14 quater ✅ COMPLET (avec réserves) — Piste 3, planification par date/heure
2.14 quinquies ✅ COMPLET (avec réserves) — Piste 1, sécurisation infrastructure diffusion + Volets 1/2 expiration
   [Détail inchangé, voir version du 25/08/2026]

2.14 quinquies bis ✅ COMPLET (avec réserves) — Piste 1 (suite), branchement effectif de la diffusion géospatiale par distance réelle
   → Périmètre initial élargi sur décision explicite du porteur pour traiter une faille de sécurité découverte fortuitement (exposition anon de la table drivers) — corrigée et vérifiée ✅ (RÉSOLU 52)
   → Volet A implémenté et déployé : rayon corrigé (15→60km), cast geography corrigé pour l'encodage HEXEWKB, RPC find_nearby_drivers appelée directement depuis le callback onNewMission (Option 3), comportement fail-open validé par le porteur ✅ (RÉSOLU 51)
   → Volet B implémenté et déployé : REVOKE SELECT anon sur drivers ✅ (RÉSOLU 52)
   → Tests de non-régression ADMIN/DRIVER : ✅ aucune régression ; CLIENT non testé (décision assumée)
   → ⚠️ Test d'exécution complet du Volet A en conditions réelles (GPS) NON réalisé — reporté Phase 4.x
   → ⚠️ Aucun nouveau .bak* créé cette session — écart à la convention habituelle, noté
   → Nouvelles recommandations : cas authenticated de drivers_select_available ; test CLIENT à intégrer dans un futur test de non-régression

2.14 sexies ✅ COMPLET (avec réserves) — Piste 2, négociation de prix structurée
   → Table mission_offers créée avec RLS (3 policies symétriques) et WITH CHECK dès conception, 2 triggers (transition à 4 garde-fous, synchronisation missions) ✅
   → Devenir sémantique de negotiated_price concrètement tranché par le trigger sync_mission_on_offer_accepted() — voir Section 2, Section 18 (recommandation requalifiée ✅ RÉSOLUE)
   → Schéma de négociation en 9 points arbitré par le porteur, processus détaillé en 2 tours avec règle de double acceptation symétrique obligatoire ✅
   → Index unique partiel sur (mission_id, driver_id) WHERE status='pending' ✅
   → 6 fonctions de service, 2 canaux Realtime, 4 notifications, écran partagé MissionOfferScreen + 2 wrappers, remplacement du mécanisme "premier arrivé premier servi" ✅
   → Deux extensions de périmètre validées par le porteur, traitées intégralement : réparation navigation client (RÉSOLU 53), réparation route MissionActive (RÉSOLU 54)
   → Gap identifié et comblé en cours de session : mécanisme de refus (rejectOfferAcceptance), absent du schéma initial en 9 points
   → Tests de non-régression 3 rôles (ADMIN/CLIENT/DRIVER) : ✅ aucune régression
   → ⚠️ Parcours complet de négociation de bout en bout NON testé (nécessite CLIENT + DRIVER simultanés avec GPS) — reporté Phase 4.x
   → ⚠️ Countdown serveur par tour : arbitrage resté explicitement ouvert
   → ⚠️ WITH CHECK absent sur missions : reporté à une session future d'audit sécurité
   → ⚠️ Extension e-commerce : reportée à la session 2.20
   → ⚠️ Chaînon de rotation du numéro partagé non documenté entre cette session et la précédente — voir Section 2, liste de suivi anomalie #16
   → Chaîne de dépendance mise à jour : 2.14 septies peut désormais démarrer

**2.14 septies ⏳ Piste 4 — Activation du canal vocal sécurisé — DÉPENDANCE DÉSORMAIS LEVÉE**
   → RLS déjà déployée depuis 2.14 ter — reste : logique de contrôle d'accès VoiceMicButton.tsx, montage du canal, notification de message reçu, avertissement anti-partage de coordonnées
   → Sa dépendance unique (livraison effective de 2.14 sexies) est levée depuis la clôture de cette session — peut démarrer dès qu'une session lui sera dédiée

2.15 ⏳ TrackingDetailScreen
2.16 ⏳ Bouton déconnexion 3 rôles
2.17 ⏳ Réforme timing commission + workflow financier générique
2.18 ⏳ Test fonctionnel complet voice-messages (Phase 4.4, RLS déjà déployée depuis 2.14 ter)
2.19 ⏳ Audit systématique Alert.alert()
2.20 ⏳ Correction route CreateParcel manquante + test flux e-commerce complet — reconfirmée comme périmètre également pour l'extension e-commerce du mécanisme de négociation (reportée depuis session 2.14 sexies)

PHASE 3 — SERVICES EXTERNES
3.1 ⏳ Twilio SMS / 3.2 ⏳ FCM Android / 3.3 ⏳ APNs iOS

PHASE 4 — TESTS DEVICE PHYSIQUE
4.1 ⏳ Tests Expo Go Android / 4.2 ⏳ Tests Expo Go iOS
4.3 ⏳ Tests utilisateurs réels — inclut désormais : chemin natif Alert.alert() (RÉSOLU 42), test complet des fonctions notify* mission + cloche Client, soumission complète du flux transport avec scheduled_pickup_time, test fonctionnel complet du Volet 1 (fermeture auto du modal), de la diffusion géospatiale réelle (branchée depuis 2.14 quinquies bis, RÉSOLU 51) et du filtre admin expired, ET (nouveau, session 2.14 sexies) test complet du parcours de négociation de prix de bout en bout (offre → contre-offre → double acceptation → MissionActive/MissionTracking) — en environnement disposant d'une géolocalisation fonctionnelle et de plusieurs comptes actifs simultanément (CLIENT + DRIVER) — non réalisable en Codespaces
4.4 ⏳ Intégrer messages vocaux dans MissionTrackingScreen (audioService.ts + bucket voice-messages prêts, RLS sécurisée depuis 2.14 ter) — UI à construire — inclut le test fonctionnel complet de la clause RLS voice-messages en conditions réelles

PHASE 5 — BUILD EAS
5.1 à 5.3 ⏳ — Environnement de staging à évaluer avant cette phase (proposé session 2.13), non déclenché

PHASE 6 — AMÉLIORATIONS POST-TESTS
6.1 à 6.5 ⏳/✅ [statuts inchangés, voir Section 6]
6.6 ✅/✅ SÉCURITÉ — RLS Storage : driver-documents ✅ (2.12), voice-messages ✅ CORRIGÉE (2.14 ter) — reste test fonctionnel Phase 4.4

PHASE 7 — PUBLICATION
7.1 ⏳ Google Play Store / 7.2 ⏳ Apple App Store

# RECOMMANDATIONS STRATÉGIQUES EN ATTENTE D'ARBITRAGE PORTEUR

(issues des sessions 2.13, 2.14, 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis et 2.14 sexies, non déclenchées dans l'immédiat)

✅ RÉSOLUE — Correction de sécurité RLS voice-messages : traitée en session 2.14 ter (RÉSOLU 43). Reste seulement le test fonctionnel en Phase 4.4/session 2.18.
✅ RÉSOLUE — Correction de sécurité vues available_drivers/driver_dashboard : traitée en session 2.14 quinquies (RÉSOLU 48/49).
✅ RÉSOLUE — Correction de sécurité accès anon sur la table drivers : traitée en session 2.14 quinquies bis (RÉSOLU 52). Le cas authenticated de la même policy reste ouvert (voir ci-dessous).
✅ RÉSOLUE — Devenir sémantique de negotiated_price : tranché concrètement par le trigger sync_mission_on_offer_accepted() en session 2.14 sexies — le prix affiché devient le prix réellement négocié à l'acceptation finale d'une offre (voir Section 2, Section 6).
Audit systématique Alert.alert() — tous les usages du projet — idéalement session 2.19, avant Phase 3 active. Portée élargie : chemin natif non testé pour 3 fichiers déjà corrigés.
Environnement de staging — à évaluer avant Phase 5 (Build EAS) — décision et calendrier à trancher par le porteur.
Refonte du reporting financier — trois mécanismes de calcul non harmonisés — étude de faisabilité à programmer, hors périmètre 2.13.
Notification admin en temps réel sur nouvelle demande de recharge — renvoyée à la session 2.17.
Second numéro de test dédié au rôle client — nécessaire pour le test complet des fonctions notify* mission, de la cloche côté client, ET désormais du parcours de négociation de prix de bout en bout (session 2.14 sexies). Point réactualisé : le numéro partagé étant actuellement DRIVER, cette recommandation reste pleinement d'actualité et voit son urgence renforcée par le nouveau mécanisme de négociation.
Anomalie #1 — bouton "← Retour" manquant NotificationCenterScreen.tsx — non bloquante, rattachement session 2.19 ou point autonome, décision du porteur.
notifyDocumentExpiry — lien check-document-reminders non vérifié — à statuer isolément, session future.
Bug de reconnexion clientProfileId vide (RootNavigator.tsx) — à documenter, session future non assignée. Voir note de rapprochement non tranchée avec RÉSOLU 53 (Section 10) et Section 16.
Robustesse topupWallet/refundWallet — à vérifier par lecture directe en tout début de session 2.17.
subscribeToDriverLocation (realtimeService.ts) — suivi de position en temps réel, non exploité, aucune session dédiée proposée à ce stade.
Décision sur la reconstitution ou l'abandon des profils DRIVER historiques orphelins (2ec2b439-..., wallet 800 DH ; profil créé en 2.14 quinquies, driverId inconnu) — décision et calendrier à trancher par le porteur. Point inchangé à l'issue des sessions 2.14 quinquies bis et 2.14 sexies.
Enrichissement fonctionnel scheduled_pickup_time (notifyRecipientBySMS, getClientParcels) — piste non assignée, à arbitrer.
Correction route CreateParcel — voir session 2.20 déjà créée pour ce traitement, reconfirmée devoir couvrir également l'extension e-commerce du mécanisme de négociation (session 2.14 sexies).
Point de sécurité cancelMission/userId — vérification d'autorisation absente ; recommandation reconfirmée pour la session 2.17 (déjà actée session 2.14, reconfirmée pertinente 2.14 quater, reconfirmée préexistante et non aggravée 2.14 sexies).
Audit des permissions par défaut (GRANT) sur l'ensemble du schéma public — constat initial lors de l'investigation de la faille sur available_drivers/driver_dashboard (session 2.14 quinquies), étendu par la découverte de l'exposition anon sur drivers (session 2.14 quinquies bis) puis par l'absence de WITH CHECK sur missions (session 2.14 sexies) — à programmer, aucune session dédiée assignée à ce stade. Ce point regroupe désormais plusieurs découvertes distinctes de sessions successives — voir NOUVELLE recommandation "cas authenticated de drivers_select_available" et "WITH CHECK absent sur missions" ci-dessous, qui s'y rattachent sans lui être fondues, chacune ayant sa propre origine et son propre statut.
Renforcement méthodologique CI/exécution réelle : après toute séquence de plusieurs commandes sed sur un même fichier, relecture structurelle complète + test d'exécution réelle obligatoires avant tout commit — règle consolidée Section 2, recommandation de vigilance continue.
NOUVELLE (session 2.14 quinquies bis) — Cas authenticated de la policy drivers_select_available : reste permissive pour tout utilisateur connecté sans filtre d'identité — décision produit à trancher (voulu ou oubli), non traité en session 2.14 sexies.
NOUVELLE (session 2.14 quinquies bis) — Test d'exécution réel du Volet A (diffusion géospatiale) : à réaliser en priorité dès qu'un environnement GPS fonctionnel sera disponible (device physique, Phase 4.x).
NOUVELLE (session 2.14 sexies) — Countdown serveur par tour (négociation de prix) : arbitrage à trancher — mécanisme existant d'expiration confirmé transposable si le porteur souhaite le réintégrer.
NOUVELLE (session 2.14 sexies) — WITH CHECK absent sur la policy UPDATE de la table missions : décision explicite du porteur de reporter à une session future d'audit sécurité — à rattacher à la recommandation "audit des permissions GRANT par défaut" ci-dessus.
NOUVELLE (session 2.14 sexies) — Doublon mort NOT_ICONS/NOTIF_ICONS dans pushNotificationService.ts : nettoyage possible dans une session future touchant ce fichier.
NOUVELLE (session 2.14 sexies) — Cause de l'incident réseau/tunnel Codespaces : à surveiller, documenter précisément les conditions de déclenchement si récurrent, pour investigation dédiée.
NOUVELLE (session 2.14 sexies) — Erreur CORS send-push-notification : à vérifier si elle se manifeste aussi hors environnement Codespaces (device physique), auquel cas investigation dédiée sur la configuration CORS de l'Edge Function.
NOUVELLE (session 2.14 sexies) — Test de bout en bout du parcours de négociation de prix complet : à programmer dès que possible, environnement GPS fonctionnel + plusieurs comptes simultanés (device physique).

# 18. ANNEXE — INVESTIGATION SESSION 2.14 — PROCESSUS DE CRÉATION DE MISSION : ÉTAT ACTUEL ET PISTES D'AMÉLIORATION

[Contenu inchangé — reprise intégrale du point zéro de l'investigation, préservé tel quel sans réécriture, y compris l'avertissement de numérotation entre les deux systèmes Piste 1-4. Voir version du 25/08/2026, qui renvoyait elle-même à la version du 11/08/2026 pour le texte complet des sections § 1 à § 5 et du § TRI — ce texte complet n'a pas été retransmis à la présente conversation dans le cadre de cette actualisation (voir liste de suivi anomalie #18, Section 6).]

Mise à jour de statut (session 2.14 quater) : la Piste "Planification par date/heure" est désormais traitée — voir Section 6, bloc "SESSION 2.14 quater", et RÉSOLU 47.

Mise à jour de statut (session 2.14 quinquies) : la Piste "Diffusion optimisée" (§ TRI, Piste 1) est partiellement traitée — infrastructure sécurisée et cartographiée, Volets 1 et 2 implémentés et déployés.

Mise à jour de statut (session 2.14 quinquies bis) : la Piste "Diffusion optimisée" (§ TRI, Piste 1) est désormais intégralement traitée — le branchement du filtrage réel par distance a été réalisé et déployé (RÉSOLU 51), avec réserve du test d'exécution en conditions réelles (GPS), non réalisable en Codespaces.

Mise à jour de statut (session 2.14 sexies) : la Piste "Négociation de prix structurée" (§ TRI, Piste 2) est désormais traitée — table mission_offers, schéma en 2 tours avec double acceptation symétrique, mécanisme intégralement implémenté et déployé (voir Section 6, bloc "SESSION 2.14 sexies"), avec réserve du test de bout en bout en conditions réelles, non réalisable en Codespaces.

# 18 bis. ANNEXE — SESSION 2.14 bis — SYNTHÈSE DE L'INVESTIGATION ET PLAN D'ACTION (PROCESSUS DE CRÉATION DE MISSION)

[Contenu inchangé — reprise intégrale.]

Synthèse ultra-condensée pour navigation rapide — MISE À JOUR :
Piste 1 (diffusion) : ✅ TRAITÉE INTÉGRALEMENT — infrastructure sécurisée et cartographiée (session 2.14 quinquies, RÉSOLU 48/49/50), branchement du filtrage réel par distance réalisé et déployé (session 2.14 quinquies bis, RÉSOLU 51) — réserve : test d'exécution en conditions réelles (GPS), Phase 4.x
Piste 2 (négociation) : ✅ TRAITÉE — nouvelle table mission_offers, schéma en 2 tours, double acceptation symétrique, mécanisme intégralement implémenté et déployé (session 2.14 sexies, RÉSOLU 53/54) — réserve : test de bout en bout en conditions réelles, Phase 4.x
Piste 3 (planification) : ✅ TRAITÉE, session 2.14 quater (voir RÉSOLU 47)
Piste 4 (canal vocal) : conservé, activation en dernier — ⏳ 2.14 septies, dépendance désormais UNIQUE ET LEVÉE (2.14 sexies clôturée) — prêt à démarrer
Hors piste : sécurité voice-messages — ✅ TRAITÉE, session 2.14 ter (RÉSOLU 43) ; sécurité available_drivers/driver_dashboard — ✅ TRAITÉE, session 2.14 quinquies (RÉSOLU 48/49) ; sécurité table drivers (accès anon) — ✅ TRAITÉE, session 2.14 quinquies bis (RÉSOLU 52) ; sécurité WITH CHECK missions — ⏳ EN ATTENTE, reportée à une session future d'audit sécurité (session 2.14 sexies)

⚠️ NOTE (actualisation du 09/09/2026) — Référent "Bloc A" : le compte-rendu de la session 2.14 quinquies bis mentionne une réserve jamais levée portant sur le « texte complet de l'annexe ROADMAP (Bloc A) », suggérant une correspondance possible avec une distinction "Bloc A"/"Bloc B" qui existerait dans le "§ TRI" évoqué en Section 18 ci-dessus. Cette correspondance a été suggérée lors de la préparation de la présente actualisation, mais n'a pas pu être vérifiée par lecture directe du texte intégral du § TRI, celui-ci n'ayant pas été retransmis à la présente conversation (voir liste de suivi anomalie #18, Section 6). Elle n'est donc pas retenue comme fait établi dans le présent document.

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
NE JAMAIS exécuter de commande SQL de modification de schéma directement en SQL Editor — toujours via fichier de migration + GitHub Actions
Indexation storage.foldername() : vérifier l'indice par simulation, ne jamais le copier d'un pattern à convention de chemin différente
Lecture intégrale obligatoire, y compris pour les fichiers de référence/modèle non modifiés
CI vert (Vérification Qualité Code) ne garantit pas que le code compile/s'exécute réellement : après toute séquence de plusieurs sed sur un même fichier, relecture structurelle complète + test d'exécution réel obligatoires (règle consolidée session 2.14 quinquies)
NOUVEAU — Vérification systématique de git status avant tout commit (règle consolidée session 2.14 sexies, a permis de détecter une omission réelle de fichier)
git pull --rebase avant tout push
Migrations via GitHub uniquement
NE JAMAIS modifier authService.ts / ProfileSetupScreen.tsx / driverService.ts / wallet_update_admin
RootNavigator.tsx : très fréquemment modifié (9 modifications rien qu'en session 2.14 sexies) — non classé ⛔ officiellement, mais à traiter avec vigilance accrue vu le volume cumulé de changements
Backup obligatoire avant toute modification
Ne jamais retester ce qui est écarté / Ne jamais modifier ce qui fonctionne
vault.create_secret(valeur, nom, desc) — valeur EN PREMIER
timeout_milliseconds := 30000 pour net.http_post
cron.unschedule() WHERE EXISTS avant tout cron.schedule()
Alert.alert() ne s'affiche pas sur web — toujours Platform.OS === 'web' ? window.alert(...) : Alert.alert(...) (3 fichiers corrigés : AdminUsersScreen, WalletTopupScreen, PendingVerificationScreen — chemin natif non testé)
DateTimeField.tsx : nécessite le même traitement différencié web/natif — voir RÉSOLU 44/45/46
✅ Vues available_drivers / driver_dashboard SÉCURISÉES (session 2.14 quinquies) — voir RÉSOLU 48/49
✅ Table drivers SÉCURISÉE pour le rôle anon (session 2.14 quinquies bis) — voir RÉSOLU 52 — ⚠️ cas authenticated de drivers_select_available toujours ouvert
✅ Diffusion géospatiale par distance réelle BRANCHÉE ET DÉPLOYÉE (session 2.14 quinquies bis) — rayon 60km, cast geography HEXEWKB corrigé, fail-open — voir RÉSOLU 51 — ⚠️ test d'exécution en conditions réelles (GPS) toujours en attente
✅ Mécanisme de négociation de prix structuré OPÉRATIONNEL (session 2.14 sexies) — table mission_offers, 2 tours max, double acceptation symétrique obligatoire — voir Section 6/9/15 — ⚠️ test de bout en bout en conditions réelles toujours en attente ; countdown serveur par tour toujours en arbitrage ouvert
⚠️ Numéro de test partagé +212600000000 : ACTUELLEMENT EN RÔLE DRIVER depuis session 2.14 sexies — nouveau profil a53521ca-c776-4b57-8370-5d934f2bb416 (is_verified = true, wallet 1000 DH, catégorie VUL, 4 documents validés). Tous les profils antérieurs (2ec2b439-..., profil de 2.14 quinquies, profil(s) CLIENT intermédiaire(s)) restent orphelins d'accès Auth, données intactes en base. Un seul rôle actif à la fois — envisager un second numéro dédié au rôle Client avant toute session nécessitant un parcours de mission complet (Client + Driver simultanés), désormais également requis pour tester le mécanisme de négociation de prix de bout en bout.
✅ RLS voice-messages CORRIGÉE (session 2.14 ter) — reste le test fonctionnel en Phase 4.4/session 2.18
✅ scheduled_pickup_time OBLIGATOIRE (NOT NULL) depuis session 2.14 quater — transport ET e-commerce
✅ Volets 1 (fermeture auto modal, rôle requalifié depuis 2.14 sexies) et 2 (expiration mission pending) OPÉRATIONNELS depuis session 2.14 quinquies
⚠️ Bug découvert : route 'CreateParcel' non déclarée en navigation — session 2.20 à traiter (couvre également l'extension e-commerce de la négociation)
⚠️ WITH CHECK absent sur la policy UPDATE de missions — décision explicite du porteur de report à une session future d'audit sécurité (session 2.14 sexies)
Chantier "amélioration processus de création de mission" : 2.14 ter ✅, 2.14 quater ✅, 2.14 quinquies ✅, 2.14 quinquies bis ✅, 2.14 sexies ✅ (avec réserves) — chantier des 8 sessions désormais COMPLET ; reste 2.14 septies (dépendance levée, prête à démarrer) — voir Section 6/18/18 bis pour détails
Prochain timestamp migration : 20260504000024

OBJECTIF SESSION : [Décrire précisément]

ERREUR ACTUELLE : [Coller l'erreur si applicable]
