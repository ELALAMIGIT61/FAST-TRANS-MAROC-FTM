ROADMAP-DOCUMENT DE REFERENCE SESSION CLAUDE — FAST TRANS MAROC — VERSION 17/10/2026

Fast Trans Maroc — Application Mobile Marocaine
Dernière mise à jour : 17/10/2026
Sessions couvertes : jusqu'à la session 2.14 sexies (version précédente du 09/09/2026), puis session 2.14 septies (14/09/2026), session 2.16 (14/09/2026), session 2.17 (14-19/09/2026), étape 2 — rôle admin (03/10/2026), étape 3 sécurité — volets 1, transitions, choix du chauffeur, 3, 4a, 4b-1 à 4b-5, 5 (05/10 → 14/10/2026), sessions 2.19 et 2.21 à 2.29 (16-17/10/2026)
Sources de l'actualisation du 17/10/2026 : comptes rendus des sessions 2.14 septies, 2.16 et 2.17 ; compte rendu complet du 17/10/2026 (étapes 2-3, volets 1 à 5, sessions 2.19 à 2.29) ; précisions de l'assistant général du projet, vérifiées dans le dépôt (mentionnées comme telles)

# INFORMATIONS PROJET

Projet : Fast Trans Maroc (FTM)
Stack : Expo SDK 50 / React Native / TypeScript strict — précision (17/10/2026) : Expo SDK 50.0.21, React Native 0.73.4
Supabase : ustckqnecsilxqlyjute (org: Tamesna Plus)
GitHub : ELALAMIGIT61/FAST-TRANS-MAROC-FTM
Codespaces : zany-disco-jj95647gqv473pj9
Chemin de travail Codespaces : /workspaces/FAST-TRANS-MAROC-FTM (dépôt public, branche main) — ajout du 17/10/2026
Base de données : PostgreSQL 17.6 — Supabase plan gratuit — PostGIS 3.3.7 dans le schéma extensions depuis la session 2.24 (auparavant dans public) — ajout du 17/10/2026

# RÈGLES CRITIQUES — À LIRE EN PREMIER

⛔ NE JAMAIS utiliser npm audit fix --force (casse la stack SDK 50 → SDK 55 incompatible)
✅ Toujours utiliser --legacy-peer-deps si conflit
✅ Toujours utiliser npx expo install pour packages Expo
✅ .env doit être dans frontend/ (pas à la racine)
✅ Migrations : timestamps uniques obligatoires
   Prochain timestamp ≥ 20260504000058 (actualisation du 17/10/2026 — 024 à 027 consommés par la session 2.17, 028 par l'étape 2, 029 à 053 par l'étape 3 sécurité, 054 à 057 par les sessions 2.23 à 2.26)
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
✅ NE JAMAIS exécuter une commande SQL de modification de schéma (DROP POLICY, CREATE POLICY, ALTER TABLE, etc.) directement en SQL Editor, même à titre de "préparation" ou "test rapide" — toujours l'intégrer d'abord au fichier de migration, puis déployer via le canal standard (GitHub Actions). Règle renforcée session 2.14 ter, suite à l'Incident 1 (DROP POLICY exécuté hors circuit, voir Section 6, bloc session 2.14 ter) : le risque de confusion entre "commande proposée à discuter" et "commande prête à exécuter" est réel dès lors que plusieurs blocs SQL sont présentés à la suite dans une même interface — ne jamais présenter une commande de modification de schéma comme une action isolée sans préciser explicitement qu'elle doit d'abord être intégrée à la migration. Seule exception accordée à ce jour : la répétition à blanc, annulée, de la migration 20260504000055 sur la vraie base (session 2.24) — compte rendu du 17/10/2026.
✅ Indexation storage.foldername() : l'indice du segment de dossier recherché n'est PAS systématiquement [1] — il dépend du nombre de segments fixes précédant l'identifiant recherché dans la convention de chemin du bucket concerné (ex. driver-documents : {driver_id}/... → [1] ; voice-messages : missions/{missionId}/... → [2]). Règle consolidée session 2.14 ter : toujours vérifier par simulation directe (storage.foldername('chemin/exemple')) plutôt que de copier l'indice utilisé dans un pattern de référence différent.
✅ La discipline de lecture intégrale d'un fichier avant modification s'applique aussi aux fichiers de référence/modèle de conception (pas seulement aux fichiers directement modifiés) — règle renforcée session 2.14 quater, suite à un gap d'investigation réel : une lecture en deux extraits disjoints de LegalDocumentsScreen.tsx (fichier de référence, non modifié) a laissé un angle mort de ~25 lignes exactement sur la branche Platform.OS === 'web', découvert seulement lors de l'implémentation, provoquant un retour en arrière évitable (voir Section 6, bloc session 2.14 quater).
✅ NOUVEAU — Un statut CI vert (workflow "Vérification Qualité Code") ne constitue pas une garantie suffisante que le code compile et s'exécute réellement — règle consolidée session 2.14 quinquies, suite à l'incident de duplication de STATUS_FILTERS (commit 69273c0) : une séquence de trois commandes sed appliquées successivement sur un même fichier a produit une déclaration dupliquée (SyntaxError bloquante à l'exécution), passée inaperçue du linting TypeScript. Après toute séquence de plusieurs sed sur un même fichier, effectuer systématiquement une relecture structurelle complète du fichier, ET un test d'exécution réel (lancement effectif du serveur), avant de committer — ne jamais se contenter d'un CI vert comme validation finale sur une session touchant du code applicatif.
✅ NOUVEAU — Vérification systématique de `git status` avant tout commit — règle consolidée session 2.14 sexies : appliquée avec constance tout au long de la session, elle a permis de détecter concrètement une omission réelle (fonction `getMissionById()` conçue et validée par relecture croisée, mais omise lors de la première transmission de commande d'écriture — un seul fichier modifié au lieu de deux attendus, corrigé avant tout commit grâce à cette vérification). À appliquer systématiquement avant chaque commit, en complément (et non en remplacement) de la règle CI vert/test d'exécution réel ci-dessus.
✅ git pull --rebase origin main avant tout push (ROADMAP mise à jour directement sur GitHub) — ⚠️ ACTUALISÉ (17/10/2026) : la procédure « création par heredoc + déploiement suivi de git pull --rebase » n'est plus utilisée depuis le volet 4b-5 (voir règles NOUVEAU de l'étape 3 ci-dessous)
✅ Backup obligatoire avant chaque modification
   ⚠️ REMPLACÉE depuis l'étape 3 sécurité : les copies .bak ne sont plus utilisées — script Python à empreinte SHA256 et ancres uniques (voir règles NOUVEAU ci-dessous) ; les 131 copies .bak accumulées ont été archivées puis supprimées le 17/10/2026 (voir section « État technique actuel »)
✅ Test non-régression CLIENT + ADMIN + DRIVER après chaque étape de modification
✅ Ne jamais retester ce qui est écarté
✅ Ne jamais modifier ce qui fonctionne
✅ Toujours vérifier l'état des fichiers avant toute action
✅ 3 workflows GitHub INTOUCHABLES :
   check_supabase.yml
   deploy_supabase.yml
   lint_code.yml
   Noms affichés (compte rendu du 17/10/2026) : Check Supabase Connection / Deploy Supabase FTM (applique les migrations puis redéploie les 4 fonctions serveur) / Vérification Qualité Code — 3 pastilles vertes si supabase/ change, sinon 2
⛔ NE JAMAIS modifier authService.ts
⛔ NE JAMAIS modifier ProfileSetupScreen.tsx
⛔ NE JAMAIS modifier driverService.ts
   Contient createDriverProfile, saveDriverDocuments, createDriverWallet
   Fichier stable — ne pas recréer
⛔ NE JAMAIS modifier wallet_update_admin
   Reste un privilège admin exclusif — confirmé explicitement hors périmètre par le porteur, session 2.13
⛔ NE JAMAIS modifier AdminUsersScreen.tsx
⛔ NE JAMAIS modifier AdminMissionsScreen.tsx
   Ajoutés à la liste des fichiers protégés après le 09/09/2026 (compte rendu du 17/10/2026, A.6)
   Exceptions accordées au cas par cas par le porteur : une ligne de déclaration de ProfileSetupScreen.tsx (session 2.27) ; deux lignes et un import de AdminUsersScreen.tsx (session 2.28)
⚠️ NOTE DE VOCABULAIRE (session 2.14 sexies) : le compte-rendu de cette session qualifie RootNavigator.tsx de "fichier protégé" en raison du volume de modifications qu'il y a subies (9 modifications cumulées dans la seule session 2.14 sexies). Cette qualification est propre au vocabulaire de ce compte-rendu — RootNavigator.tsx NE figure PAS dans la liste ⛔ officielle ci-dessus, et rien dans les documents reçus ne documente une décision explicite du porteur de l'y ajouter. Il ne s'agit donc pas d'une règle ⛔ nouvelle, mais d'un simple rappel de vigilance vu le nombre de sessions ayant modifié ce fichier (2.14, 2.14 quater [import DateTimeField non concerné], 2.14 sexies) — voir Section 6, bloc session 2.14 sexies, pour le détail des modifications.
⚠️ COMPTE ADMIN +212600000001
   NE JAMAIS SUPPRIMER CE PROFIL
   Même entre les tests
⚠️ NUMÉRO PARTAGÉ +212600000000 — CLIENT OU DRIVER (exclusif) — ⚠️ HISTORIQUE depuis le 03/10/2026 : compte CLIENT dédié +212600000002 (voir « État actuel des comptes de test » ci-dessous)
   Le même numéro ne peut avoir qu'UN profil actif à la fois (recherche par user_id, suppression Auth = cascade profil/driver)
   ⚠️ ÉTAT ACTUEL (depuis session 2.14 sexies) : rôle DRIVER — nouveau profil créé via un nouvel onboarding complet durant la session 2.14 sexies, driverId a53521ca-c776-4b57-8370-5d934f2bb416, is_verified = true, wallet 1000.00 DH (recharge admin validée), catégorie véhicule VUL, 4 documents légaux soumis et validés. Ce nouveau profil est distinct de tous les profils DRIVER antérieurs (2ec2b439-... historique, et celui créé en session 2.14 quinquies) : il ne s'agit PAS d'une reconstitution de l'un de ces profils, mais d'un profil entièrement nouveau. Les profils antérieurs restent orphelins de tout accès Auth, leurs données restant intactes en base — voir bloc dédié Section 3. ⚠️ DÉPASSÉ (actualisation du 17/10/2026) : la suppression d'un compte Auth supprime en cascade profil, fiche chauffeur, portefeuille et transactions — ces profils antérieurs et leurs données n'existent plus en base.
   ⚠️ CHAÎNON DE ROTATION NON DOCUMENTÉ (signalé lors de l'actualisation du 09/09/2026) : le compte-rendu de la session 2.14 sexies indique que le numéro partagé était "déjà en CLIENT" au moment de démarrer sa séquence de tests de non-régression, alors que l'état documenté à l'issue de la session 2.14 quinquies bis (28/08/2026) était DRIVER, sans rotation décidée durant cette session (le porteur ayant explicitement choisi de préserver le profil DRIVER actif plutôt que d'effectuer une rotation). Aucun des trois documents reçus pour la présente actualisation ne documente l'événement de rotation DRIVER→CLIENT qui a dû se produire entre le 28/08/2026 et le 09/09/2026. Ce chaînon est donc explicitement signalé comme une lacune de traçabilité plutôt que reconstitué par déduction — les caractéristiques de ce profil CLIENT intermédiaire (s'il a existé) sont INCONNUES. (Actualisation du 17/10/2026 : point sans objet pour la suite depuis la création d'un compte CLIENT dédié ; chaînon toujours non reconstitué.)
   ⚠️ Limitation confirmée à nouveau sessions 2.14, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis et 2.14 sexies : absence de second numéro de test dédié au rôle client — a empêché tout test de bout en bout nécessitant simultanément un profil CLIENT et un profil DRIVER distincts, y compris désormais le test complet du parcours de négociation de prix (offre → contre-offre → double acceptation) introduit en session 2.14 sexies — recommandation transmise en Section 17.
   ✅ LIMITATION LEVÉE le 03/10/2026 : compte CLIENT dédié +212600000002 (voir ci-dessous).

⚠️ ÉTAT ACTUEL DES COMPTES DE TEST (actualisation du 17/10/2026 — compte rendu du 17/10/2026, A.3) — valides jusqu'au 31/12/2026, à retirer avant la production — code de vérification 123456 pour les trois :
   +212600000001 — ADMIN — ⛔ ne jamais supprimer
   +212600000000 — CHAUFFEUR — ⛔ ne jamais supprimer sans décision explicite du porteur — driverId a53521ca-c776-4b57-8370-5d934f2bb416, profileId 309967af-404b-4658-9c1a-a52b6cd16204 — état détaillé en section « État technique actuel »
   +212600000002 — CLIENT — profileId 08672d5c-96f1-42f0-81ab-bb74611ae95c — créé le 03/10/2026 (précision de l'assistant général du projet)
   ⚠️ Le numéro +212600000000 n'est donc plus partagé entre CLIENT et DRIVER. L'historique des rotations et les procédures de rotation ci-dessous sont conservés à titre HISTORIQUE.
   ⚠️ Deux comptes ne peuvent pas être connectés en même temps dans le navigateur (un seul onglet, verrou de session) — compte rendu du 17/10/2026, partie D.
   ⚠️ DÉCOUVERTE CRITIQUE (confirmée par lecture directe, étape 1 de l'étape 3 sécurité) : supprimer un compte Auth supprime EN CASCADE le profil, la fiche chauffeur, le portefeuille et les transactions. La table drivers ne contient plus que le chauffeur de test. Les mentions de profils « orphelins, données intactes en base » figurant dans le présent document sont DÉPASSÉES.

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

Si un test DRIVER est à nouveau nécessaire (depuis un état CLIENT) : — ⚠️ HISTORIQUE (plus nécessaire depuis le 03/10/2026)
   Supprimer +212600000000 dans Supabase Auth
   Reconnexion → ProfileSetupScreen → sélectionner "Driver"
   Remplir à nouveau les 4 pages onboarding : VehicleInfo → LegalDocuments → DocumentUpload → PendingVerification
   Validation admin requise pour is_verified=true
   Wallet à recréditer manuellement si besoin — NOTE : les profils historiques (2ec2b439-..., wallet 800 DH ; profil de session 2.14 quinquies) ne seront pas automatiquement récupérés par cette procédure (nouvel onboarding = nouveau driverId), sauf action explicite de récupération des données existantes
   ⚠️ DÉPASSÉ (17/10/2026) : ces profils historiques ont été supprimés en cascade avec leur compte Auth

Si un test CLIENT est à nouveau nécessaire depuis un état DRIVER : — ⚠️ HISTORIQUE (plus nécessaire depuis le 03/10/2026)
   Supprimer +212600000000 dans Supabase Auth
   Reconnexion → ProfileSetupScreen → sélectionner "Client"
   ⚠️ Depuis session 2.14 sexies, l'état actuel du numéro partagé est DRIVER (nouveau profil a53521ca-...) — cette procédure sera nécessaire pour tout futur test CLIENT, y compris pour tester enfin le parcours de négociation de prix de bout en bout (nécessite CLIENT + DRIVER simultanés — voir Section 15/17, limitation confirmée non résolue).
   ⚠️ DÉPASSÉ (actualisation du 17/10/2026) : compte CLIENT dédié +212600000002 depuis le 03/10/2026.

⚠️ window.history.back() ne fonctionne pas toujours sur web
   Utiliser le bouton "← Retour" (navigation.goBack())
   ✅ Depuis la session 2.21 : composant commun BackButton (retour, ou accueil du rôle s'il n'y a pas d'écran précédent) — 12 écrans corrigés
⚠️ Convention non appliquée sur NotificationCenterScreen.tsx (nouvel écran, session 2.14) — voir Anomalie #1, Section 15 — ✅ CORRIGÉE session 2.21 (commit c090c27, BackButton — voir RÉSOLU 81)
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
✅ Fichier de rollback obligatoire pour toute migration RLS sensible : à placer dans supabase/rollbacks/ (hors du dossier migrations/, pour éviter toute exécution automatique non désirée) — convention introduite session 2.12, reconduite systématiquement depuis (2.13, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, 2.14 sexies). Reconduite pour les migrations 024 à 057 (un rollback par migration). ⚠️ Incident session 2.17 : un rollback placé par erreur dans supabase/migrations/ avec un timestamp identique a fait échouer le déploiement (duplicate key … schema_migrations_pkey) — déplacé dans supabase/rollbacks/ par le commit bfb34d3 (voir RÉSOLU 58). Le dossier supabase/rollbacks/ existe depuis la session 2.12.
✅ Convention étendue session 2.13 : rollback créé par précaution même pour une migration non-RLS (renommage de vue, contrainte NOT NULL), avec commentaire explicite précisant qu'un rollback SQL seul est insuffisant en cas de déploiement partiel et nécessite un git revert coordonné du code applicatif. Précision session 2.14 quater : pour une contrainte NOT NULL, l'ordre des opérations en cas de rollback complet est impératif — SQL d'abord (retrait de la contrainte), git revert du code applicatif ensuite, jamais l'inverse, sous peine de bloquer toute création de mission. Précision session 2.14 quinquies : pour un ajout de valeur d'enum (ALTER TYPE ... ADD VALUE), un rollback complet (retrait de la valeur) n'est pas trivialement automatisable en toute sécurité par PostgreSQL — rollback documentaire uniquement, procédure manuelle à documenter en cas de besoin réel.
⚠️ Isoler une clause RLS via fetch() authentifié direct (sans passer par le code applicatif, ex. topupWallet()) peut produire des valeurs déclaratives trompeuses (ex. balance_after renseigné manuellement dans une ligne de test) — toujours vérifier la valeur réelle en base (ex. wallet.balance) plutôt que de se fier au contenu de la ligne insérée manuellement — session 2.12
⚠️ Alert.alert() (React Native) ne s'affiche pas sur web
   Toujours prévoir Platform.OS === 'web' ? window.alert(...) : Alert.alert(...) pour tout message destiné à s'afficher aussi sur web — bug redécouvert session 2.13 (WalletTopupScreen.tsx ligne 70, cf. RÉSOLU 41) après un premier correctif partiel en session 2.8 (AdminUsersScreen.tsx, sans généralisation Platform.OS) — voir audit recommandé section 17
✅ Pattern réappliqué avec succès session 2.14 sur PendingVerificationScreen.tsx (alerte Realtime) — voir RÉSOLU 42.
⚠️ Chemin natif (hors web) toujours non testé à ce jour sur aucun des fichiers concernés — environnement de développement limité au web (Codespaces) — audit systématique proposé (session 2.19) reste pertinent
   ✅ Audit réalisé session 2.19 (commit 46d52ca) : module commun utils/dialogs.ts — showMessage et confirmAction (fenêtres du navigateur sur le web, natives sur téléphone) ; 25 messages remplacés dans 11 écrans ; complété session 2.28 (commit e78b1a6 : 13 anciens messages alignés dans 11 écrans) ; 3 messages Alert.alert restent dans des écrans e-commerce et de suivi non raccordés à la navigation ; chemin natif toujours non testé (tous les tests réalisés sur le web) — voir RÉSOLU 80
⚠️ CLARIFICATION MÉTIER FONDAMENTALE (rappelée sessions 2.13, 2.14, 2.14 bis, à ne jamais perdre) : le paiement de la course est TOUJOURS hors application — le client paie directement le chauffeur (espèces ou autre moyen), sans jamais transiter par FTM. Seule la COMMISSION (montant fixe selon catégorie de véhicule) est prélevée automatiquement sur le wallet du chauffeur à chaque mission terminée (trigger process_commission_payment). Le wallet n'est donc alimenté QUE par les recharges (jamais par un paiement client), et diminué QUE par les commissions. Cette clarification est la raison structurelle du renommage revenue_current_month → recharges_current_month (RÉSOLU 39) — à garder impérativement en tête pour toute session touchant au workflow financier (notamment 2.17), pour éviter de reproduire la même confusion de nommage ou de conception ailleurs.
   ⚠️ ACTUALISÉ (17/10/2026) — moment du prélèvement : depuis la session 2.17 (migration 20260504000024), la commission est prélevée par ANTICIPATION, dans la fenêtre de 24 h avant scheduled_pickup_time (colonne commission_charged_at, fonction charge_commission_anticipated()), le trigger process_commission_payment() ne servant plus que de filet de sécurité à la complétion si le prélèvement anticipé n'a pas eu lieu ; depuis la session 2.23 (migration 20260504000054), ce prélèvement anticipé est effectué par le SERVEUR (tâche planifiée process-missions-24h, toutes les 5 minutes), charge_commission_anticipated étant réservée au système. Montants fixes par catégorie (compte rendu 2.17) : VUL 25 DH / N2 moyen 40 DH / N2 grand 50 DH, fixés à la création par le trigger set_commission_amount(). Depuis la session 2.17 existent également une demande de remboursement de commission par le chauffeur (mission annulée après prélèvement, validation admin) et un rapprochement bancaire a posteriori — voir section « Modifications commitées — détail », blocs SESSION 2.17 et SESSIONS 2.19 À 2.29.
⚠️ negotiated_price (CreateMissionScreen.tsx) ne représente jamais un montant transitant par FTM, uniquement une base d'accord hors app entre client et chauffeur — principe reconfirmé session 2.14 bis (Piste 2, négociation de prix structurée). MISE À JOUR (session 2.14 sexies) : le mécanisme de négociation structurée est désormais tranché et implémenté — table mission_offers, schéma en 2 tours avec double acceptation symétrique (voir Section 6, bloc session 2.14 sexies). Le devenir sémantique de negotiated_price est concrètement fixé par le trigger sync_mission_on_offer_accepted() : à l'acceptation finale d'une offre, missions.negotiated_price est mis à jour avec la valeur réellement négociée (offered_price de l'offre acceptée). negotiated_price reste, comme toujours, une base d'accord hors app — ce principe demeure inchangé, seul le mécanisme qui alimente ce champ est désormais structuré plutôt que déclaratif au moment de la création de mission.
✅ Composant DateTimeField.tsx (session 2.14 quater) : sur le modèle des composants Alert.alert()/Platform.OS, ce composant nécessite lui aussi un traitement différencié web/natif (@react-native-community/datetimepicker strictement natif, aucun support web). Toujours vérifier avant tout usage : (1) mémoïsation React.memo si le composant contrôle un champ de saisie texte, pour éviter la corruption de saisie par re-rendu en boucle ; (2) séparation onChange (état local) / onBlur (validation finale) pour tout <input type="date"/"time"> HTML, le navigateur déclenchant onChange dès qu'une valeur techniquement complète est formée, avant la fin de la saisie utilisateur — voir RÉSOLU 44/45/46, session 2.14 quater.
✅ NOUVEAU — Vues Supabase exposées sans authentification (session 2.14 quinquies) : toute vue simple (non protégée par RLS, à la différence des tables) accessible en SELECT par les rôles anon/authenticated expose intégralement son contenu, y compris des colonnes sensibles (ex. phone_number sur available_drivers, solde wallet et commissions sur driver_dashboard) — une vue n'hérite pas automatiquement des protections RLS des tables sous-jacentes sauf activation explicite de security_invoker = true (PostgreSQL 17.6, confirmé compatible sur ce projet). Toute nouvelle vue exposant des données issues de tables protégées par RLS doit systématiquement faire l'objet d'une revue de permissions (GRANT) et d'une activation de security_invoker si applicable — voir RÉSOLU 48, session 2.14 quinquies.
✅ NOUVEAU — CREATE OR REPLACE VIEW ne permet pas de retirer une colonne existante (SQLSTATE 42P16 — cannot drop columns from view) — pour retirer une colonne d'une vue, procéder par DROP (et DROP des objets dépendants dans l'ordre, ex. RPC SECURITY DEFINER s'appuyant sur la vue) puis CREATE — session 2.14 quinquies, RÉSOLU 49.
✅ NOUVEAU — Le principe de vigilance sur les GRANT larges par défaut (anon/authenticated) s'étend au-delà des vues : la table drivers elle-même était accessible en SELECT au rôle anon (combiné à une policy RLS drivers_select_available sans filtre d'identité), découverte fortuitement en investigation de la session 2.14 quinquies bis — un audit des permissions GRANT par défaut sur l'ensemble du schéma public reste une recommandation ouverte (voir Section 17), le perimètre du cas authenticated de cette même policy restant également non traité — voir RÉSOLU 52.
✅ NOUVEAU — Le payload Realtime Supabase transmet les colonnes de type geography sous forme de chaîne hexadécimale EWKB (format canonique PostgreSQL/PostGIS), et non en texte lisible de type POINT(...) — confirmé par recherche documentaire officielle et vérification SQL directe, session 2.14 quinquies bis. Toute lecture applicative d'une colonne geography reçue via un canal Realtime doit tenir compte de cet encodage. Le cast SQL natif ::geography accepte indifféremment WKT et HEXEWKB en entrée de fonction — voir RÉSOLU 51.
✅ NOUVEAU — Diffusion géospatiale par distance réelle branchée et opérationnelle depuis session 2.14 quinquies bis (fail-open : en cas d'échec de la vérification de distance, la mission reste affichée par défaut, décision validée par le porteur pour ne jamais priver un chauffeur de mission à cause d'un incident technique passager) — voir RÉSOLU 51, Section 6 et Section 15.
✅ NOUVEAU — Mécanisme de négociation de prix structuré (table mission_offers, 2 tours maximum, double acceptation symétrique obligatoire dans tous les cas — quel que soit l'ordre d'acceptation entre client et chauffeur) opérationnel depuis session 2.14 sexies — voir Section 6, Section 7, Section 9, Section 15.
✅ NOUVEAU (étape 3 sécurité et sessions 2.19 à 2.29 — règles du compte rendu du 17/10/2026, A.4/A.5) :
   Sauvegardes : la copie .bak avant toute modification n'est plus utilisée ; elle est remplacée par un script Python qui vérifie l'empreinte SHA256 complète du fichier avant de le modifier et l'unicité de chaque ancre (count == 1), s'arrête « rien n'a été modifié » au moindre écart, affiche l'empreinte après modification, puis est supprimé ; l'historique git conserve toutes les versions publiées
   Livraison des fichiers : archive tar compressée, encodée en base64 (lignes de 76 caractères), envoyée par morceaux de 15 lignes ; chaque morceau affiche sa taille et sa propre empreinte ; empreinte du paquet complet contrôlée avant extraction ; les longs collages directs (heredoc) sont proscrits (le terminal du navigateur les tronque)
   Fichiers existants de l'application : ne voyagent plus en entier, modifiés par script à ancres ; seuls les nouveaux fichiers voyagent par paquet
   Une commande à la fois : chaque résultat est vérifié avant la suivante ; git --no-pager pour log et diff ; git status avant chaque commit ; seuls les fichiers voulus sont ajoutés, un par un
   Éditeur SQL : un onglet vide par requête ; vérifier l'éditeur avant « Run »
   Écriture en base : toujours vérifier le nombre de lignes modifiées (une écriture bloquée par RLS échoue en silence : 0 ligne, aucune erreur) ; toute écriture ajoutée depuis le volet 4b-5 le vérifie dans le code
   Distinguer strictement « vérifié par lecture directe » et « supposé » ; ne jamais présumer
   tsc --noEmit après toute modification de l'application, comparé à la référence (jamais en absolu)
   Incident GitHub récurrent : échec « rate limit exceeded » à l'étape d'installation de l'outil Supabase — ce n'est pas une erreur de migration : « Re-run failed jobs »
   Copie locale de la base (PostgreSQL 16 avec PostGIS 3.4 dans l'espace de travail de l'assistant ; schéma, règles et déclencheurs reproduits ; cron, net.http_post et Vault simulés) : chaque migration y est testée avant, après et après rollback
   Tests sur la vraie base : dans l'éditeur SQL, dans une transaction annulée ; utilisateur simulé par set_config('request.jwt.claims', …) et SET LOCAL ROLE authenticated ; résultat renvoyé par une erreur volontaire RAISE EXCEPTION 'RESULTAT …', qui annule tout ; contrôles « avant » (prouver le défaut) et « après » (prouver la correction)
   Procédure standard d'une migration : investigation en lecture seule sur la vraie base → synthèse en langage naturel et validation du porteur → migration + rollback, tests sur la copie locale (avant, après, après rollback, réapplication) → contrôle « avant » sur la vraie base (transaction annulée) → livraison par paquet base64 contrôlé, git status --short supabase/ : exactement les 2 nouveaux fichiers → commit et push, le workflow « Deploy Supabase FTM » applique la migration (3 pastilles vertes ; relancer si « rate limit ») → contrôle « après » sur la vraie base, puis test dans l'application si l'effet y est visible
   Échanges : le porteur répond par texte ou par export SQL (« Copy as markdown ») ; captures seulement si nécessaire (100 images au plus par conversation)
✅ NOUVEAU — Règle B4(b) (volet 5, lot B) : toute nouvelle fonction ou vue reçoit par défaut tous les droits pour anon et authenticated (droits par défaut du schéma public) ; les droits sont donc fixés explicitement dans la migration qui la crée, et l'inventaire est relancé après
✅ NOUVEAU — Mécanique des droits sur les fonctions et les vues (compte rendu du 17/10/2026, B.8) : toute fonction créée, et recréée par CREATE OR REPLACE, reçoit EXECUTE pour anon et authenticated ; les fonctions en langage SQL reçoivent en plus EXECUTE pour PUBLIC ; un REVOKE dans la migration qui crée la fonction ne tient pas toujours ; viser le bon niveau (PUBLIC) ; toujours vérifier les droits réels (proacl) en lecture directe ; le même mécanisme vaut pour les vues (constaté en 2.24) ; les droits de supabase_admin ne sont pas modifiables par le projet ; un REVOKE UPDATE par colonne est inefficace si un droit sur la table entière existe ; un REVOKE FROM anon est inefficace si le droit vient de PUBLIC
✅ NOUVEAU — Enseignements techniques (compte rendu du 17/10/2026, B.12) :
   Colonne calculée : is_verified est GENERATED ALWAYS ; dans un trigger BEFORE, sa nouvelle valeur vaut NULL — ne jamais la contrôler à cet endroit
   Identité dans une fonction exécutée avec les droits du propriétaire : current_user y vaut le propriétaire ; identifier l'appelant par auth.uid() (NULL pour le système) ou par get_my_role() — deux défauts réels en venaient (gardien de disponibilité de 039, corrigé par 043 ; contrôle d'identité de 029, corrigé par 054)
   Verrouillage par colonnes : retirer un droit de colonne bloque aussi les fonctions exécutées avec l'identité de l'utilisateur (cas de sync_mission_on_offer_accepted) — vérifier tous les écrivains d'une colonne avant de la verrouiller
   Lecture conditionnée : un contrôle qui relit une table n'aboutit que si l'appelant a le droit de la lire (une notification envoyée depuis le téléphone échouait en silence hors disponibilité) — préférer un dépôt par la base
   PostGIS s'installe dans le schéma extensions (documentation Supabase)
   Clés de service : la clé du coffre-fort et la variable d'environnement d'une fonction serveur peuvent avoir des formats différents — reconnaître le rôle inscrit dans la clé (la passerelle a déjà vérifié la signature)
   Web : Alert.alert ne s'affiche pas (module dialogs.ts) ; la barre de titre de navigation n'existe pas (toutes les piles sont sans en-tête) ; un seul onglet (verrou de session) ; le sélecteur de fichier exige une action directe de l'utilisateur (aucune boîte de confirmation ne doit précéder son ouverture)
   tsc détecte bien les imports dupliqués (constat de l'étape 1 de l'étape 3 — le compte rendu 2.16 affirmait le contraire)

# ÉTAT TECHNIQUE ACTUEL

SDK Expo : 50.0.21 ✅ stable
Vulnerabilities : 39 (outils dev uniquement) — ⚠️ 63 observées en session 2.14 septies (npm audit, 14/09/2026) : aucune imputable à expo-av, toutes dans la chaîne d'outils de build/CLI (Expo CLI, Metro, @remix-run/*, @xmldom/xmldom, ws) — écart 39 → 63 attribué très probablement à l'évolution de la base de vulnérabilités connues ; aucune correction --force appliquée
   Impact ZÉRO sur app/publication
   NE PAS corriger avec --force
   Passage de 23 à 39 en session 2.4
   Cause : dépendances dev de expo-image-picker + expo-document-picker
App démarre : ✅ Web Bundled confirmé
   Lancement app web : cd frontend && npx expo start --web --no-dev
   URL web : https://zany-disco-jj95647gqv473pj9-8081.app.github.dev
   ✅ Commande de lancement actualisée (compte rendu du 17/10/2026) : cd /workspaces/FAST-TRANS-MAROC-FTM/frontend && npx expo start --web, puis F5 — un seul onglet (verrou de session)
Page blanche web : ✅ RÉSOLUE — session 2.2
   Cause : BORDER_RADIUS manquant dans theme.ts — commit e7beed2
Bundle web : ✅ 1173ms
Contrôle TypeScript (npx tsc --noEmit) — NOUVEAU (actualisation du 17/10/2026) : 19 erreurs au 17/10/2026, toutes dans parcelService.ts (volet e-commerce)
   Historique : erreurs relevées dans 21 fichiers lors de la vérification globale de la session 2.14 septies (180 lignes de sortie brute ; 178 en session 2.16, écart dû à la méthode de comptage par expression régulière) ; 147 erreurs au 10/10/2026 ; 34 après le volet 5 (lot E, anomalie COLORS corrigée) ; 19 après la session 2.27
   Règle : toujours comparer à la référence, jamais en absolu

Auth CLIENT : ✅ confirmé — session 2.3
   Navigation → CreateMissionScreen
   ⚠️ Non re-testé sessions 2.13, 2.14, 2.14 bis, 2.14 ter, 2.14 quinquies bis (contrainte numéro partagé, occupé par DRIVER durant ces sessions)
   ⚠️ Session 2.14 quater : test complet resté bloqué (GPS Codespaces/iframe), table missions confirmée vide à l'issue de la session
   ⚠️ Session 2.14 quinquies : le compte Auth CLIENT ("TEST CLIENT FTM") a été supprimé en cours de session pour permettre un nouvel onboarding DRIVER
   ✅ Session 2.14 sexies : re-testé en conditions réelles (ClientHome/CreateMissionScreen fonctionnel avec le nouveau typage élargi, aucune régression sur le premier montage via initialParams) — voir Section 17. Chaîne de navigation client réparée (routes MissionTracking/Rating manquantes, ClientHome mal paramétrée — voir RÉSOLU 53, Section 6).
   ✅ NOUVEAU (03/10/2026) — compte CLIENT dédié +212600000002 (profileId 08672d5c-96f1-42f0-81ab-bb74611ae95c) — voir section « Règles critiques »
   ✅ Test réel du 14/10/2026 (volet 5) : mission de test N2 créée en base, connexions successives client puis chauffeur — offre, acceptation, refus, retrait et notifications conformes après les lots E-bis et E-ter ; ménage final : 0 mission, 0 offre
   ✅ Bouton de déconnexion (session 2.16, CreateMissionScreen.tsx) puis composant LogoutButton (session 2.21) — test CLIENT de la déconnexion non documenté

Auth ADMIN : ✅ confirmé — session 2.7
   Navigation → AdminDashboardScreen
   5 écrans dans AdminNavigator : AdminHome ✅ DocumentReview ✅ WalletManagement ✅ AdminMissions ✅ AdminUsers ✅
   ✅ NOUVEAU (session 2.17) — écrans PendingTransactions (demandes financières) et BankReconciliation (rapprochement bancaire) intégrés à la navigation admin, avec badges de comptage sur le tableau de bord
   ✅ Reconfirmé en conditions réelles session 2.14 quinquies (tests de non-régression) : dashboard, gestion missions, validation documents 4/4, gestion wallet (recharge 300 DH validée)
   ✅ Reconfirmé sans régression sessions 2.14 quinquies bis et 2.14 sexies (dashboard, AdminMissionsScreen 7 filtres intacts dont "Expirées", malgré 9 modifications cumulées de RootNavigator.tsx en session 2.14 sexies)
   ✅ Reconfirmé session 2.14 septies (dashboard, KPIs cohérents : Chauffeurs Total 1/1 vérifié, Missions Total 0), session 2.16 (déconnexion validée) et session 2.17 (cycle complet de validation d'une recharge par virement)

Auth DRIVER : ✅ OPÉRATIONNEL — profil actuel créé session 2.14 sexies
   Flux complet historique testé et validé à l'époque (session 2.4 suite) : Étape 1 → VehicleInfoScreen ✅ / Étape 2 → LegalDocumentsScreen ✅ / Étape 3 → DocumentUploadScreen ✅ / Étape 4 → PendingVerification ✅ / Validation admin → DriverHome ✅
   Realtime Supabase ✅
   ⚠️ ÉTAT ACTUEL (depuis session 2.14 sexies) : le rôle DRIVER est accessible sur le numéro partagé via un nouveau profil (a53521ca-c776-4b57-8370-5d934f2bb416), créé et validé durant cette session. Voir Section 2, bloc "numéro partagé", et Section 3. (Toujours le profil chauffeur de test au 17/10/2026 — voir « Profil DRIVER actif » ci-dessous.)
   ⚠️ Alerte Realtime de validation sur PendingVerificationScreen.tsx : ✅ CORRIGÉE session 2.14 (RÉSOLU 42) — chemin web uniquement, chemin natif non testé
   ✅ Reconfirmé fonctionnel session 2.14 sexies : nouvelle rotation complète effectuée (onboarding 4 étapes, validation admin, recharge wallet 1000 DH validée), DriverHomeScreen avec le code modifié (bouton d'offre de prix onOfferCreated) affiché sans erreur — chemin le plus modifié de la session, validé en dernier sur demande explicite du porteur
   ✅ Depuis le volet 4b-5 : chauffeur de test en catégorie N2 Moyen — il ne voit que les missions N2 Moyen ; pour un test de mission, créer une mission N2 Moyen, ou le repasser en VUL par « Changer de véhicule » (compte rendu du 17/10/2026)
   ✅ NOUVEAU (session 2.21) — écran AccountSuspendedScreen (un compte suspendu voyait un écran blanc) ; reprise de l'inscription chauffeur : l'étape 1 préremplit et met à jour la fiche existante au lieu d'en créer une seconde (erreur de doublon)

Bugs session 2.5 : ✅ 3 bugs corrigés (BUG 1 SIGNED_IN onboarding, BUG 2 wallet 404, BUG 3 document_reminders)
Bugs session 2.7 : ✅ 5 bugs corrigés (BUG A wallet RLS récursion, navigation admin 4 menus, SIGNED_IN loop admin, 403 notifications, enum mission_status) — BUG 4 → INFIRMÉ ✅

Packages ajoutés : expo-image-picker ~14.7.1 ✅ expo-document-picker ~11.10.1 ✅ — commit c318a92

Storage :
✅ Bucket driver-documents créé — 5 MB max — jpeg/png/pdf — RLS policies configurées — commits 7222601 + c39cafb
✅ RLS ownership chain corrigée — session 2.12 (commit 67e9e65) — voir item 6.6 / RÉSOLU 36
✅ Bucket voice-messages créé — session 2.8 — 5 MB max — audio/m4a, mp4, mpeg, wav, x-m4a — RLS policies configurées (4) — commit 5ee383e
   ⚠️ Infrastructure créée mais NON testée fonctionnellement (audioService.ts non référencé dans aucun screen — voir item 4.4) — ⚠️ DÉPASSÉ : canal monté depuis la session 2.14 septies (VoiceChatScreen.tsx via ClientVoiceChatScreen.tsx et DriverVoiceChatScreen.tsx) ; reste le test fonctionnel de bout en bout (Phase 4.4)
   ✅ RLS ownership CORRIGÉE — session 2.14 ter (commit 9c36d84) — voir RÉSOLU 43 (renvoi corrigé le 17/10/2026, la mention antérieure « RÉSOLU 46 » était erronée). Chaîne de propriété double (client + chauffeur de la mission) via UNION, indice storage.foldername()[2] (convention de chemin missions/{missionId}/...). Fichier applicatif réel confirmé : frontend/src/services/audioService.ts. Confirmée par lecture directe en base (pg_policies : 4 policies conformes à la migration) en session 2.14 septies.
   ⚠️ Test fonctionnel en conditions réelles reporté à la Phase 4.4 / session 2.18 — décision motivée session 2.14 ter
   ✅ NOUVEAU (volet 4a, migration 20260504000035) — suppression de la règle de modification (un message vocal ne se modifie jamais) ; suppression permise seulement à l'auteur, mission terminée — voir RÉSOLU 67 ; session 2.18 requalifiée (voir section « Étapes restantes »)
✅ NOUVEAU — Bucket payment-proofs créé — session 2.17 (migration 20260504000025) — justificatifs de paiement des demandes de recharge ; RLS sur le patron get_my_role() : lecture/écriture du chauffeur sur ses propres fichiers, suppression réservée à l'admin (intégrité de la preuve) — opérationnel, confirmé en test réel (upload d'un justificatif de virement)

Connexion Supabase : ✅ .env configuré dans frontend/
Token Supabase : ✅ Renouvelé le 29/04/2026 — Nom : FTM_GITHUB_ACTIONS — Expiration : Never
Mode test OTP : ✅ configuré (MessageBird fictif) — Numéro test : +212600000000 — Code fixe : 123456 — Valide jusqu'au : 31/12/2026 — étendu aux trois comptes de test +212600000000, +212600000001, +212600000002 (code 123456 pour les trois — compte rendu du 17/10/2026)

Extensions Supabase : ✅ pg_cron 1.6.4 — installée session 2.9 / ✅ pg_net 0.19.5 — installée session 2.9
   ✅ NOUVEAU (session 2.24, migration 20260504000055) — PostGIS 3.3.7 et spatial_ref_sys déplacés de public vers le schéma extensions ; pg_net (objets dans le schéma net) ; pg_cron

CRON reminders : ✅ OPÉRATIONNEL — session 2.9
   jobid=2, 0 8 * * *, active=true — timeout_milliseconds := 30000
   5 exécutions succeeded : 18→22/06/2026 — check-document-reminders appelée quotidiennement
   ⚠️ Lien avec notifyDocumentExpiry non vérifié — voir Section 15/17 (en attente depuis session 2.14, non traité en 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, ni 2.14 sexies — hors périmètre de chacune)
   ⚠️ Couverture (compte rendu du 17/10/2026, B.9 et C.3) : table document_reminders — rappels créés uniquement à l'inscription, pour le permis, l'assurance et la visite technique ; AUCUN rappel pour la carte grise ; aucune mise à jour des rappels lors d'un remplacement de document. check-document-reminders n'envoie que des rappels ; le blocage est assuré par block-expired-documents
CRON block-expired-documents : ✅ NOUVEAU — volet 4b-2 (migrations 20260504000037 et 038) — tous les jours à 7 h — fonction block_drivers_with_expired_documents() (réservée au système) : passe indisponible tout chauffeur ayant un document expiré ; elle ne fait que bloquer — ⚠️ exécution manuelle non testée en réel (faisable sans GPS, dès accord du porteur)
CRON process-missions-24h : ✅ NOUVEAU — session 2.23 (migration 20260504000054) — toutes les 5 minutes — fonction process_missions_24h_window() : prélèvement anticipé de la commission 24 h avant la date prévue (solde insuffisant : nouvel essai, alerte unique au chauffeur et aux admins) et annonce unique de la messagerie vocale — ⚠️ jamais exercée sur une mission réelle

Vault Supabase : ✅ Secret supabase_service_role_key — 219 caractères — identique Dashboard — Créé session 2.9 — lu aussi, depuis la session 2.26, par le déclencheur de sonnerie notifications_push_dispatch — ne jamais l'afficher

Realtime Supabase : ✅ OPÉRATIONNEL — session 2.10
   5 tables activées initialement : drivers, missions, wallet, transactions, notifications — Migration 20260504000012 déployée
   WalletDashboardScreen SUBSCRIBED ✅
   transactions ✅ écoute branchée — session 2.14
   notifications : Realtime actif — non branché UI directement, remplacé par NotificationBell/Center (résolution du profil via getCurrentProfileId(), déclenché par événement Realtime)
   ✅ (session 2.14 quinquies) — canal subscribeToMissionUpdates exploité côté DriverHomeScreen.tsx : abonnement immédiat dès réception d'une nouvelle mission (Volet 1 diffusion), fermeture automatique du modal de proposition si le statut de la mission change avant acceptation.
   ⚠️ PRÉCISION IMPORTANTE (session 2.14 sexies) — RÔLE DU VOLET 1 REQUALIFIÉ : depuis l'introduction du mécanisme de négociation de prix structuré (mission_offers, 2.14 sexies), une mission reste au statut pending pendant toute la durée de la négociation (jusqu'à 2 tours), et non plus jusqu'à une acceptation immédiate de type "premier arrivé, premier servi". Le canal subscribeToMissionUpdates (Volet 1) reste pertinent et actif, mais son rôle se restreint désormais à la fermeture du modal en cas d'annulation ou d'expiration de la mission — il ne gère plus un cas de "changement de chauffeur retenu" au sens où ce cas n'existe plus de la même façon pendant la phase de négociation. Voir aussi Section 7 (Chaîne de navigation Driver) pour la même précision appliquée à la description fonctionnelle du parcours, et Section 6 (bloc session 2.14 sexies, § 4.1 point c) pour le détail complet de cette découverte.
   ✅ NOUVEAU (session 2.14 sexies) — 2 nouveaux canaux ajoutés : subscribeToMissionOffers(missionId, onOfferChange) côté client (écoute INSERT + UPDATE sur mission_offers filtré par mission_id) et subscribeToDriverOffers(driverId, onOfferChange) côté chauffeur (écoute UPDATE uniquement sur mission_offers filtré par driver_id) — voir Section 6, bloc session 2.14 sexies.
   ✅ NOUVEAU (volet 5, lot E-bis, migration 20260504000052) — table mission_offers ajoutée à la diffusion en direct ; chargement initial des offres à l'ouverture de l'écran (aucune négociation ne pouvait aboutir dans l'application auparavant — voir RÉSOLU 79)

RLS transactions : ✅ transactions_insert_own corrigée — session 2.12 (commit 67e9e65) — voir RÉSOLU 37
   ✅ Fondation confirmée fonctionnelle en usage réel session 2.13 : requestWalletTopup() insère des transactions status: 'pending' via cette même politique — RÉSOLU 38
   ✅ Confirmée compatible avec le listener Realtime (Volet 2, session 2.14)
   ✅ NOUVEAU (session 2.17, migration 20260504000027) — policy transactions_update_admin (get_my_role() = 'admin') : la table ne disposait que de policies SELECT et INSERT, la validation d'une demande de recharge échouait silencieusement — voir RÉSOLU 61
   🔵 Pattern RLS de transactions_select_own / notifications_select_own identifié — session 2.14 bis — réutilisé avec succès comme référence pour voice-messages (session 2.14 ter, via jointure adaptée à un double accès), puis pour mission_offers (session 2.14 sexies, avec une adaptation notable — voir Section 2, bloc "RLS Storage / conception ownership").

Wallet topup : ✅ Mécanisme honnête — session 2.13 (commit 2e76429) — requestWalletTopup() — voir RÉSOLU 38
   ⛔ wallet_update_admin non modifiée — reste privilège admin exclusif
   ⚠️ Robustesse topupWallet/refundWallet (échec silencieux possible de l'insertion de la transaction après UPDATE du solde) — découverte annexe session 2.14, préexistante, hors périmètre — à documenter pour session future (voir Section 15/17) — ✅ CORRIGÉE session 2.17 (commit 6aeded2) : topupWallet() et refundWallet() retournent désormais une erreur explicite — voir RÉSOLU 57. ⚠️ Reste ouvert : topupWallet calcule le solde par « lire → ajouter → réécrire » (fragile en cas de crédits simultanés, y compris la recharge directe par l'admin) — crédit atomique en base (option 2 du volet 3) non traité
   ✅ Session 2.14 quinquies : validation fonctionnelle croisée obtenue en conditions réelles sur le nouveau profil DRIVER — recharge admin de 300 DH testée et confirmée (0 → 300 DH), et le chauffeur ne voit que son propre solde (jamais celui d'un autre profil), confirmant au passage le bon fonctionnement de security_invoker sur driver_dashboard (voir RÉSOLU 48)
   ✅ Session 2.14 sexies : recharge admin de 1000 DH testée et confirmée sur le nouveau profil DRIVER (a53521ca-...), sans régression
   ✅ NOUVEAU (session 2.17) — Workflow financier générique : requestWalletTopup() étendu (paymentMethod, proofUrl, stockés dans metadata, rétrocompatibles) ; sélecteur de 3 modes de paiement dans WalletTopupScreen.tsx (justificatif exigé si mode ≠ cash_agent) ; validation/rejet par l'admin (PendingTransactionsScreen.tsx) ; remboursement de commission demandé par le chauffeur sur mission annulée (requestRefund : statut d'annulation, présence de commission_charged_at, appartenance au chauffeur, absence de demande existante) ; rapprochement bancaire a posteriori, purement informatif (BankReconciliationScreen.tsx, colonne bank_reconciled_at) — le crédit réel intervient dès la validation documentaire
   ✅ NOUVEAU (volet 3, commit 65245b1) — anti double crédit : réservation atomique de la demande (UPDATE … WHERE status = 'pending') avant le crédit, puis crédit, puis remise en attente si le crédit échoue — voir RÉSOLU 66 — ⚠️ double clic réel non testé
   ✅ NOUVEAU (session 2.22) — historique des transactions : totaux calculés sur l'effet réel (solde après − solde avant) ; les lignes de trace « Demande validée » s'affichent « déjà créditée » — voir RÉSOLU 82
   ✅ Seuil de blocage : is_available passe à false si le solde est inférieur à 100 DH ; depuis la session 2.17, checkAndEnforceWalletBlock() notifie le chauffeur une seule fois, à la transition (notifyDriverLowBalance — voir RÉSOLU 59) — ⚠️ jamais déclenchée réellement

Dashboard driver : ✅ recharges_current_month — session 2.13 (commit 2e76429, migration 20260504000014) — voir RÉSOLU 39
   ✅ Vue driver_dashboard désormais protégée : SELECT anon révoqué, security_invoker = true activé — session 2.14 quinquies (voir RÉSOLU 48)

Bug Alert.alert/web : ⚠️ Statut par fichier — mis à jour session 2.14 :
   WalletTopupScreen.tsx ligne 70 (succès) → ✅ CORRIGÉ (commit 480130d, session 2.13) — RÉSOLU 41
   WalletTopupScreen.tsx ligne 66 (erreur) → ⚠️ NON VÉRIFIÉ, laissé inchangé (Option A) — voir bug résiduel Section 16
   AdminUsersScreen.tsx (session 2.8) → ⚠️ fonctionne web, sans distinction Platform.OS — risque mobile natif — voir bug résiduel Section 16
   PendingVerificationScreen.tsx (alerte Realtime) → ✅ CORRIGÉ session 2.14 — RÉSOLU 42 — ⚠️ chemin natif non testé
   Audit systématique recommandé — session 2.19 suggérée (voir Section 17)
   ✅ ACTUALISÉ (17/10/2026) — audit réalisé session 2.19 (module utils/dialogs.ts, 25 messages dans 11 écrans) et complété session 2.28 (13 anciens messages dans 11 écrans, dont la suspension d'un chauffeur dans AdminUsersScreen.tsx) — voir RÉSOLU 80 ; statut individuel de WalletTopupScreen.tsx ligne 66 non documenté ; chemin natif non testé

Realtime transactions/notifications (Volets 2-3, session 2.14) :
   ✅ subscribeToNewTransactions branché — TransactionHistoryScreen.tsx — écoute INSERT uniquement (limitation assumée, documentée)
   ✅ NotificationBell/NotificationCenterScreen montés sur les 3 rôles (Driver, Client, Admin)
   ⚠️ Anomalie #1 : NotificationCenterScreen.tsx sans bouton "← Retour" — voir Section 16 — ✅ CORRIGÉE session 2.21 (RÉSOLU 81)

Fonctions notify mission : 13 fonctions notify* inventoriées au total à ce jour (au 09/09/2026) — puis +1 en session 2.14 septies (notifyVoiceChannelOpened : décompte de 14 obtenu par déduction, validée) et +4 en session 2.17 (notifyDriverLowBalance, notifyTransactionValidated, notifyTransactionRejected, notifyTransactionBankConfirmed) — total exact au 17/10/2026 non documenté
   2 déjà branchées avant 2.14 (notifyDocumentVerified, notifyDocumentRejected)
   4 branchées session 2.14 : notifyMissionStarted, notifyMissionAccepted, notifyMissionCompleted (Option C), notifyMissionCancelled
   ✅ NOUVEAU (session 2.14 sexies) — 4 nouvelles fonctions branchées, dédiées au mécanisme de négociation, mutualisées sous un seul type 'offer_update' (icône et canal Android partagés) : notifyClientOfferUpdate, notifyDriverCounterOffer, notifyOfferAcceptancePending, notifyDriverOfferNotSelected. Table de couverture complète établie avant écriture, mappant chaque transition d'état du processus en 2 tours à son appelant exact dans missionService.ts.
   ⛔ 3 non retenues : notifyNewMission (incompatibilité structurelle, exclusion reconfirmée sans réserve session 2.14 quinquies — aucun appelant dans tout le projet, confirmé par grep global), notifyDocumentExpiry (en attente), notifyWalletLowBalance (écartée) — ⚠️ précisé session 2.17 : notifyWalletLowBalance() n'a jamais été appelée depuis le commit fondateur du wallet (4dda161), et son mode d'écriture (insertion directe en base, sans insertNotification()) n'aurait déclenché aucun push — remplacée par notifyDriverLowBalance() (voir RÉSOLU 59)
   ⚠️ NON TESTÉES fonctionnellement à ce jour, pour les 4 fonctions branchées en session 2.14 — le numéro partagé étant actuellement en rôle DRIVER, ceci ne permet toujours pas de test de bout en bout côté Client (absence de second numéro dédié CLIENT) — voir Section 16/17. Les 4 nouvelles fonctions liées à la négociation (session 2.14 sexies) sont également non testées fonctionnellement de bout en bout, pour la même raison structurelle. ✅ Partiellement levé (actualisation du 17/10/2026) : compte CLIENT dédié depuis le 03/10/2026 ; négociation testée en réel le 14/10/2026 (offre, acceptation, refus, retrait, notifications conformes) ; sonnerie sur un vrai téléphone toujours non testée.
   ⚠️ Doublon mort découvert, non corrigé (session 2.14 sexies) : constante NOTIF_ICONS dupliquée dans pushNotificationService.ts, jamais importée nulle part (confirmé par grep global) — préexistant à cette session, hors périmètre, documenté pour transparence — voir Section 16/17. ✅ Constaté absent du code au 17/10/2026 (précision de l'assistant général ; session de suppression non documentée). [Coquille « NOT_ICONS » de la version précédente corrigée le 17/10/2026.]
   ✅ NOUVEAU (session 2.14 septies) — notifyVoiceChannelOpened() (patron notify* standard) : annonce de l'ouverture du canal vocal, déclenchement unique à la transition — ⚠️ depuis la session 2.23, l'annonce est faite par le serveur (process_missions_24h_window) et les déclenchements ont été retirés de MissionActiveScreen et MissionTrackingScreen
   ✅ NOUVEAU (volet 5, lots E et E-ter, migrations 20260504000051 et 053) — « Offre non retenue » déposée par la base chez chaque chauffeur évincé ; client prévenu du retrait d'une offre ; trigger notify_mission_offer_events : les 7 notifications de la négociation sont déposées par la base chez l'autre partie
   ✅ NOUVEAU (volet 5, lot D-bis, migration 20260504000049) — can_notify_profile : notification vers soi-même, par l'admin, ou entre client et chauffeur d'une même mission ou offre (remplace deux règles « tout est permis »)
   ✅ NOUVEAU (session 2.26, migration 20260504000057) — sonnerie déclenchée par le SERVEUR : trigger notifications_push_dispatch — chaque notification enregistrée demande la sonnerie à send-push-notification par pg_net (clé lue dans le coffre-fort), envoi unique grâce à push_sent_at, canal Android choisi par la fonction ; la mention « notify* → dispatchPushNotification() » est dépassée
   ⚠️ Redirection au toucher d'une notification : corrections de la session 2.17 (commit e13dba4 — voir RÉSOLU 60) jamais testées par un clic réel

⚠️ Compte ADMIN test :
   Numéro : +212600000001 — Rôle admin défini via SQL Editor — NE PAS SUPPRIMER CE PROFIL
   Reconfirmé intact — sessions 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, 2.14 sexies (aucune modification, jamais touché) ; reconfirmé sessions 2.14 septies, 2.16 et 2.17 ; toujours présent au 17/10/2026 (compte rendu du 17/10/2026, A.3)

⚠️ DRIVER TEST HISTORIQUE — état à date de la session 2.14 ter (dernière vérification par lecture directe avant la rotation de 2.14 quater), TOUJOURS ORPHELIN D'ACCÈS AUTH :
   ⚠️ DÉPASSÉ (actualisation du 17/10/2026) : la suppression d'un compte Auth supprime en cascade profil, fiche chauffeur, portefeuille et transactions (découverte confirmée par lecture directe, étape 1 de l'étape 3 sécurité) ; la table drivers ne contient plus que le chauffeur de test — ce profil et ses données n'existent plus en base. Bloc conservé à titre historique.
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
   ⚠️ Ce profil DRIVER historique et l'intégralité de ses données restent en base, toujours orphelines de tout accès Auth, récupérables sur décision future (voir Section 17). Décision toujours en attente d'arbitrage. ⚠️ DÉPASSÉ (voir ci-dessus).

⚠️ AUTRES PROFILS DRIVER/CLIENT ANTÉRIEURS, ORPHELINS EN BASE (état à l'issue de la session 2.14 sexies) : — ⚠️ DÉPASSÉ (actualisation du 17/10/2026 : suppression en cascade, ces profils n'existent plus en base)
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
   (Catégorie et solde ci-dessus : état au 09/09/2026)
   ✅ ÉTAT AU 17/10/2026 (compte rendu du 17/10/2026, A.3) :
   profileId : 309967af-404b-4658-9c1a-a52b6cd16204
   Catégorie véhicule : N2 Moyen depuis le volet 4b-5 (décision D8) — IVECO Daily, plaque 54321-B-7, 5 000 kg (auparavant VUL, Mercedes Sprinter, plaque 12345-A-1, 1 000 kg)
   Documents légaux : 4 validés
   wallet_balance : 4 500 DH — historique : 1 000 DH (2.14 sexies) → 4 000 DH en session 2.17 (une demande de recharge de 1 000 DH bloquée depuis le 09/09/2026 a été créditée à chacune de trois tentatives de validation avant la correction du bug — RÉSOLU 61 ; donnée de test conservée par décision du porteur) → 4 500 DH (solde confirmé juste par la session 2.22 ; l'opération intermédiaire n'est pas détaillée dans les sources)
   Note : 0.00 (après le ménage du volet 5) — non disponible
   ⚠️ Ne voit que les missions N2 Moyen

⚠️ SIGNED_IN répétés en console admin : Comportement normal Supabase web via refresh token périodique — Non bloquant

✅ NOUVEAU — OBJETS DE SÉCURITÉ EN BASE (récapitulatif au 17/10/2026 — compte rendu du 17/10/2026, F.4) :
   Triggers : profiles : protect_profile_privileged_fields ; missions : control_mission_status_transition, protect_mission_participant_fields ; drivers : control_driver_availability, protect_driver_verification_fields, protect_driver_insert_fields ; mission_offers : check_mission_offer_transition, protect_mission_offer_fields, sync_mission_on_offer_accepted, notify_mission_offer_events ; notifications : notifications_push_dispatch ; plus les triggers préexistants (dates de mise à jour, numéros, commission)
   Fonctions système (réservées au système) : charge_commission_anticipated, process_missions_24h_window, block_drivers_with_expired_documents, driver_has_expired_documents, dispatch_push_on_notification_insert ; autres fonctions : can_notify_profile, get_public_parcel_tracking, find_nearby_drivers, calculate_distance, get_my_role
   Vues : client_offer_drivers (security_invoker) ; available_drivers (aucun droit pour anon et authenticated, lue seulement par find_nearby_drivers) ; public_parcel_tracking (aucun droit direct, lue par get_public_parcel_tracking)
   Colonnes ajoutées : drivers.vehicle_registration_expiry, drivers.vehicle_first_service_date ; missions.voice_channel_notified_at, missions.commission_alert_sent_at ; ecommerce_parcels.tracking_sms_sent_at ; notifications.push_sent_at — et, en session 2.17, missions.commission_charged_at et transactions.bank_reconciled_at
   Diffusion en direct : mission_offers ajoutée (052)
   Tâches planifiées : check-document-reminders (8 h), block-expired-documents (7 h), process-missions-24h (toutes les 5 minutes)
   Security Advisor : seule erreur critique (spatial_ref_sys) corrigée en 2.24 ; 8 avertissements acceptés et documentés en 2.25


⚠️ État du dépôt — HEAD : c886722 (fin de session 2.14 sexies), synchronisé avec origin/main d'après lecture directe réalisée au sein de cette même session (information qui me parvient ici en relais document, ma propre vérification par lecture directe du dépôt reste à faire en tout début de la prochaine session de supervision). ~59+ fichiers untracked de type .bak* identifiés comme mécanisme de traçabilité délibéré, avec deux précisions : (1) AUCUN nouveau .bak* n'a été créé en session 2.14 quinquies bis — écart explicitement noté dans le compte-rendu source par rapport à la convention habituelle du projet (modifications faites directement via str_replace/Python, sans backup manuel préalable) ; (2) la convention .bak.session2.14sexies a été reprise pour chaque fichier modifié en session 2.14 sexies, avec des suffixes supplémentaires .v2/.v3/.v4 lorsqu'un même fichier a été rouvert plusieurs fois dans cette session (traçabilité intégrale, tous les backups intermédiaires préservés) — cette nuance de la convention (versionnement des backups) est nouvelle et n'existait pas dans les sessions précédentes.

⚠️ État du dépôt — ACTUALISÉ (17/10/2026) : HEAD bcff143 (session 2.29), synchronisé avec origin/main — vérification d'usage à la reprise : git --no-pager log --oneline -1 doit afficher bcff143, et git status --short doit être vide.
   Précision de l'assistant général (journal git) : le commit 1b3738f (10/09/2026) est celui de la mise à jour de la ROADMAP du 09/09/2026 ; c886722 était le dernier commit de code de la session 2.14 sexies — le HEAD 1b3738f constaté au démarrage de la session 2.14 septies n'est donc pas une contradiction.
   Fichiers .bak* : convention .bak.session2.14septies (session 2.14 septies) et .bak.session2.16 (session 2.16) appliquée ensuite ; les copies .bak (131 fichiers, dont .bak.session_securite_choixchauffeur et .bak.session_securite_doublecredit) ont été réunies le 17/10/2026 dans l'archive FTM_copies_sauvegarde_2026-10-17.tar.gz (249 Ko, 2 090 411 octets non compressés), conservée dans /workspaces sur le Codespace et sur le PC du porteur, puis supprimées du dépôt ; aucune n'était suivie par git.
   Le dépôt ne contient ni app.json ni eas.json (constat session 2.29) — voir Phase 3.4.

# GITHUB SECRETS CONFIGURÉS

SUPABASE_ACCESS_TOKEN ✅ renouvelé 29/04/2026 — Token : FTM_GITHUB_ACTIONS — Expiration : Never
SUPABASE_PROJECT_ID ✅ (ustckqnecsilxqlyjute)
SUPABASE_DB_PASSWORD ✅
SUPABASE_ANON_KEY ✅
SUPABASE_URL ✅

# HISTORIQUE COMMITS CLÉS

[Actualisation du 17/10/2026 — commits ajoutés de 1b3738f à bcff143. Pour ces commits, les messages de commit exacts ne figurent pas dans les sources reçues : chaque ligne porte une description du contenu, sans guillemets, et non le message réel. Au sein d'une même journée, l'ordre suit l'ordre de présentation des comptes rendus.]

bcff143 retrait du code mort (chargeCommissionAnticipated, getChannelForType — 2 fichiers) ; ménage des 131 copies .bak (archive conservée) — session 2.29 (17/10/2026) ✅
e78b1a6 13 anciens messages alignés sur utils/dialogs.ts dans 11 fichiers (déconnexion des 3 accueils, transactions en attente, suspension d'un chauffeur…) — session 2.28 (17/10/2026) ✅
c903c2f erreurs TypeScript 34 → 19 (configuration "module": "esnext", déclarations de type — 5 fichiers) — session 2.27 (17/10/2026) ✅ — voir RÉSOLU 87
6b1026b correctif de send-push-notification : reconnaissance du rôle service_role inscrit dans la clé (erreur 401) — session 2.26 (17/10/2026) ✅ — voir RÉSOLU 86
6a53264 migration 20260504000057 — sonnerie déclenchée par le serveur (déclencheur notifications_push_dispatch) — session 2.26 (16/10/2026) ✅
4424a39 migration 20260504000056 — avertissements du Security Advisor (chemin de recherche de 9 fonctions, droits de 4 fonctions de déclenchement) — session 2.25 (16/10/2026) ✅ — voir RÉSOLU 85
aa1f8d8 migration 20260504000055 — PostGIS déplacé de public vers extensions — session 2.24 (16/10/2026) ✅ — voir RÉSOLU 84
633d78d migration 20260504000054 — prélèvement anticipé et annonce de la messagerie par le serveur (tâche process-missions-24h) ; déclenchements retirés de MissionActiveScreen et MissionTrackingScreen — session 2.23 (16/10/2026) ✅ — voir RÉSOLU 83
b1701e7 historique des transactions : totaux calculés sur l'effet réel — session 2.22 (16/10/2026) ✅ — voir RÉSOLU 82
c090c27 BackButton, LogoutButton, AccountSuspendedScreen, reprise de l'inscription chauffeur (17 fichiers) — session 2.21 (16/10/2026) ✅ — voir RÉSOLU 81
46d52ca module utils/dialogs.ts, 25 messages remplacés dans 11 écrans — session 2.19 (16/10/2026) ✅ — voir RÉSOLU 80
35d1cc8 migration 20260504000053 — notifications de négociation déposées par la base (trigger notify_mission_offer_events) — étape 3, volet 5, lot E-ter (14/10/2026) ✅ — voir RÉSOLU 79
74df2ff migration 20260504000052 — mission_offers en diffusion en direct, chargement initial des offres — étape 3, volet 5, lot E-bis (14/10/2026) ✅ — voir RÉSOLU 79
b066dae migration 20260504000051 — couleurs manquantes du thème, « Offre non retenue », retrait d'une offre signalé au client — étape 3, volet 5, lot E (14/10/2026) ✅ — voir RÉSOLU 78
2750835 migration 20260504000050 — fonctions serveur authentifiées, CORS corrigé, un SMS par colis — étape 3, volet 5, lot D-bis (13/10/2026) ✅ — voir RÉSOLU 77
967a406 migration 20260504000049 — notifications (can_notify_profile) et colis (get_public_parcel_tracking) — étape 3, volet 5, lot D-bis (13/10/2026) ✅ — voir RÉSOLU 77
6434eba migration 20260504000048 — offres et attribution (protect_mission_offer_fields, fonctions exécutées avec les droits du propriétaire) — étape 3, volet 5, lot C5 (13/10/2026) ✅ — voir RÉSOLU 76
67cc79a migration 20260504000047 — contrat de mission verrouillé, protect_mission_participant_fields — étape 3, volet 5, lot C (13/10/2026) ✅ — voir RÉSOLU 75
9acac5a migration 20260504000046 — droits des fonctions, règle B4(b) — étape 3, volet 5, lot B (13/10/2026) ✅ — voir RÉSOLU 74
d6bae44 migration 20260504000045 — fiche chauffeur — étape 3, volet 5, lot A (13/10/2026) ✅ — voir RÉSOLU 73
01d689f changement de véhicule dans l'application, accès aux documents pendant l'attente — étape 3, volet 4b-5 (12/10/2026) ✅ — voir RÉSOLU 71
ff7897f migration 20260504000044 — changement de véhicule soumis à validation — étape 3, volet 4b-5 (12/10/2026) ✅ — voir RÉSOLU 71
63f7f0d écran d'inscription : 2 dates de la carte grise obligatoires, note NB (non testé dans l'application) — étape 3, volet 4b-5 (12/10/2026) ✅ — voir RÉSOLU 70
592d1a5 écran admin de validation : dates de la carte grise, bug de rafraîchissement de la fiche corrigé — étape 3, volet 4b-5 (12/10/2026) ✅ — voir RÉSOLU 72
ebeb722 date à chaque remplacement de document, composant DateOnlyField.tsx — étape 3, volet 4b-5 (12/10/2026) ✅ — voir RÉSOLU 70
e8d01a7 migration 20260504000043 — réparation des deux gardiens et dates des documents — étape 3, volet 4b-5 (11/10/2026) ✅ — voir RÉSOLU 69
5f1c0d0 migration 20260504000042 — anti-auto-validation des documents (protect_driver_verification_fields) — étape 3, volet 4b-4 (09/10/2026) ✅ — voir RÉSOLU 69 (gardien défectueux, réparé par e8d01a7)
ce37519 migration 20260504000041 — droits de driver_has_expired_documents (PUBLIC subsistait) — étape 3, volet 4b-3 (09/10/2026) ✅ — voir RÉSOLU 69
528eb56 migration 20260504000040 — droits de driver_has_expired_documents (insuffisant) — étape 3, volet 4b-3 (08/10/2026) ⚠️ (complété par ce37519)
168ca8c migration 20260504000039 — gardien de disponibilité (control_driver_availability) — étape 3, volet 4b-3 (08/10/2026) ✅ — voir RÉSOLU 69 (gardien défectueux, réparé par e8d01a7)
069190b migration 20260504000038 — droits de la fonction de blocage — étape 3, volet 4b-2 (07/10/2026) ✅ — voir RÉSOLU 68
f23495a migration 20260504000037 — blocage des documents expirés (tâche block-expired-documents) — étape 3, volet 4b-2 (07/10/2026) ✅ — voir RÉSOLU 68
c0ac59b migration 20260504000036 — dates de la carte grise (vehicle_registration_expiry, vehicle_first_service_date) — étape 3, volet 4b-1 (07/10/2026) ✅ — voir RÉSOLU 68
c48ab60 migration 20260504000035 — messages vocaux : modification supprimée, suppression réservée à l'auteur — étape 3, volet 4a (06/10/2026) ✅ — voir RÉSOLU 67
65245b1 anti double crédit (walletService.ts) — étape 3, volet 3 (06/10/2026) ✅ — voir RÉSOLU 66
eed9a5f migration 20260504000034 — suppression de la règle drivers_select_available — étape 3, choix du chauffeur (06/10/2026) ✅ — voir RÉSOLU 65
ba8e61f informations du chauffeur affichées au client (getClientOfferDrivers, MissionOfferScreen.tsx) — étape 3, choix du chauffeur (06/10/2026) ✅
d3b5f40 migration 20260504000033 — vue client_offer_drivers — étape 3, choix du chauffeur (05/10/2026) ✅
4b473d2 migration 20260504000032 — carte des transitions de mission, driver_id et prix verrouillés — étape 3, volet transitions (05/10/2026) ✅ — voir RÉSOLU 64
18fd457 migration 20260504000031 — droits du prélèvement — étape 3, volet 1 (05/10/2026) ✅ — voir RÉSOLU 63
09a40ac migration 20260504000030 — colonnes de commission verrouillées — étape 3, volet 1 (05/10/2026) ✅ — voir RÉSOLU 63
a0b4c19 migration 20260504000029 — anti-négatif, sécurisation du prélèvement — étape 3, volet 1 (05/10/2026) ✅ — voir RÉSOLU 63 (contrôle d'identité inopérant, corrigé par 633d78d)
24e079a migration 20260504000028 — anti-élévation au rôle admin — étape 2 (03/10/2026) ✅ — voir RÉSOLU 62
f370da5 migration 20260504000027 — policy transactions_update_admin — session 2.17 (19/09/2026) ✅ — voir RÉSOLU 61 — dernier commit de la session 2.17
0e780b5 validatePendingTransaction : delete() remplacé par update() du statut — session 2.17 ⚠️ (correction insuffisante, complétée par f370da5)
e13dba4 redirections des notifications (notifyMissionCancelled dynamique, screenMap étendu, handleNotificationTap async) — session 2.17 ✅ — voir RÉSOLU 60
25f2553 Point 11 : getUnreconciledTransactions, markBankReconciled, BankReconciliationScreen.tsx — session 2.17 ✅
becda8d migration 20260504000026 — colonne bank_reconciled_at — session 2.17 (18/09/2026) ✅ — commit omis par le compte rendu 2.17, signalé par le compte rendu du 17/10/2026 et vérifié par l'assistant général
67e21fe notifications : checkAndEnforceWalletBlock corrigée, notifyDriverLowBalance et 3 notifications de transaction — session 2.17 ✅ — voir RÉSOLU 59
fdf0631 remboursement : requestRefund, bouton conditionnel dans MissionActiveScreen.tsx, type Mission étendu — session 2.17 ✅
79fa62c workflow financier générique (sous-étapes 2a à 2d) — 3e des 3 commits de l'étape, répartition exacte non documentée — session 2.17 ✅
69813ad workflow financier générique (sous-étapes 2a à 2d) — 2e des 3 commits de l'étape, répartition exacte non documentée — session 2.17 ✅
fa420de workflow financier générique (sous-étapes 2a à 2d, dont migration 20260504000025 — bucket payment-proofs) — 1er des 3 commits de l'étape, répartition exacte non documentée — session 2.17 ✅
d3b43ad fusion du prélèvement anticipé avec la fenêtre de 24 h du canal vocal (MissionActiveScreen.tsx) — session 2.17 ✅
bfb34d3 correction : rollback de la migration 024 déplacé dans supabase/rollbacks/ — session 2.17 ✅ — voir RÉSOLU 58
2320671 migration 20260504000024 — commission anticipée — session 2.17 ⚠️ (échec initial du déploiement, corrigé par bfb34d3)
6aeded2 topupWallet/refundWallet : erreur explicite au lieu d'un faux succès — session 2.17 ✅ — voir RÉSOLU 57
ad797da bouton de déconnexion — AdminDashboardScreen.tsx — session 2.16 (14/09/2026) ✅
61f5a54 bouton de déconnexion — CreateMissionScreen.tsx — session 2.16 (14/09/2026) ✅
ad62dd6 bouton de déconnexion — DriverHomeScreen.tsx — session 2.16 (14/09/2026) ✅
8d8176b réinstallation d'expo-av 13.10.6 — session 2.14 septies (14/09/2026) ✅ — voir RÉSOLU 56
b80d910 bandeau d'avertissement anti-partage (VoiceChatScreen.tsx) — session 2.14 septies ✅
9ba34cb condition d'accès temporisée au canal vocal, boutons conditionnels, notifyVoiceChannelOpened ; fermeture sur annulation (étape 6 regroupée dans ce commit) — session 2.14 septies ✅
518c900 route VoiceChat, wrappers ClientVoiceChatScreen.tsx et DriverVoiceChatScreen.tsx — session 2.14 septies ✅
24cd5f0 fonction getDriverProfileId(driverId) (missionService.ts) — session 2.14 septies ✅
4ee8257 nettoyage de onAccepted et ajout de onOfferCreated (DriverHomeScreen.tsx) — session 2.14 septies ✅ — voir RÉSOLU 55
1b3738f mise à jour de la ROADMAP après les sessions 2.14 quinquies bis et 2.14 sexies (10/09/2026) — précision de l'assistant général (journal git)
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

[Actualisation du 17/10/2026 : ajout, à la suite du bloc SESSION 2.14 sexies, des blocs SESSION 2.14 septies, SESSION 2.16, SESSION 2.17, ÉTAPE 2, ÉTAPE 3 SÉCURITÉ (volets 1 à 4b-4, volet 4b-5, volet 5) et SESSIONS 2.19 À 2.29.]

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
2.14 septies ✅ Piste 4 — activation canal vocal sécurisé (avec réserves) — 14/09/2026 [statut au 09/09/2026 : ⏳ dépendance levée, prête à démarrer]
2.15 ⏳ TrackingDetailScreen (suivi de colis) — REPORTÉE par décision du porteur avant l'ouverture de la session 2.16 (aucune dépendance) ; non reprogrammée au 17/10/2026
2.16 ✅ Bouton déconnexion 3 rôles (avec réserves) — 14/09/2026
2.17 ✅ Réforme timing commission + workflow financier générique — 14-19/09/2026
2.18 ⏳ Test fonctionnel complet voice-messages — REQUALIFIÉE : « canal vocal de bout en bout », Phase 4.4 (canal monté en 2.14 septies, annonce par le serveur depuis 2.23)
2.19 ✅ Audit systématique Alert.alert() — 16/10/2026 (module utils/dialogs.ts)
2.20 ⏳ Correction route CreateParcel manquante + test flux e-commerce complet (voir Section 6, bloc 2.14 quater) — REPORTÉE : le volet e-commerce sera examiné ultérieurement
Étape 2 ✅ Faille du rôle admin — 03/10/2026
Étape 3 sécurité ✅ Volets 1, transitions, choix du chauffeur, 3, 4a, 4b-1 à 4b-5, 5 — 05/10 → 14/10/2026 — volet 6 (configuration de la connexion) ⏳ jamais examiné
2.21 ✅ Boutons Retour et Déconnexion, compte suspendu, reprise de l'inscription chauffeur — 16/10/2026
2.22 ✅ Totaux de l'historique des transactions — 16/10/2026
2.23 ✅ Prélèvement de la commission et annonce de la messagerie par le serveur — 16/10/2026
2.24 ✅ PostGIS déplacé dans le schéma extensions — 16/10/2026
2.25 ✅ Avertissements du Security Advisor — 16/10/2026
2.26 ✅ Sonnerie déclenchée par le serveur — 16-17/10/2026
2.27 ✅ Erreurs TypeScript 34 → 19 — 17/10/2026
2.28 ✅ 13 anciens messages alignés sur dialogs.ts — 17/10/2026
2.29 ✅ Retrait du code mort, ménage des copies .bak — 17/10/2026

⚠️ NOTE DE NUMÉROTATION (actualisation du 17/10/2026, décision du porteur) : les numéros réels des sessions sont conservés. Les numéros 2.21 à 2.29 ont été attribués après le 09/09/2026, sans collision avec le plan ci-dessus (qui s'arrêtait à 2.20) ; 2.19 a conservé son objet prévu ; 2.15 et 2.20 sont reportées ; 2.18 est requalifiée. L'étape 2 et l'étape 3 sécurité ne portent pas de numéro 2.x : elles figurent comme blocs datés entre 2.17 et 2.19.

Ordre logique actualisé : 2.12 → 2.13 → 2.14 → 2.14 bis → 2.14 ter → 2.14 quater → 2.14 quinquies → 2.14 quinquies bis → 2.14 sexies (chantier "processus de mission" désormais complet sur ces 8 sessions) → 2.14 septies (peut démarrer immédiatement) → 2.15 (parallélisable) → 2.16 (glissable) → 2.17 (dernière du chantier wallet) → 2.18 (test fonctionnel voice-messages, Phase 4.4) → 2.19 (glissable, avant Phase 3) → 2.20 (fin de séquence chantier processus de mission au sens large, sans dépendance avec 2.14 septies)

Ordre réel (actualisation du 17/10/2026) : … → 2.14 sexies → 2.14 septies (14/09) → 2.16 (14/09, réalisée avant 2.15, reportée) → 2.17 (14-19/09) → étape 2 (03/10) → étape 3 sécurité (05/10 → 14/10) → 2.19 → 2.21 → 2.22 → 2.23 → 2.24 → 2.25 → 2.26 (16-17/10) → 2.27 → 2.28 → 2.29 (17/10) — prochaine étape : Phase 3, GPS compris (voir section « Étapes restantes »)

LISTE DE SUIVI — ANOMALIES/OBSERVATIONS DOCUMENTAIRES (à corriger dans le présent document) :
1. ID driver test coquille → CORRIGÉ session 2.12
2-3. Chemins onboarding → confirmés sous frontend/src/screens/driver/onboarding/
4. Bug WalletRecharge → CORRIGÉ session 2.13 (RÉSOLU 40)
5. Filtrage géographique absent → RPC find_nearby_drivers identifiée session 2.14 bis, infrastructure sécurisée session 2.14 quinquies, branchement réel réalisé et déployé session 2.14 quinquies bis (voir RÉSOLU 51) — test d'exécution complet en conditions réelles (GPS) toujours en attente, Phase 4.x — renvoyé en Phase 3.5 (GPS) par décision du porteur du 17/10/2026
6. Convention de chemins non documentée (sous-dossiers thématiques)
7. RLS transactions INSERT sans restriction → CORRIGÉ session 2.12 (RÉSOLU 37)
8. RLS voice-messages sans clause de propriété → CORRIGÉ session 2.14 ter (RÉSOLU 43 — renvoi corrigé le 17/10/2026, la mention antérieure « RÉSOLU 46 » était erronée)
9. Décompte transactions pending driver test → corrigé session 2.14 ter, voir Section 3
10. Divergence documentaire NotificationBell (Realtime événementiel, pas polling) → corrigée session 2.14 quater
11. Fichier applicatif du canal vocal confirmé frontend/src/services/audioService.ts → session 2.14 ter/quater
12. Route de navigation CreateParcel manquante (bug préexistant découvert, sans rapport avec la session) → session 2.20 assignée — session 2.20 reportée : le volet e-commerce sera examiné ultérieurement
13. Ambiguïté définition « Volet 2 » (expiration vs rappel 24h) → levée session 2.14 quinquies, confirmée par lecture directe de la ROADMAP
14. Nombre de profils DRIVER opérationnels → clarifié session 2.14 quinquies : un seul profil actif à la fois
15. Statut CI comme garantie de fonctionnement du code → infirmé par l'incident STATUS_FILTERS, RÉSOLU 50, règle consolidée Section 2
16. NOUVEAU (actualisation du 09/09/2026) — Chaînon de rotation du numéro de test partagé non documenté entre la session 2.14 quinquies bis (état DRIVER confirmé, sans rotation) et la session 2.14 sexies (compte-rendu mentionnant un état CLIENT en tout début de sa séquence de tests, sans événement de rotation documenté dans aucune des trois sources reçues pour cette actualisation) — signalé comme lacune de traçabilité, non reconstitué. Voir Section 2. — Actualisation du 17/10/2026 : sans objet pour la suite depuis la création du compte CLIENT dédié (03/10/2026) ; chaînon toujours non reconstitué.
17. NOUVEAU (actualisation du 09/09/2026) — Nuance de formulation relevée dans le compte-rendu de la session 2.14 quinquies bis, entre sa section 2 (« Déploiement : CI vert [...] vérifié par lecture directe de l'état réel de production [...] conformément à la règle méthodologique post-RÉSOLU 50 ») et sa section 5 (« sans test d'exécution réel du nouveau code [du Volet A], contrairement à la règle stricte post-RÉSOLU 50, appliquée ici avec une dérogation assumée »). Une hypothèse de lecture a été transmise séparément lors de la préparation de cette actualisation, suggérant que ces deux phrases porteraient sur deux objets distincts (vérification de la migration SQL en base vs test d'exécution réelle du code applicatif TypeScript), ce qui dissoudrait l'apparente contradiction — cette hypothèse n'a toutefois pas pu être vérifiée par une lecture directe et exhaustive du document source par la présente conversation, et n'est donc pas retenue comme fait établi. Point signalé pour vérification par le lecteur du présent document, avec le detail exact des deux formulations disponible dans le compte-rendu original de la session 2.14 quinquies bis. Voir Section 6, bloc session 2.14 quinquies bis.
18. NOUVEAU (actualisation du 09/09/2026) — Référent « Bloc A » mentionné dans le compte-rendu de la session 2.14 quinquies bis (« texte complet de l'annexe ROADMAP (Bloc A) non consulté dans cette conversation »), au sujet d'une réserve de la Partie 1 jamais levée. Une correspondance a été suggérée lors de la préparation de cette actualisation avec la distinction « Bloc A »/« Bloc B » qui existerait dans le « § TRI » de l'Annexe § 18 de la présente ROADMAP — mais le texte réel de ce § TRI n'a pas été transmis à la présente conversation (la version reçue de la ROADMAP du 25/08/2026 renvoie elle-même, pour ce passage, à « la version du 11/08/2026 » pour son texte complet). Cette correspondance n'a donc pas pu être vérifiée par lecture directe et n'est pas retenue comme fait établi dans le présent document. Voir Annexe § 18 bis.
19. NOUVEAU (actualisation du 17/10/2026) — HEAD au démarrage de la session 2.14 septies (1b3738f) différent du HEAD documenté au 09/09/2026 (c886722) : pas de contradiction — 1b3738f (10/09/2026) est le commit de la mise à jour de la ROADMAP du 09/09/2026, c886722 le dernier commit de code de 2.14 sexies (précision de l'assistant général, journal git).
20. NOUVEAU (actualisation du 17/10/2026) — HEAD final de la session 2.17 : le compte rendu 2.17 indique e13dba4, mais liste ensuite 0e780b5 et f370da5 ; le dernier commit de la session est f370da5 (19/09/2026) — confirmé par le compte rendu du 17/10/2026 (C.6) et par l'assistant général.
21. NOUVEAU (actualisation du 17/10/2026) — Commit becda8d (18/09/2026, migration 20260504000026, colonne bank_reconciled_at) omis par le compte rendu 2.17 — signalé par le compte rendu du 17/10/2026, placé entre 67e21fe et 25f2553 (vérifié par l'assistant général).
22. NOUVEAU (actualisation du 17/10/2026) — Suppression d'un compte Auth = suppression en cascade complète (profil, fiche chauffeur, portefeuille, transactions) : la description de profils « orphelins, données intactes en base » de la version précédente était erronée (compte rendu du 17/10/2026, B.0 et A.3) — blocs concernés marqués ⚠️ DÉPASSÉ.
23. NOUVEAU (actualisation du 17/10/2026) — Dossier supabase/rollbacks/ : existe depuis la session 2.12 ; le compte rendu 2.17 le présentait à tort comme un « nouveau dossier » — bfb34d3 a seulement déplacé dans ce dossier un rollback placé par erreur dans migrations/.
24. NOUVEAU (actualisation du 17/10/2026) — tsc détecte bien les imports dupliqués ; le compte rendu 2.16 affirmait le contraire (compte rendu du 17/10/2026, B.0).
25. NOUVEAU (actualisation du 17/10/2026) — audioService.ts : le compte rendu 2.14 septies lui attribuait 3 erreurs TypeScript ; le compte rendu 2.16 a établi 1 erreur réelle (TS2322, sans lien avec COLORS) — version retenue : celle de 2.16.
26. NOUVEAU (actualisation du 17/10/2026) — Renvois « RÉSOLU 46 » pour la correction RLS voice-messages : erronés (RÉSOLU 46 concerne DateTimeField.tsx) — corrigés en « RÉSOLU 43 » dans le présent document ; coquille « NOT_ICONS » corrigée en « NOTIF_ICONS ». Les renvois de section numérotés de la version précédente (ex. « Section 17 », « Section 18 ») sont laissés intacts même lorsqu'ils ne correspondent pas au rang réel de la section ; le texte ajouté le 17/10/2026 renvoie par titre de section.
27. NOUVEAU (actualisation du 17/10/2026) — Correction héritée « 7 destinations des notifications » signalée par le compte rendu du 17/10/2026 (C.6) : contenu exact non disponible dans les sources ; l'état des redirections est décrit d'après le compte rendu 2.17 (voir RÉSOLU 60).
28. NOUVEAU (actualisation du 17/10/2026) — Anomalie de redirection des notifications rattachée par le compte rendu 2.17 à une « découverte fortuite de la session 2.14 septies », non mentionnée dans le compte rendu 2.14 septies lui-même.
29. NOUVEAU (actualisation du 17/10/2026) — Écart de nombre de transactions pending historique/actuel (4 contre 1) signalé en session 2.17 : non résolu ; une explication par la suppression en cascade des profils historiques est une hypothèse non vérifiée.

Prochain timestamp migration disponible : 20260504000024 (consommé : 019 et 020 par session 2.14 quinquies bis, 021 à 023 par session 2.14 sexies)
Prochain timestamp migration disponible — ACTUALISÉ (17/10/2026) : 20260504000058 (consommé : 024 à 027 par session 2.17, 028 par l'étape 2, 029 à 053 par l'étape 3 sécurité, 054 à 057 par les sessions 2.23 à 2.26)

## REQUALIFICATION PHASE 6 — AMÉLIORATIONS POST-TESTS

[Contenu inchangé depuis la version du 25/08/2026 — items 6.1 à 6.6 repris à l'identique, voir Section 17/18 pour statuts courants.]
6.1 ⏳ Modes de paiement multiples wallet → session 2.17 — ✅ RÉALISÉ session 2.17 (3 modes de paiement, justificatif si mode ≠ cash_agent)
6.2 ⏳ Workflow validation recharge admin → session 2.17 (fondation posée 2.13) — ✅ RÉALISÉ session 2.17 (PendingTransactionsScreen, validation/rejet) — ⚠️ rejet non testé par un clic réel
6.3 ⏳ Remboursements flux dédié → session 2.17 — ✅ RÉALISÉ session 2.17 (requestRefund, demande du chauffeur sur mission annulée) — ⚠️ aucun test réel du remboursement documenté
6.4 ⏳ Bouton déconnexion 3 rôles → session 2.16 — ✅ RÉALISÉ session 2.16 (puis composant LogoutButton en 2.21, messages alignés en 2.28) — ⚠️ test CLIENT de la déconnexion non documenté
6.5 ✅/⏳ Refonte WalletTopupScreen — Partie 1 ✅ (2.13), Partie 2 ⏳ → session 2.17 — ✅ Partie 2 RÉALISÉE session 2.17
6.6 ✅/✅ SÉCURITÉ — RLS Storage : driver-documents ✅ (2.12), voice-messages ✅ CORRIGÉE (2.14 ter, RÉSOLU 43 — renvoi corrigé le 17/10/2026) — reste le test fonctionnel en Phase 4.4/session 2.18 — ✅ volet 4a (migration 20260504000035, RÉSOLU 67) : modification supprimée, suppression réservée à l'auteur, mission terminée ; payment-proofs ✅ (2.17) — reste le canal vocal de bout en bout (Phase 4.4)

⚠️ DÉPENDANCE CROISÉE À NOTER — Phase 3 / Session 2.14 : les fonctions notify* mission (y compris les 4 nouvelles de 2.14 sexies) dépendent de l'infrastructure FCM/APNs non réalisée à ce jour (voir Section 15). ⚠️ ACTUALISÉ (17/10/2026) : depuis la session 2.26, la sonnerie est déclenchée par le serveur ; aucun téléphone ne peut encore la recevoir (fonctions d'équipement du téléphone non raccordées, ni app.json ni eas.json) — voir Phase 3.4.

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

## SESSION 2.14 septies — commits 4ee8257 → 8d8176b

**Date** : 14/09/2026 — **Statut** : CLÔTURÉE ✅ (avec réserves) — source : compte rendu de la session 2.14 septies (actualisation du 17/10/2026)

### Contexte et objectif

Dernière session du chantier "amélioration du processus de création de mission" sur son périmètre restreint (2.14 ter → 2.14 septies). Dépendance unique (livraison effective de 2.14 sexies) levée en préambule, confirmée par lecture directe du HEAD réel du dépôt (1b3738f au démarrage — commit de la mise à jour de la ROADMAP du 09/09/2026, voir liste de suivi anomalie #19).

Objectif du prompt de mission : logique de contrôle d'accès en amont de VoiceMicButton.tsx, montage du canal, notification de message reçu, avertissement anti-partage de coordonnées — sur la base de la RLS déjà déployée (RÉSOLU 43) et de VoiceChatScreen.tsx (confirmé orphelin, conservé). ⚠️ Précision : la notification effectivement réalisée est une notification d'ouverture du canal (notifyVoiceChannelOpened) ; le compte rendu ne documente pas de notification de réception d'un message vocal.

Schéma d'activation temporisé, arbitré par le porteur avant investigation : le canal vocal ne s'ouvre qu'au croisement de deux conditions — accord de mission conclu (double acceptation symétrique, driver_id assigné) ET délai fixe de 24 h avant scheduled_pickup_time atteint. Mission à moins de 24 h : ouverture immédiate à l'acceptation, sans branche de code séparée. Fermeture : canal ouvert jusqu'à completed, fermeture immédiate sur toute annulation. Avertissement anti-partage : ton direct, affirme l'unicité de l'app comme canal, sans mentionner les coordonnées, en français, bandeau fixe et permanent (pas de modale), visible à chaque ouverture (pas de mémorisation « déjà vu »).

### Méthode

Partie 1 (investigation, lecture seule) structurée par objectif d'implémentation (5 objectifs), chaque bloc ne posant que les questions strictement nécessaires — principe arbitré par le porteur. Partie 2 (implémentation) en 6 étapes séquentielles, 1 commande à la fois, vérification par lecture directe après chaque modification, tsc --noEmit après chaque étape.

### Partie 1 — Investigation, résultats par objectif

- Objectif 1 (contrôle d'accès) : VoiceMicButton.tsx (217 lignes) autonome, sans donnée de mission ; VoiceChatScreen.tsx (214 lignes) sans donnée de statut ni de date ; aucun point d'appel vers VoiceChatScreen (orphelin, 3ᵉ confirmation indépendante) ; scheduled_pickup_time écrit une seule fois, à la création — condition fondée sur une valeur figée. Découverte fortuite : code mort onAccepted dans DriverHomeScreen.tsx (voir RÉSOLU 55).
- Objectif 2 (navigation) : aucune amorce dans MissionTrackingScreen.tsx ni MissionActiveScreen.tsx ; RLS voice-messages (migration 20260504000015) confirmée par lecture directe en base (pg_policies, 4 policies conformes) — RÉSOLU 43 passé du niveau relais document au niveau lecture directe ; convention de chemin d'audioService.ts cohérente avec l'indice [2] ; manque réel : aucune fonction driver_id → profile_id.
- Objectif 3 (double rappel automatique) : patron de vérification périodique de 30 s réutilisable, à écrire en propre ; arbitrage du porteur : détection différée acceptée (à la prochaine ouverture de l'app si le seuil est dépassé), pas de mécanisme serveur/CRON [décision ultérieurement remplacée : prélèvement et annonce par une tâche serveur depuis la session 2.23] ; mécanisme insertNotification() → dispatchPushNotification() → send-push-notification confirmé mature ; 13 fonctions notify* confirmées, toutes côté chauffeur avec un driverProfileId.
- Objectif 4 (avertissement) : aucun composant de bandeau réutilisable ; décisions du porteur actées (voir ci-dessus).
- Objectif 5 (fermeture sur annulation) : subscribeToMissionUpdates() sans filtre de statut ; côté client, canal déjà monté en permanence ; côté chauffeur, abonnement dédié nécessaire ; cancelMission() n'autorise l'annulation que si status IN ('pending', 'accepted') — seul le client peut annuler, et seulement avant le démarrage.

### Découvertes annexes

- 4.1 — TS2322 sur onProfileCreated (RootNavigator.tsx) : préexistante (comparaison avec le backup), sans impact fonctionnel, cause probable dans ProfileSetupScreen.tsx (fichier ⛔) — ✅ corrigée en session 2.27 (exception accordée, RÉSOLU 87).
- 4.2 — TS2339 sur COLORS : l'objet COLORS de theme.ts ne définissait que 8 propriétés ; noms absents utilisés (text, textSecondary, surface, border) — DriverHomeScreen.tsx 11 occurrences, MissionTrackingScreen.tsx 10, MissionActiveScreen.tsx 11 ; vérification globale : erreurs dans 21 fichiers, dont 18 non modifiés et non inspectés individuellement (dont parcelService.ts et audioService.ts, services dont les erreurs ne peuvent pas relever de COLORS) ; impact cosmétique — ✅ corrigée au volet 5, lot E (RÉSOLU 78).
- 4.3 — Code mort onAccepted + bug réel onOfferCreated manquant : traité (RÉSOLU 55).
- 4.4 — expo-av manquant : retrait historique accidentel (commit ec7d061), réinstallation (RÉSOLU 56) ; compatibilité vérifiée (Expo SDK 50) ; ⚠️ module en fin de vie (retrait annoncé avec SDK 55) ; écart de vulnérabilités 39 → 63 investigué : aucune imputable à expo-av, aucune correction --force.

### Partie 2 — Implémentation (6 étapes)

| Étape | Contenu | Fichiers | Commit |
|---|---|---|---|
| 1 | Nettoyage onAccepted + correctif onOfferCreated | DriverHomeScreen.tsx | 4ee8257 |
| 2 | Fonction getDriverProfileId(driverId) — résolution driver_id → profile_id ; risque vérifié (policies SELECT drivers_select_own / drivers_select_available / drivers_select_admin combinées en OU) | missionService.ts | 24cd5f0 |
| 3 | Route VoiceChat (client + chauffeur), wrappers ClientVoiceChatScreen.tsx (mission.client_id) et DriverVoiceChatScreen.tsx (résolution asynchrone via getDriverProfileId, états loading/error) | RootNavigator.tsx + 2 nouveaux fichiers | 518c900 |
| 4 | Condition d'accès temporisée (useEffect 30 s, statuts accepted/in_progress, seuil 24 h) + boutons conditionnels + notifyVoiceChannelOpened() avec déclenchement unique (useRef) | MissionTrackingScreen.tsx, MissionActiveScreen.tsx, notificationTemplates.ts | 9ba34cb |
| 5 | Bandeau d'avertissement anti-partage, permanent, sous le header | VoiceChatScreen.tsx | b80d910 |
| 6 | Fermeture sur annulation : abonnement subscribeToMissionUpdates dédié dans les deux wrappers, navigation.goBack() si cancelled_client/cancelled_driver | ClientVoiceChatScreen.tsx, DriverVoiceChatScreen.tsx (réécrits) | inclus dans 9ba34cb |

Commit supplémentaire : 8d8176b (réinstallation d'expo-av 13.10.6, diff minimal de 11 lignes). Méthode d'insertion affinée : manipulation par indice de ligne en Python avec assert de sécurité, plus fiable que str_replace sur les blocs à caractères spéciaux.

### Tests de non-régression

Contexte : GPS non branché (Codespaces), un seul numéro de test partagé à l'époque. ADMIN ✅ sans réserve ; DRIVER fonctionnel au lancement (deux démarrages réussis), sans test interactif complet ; CLIENT écarté par décision du porteur (préservation du profil DRIVER a53521ca-...). Détail en section « Tests de non-régression ».

### État final

HEAD : 8d8176b, synchronisé origin/main. Chaîne : 4ee8257 → 24cd5f0 → 518c900 → 9ba34cb → b80d910 → 8d8176b. Aucune migration. Fichiers créés : ClientVoiceChatScreen.tsx, DriverVoiceChatScreen.tsx. Fichiers modifiés : DriverHomeScreen.tsx, missionService.ts, RootNavigator.tsx, MissionTrackingScreen.tsx, MissionActiveScreen.tsx, notificationTemplates.ts, VoiceChatScreen.tsx, package.json, package-lock.json. Backups : convention .bak.session2.14septies.

Remarque méthodologique : l'implémentation a été entièrement committée avant les tests (écart signalé par le porteur, assumé pour cette session, retour à la pratique habituelle ensuite).

### Limites et réserves

- Parcours complet du canal vocal (ouverture réelle à 24 h, envoi/réception d'un message vocal, fermeture sur annulation en conditions réelles) jamais testé — Phase 4.4.
- Bouton « 💰 Proposer ce prix » corrigé, vérifié par tsc et relecture uniquement.
- Anomalie COLORS et 18 fichiers non inspectés (✅ traités depuis — volet 5, session 2.27).
- Anomalie onProfileCreated : cause non confirmée à l'époque (✅ corrigée en 2.27).
- Test CLIENT non réalisé, décision assumée du porteur.
- Note mineure : getDriverProfileId() appelée à deux endroits côté chauffeur (appel réseau dupliqué évitable, non bloquant).

### Recommandations en attente d'arbitrage (issues de cette session)

- onProfileCreated (dérogation sur ProfileSetupScreen.tsx) — ✅ traitée en 2.27.
- COLORS — ✅ traitée au volet 5, lot E.
- Dépréciation d'expo-av : migration vers expo-audio/expo-video avant toute montée vers Expo SDK 55+ — ouverte.
- Test de bout en bout du canal vocal et de la négociation — négociation testée le 14/10/2026 avec un chauffeur ; canal vocal : Phase 4.4.

## SESSION 2.16 — commits ad62dd6 → ad797da

**Date** : 14/09/2026 — **Statut** : CLÔTURÉE ✅ (avec réserves) — source : compte rendu de la session 2.16 (actualisation du 17/10/2026)

### Contexte et objectif

Session issue du « Point 2 » de la planification de la session 2.11, qualifiée de « glissable », sans dépendance avec 2.15 ou 2.17. Report explicite de la session 2.15 (TrackingDetailScreen) décidé par le porteur avant l'ouverture de cette session. Objectif : moyen de déconnexion accessible pour les 3 rôles, en s'appuyant sur handleSignOut() déjà existante dans authService.ts (ligne 179), sans jamais modifier ce fichier. Fiche de mission d'origine (session 2.11) restructurée en 3 parties strictes (Investigation → validation obligatoire → Implémentation → Tests).

### Partie 1 — Investigation

- Aucun composant d'en-tête commun aux 3 rôles ; NotificationBell montée séparément dans chacun. Écran Home Client = CreateMissionScreen.tsx, écran Home Admin = AdminDashboardScreen.tsx (incertitudes de la fiche 2.11 levées).
- handleSignOut() jamais appelée avant cette session (double recherche, élargie).
- Redirection après déconnexion déjà fonctionnelle : clause SIGNED_OUT de onAuthStateChange (RootNavigator.tsx) → setInitialRoute("AuthStack") — aucun code supplémentaire.
- États clientProfileId, driverProfileId, driverVehicleCategory non réinitialisés sur SIGNED_OUT : risque réel mais structurellement inoffensif (aucun chemin d'affichage) — aucune correction.
- Décisions du porteur : icône + texte « Se déconnecter » ; confirmation requise dans tous les cas (window.confirm sur le web, Alert.alert sinon).

### Partie 2 — Implémentation

Patron identique sur les 3 écrans : import de handleSignOut, fonction locale handleLogout() (confirmation, appel, gestion d'erreur symétrique), bouton 🚪 « Se déconnecter » après NotificationBell, couleur codée en dur (#DC3545) pour ne pas créer de nouvelle occurrence COLORS.

| Écran | Imports ajoutés | Commit |
|---|---|---|
| DriverHomeScreen.tsx | Platform, handleSignOut | ad62dd6 |
| CreateMissionScreen.tsx | handleSignOut (Platform déjà présent) | 61f5a54 |
| AdminDashboardScreen.tsx | Alert, Platform, handleSignOut | ad797da |

Incidents corrigés : ligne d'import dupliquée par un écho de terminal (CreateMissionScreen.tsx), détectée par relecture et retirée ; deux échecs d'assert de sécurité (numéros de ligne décalés), sans écriture fautive. Écart de comptage tsc 180 → 178 lignes : limite de la méthode d'extraction par expression régulière ; audioService.ts : 1 erreur réelle TS2322 (voir liste de suivi anomalie #25).

### Tests de non-régression

ADMIN ✅ et DRIVER ✅ (profileId 309967af-...) : confirmation affichée, chaîne Sign out initiated → SIGNED_OUT → Signed out successfully, redirection vers l'authentification. CLIENT non réalisé (préservation du profil chauffeur ; une déconnexion ne supprime aucune donnée, contrairement à une rotation). Détail en section « Tests de non-régression ».

### État final

HEAD : ad797da, synchronisé origin/main (chaîne vérifiée par git log 8d8176b..origin/main). Aucune migration. Fichiers modifiés : DriverHomeScreen.tsx, CreateMissionScreen.tsx, AdminDashboardScreen.tsx. Backups : convention .bak.session2.16.

### Limites, réserves et recommandations

- Test CLIENT du bouton de déconnexion : à réaliser (compte CLIENT dédié disponible depuis le 03/10/2026 ; test non documenté).
- Avertissement de dépréciation props.pointerEvents is deprecated. Use style.pointerEvents (console, écran d'authentification) : aucun des 3 fichiers modifiés ne l'utilise ; origine non localisée — classé depuis anomalie préexistante propre à React Native sur le web, sans conséquence (compte rendu du 17/10/2026, partie E).
- Réinitialisation explicite des états de profil sur SIGNED_OUT : par précaution, si RootNavigator.tsx est restructuré.
- Suites : bouton remplacé par le composant commun LogoutButton (session 2.21), messages de déconnexion des 3 accueils alignés sur dialogs.ts (session 2.28).

## SESSION 2.17 — commits 6aeded2 → f370da5

**Date** : 14-19/09/2026 (session étendue sur plusieurs jours, avec pause) — **Statut** : CLÔTURÉE ✅ — source : compte rendu de la session 2.17 (actualisation du 17/10/2026)

### Contexte et objectif

Session la plus vaste de la planification issue de 2.11, traitée en une seule session (décision du porteur) : réforme du timing de commission, workflow financier générique (recharge, remboursement, paiements multiples) et second niveau de validation (rapprochement bancaire, « Point 11 »). Dépendances 2.13 et 2.14 clôturées. Méthode : Partie 1 (7 objectifs) → synthèse validée → Partie 2 (ordre imposé : timing → workflow générique → Point 11 → notifications) → Partie 3 (tests).

### Rappel de la Partie 1

- Commission : montant fixe par catégorie (VUL 25 DH / N2 moyen 40 DH / N2 grand 50 DH), fixé à la création par set_commission_amount(), prélevé à la complétion par process_commission_payment().
- cancelMission() sans logique de commission ; risque de solde insuffisant au prélèvement anticipé jugé couvert par la marge de 100 DH et le blocage automatique.
- Statut pending des transactions déjà vivant depuis 2.13, mais aucun écran admin pour le traiter (transaction réelle de 1 000 DH bloquée depuis le 09/09/2026).
- refundWallet()/topupWallet() : gestion d'erreur silencieuse sur les deux fonctions.
- Point 11 : aucune migration de schéma nécessaire pour metadata (JSONB) ; nouveau bucket nécessaire.
- Notifications : prérequis « non négociable » du Point 7 confirmé à un niveau partiel — test reporté après l'abonnement aux services externes, avant la mise en production.

### Partie 2 — Implémentation

- Prérequis — fonctions wallet corrigées (6aeded2, RÉSOLU 57) ; décision : l'erreur n'est captée que par l'écran admin.
- Étape 1 — réforme du timing : migration 20260504000024_anticipated_commission_charge.sql (colonne commission_charged_at, RPC charge_commission_anticipated() avec verrouillage FOR UPDATE et garde-fou d'idempotence, process_commission_payment() transformé en filet de sécurité) ; incident de déploiement du rollback (RÉSOLU 58) ; fusion avec le canal vocal : prélèvement déclenché par le même useEffect / la même fenêtre de 24 h, dans MissionActiveScreen.tsx, avec le même garde-fou (voiceChannelNotifiedRef). Commits 2320671 (échec initial), bfb34d3, d3b43ad. [Depuis la session 2.23, prélèvement par le serveur.]
- Étape 2 — workflow financier générique : 2a requestWalletTopup() étendu (paymentMethod, proofUrl, rétrocompatibles) ; 2b bucket payment-proofs (migration 20260504000025_create_payment_proofs_bucket.sql, RLS sur get_my_role(), suppression réservée à l'admin) et uploadPaymentProof() ; 2c WalletTopupScreen.tsx étendu (driverId transmis depuis WalletDashboardScreen, sélecteur de 3 modes, upload conditionnel si mode ≠ cash_agent, texte d'information généralisé) ; 2d nouvel écran admin PendingTransactionsScreen.tsx (modèle DocumentReviewScreen.tsx), getPendingTransactions(), validatePendingTransaction(), rejectPendingTransaction(), badge sur AdminDashboardScreen.tsx (getAdminStats() étendu). Commits fa420de, 69813ad, 79fa62c.
- Flux de remboursement : demande déclenchée par le chauffeur (et non création automatique — décision du porteur) ; requestRefund(missionId, driverId) ; bouton conditionnel dans MissionActiveScreen.tsx ; type Mission étendu avec commission_charged_at. Commit fdf0631.
- Étape 4 — notifications : découverte de notifyWalletLowBalance() jamais appelée (RÉSOLU 59) ; checkAndEnforceWalletBlock() corrigée ; notifyDriverLowBalance(), notifyTransactionValidated(), notifyTransactionRejected(), notifyTransactionBankConfirmed(). Commit 67e21fe.
- Étape 3 — Point 11 : migration 20260504000026_add_bank_reconciliation_tracking.sql (colonne bank_reconciled_at, rollback placé dès le départ dans supabase/rollbacks/, déploiement réussi du premier coup) — commit becda8d (18/09/2026, omis par le compte rendu 2.17) ; getUnreconciledTransactions() (filtre renforcé par .not(is, null)), markBankReconciled(), nouvel écran BankReconciliationScreen.tsx avec badge — commit 25f2553. Le crédit réel intervient dès la validation documentaire ; le rapprochement est une vérification a posteriori, purement informative.
- Redirection des notifications : RÉSOLU 60, commit e13dba4.

### Partie 3 — Tests, bug critique

Bug critique découvert au premier test réel de validation (RÉSOLU 61) : table transactions sans policy DELETE ni UPDATE ; première correction insuffisante (0e780b5), correction définitive par migration 20260504000027_add_transactions_update_admin_policy.sql (f370da5) ; incident CI « rate limit exceeded » résolu par ré-essai. Conséquence assumée : trois crédits successifs, solde de test à 4 000 DH au lieu de 2 000 DH, conservé par décision du porteur. Tests ADMIN, DRIVER et cycle complet de recharge par virement réussis ; CLIENT non testé (aucun fichier propre au client modifié). Détail en section « Tests de non-régression ».

### État final

Dernier commit de la session : f370da5 (19/09/2026) — le compte rendu indiquait HEAD e13dba4 (dernier commit applicatif), incohérence relevée (liste de suivi anomalie #20). Chaîne complète : 6aeded2 → 2320671 → bfb34d3 → d3b43ad → fa420de → 69813ad → 79fa62c → fdf0631 → 67e21fe → becda8d → 25f2553 → e13dba4 → 0e780b5 → f370da5. Migrations 20260504000024 à 20260504000027 déployées et vérifiées en base, avec leurs rollbacks dans supabase/rollbacks/. Fichiers créés : PendingTransactionsScreen.tsx, BankReconciliationScreen.tsx. Fichiers modifiés : walletService.ts, adminService.ts, notificationTemplates.ts, pushNotificationService.ts, missionService.ts, MissionActiveScreen.tsx, WalletDashboardScreen.tsx, WalletTopupScreen.tsx, AdminDashboardScreen.tsx, RootNavigator.tsx, NotificationCenterScreen.tsx.

### Découvertes annexes

- TS2352 sur getTransactionHistory() (walletService.ts) — préexistante — ✅ corrigée en 2.27 (RÉSOLU 87).
- TS1323 sur les imports dynamiques (configuration --module) — préexistante, nouvelles occurrences de même nature — ✅ corrigée en 2.27 (RÉSOLU 87).
- canDriverAcceptMission() (walletService.ts) : jamais appelée, redondante tant que le seuil (100 DH) reste supérieur à la commission maximale (50 DH) — toujours présente et jamais appelée au 17/10/2026 (précision de l'assistant général).
- processed_at non renseigné sur les lignes pending devenues completed — cosmétique, ouvert.
- Écart de nombre de transactions pending historique/actuel (4 contre 1) — non résolu (liste de suivi anomalie #29).

### Limites et réserves

- Test CLIENT non réalisé ; rejet d'une demande non testé par un clic réel ; correction du screenMap jamais testée par un clic réel ; notifyDriverLowBalance() jamais déclenchée réellement ; prérequis « non négociable » du Point 7 reporté avant la mise en production ; push réelles non testées en conditions natives ; solde de test à 4 000 DH (donnée volontairement conservée).

### Recommandations en attente d'arbitrage (issues de cette session)

- TS2352 et TS1323 — ✅ traitées en 2.27.
- Ajout de processed_at dans validatePendingTransaction() — ouvert.
- Tests réels : rejet d'une demande, screenMap (5 destinations, en particulier MissionOfferScreen), notifyDriverLowBalance(), Point 7 avant production — ouverts.
- Mise à jour de la ROADMAP — réalisée le 17/10/2026 (présente version).

## ÉTAPE 2 — RÔLE ADMIN — commit 24e079a

**Date** : 03/10/2026 — **Statut** : CLOSE ✅ — source : compte rendu complet du 17/10/2026 (B.0, F.1)

Étape 1 (préalable, découvertes par lecture directe, sans commit) : suppression Auth → cascade complète (la ROADMAP se trompait) ; tsc détecte les imports dupliqués (le compte rendu 2.16 se trompait) ; supabase/rollbacks/ existe depuis la session 2.12 ; un REVOKE UPDATE par colonne est inefficace si un droit sur la table entière existe ; un REVOKE FROM anon est inefficace si le droit vient de PUBLIC.

Étape 2 — faille du rôle admin (close) : trigger protect_profile_privileged_fields sur profiles, qui empêche l'auto-élévation au rôle admin et la modification de is_active. Migration 20260504000028_protect_profile_role_and_is_active.sql, commit 24e079a (03/10/2026). Voir RÉSOLU 62.

Compte CLIENT de test +212600000002 créé le 03/10/2026 (précision de l'assistant général du projet).

## ÉTAPE 3 SÉCURITÉ — VOLETS 1 À 4b-4 — commits a0b4c19 → 5f1c0d0

**Dates** : 05/10 → 09/10/2026 — **Statut** : CLOS ✅ (gardiens des volets 4b-3/4b-4 réparés au volet 4b-5) — source : compte rendu complet du 17/10/2026 (B.1 à B.8)

L'étape 3 était une grande session de sécurité ; elle a fait émerger des fonctionnalités métier manquantes (choix du chauffeur, blocage des documents expirés, saisie des dates, changement de véhicule), traitées en cours de route. L'assistant général conduit le volet technique ; le porteur valide les décisions métier et exécute les commandes.

**Volet 1 — Protection financière des missions ✅** (RÉSOLU 63) : failles — colonnes financières librement modifiables, aucune contrainte contre les montants négatifs, charge_commission_anticipated sans contrôle d'identité. Migrations 029 secure_mission_financial_fields (a0b4c19), 030 lock_commission_columns_properly (09a40ac : retrait du droit UPDATE sur toute la table pour anon et authenticated, ré-octroi des 29 colonnes légitimes), 031 restrict_charge_commission_execute (18fd457). ⚠️ Actualisé : le contrôle d'identité de 029 était inopérant (fonction exécutée avec les droits du propriétaire) — depuis la migration 054 (session 2.23), charge_commission_anticipated n'est plus exécutable que par le système et le prélèvement est fait par une tâche planifiée du serveur.

**Volet transitions — statut, driver_id, negotiated_price ✅** (RÉSOLU 64) : une mission ne passe à accepted que par le trigger sync_mission_on_offer_accepted (AFTER UPDATE sur mission_offers), après la double acceptation contrôlée par check_mission_offer_transition. Carte des transitions légitimes : création → pending (client) ; pending → accepted (trigger des offres uniquement) ; accepted → in_progress puis in_progress → completed (chauffeur de la mission) ; pending ou accepted → cancelled_client (client) ou cancelled_driver (chauffeur) ; pending → expired (mécanisme applicatif expireMission, pas de fonction en base). Migration 032 control_mission_transitions (4b473d2) : verrouillage de driver_id et negotiated_price (ré-octroi de 27 colonnes), trigger control_mission_status_transition (BEFORE UPDATE missions), offre acceptée exigée pour pending → accepted, vérification de l'identité (corrige la faille cancelMission/userId) ; admin et système libres ; rollback fin qui préserve le volet 1. ⚠️ Actualisé : après le verrouillage du lot C du volet 5, la double acceptation ne pouvait plus attribuer la mission — corrigé au lot C5 (048). acceptMission() (code mort) : sort à décider pendant la phase GPS.

**Bloc choix du chauffeur ✅** (RÉSOLU 65) : le client ne voyait que le prix des offres — fonctionnalité construite puis sécurisée dans la même session. Informations affichées au client (décision du porteur) : catégorie du véhicule, capacité, note moyenne, nombre de missions ; jamais nom (champ unique, découpage non fiable), téléphone, plaque, position, documents. Migration 033 create_client_offer_drivers_view (d3b5f40 — vue client_offer_drivers, security_invoker, filtrée sur le client connecté) ; commit ba8e61f (getClientOfferDrivers dans missionService.ts, affichage compact dans MissionOfferScreen.tsx) ; migration 034 close_drivers_select_available (eed9a5f — suppression de drivers_select_available et d'un doublon). ⚠️ Actualisé : la vue available_drivers a été recréée en 2.24 sans aucun droit pour anon et authenticated ; elle n'est plus lue que par find_nearby_drivers.

**Volet 3 — Double crédit ✅** (RÉSOLU 66) : commit 65245b1 — réservation atomique de la demande avant le crédit. Découverte élargie : topupWallet calcule le solde par « lire → ajouter → réécrire » — option 2 (crédit atomique en base) reportée à un volet « robustesse du portefeuille », non traitée au 17/10/2026.

**Volet 4a — Messages vocaux ✅** (RÉSOLU 67) : convention des fichiers missions/{missionId}/{profileId}_{horodatage}.ext ; migration 035 restrict_voice_messages_delete_update (c48ab60).

**Volet 4b — Documents du chauffeur : recadrage** : objectif — garantir qu'un chauffeur ne travaille que si ses documents sont validés et non expirés. is_verified est global (calculé) ; is_available conditionne la réception des missions (find_nearby_drivers ne retient que les chauffeurs disponibles) et passe à false si le solde est inférieur à 100 DH. Décisions : D1 tâche quotidienne uniforme ; D2 visite technique exigée seulement au-delà de 5 ans ; D3 pas de contrôle automatique des dates, jugement manuel de l'admin ; D4 un chauffeur bloqué pour documents peut encore recharger ; D5 blocage le jour même de l'expiration ; blocage par is_available = false ; remplacement : le chauffeur propose, l'admin valide (auto-validation interdite) ; changement de véhicule : action du chauffeur et validation de l'admin ; tolérance des dates vides des données de test (obligatoires en production). La « suspension pendant revalidation » a été tranchée au volet 4b-5 (D1).

**Sous-volets 4b-1 à 4b-4 ✅** (RÉSOLU 68 et 69) : 4b-1 — 036 (c0ac59b) ; 4b-2 — 037 (f23495a) et correctif 038 (069190b) ; 4b-3 — 039 (168ca8c), correctifs 040 (528eb56) et 041 (ce37519) ; 4b-4 — 042 (5f1c0d0). ⚠️ Actualisé : les deux gardiens étaient défectueux (test du 10/10/2026) — réparés par la migration 043 (volet 4b-5).

**Enseignement majeur — droits sur les fonctions** : voir section « Règles critiques » (règles NOUVEAU de l'étape 3). État au 17/10/2026 : block_drivers_with_expired_documents réservée au système ; driver_has_expired_documents retirée à PUBLIC, anon et authenticated (046) ; charge_commission_anticipated réservée au système (054).

## ÉTAPE 3 SÉCURITÉ — VOLET 4b-5 — commits e8d01a7 → 01d689f

**Dates** : 10-13/10/2026 — **Statut** : CLOS ✅ — source : compte rendu complet du 17/10/2026 (B.9)

Objet : imposer une nouvelle date d'expiration à chaque remplacement de document (défaut bloquant : un chauffeur bloqué pour document expiré restait bloqué après revalidation), permettre le renouvellement anticipé, intégrer les dates de la carte grise, puis traiter le changement de véhicule.

Décisions du porteur : D1 tout document remplacé, même par anticipation, repasse en attente, chauffeur indisponible jusqu'à la validation ; D2 données de test corrigées en base avant les tests ; D3 véhicule de moins de 5 ans : 2e copie de la carte grise à la place de la visite technique, note « NB » pour le chauffeur, indication de contrôle pour l'admin ; D4 inscription : 2 dates obligatoires pour la carte grise, commit sans test applicatif ; D5 changement de véhicule : pas de parcours spécial pour les documents, ressaisie des informations du véhicule, tout changement en attente de validation, la plaque est le numéro unique, pas de blocage pendant une mission en cours ; D6 l'admin vérifie la plaque sur la carte grise, l'assurance et la visite technique, et ne valide pas la carte grise tant que les deux autres documents du nouveau véhicule ne sont pas fournis ; D7 bouton « Mettre à jour mes documents » sur l'écran d'attente ; D8 le chauffeur de test reste sur le nouveau véhicule ; D9 correction générale des messages invisibles sur le web reportée à la session 2.19.

Réalisations : migration 043 fix_driver_guards_and_document_dates (e8d01a7 — réparation des deux gardiens, RÉSOLU 69 ; 15 scénarios locaux et contrôles réels avant/après) ; écran chauffeur ebeb722 (DateOnlyField.tsx, saveDocumentReplacement, bouton « Remplacer » — RÉSOLU 70) ; écran admin 592d1a5 (dates de la carte grise, bug de rafraîchissement corrigé — RÉSOLU 72) ; écran d'inscription 63f7f0d (non testé dans l'application) ; migration 044 vehicle_change_requires_validation (ff7897f) et application 01d689f (« Mon véhicule », « Changer de véhicule », accès aux documents pendant l'attente — RÉSOLU 71).

Tests réels : remplacement de l'assurance avec date (T4-T5) ; cycle complet de la carte grise côté admin (T6-T10) ; changement de véhicule complet, de la saisie à la validation des 3 documents (T11-T16d). Leçons de méthode : paquets base64 contrôlés (un collage de 8 Ko avait été tronqué), scripts à ancres, réponses courtes « OK/ECART » des requêtes de contrôle.

Constats laissés ouverts : rappels d'expiration absents pour la carte grise et non mis à jour au remplacement ; capacité laissée vide à l'inscription (0 envoyé, contrainte > 0) ; plaque saisie deux fois à l'inscription ; écran d'attente sans lecture des statuts à l'ouverture et route de sortie à vérifier ; fichier orphelin si l'enregistrement échoue après l'envoi.

## ÉTAPE 3 SÉCURITÉ — VOLET 5 — commits d6bae44 → 35d1cc8

**Dates** : 13-14/10/2026 — **Statut** : CLOS ✅ — source : compte rendu complet du 17/10/2026 (B.10)

Objet : fermer les failles laissées par le volet 4b-5 et les points de sécurité restants, par lots validés un à un : A (fiche chauffeur), B (droits des fonctions), C (missions), D (CORS de send-push-notification), E (couleurs) ; élargissements C5, D-bis, E-bis, E-ter.

| Lot | Migration, commit | Contenu |
|---|---|---|
| A | 045 driver_row_rights_lot_a, d6bae44 | Note moyenne et nombres de missions et d'avis non modifiables par le chauffeur ; fiche créée par un utilisateur normalisée ; anon perd l'écriture sur drivers ; update_driver_rating exécutée avec les droits du propriétaire (RÉSOLU 73) |
| B | 046 function_rights_lot_b, 9acac5a | Chemin de recherche fixé pour find_nearby_drivers et get_my_role ; driver_has_expired_documents retirée à PUBLIC, anon, authenticated ; adoption de la règle B4(b) (RÉSOLU 74) |
| C | 047 missions_rights_lot_c, 67cc79a | « Contrat » de la mission non modifiable ; trigger protect_mission_participant_fields ; anciennes règles redondantes supprimées (RÉSOLU 75) |
| C5 | 048 mission_offers_lot_c5, 6434eba | Trigger protect_mission_offer_fields ; sync_mission_on_offer_accepted et process_commission_payment exécutées avec les droits du propriétaire ; ménage des droits sur mission_offers (RÉSOLU 76) |
| D-bis 1 | 049 notifications_parcels_lot_dbis, 967a406 | can_notify_profile ; suppression de la lecture publique de tous les colis, suivi par get_public_parcel_tracking(numéro), téléphone masqué (RÉSOLU 77) |
| D-bis 2 | 050 tracking_sms_once, 2750835 | Fonctions serveur authentifiées ; CORS corrigé (RÉSOLU 77) |
| E | 051 offer_not_selected_notification, b066dae | Couleurs manquantes ajoutées au thème (147 → 34 erreurs TypeScript) ; « Offre non retenue » ; retrait d'une offre signalé au client (RÉSOLU 78) |
| E-bis | 052 realtime_mission_offers, 74df2ff | mission_offers en diffusion en direct ; chargement initial des offres (RÉSOLU 79) |
| E-ter | 053 offer_negotiation_notifications, 35d1cc8 | Trigger notify_mission_offer_events : les 7 notifications de la négociation déposées par la base (RÉSOLU 79) |

Décisions marquantes : D2 PostGIS dans public à réexaminer (traité en 2.24) ; D5 prélèvement et canal vocal 24 h avant la date prévue ; D7 limites anti-abus (push dans les 10 minutes suivant la notification, un SMS par colis) ; D9 nuancier complété ; D10 notifications de négociation confiées à la base, et lot « sonnerie déclenchée par le serveur » inscrit comme prérequis de production (fait en 2.26).

Test réel du 14/10/2026 (mission de test N2 créée en base, connexions successives client puis chauffeur) : offre, acceptation, refus, retrait et notifications conformes après E-bis et E-ter. Ménage final : 0 mission, 0 offre, notifications d'origine intactes.

## SESSIONS 2.19 À 2.29 — commits 46d52ca → bcff143

**Dates** : 16-17/10/2026 — **Statut** : CLOSES ✅ (avec réserves, voir section « Tests de non-régression ») — source : compte rendu complet du 17/10/2026 (B.11, B.12, F.2) ; détail (constats, tests, empreintes) dans le compte rendu « Sessions 2.19 à 2.29 », non repris ici

| Session | Commit | Contenu |
|---|---|---|
| 2.19 | 46d52ca | Module commun utils/dialogs.ts : showMessage et confirmAction (fenêtres du navigateur sur le web, natives sur téléphone) ; 25 messages remplacés dans 11 écrans ; les confirmations « terminer la mission » et « annuler la mission » fonctionnent sur le web (RÉSOLU 80) |
| 2.21 | c090c27 | BackButton (retour, ou accueil du rôle s'il n'y a pas d'écran précédent), LogoutButton, écran AccountSuspendedScreen (un compte suspendu voyait un écran blanc) ; 12 écrans corrigés ; reprise de l'inscription chauffeur : l'étape 1 préremplit et met à jour la fiche existante au lieu d'en créer une seconde (17 fichiers — RÉSOLU 81) |
| 2.22 | b1701e7 | Historique des transactions : totaux calculés sur l'effet réel ; lignes de trace « Demande validée » affichées « déjà créditée » ; le solde de 4 500 DH était juste (RÉSOLU 82) |
| 2.23 | 633d78d | Migration 054 mission_24h_window_server : process_missions_24h_window() et tâche process-missions-24h (toutes les 5 minutes) — prélèvement anticipé de la commission (solde insuffisant : nouvel essai, alerte unique au chauffeur et aux admins) et annonce unique de la messagerie ; charge_commission_anticipated réservée au système ; déclenchements retirés de MissionActiveScreen et MissionTrackingScreen (RÉSOLU 83) |
| 2.24 | aa1f8d8 | Migration 055 move_postgis_to_extensions : PostGIS déplacé de public vers extensions (spatial_ref_sys modifiable par tous via l'API — seule erreur critique du Security Advisor) ; colonnes, index, vue available_drivers (droits retirés) et fonctions recréés ; chemin de recherche incluant extensions ; répétition à blanc sur la vraie base ; ticket au support Supabase envoyé, puis clos le 17/10 (RÉSOLU 84) |
| 2.25 | 4424a39 | Migration 056 security_advisor_warnings : chemin de recherche fixé pour 9 fonctions ; droit d'exécution retiré sur 4 fonctions de déclenchement ; 8 avertissements acceptés et documentés (RÉSOLU 85) |
| 2.26 | 6a53264, 6b1026b | Migration 057 server_push_dispatch : déclencheur notifications_push_dispatch (sonnerie demandée à send-push-notification par pg_net, clé lue dans le coffre-fort, envoi unique par push_sent_at, canal Android choisi par la fonction) ; correctif : la fonction reconnaît le rôle service_role inscrit dans la clé (erreur 401 — RÉSOLU 86) |
| 2.27 | c903c2f | Erreurs TypeScript 34 → 19 (configuration, déclarations de type — 5 fichiers) ; les 19 restantes concernent parcelService.ts (RÉSOLU 87) |
| 2.28 | e78b1a6 | 13 anciens messages alignés sur dialogs.ts dans 11 écrans (déconnexion des 3 accueils, transactions en attente, suspension d'un chauffeur…) |
| 2.29 | bcff143 | Code mort retiré (chargeCommissionAnticipated, getChannelForType — 2 fichiers) ; ménage des 131 copies .bak (archive conservée) ; constat : aucun téléphone ne s'enregistre (les fonctions d'équipement du téléphone ne sont appelées par aucun écran ; ni app.json ni eas.json) |

Numérotation : les numéros 2.21 à 2.29 ont été attribués dans la conversation du 10/10 → 17/10/2026, sans session 2.20 (reportée) ; voir la note de numérotation du bloc SESSION 2.11 ci-dessus.

État final au 17/10/2026 : HEAD bcff143, prochaine migration 20260504000058, 19 erreurs TypeScript (toutes dans parcelService.ts). Point d'entrée : ouvrir la Phase 3, GPS compris (voir section « Étapes restantes »).

# CHAÎNE DE NAVIGATION DRIVER

ProfileSetupScreen → onProfileCreated(role='driver') → DriverOnboardingStack
VehicleInfoScreen → createDriverProfile() → navigate('LegalDocuments', { driverId })
LegalDocumentsScreen [reçoit driverId] → saveDriverDocuments() → navigate('DocumentUpload', { driverId })
DocumentUploadScreen [reçoit driverId] → uploadDocument() × 4 → upload dans bucket driver-documents
   ⚠️ limitations web : bouton Photo non disponible, utiliser bouton Fichier uniquement sur web
   → navigate('PendingVerification', { driverId })
Écran d'inscription — ✅ NOUVEAU (volet 4b-5, commit 63f7f0d) : 2 dates de la carte grise obligatoires, note NB (véhicule de moins de 5 ans : 2e copie de la carte grise ; date « 1re mise en circulation + 5 ans » saisie par le chauffeur), enregistrement par saveRegistrationDates (sans toucher à driverService.ts) — ⚠️ non testé dans l'application ; ✅ (session 2.21) reprise de l'inscription : l'étape 1 préremplit et met à jour la fiche existante ; « Déconnexion » à l'étape 1 et « Retour » aux étapes 2 et 3 — ⚠️ non testés ; constats ouverts : capacité laissée vide (0 envoyé, contrainte > 0), plaque saisie deux fois
PendingVerificationScreen [reçoit driverId] → souscrit realtime driver-verification-{driverId} → si is_verified === true → Platform.OS === 'web' ? window.alert(...) + navigation.replace('DriverHome') : Alert.alert(...) ✅ RÉSOLU 42
   ⚠️ Chemin natif non testé
   ⚠️ Bouton "Recharger mon wallet" SUPPRIMÉ — session 2.13 (RÉSOLU 40)
   ⚠️ navigation.replace('DriverHome') cible toujours un écran absent du stack DriverPendingStack — bug distinct, non traité (voir Section 16) — ⚠️ FUSIONNÉ (17/10/2026) avec le constat « écran d'attente du chauffeur : lecture des statuts à l'ouverture et route de sortie après la validation complète » (compte rendu du 17/10/2026, C.3) — toujours ouvert
   ✅ NOUVEAU (volet 4b-5) — bouton « Mettre à jour mes documents » sur l'écran d'attente (accès aux documents pendant l'attente, impasse levée) ; ✅ (session 2.21) déconnexion depuis l'écran « Vérification en cours » — ⚠️ non testée
DriverHomeScreen → attend driverId + vehicleCategory obligatoires → affiche solde wallet (table wallet sans 's') → carte Wallet → WalletDashboard { driverId } → bouton Mes documents → DocumentStatus → ✅ NotificationBell montée — session 2.14 → NotificationBell → NotificationCenterScreen ⚠️ Aucun bouton "← Retour" — Anomalie #1 — ✅ CORRIGÉE session 2.21 (BackButton, RÉSOLU 81)
   ✅ (session 2.14 quinquies) — abonnement subscribeToMissionUpdates dès réception d'une nouvelle mission pending (Volet 1) : fermeture automatique du modal de proposition si le statut de la mission change avant acceptation par ce chauffeur ; désabonnement systématique à chaque point de sortie
   ⚠️ PRÉCISION IMPORTANTE (session 2.14 sexies) — RÔLE DU VOLET 1 REQUALIFIÉ : ce mécanisme reste actif, mais avec le mécanisme de négociation à 2 tours désormais en place, une mission reste pending pendant toute la durée de la négociation. Le rôle du Volet 1 se restreint donc à la fermeture du modal en cas d'annulation/expiration de la mission — il ne couvre plus un scénario de "changement de chauffeur retenu" au sens où ce scénario n'existe plus de la même façon durant la phase de négociation (plusieurs chauffeurs peuvent avoir une offre active simultanément). Voir Section 2 et Section 6 (bloc session 2.14 sexies, § Partie 1) pour le détail complet.
   ✅ NOUVEAU (session 2.14 quinquies bis) — filtrage géospatial réel branché : dans le callback onNewMission, appel direct à la RPC find_nearby_drivers (Option 3) avant setPendingMission, catégorie VUL, rayon 60 km, comportement fail-open en cas d'échec de la vérification (voir RÉSOLU 51). Test d'exécution en conditions réelles (GPS) toujours en attente, Phase 4.x.
   ✅ NOUVEAU (session 2.14 sexies) — le bouton "✅ Accepter" de NewMissionModal.tsx, qui appelait directement acceptMission() (mécanisme "premier arrivé, premier servi"), est remplacé par un champ de saisie de prix + bouton "💰 Proposer ce prix" (appelant createMissionOffer()). Countdown 30s et bouton "❌ Refuser" inchangés. → navigation vers MissionOfferScreen (via DriverMissionOfferScreen wrapper) pour le suivi de la négociation (offre, contre-offre éventuelle, acceptation, ou retrait via rejectOfferAcceptance) → à la double acceptation, navigation vers MissionActiveScreen (route désormais déclarée, RÉSOLU 54).
   ✅ ACCÈS RÉTABLI (depuis session 2.14 sexies) pour le numéro de test partagé — nouveau profil DRIVER créé via un nouvel onboarding complet (a53521ca-...), distinct de tous les profils antérieurs.
   ✅ NOUVEAU (session 2.14 septies) — correction du câblage : DriverHomeScreen.tsx fournit enfin la prop obligatoire onOfferCreated à NewMissionModal (navigation vers MissionOffer { missionId, driverId }) — voir RÉSOLU 55
   ✅ NOUVEAU (session 2.16) — bouton « 🚪 Se déconnecter » dans l'en-tête, après NotificationBell, avec confirmation → handleSignOut() → SIGNED_OUT → AuthStack ; remplacé par le composant commun LogoutButton (session 2.21), message aligné sur dialogs.ts (session 2.28)
   ⚠️ Interrupteur « En service » : contrôlé en base par le trigger control_driver_availability (refus si solde insuffisant, document expiré ou statut non validé — RÉSOLU 69) — non testé dans l'application (Phase 3.5, GPS) ; chauffeur de test en N2 Moyen, ne voit que les missions N2 Moyen
MissionActiveScreen → ✅ NOUVEAU (session 2.14 septies) — bouton conditionnel vers VoiceChat (via DriverVoiceChatScreen, résolution asynchrone du profileId par getDriverProfileId) quand la mission est accepted/in_progress et à 24 h ou moins de scheduled_pickup_time ; fermeture du canal (navigation.goBack()) sur annulation
   ⚠️ Depuis la session 2.23 : l'annonce d'ouverture de la messagerie et le prélèvement anticipé de la commission (fusionnés dans cet écran en session 2.17) sont effectués par le serveur ; les déclenchements ont été retirés de l'écran
   ✅ NOUVEAU (session 2.17) — bouton conditionnel de demande de remboursement (requestRefund) sur mission annulée après prélèvement — ⚠️ aucun test réel documenté
   ✅ (session 2.19) — confirmations « terminer la mission » et « annuler la mission » fonctionnelles sur le web (dialogs.ts) — ⚠️ non testées en réel (première mission réelle)
WalletDashboardScreen → WalletTopupScreen { driverId } → ✅ NOUVEAU (session 2.17) — sélecteur de mode de paiement (3 options), justificatif exigé si mode ≠ cash_agent (bucket payment-proofs), demande pending → validation admin
DocumentStatusScreen → ✅ NOUVEAU (volet 4b-5) — bouton « Remplacer » quel que soit le statut, avec nouvelle date d'expiration (DateOnlyField) ; bloc « Mon véhicule » et bouton « Changer de véhicule » (remet la carte grise en attente, chauffeur indisponible jusqu'à validation — RÉSOLU 70/71)
AccountSuspendedScreen → ✅ NOUVEAU (session 2.21) — affiché à un compte suspendu (écran blanc auparavant)
TransactionHistoryScreen → ✅ Écoute Realtime branchée — session 2.14 (INSERT uniquement) — ✅ totaux calculés sur l'effet réel depuis la session 2.22 (RÉSOLU 82)

⚠️ is_verified = GENERATED ALWAYS AS — devient true quand driver_license_verified, vehicle_registration_verified, insurance_verified, technical_inspection_verified = 'verified'

# CHAÎNE DE NAVIGATION ADMIN

AdminDashboardScreen → Documents en attente → DocumentReviewScreen ✅ → Toutes les missions → AdminMissionsScreen ✅ → Gestion utilisateurs → AdminUsersScreen ✅ → Wallets & Transactions → WalletManagementScreen ✅ → ✅ NotificationBell montée — session 2.14 → NotificationBell → NotificationCenterScreen ⚠️ Anomalie #1 — ✅ CORRIGÉE session 2.21
   ✅ NOUVEAU (session 2.17) — Demandes financières → PendingTransactionsScreen ✅ → Rapprochement bancaire → BankReconciliationScreen ✅ (badges de comptage via getAdminStats(), réagissant en temps réel aux données)
   ✅ NOUVEAU (session 2.16) — bouton « Se déconnecter » (confirmation window.confirm sur le web) — testé ✅ ; composant LogoutButton depuis la session 2.21

DocumentReviewScreen → Valider/Rejeter documents driver → Notification driver via insertNotification() → Driver fully verified → DriverHomeScreen (realtime)
   ⚠️ Bug d'affichage session 2.12 : modal ne se rafraîchit pas visuellement après validation du 4e/dernier document — non traité faute de temps, reporté à une session ultérieure à assigner — ✅ CORRIGÉ volet 4b-5 (commit 592d1a5, RÉSOLU 72)
   ✅ NOUVEAU (volet 4b-5) — dates de la carte grise, indication « visite technique exigée à partir du … », consigne de vérification de la plaque sur la carte grise, l'assurance et la visite technique (D6 : ne pas valider la carte grise tant que les deux autres documents du nouveau véhicule ne sont pas fournis)
   ⚠️ Vérification des documents avec un message : non testée en réel (partie D du compte rendu du 17/10/2026)

WalletManagementScreen → Liste drivers vérifiés avec solde → Recharger wallet → adminTopupDriverWallet() → Solde mis à jour en temps réel ✅
   ⚠️ Ne gère pas encore les demandes de recharge chauffeur en statut pending (voir Section 3) — écran de traitement dédié prévu session 2.17
   ✅ RÉSOLU session 2.17 : écran dédié PendingTransactionsScreen (ci-dessous)

PendingTransactionsScreen (✅ NOUVEAU, session 2.17) → liste des demandes pending (mode de paiement, lien vers le justificatif via Linking.openURL()) → Valider / Rejeter avec confirmation → validatePendingTransaction() (réservation atomique depuis le volet 3, RÉSOLU 66) / rejectPendingTransaction() → notifyTransactionValidated / notifyTransactionRejected — ⚠️ rejet non testé par un clic réel ; double clic réel sur « Valider » non testé

BankReconciliationScreen (✅ NOUVEAU, session 2.17) → transactions completed, mode ≠ cash_agent, non encore rapprochées (getUnreconciledTransactions) → markBankReconciled() → notifyTransactionBankConfirmed — vérification a posteriori, purement informative

AdminMissionsScreen → Liste toutes missions avec 7 filtres (dont expired, ajouté session 2.14 quinquies, incident de duplication détecté et corrigé — voir RÉSOLU 50) → Enum : pending / accepted / in_progress / completed / cancelled_client / cancelled_driver / expired
   ✅ Reconfirmé fonctionnel sans régression sessions 2.14 quinquies bis et 2.14 sexies

AdminUsersScreen → Liste drivers avec statut actif/suspendu → Suspendre/Activer via toggleUserActive() ⚠️ sans distinction Platform.OS — ✅ aligné sur dialogs.ts session 2.28 (suspension d'un chauffeur — exception accordée sur ce fichier protégé : deux lignes et un import)

# CHAÎNE DE NAVIGATION CLIENT

CreateMissionScreen → ✅ NotificationBell montée — session 2.14 → NotificationBell → NotificationCenterScreen ⚠️ Anomalie #1 — ✅ CORRIGÉE session 2.21
   ✅ NOUVEAU (session 2.16) — bouton « Se déconnecter » (commit 61f5a54), puis LogoutButton (2.21), message aligné sur dialogs.ts (2.28) — ⚠️ test CLIENT de la déconnexion non documenté
   ✅ (session 2.14 quater) — champ scheduled_pickup_time désormais OBLIGATOIRE (composant DateTimeField.tsx), bouton de soumission désactivé tant qu'une date/heure valide n'est pas sélectionnée, date passée rejetée, aucun délai minimum requis
   ✅ RECONFIRMÉ SANS RÉGRESSION (session 2.14 sexies) — fonctionnel avec le nouveau typage élargi de ClientHome ({ clientProfileId?: string })
   ⚠️ Le numéro de test partagé occupe actuellement le rôle DRIVER (depuis session 2.14 sexies) et non plus CLIENT — aucune mission n'a été insérée en base à ce jour, d'après l'ensemble des documents reçus pour la présente actualisation — ⚠️ DÉPASSÉ (actualisation du 17/10/2026) : compte CLIENT dédié +212600000002 depuis le 03/10/2026 ; une mission de test N2 a été créée en base pour le test réel du 14/10/2026, puis supprimée (ménage final : 0 mission, 0 offre) ; création de mission depuis l'application (GPS) : Phase 3.5

MissionOfferScreen (nouveau, session 2.14 sexies, accessible via ClientMissionOfferScreen wrapper) → écran partagé client/chauffeur (voir Section 6, bloc session 2.14 sexies) → suivi du processus de négociation en 2 tours : réception des offres, envoi d'une contre-offre collective unique (submitClientCounterOffer), acceptation finale ou retrait (rejectOfferAcceptance) → à la double acceptation, navigation vers MissionActiveScreen/MissionTrackingScreen (routes réparées, RÉSOLU 53)
   ⚠️ Test de bout en bout non réalisé (nécessite CLIENT + DRIVER simultanés) — voir Section 15/16/17 — ✅ partiellement levé le 14/10/2026 (voir ci-dessous)
   ✅ NOUVEAU (étape 3, choix du chauffeur) — informations du chauffeur affichées au client pour chaque offre : catégorie du véhicule, capacité, note moyenne, nombre de missions (vue client_offer_drivers, getClientOfferDrivers) ; jamais nom, téléphone, plaque, position, documents — ⚠️ affichage réel non testé (Phase 3.5)
   ✅ NOUVEAU (volet 5, E-bis/E-ter) — offres diffusées en direct et chargées à l'ouverture de l'écran ; notifications de négociation déposées par la base — test réel du 14/10/2026 conforme (offre, acceptation, refus, retrait, avec un chauffeur) ; ⚠️ négociation avec plusieurs chauffeurs et « Offre non retenue » en concurrence non testées (Phase 3.5, GPS) ; retour de l'écran des offres (2.21) non testé
   ⚠️ Erreur 406 côté client en touchant une notification d'offre (recherche inutile d'une fiche chauffeur) — bavarde, sans conséquence

MissionTrackingScreen.tsx → ✅ (session 2.14 quinquies, Volet 2) — nouveau useEffect actif uniquement si status === 'pending' et scheduled_pickup_time renseigné : vérification locale toutes les 30 secondes (EXPIRATION_CHECK_INTERVAL_MS), appel de expireMission() en base uniquement si expiration détectée ; nouveau case 'expired' dans renderStatus() (message dédié + bouton de recréation de mission)
   ✅ (session 2.14 sexies) — type local RootStackParamList corrigé (CreateMission → ClientHome), navigation.replace corrigés avec clientProfileId (RÉSOLU 53)
   ⚠️ Non testable en conditions réelles à ce jour — table missions vide (0 ligne), d'après l'ensemble des documents reçus — mission de test créée en base le 14/10/2026 pour le test de négociation (volet 5), puis supprimée
   ✅ NOUVEAU (session 2.14 septies) — bouton conditionnel vers VoiceChat (ClientVoiceChatScreen, mission.client_id) à 24 h ou moins de scheduled_pickup_time, mission accepted/in_progress ; bandeau anti-partage permanent dans VoiceChatScreen ; fermeture sur annulation ; annonce d'ouverture faite par le serveur depuis la session 2.23 (déclenchement retiré de l'écran) — ⚠️ canal vocal de bout en bout non testé (Phase 4.4)

RatingScreen.tsx → ✅ (session 2.14 sexies) — type local corrigé, navigation.replace('ClientHome') désormais alimentés avec clientProfileId (RÉSOLU 53)

CreateParcelScreen (flux e-commerce) → ⚠️ Route 'CreateParcel' non déclarée dans frontend/src/navigation/, écran inaccessible depuis l'UI normale — correction assignée à la session 2.20 [session 2.20 reportée : le volet e-commerce sera examiné ultérieurement] ; reconfirmé hors périmètre en session 2.14 sexies (extension e-commerce du mécanisme de négociation également reportée à 2.20)
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
RÉSOLU 30 — Bucket voice-messages + RLS (session 2.8) — ⚠️ RLS reclassifiée priorité sécurité session 2.14 bis, DÉSORMAIS CORRIGÉE, voir RÉSOLU 43 (renvoi corrigé le 17/10/2026, la mention antérieure « RÉSOLU 46 » était erronée)
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

**RÉSOLU 55 — Prop obligatoire onOfferCreated jamais fournie à NewMissionModal par DriverHomeScreen.tsx (session 2.14 septies)**
Cause : DriverHomeScreen.tsx transmettait encore une prop onAccepted (résidu du mécanisme « premier arrivé, premier servi » remplacé en 2.14 sexies, commit 3d6717e), ignorée silencieusement par NewMissionModal.tsx, qui ne déclare que onOfferCreated. Après retrait de ce code mort, tsc a révélé une seconde anomalie, préexistante et masquée : la prop onOfferCreated, déclarée obligatoire, n'était jamais fournie — un clic sur « 💰 Proposer ce prix » depuis cet écran aurait provoqué un plantage à l'exécution (appel d'une fonction undefined), ce qui explique potentiellement que le parcours de négociation n'ait jamais pu être testé de bout en bout auparavant.
Correctif : retrait de onAccepted ; type local RootStackParamList de DriverHomeScreen.tsx élargi (MissionOffer: { missionId: string; driverId: string }, route existante du DriverStack) ; callback onOfferCreated ajouté (ferme le modal, arrête la surveillance, puis navigation.navigate('MissionOffer', { missionId, driverId }), missionId capturé avant la fermeture du modal).
Fichier : frontend/src/screens/driver/DriverHomeScreen.tsx
Commit : 4ee8257
Confirmé : tsc --noEmit (erreur onOfferCreated disparue, erreurs COLORS inchangées) ✅ (partiel) — non re-testé par un clic réel en session 2.14 septies, faute de mission diffusable ; voir aussi le test réel de négociation du 14/10/2026 (section « Tests de non-régression »).

**RÉSOLU 56 — Dépendance expo-av absente de package.json : échec du bundling web (session 2.14 septies)**
Cause : au premier lancement après le montage du canal vocal, Unable to resolve "expo-av" from "src/services/audioService.ts". Preuve par l'historique git : expo-av ajouté par le commit 037a2be (feat(P6): notifications push, chat audio Darija, Edge Functions), puis retiré accidentellement par le commit ec7d061 (fix(security): enable RLS on push_tokens table), qui faisait aussi passer expo de ^55.0.9 à ~50.0.0 et régénérait package-lock.json (13 037 lignes modifiées) — audioService.ts a continué d'importer expo-av dans tout l'historique postérieur.
Correctif : précautions préalables (git status propre, backups package.json et package-lock.json, baseline tsc) ; npx expo install expo-av → version 13.10.6 (compatible SDK 50, cohérente avec la version historique ^13.10.0) ; diff minimal (11 lignes ajoutées, 0 supprimée).
Fichiers : frontend/package.json, frontend/package-lock.json
Commit : 8d8176b
Confirmé : deux lancements consécutifs « Web Bundled » sans erreur expo-av, écran DRIVER fonctionnel ✅ — ⚠️ module en fin de vie (API dépréciées au profit d'expo-audio/expo-video, retrait annoncé avec SDK 55) : dette technique, migration à prévoir avant toute montée de SDK.

**RÉSOLU 57 — Faux succès de topupWallet() et refundWallet() en cas d'échec d'enregistrement de la transaction (session 2.17)**
Cause : défaut de gestion d'erreur silencieuse découvert sur les deux fonctions (pas seulement celle initialement suspectée) — un échec d'enregistrement de la transaction après mise à jour du solde renvoyait un faux succès (robustesse signalée dès la session 2.14).
Correctif : retour d'une erreur explicite ; adminTopupDriverWallet() hérite automatiquement de la correction (simple délégation). Décision du porteur : cette erreur technique ne remonte jamais à l'écran chauffeur, seul l'écran admin la capte (le chauffeur n'a aucune action possible et son solde a déjà changé).
Fichier : frontend/src/services/walletService.ts
Commit : 6aeded2
Confirmé : correction réalisée comme prérequis technique de la session 2.17 — aucun test dédié documenté.

**RÉSOLU 58 — Rollback placé dans supabase/migrations/ avec un timestamp identique : échec du déploiement (session 2.17)**
Cause : le fichier de rollback de la migration 20260504000024, placé dans supabase/migrations/ avec le même timestamp que la migration principale, a été traité comme une seconde migration par supabase db push — erreur duplicate key value violates unique constraint "schema_migrations_pkey" (diagnostic par les logs CI/CD ; seul le dossier migrations/ est scanné par Supabase).
Correctif : rollback déplacé dans supabase/rollbacks/ (dossier existant depuis la session 2.12, jamais scanné par le pipeline) ; rollbacks suivants placés directement au bon endroit (migration 026 déployée du premier coup).
Migration : supabase/migrations/20260504000024_anticipated_commission_charge.sql
Commits : 2320671 (échec initial), bfb34d3 (correction)
Confirmé : déploiement réussi après correction ✅

**RÉSOLU 59 — Alerte de solde bas jamais envoyée : notifyWalletLowBalance() jamais appelée (session 2.17)**
Cause : seule pièce conçue pour alerter un chauffeur d'un solde bas depuis le commit fondateur du wallet (4dda161), jamais appelée nulle part ; son mode d'écriture (insertion directe en base, sans insertNotification()) n'aurait de toute façon déclenché aucun push réel — défaut fragilisant l'argument de sécurité validé en Partie 1 (marge de 100 DH suffisante parce que le chauffeur serait informé).
Correctif : checkAndEnforceWalletBlock() corrigée (détection de transition de is_available avant/après le blocage, notification une seule fois — décision du porteur) ; nouvelle fonction notifyDriverLowBalance() (message actionnable, montant minimum et conséquence explicites) sur le vrai patron notify* ; ajout de notifyTransactionValidated(), notifyTransactionRejected(), notifyTransactionBankConfirmed(), branchées dans validatePendingTransaction()/rejectPendingTransaction().
Fichiers : services wallet et notifications (frontend/src/services/walletService.ts, frontend/src/services/notificationTemplates.ts — répartition exacte par fichier non détaillée dans le compte rendu)
Commit : 67e21fe
Confirmé : par lecture de code uniquement ⚠️ — jamais déclenchée réellement (passage du solde sous 100 DH non provoqué).

**RÉSOLU 60 — Redirections des notifications sans effet ou erronées au toucher (session 2.17)**
Cause : notifyMissionCancelled() pointait toujours vers screen: 'ClientHomeStack', quel que soit le destinataire (un chauffeur était dirigé vers un écran client). Vérification exhaustive : 10 des 18 valeurs de screen utilisées dans notificationTemplates.ts ne correspondaient à aucune clé du screenMap de pushNotificationService.ts (aucune erreur, aucune navigation au toucher) — dont 4 issues des notifications de la session 2.17 (WalletDashboard, sans le suffixe attendu), 1 de la session 2.14 septies (VoiceChat) et 3 MissionOfferScreen (session 2.14 sexies). Le compte rendu 2.17 rattache cette anomalie à une découverte fortuite de la session 2.14 septies (voir liste de suivi anomalie #28).
Correctif : destination de notifyMissionCancelled() calculée selon cancelledBy ; screenMap étendu (VoiceChat, WalletDashboard, DriverHomeScreen, MissionOfferScreen — résolution asynchrone du driverId manquant, handleNotificationTap() devenue async après vérification des deux points d'appel) ; pertinence des 8 destinations déjà fonctionnelles revérifiée (7 cohérentes ; notifyDriverOfferNotSelected → accueil jugée raisonnable). ⚠️ Le sort individuel des 10 destinations n'est pas entièrement détaillé par le compte rendu (8 attribuées sur 10) ; correction héritée « 7 destinations » signalée par le compte rendu du 17/10/2026 sans contenu disponible (liste de suivi anomalie #27).
Fichiers : frontend/src/services/notificationTemplates.ts, frontend/src/services/pushNotificationService.ts
Commit : e13dba4
Confirmé : lecture de code et tsc --noEmit uniquement ⚠️ — jamais testé par un clic réel sur une notification reçue.

**RÉSOLU 61 — Validation d'une demande de recharge sans effet : table transactions sans policy DELETE ni UPDATE (session 2.17)**
Cause : au premier test réel de validation (transaction de 1 000 DH bloquée depuis le 09/09/2026), succès apparent mais demande toujours listée. Diagnostic par lecture directe en base : même ligne d'origine ; crédit réellement effectué (solde 1 000 → 2 000 DH) ; aucune policy DELETE sur transactions — la suppression échouait silencieusement (0 ligne, aucune erreur remontée par le SDK) ; après remplacement par un update(), même échec : aucune policy UPDATE non plus (la table ne disposait que de SELECT et INSERT). Chaque tentative ayant crédité le compte, le solde de test est passé à 4 000 DH (donnée conservée par décision du porteur).
Correctif : validatePendingTransaction() réécrite (update() du statut vers completed avec description explicite, crédit avant mise à jour du statut) ; nouvelle policy transactions_update_admin (get_my_role() = 'admin'), couvrant validatePendingTransaction(), rejectPendingTransaction() et markBankReconciled().
Fichier : frontend/src/services/walletService.ts
Migration : supabase/migrations/20260504000027_add_transactions_update_admin_policy.sql
Commits : 0e780b5 (première correction, insuffisante), f370da5 (policy)
Confirmé : test rejoué avec succès à chaque étape (interface, console, vérification SQL directe : la transaction disparaît de la liste, statut completed en base) ✅ — incident CI annexe « rate limit exceeded », résolu par ré-essai.

**RÉSOLU 62 — Auto-élévation au rôle admin possible (étape 2)**
Cause : faille du rôle admin — un utilisateur pouvait s'attribuer le rôle admin et modifier is_active sur son propre profil (détail de l'investigation dans les documents de la conversation du 03/10 → 10/10/2026, non repris ici).
Correctif : trigger protect_profile_privileged_fields sur profiles, qui empêche l'auto-élévation au rôle admin et la modification de is_active.
Migration : supabase/migrations/20260504000028_protect_profile_role_and_is_active.sql
Commit : 24e079a (03/10/2026)
Confirmé : migration vérifiée en base ✅ (compte rendu du 17/10/2026, F.1)

**RÉSOLU 63 — Colonnes financières des missions librement modifiables, montants négatifs possibles, prélèvement sans contrôle d'identité (étape 3, volet 1)**
Cause : colonnes financières librement modifiables, aucune contrainte contre les montants négatifs, charge_commission_anticipated sans contrôle d'identité.
Correctif : 029 — contraintes anti-négatif, sécurisation de la fonction (appelant = chauffeur de la mission, statut accepted ou in_progress, chemin de recherche), suppression d'une règle en double ; 030 — retrait du droit UPDATE sur toute la table missions pour anon et authenticated, ré-octroi des 29 colonnes légitimes (tout sauf commission_amount et commission_charged_at) ; 031 — EXECUTE retiré à PUBLIC, accordé à authenticated et service_role.
Migrations : 20260504000029_secure_mission_financial_fields.sql, 20260504000030_lock_commission_columns_properly.sql, 20260504000031_restrict_charge_commission_execute.sql
Commits : a0b4c19, 09a40ac, 18fd457 (05/10/2026)
Confirmé : migrations vérifiées en base ✅ — ⚠️ le contrôle d'identité de 029 s'est révélé inopérant (fonction exécutée avec les droits du propriétaire) : corrigé par la migration 054, voir RÉSOLU 83.

**RÉSOLU 64 — Transitions de statut des missions non contrôlées en base ; driver_id et negotiated_price modifiables ; faille cancelMission/userId (étape 3, volet transitions)**
Cause : aucune carte des transitions appliquée en base ; driver_id et negotiated_price modifiables ; aucune vérification d'autorisation dans cancelMission() (point ouvert depuis la session 2.14).
Correctif : verrouillage de driver_id et negotiated_price (retrait UPDATE sur la table, ré-octroi de 27 colonnes) ; trigger control_mission_status_transition (BEFORE UPDATE missions) appliquant la carte des transitions légitimes, exigeant une offre acceptée pour pending → accepted et vérifiant l'identité ; admin et système libres ; rollback fin qui préserve le volet 1.
Migration : supabase/migrations/20260504000032_control_mission_transitions.sql
Commit : 4b473d2 (05/10/2026)
Confirmé : migration vérifiée en base ✅ — ⚠️ effet de bord ultérieur sur sync_mission_on_offer_accepted après le lot C du volet 5, corrigé au lot C5 (RÉSOLU 76).

**RÉSOLU 65 — Lecture de tous les chauffeurs par tout utilisateur connecté, policy drivers_select_available (étape 3, choix du chauffeur)**
Cause : règle drivers_select_available — tout utilisateur connecté lisait tous les chauffeurs (cas authenticated laissé ouvert depuis la session 2.14 quinquies bis, voir RÉSOLU 52) ; par ailleurs, le client ne voyait que le prix des offres.
Correctif : suppression de la règle drivers_select_available et d'un doublon ; informations utiles au client exposées par la vue client_offer_drivers (security_invoker, filtrée sur le client connecté) : catégorie du véhicule, capacité, note moyenne, nombre de missions — jamais nom, téléphone, plaque, position, documents (décision du porteur) ; getClientOfferDrivers dans missionService.ts, affichage compact dans MissionOfferScreen.tsx.
Migrations : supabase/migrations/20260504000033_create_client_offer_drivers_view.sql, supabase/migrations/20260504000034_close_drivers_select_available.sql
Commits : d3b5f40 (033), ba8e61f (application), eed9a5f (034)
Confirmé : migrations vérifiées en base ✅ — ⚠️ affichage réel des informations du chauffeur au client non testé (Phase 3.5, GPS).

**RÉSOLU 66 — Double crédit possible à la validation d'une demande de recharge (étape 3, volet 3)**
Cause : validatePendingTransaction vérifiait puis créditait en deux temps (double clic = double crédit, incident réel en session 2.17).
Correctif : réservation atomique de la demande (UPDATE … WHERE status = 'pending') avant le crédit, puis crédit, puis remise en attente si le crédit échoue.
Fichier : frontend/src/services/walletService.ts
Commit : 65245b1 (06/10/2026)
Confirmé : ⚠️ double clic réel non testé (dès accord du porteur) — option 2 (crédit atomique en base) reportée à un volet « robustesse du portefeuille ».

**RÉSOLU 67 — Messages vocaux : auteur jamais vérifié par les règles du stockage voice-messages (étape 3, volet 4a)**
Cause : les 4 règles du stockage voice-messages vérifiaient la mission, jamais l'auteur (convention des fichiers missions/{missionId}/{profileId}_{horodatage}.ext).
Correctif : suppression de la règle de modification (un message vocal ne se modifie jamais) ; suppression permise seulement à l'auteur, mission terminée.
Migration : supabase/migrations/20260504000035_restrict_voice_messages_delete_update.sql
Commit : c48ab60 (06/10/2026)
Confirmé : migration vérifiée en base ✅ — canal vocal de bout en bout non testé (Phase 4.4).

**RÉSOLU 68 — Expiration des documents du chauffeur jamais surveillée après validation (étape 3, volets 4b-1 et 4b-2)**
Cause : avant le volet, rien ne surveillait l'expiration après validation ; date d'expiration de la carte grise oubliée jusque-là.
Correctif : 036 — colonnes vehicle_registration_expiry et vehicle_first_service_date ; 037 — fonction block_drivers_with_expired_documents() et tâche block-expired-documents (7 h) : passe indisponible tout chauffeur ayant un document expiré (elle ne fait que bloquer) ; 038 — droits de la fonction (réservée au système).
Migrations : supabase/migrations/20260504000036_add_vehicle_registration_expiry_and_service_date.sql, supabase/migrations/20260504000037_block_drivers_expired_documents_cron.sql, supabase/migrations/20260504000038_restrict_block_function_execute.sql
Commits : c0ac59b, f23495a, 069190b (07/10/2026)
Confirmé : migrations vérifiées en base ✅ — ⚠️ exécution manuelle de block_drivers_with_expired_documents() non testée (faisable sans GPS, dès accord du porteur).

**RÉSOLU 69 — Disponibilité du chauffeur sans contrôle, auto-validation des documents possible ; gardiens défectueux (étape 3, volets 4b-3, 4b-4 et 4b-5)**
Cause : l'interrupteur de l'accueil chauffeur écrivait is_available sans contrôle ; un chauffeur pouvait s'auto-valider ses documents (faille réelle). Les deux gardiens créés étaient défectueux (test du 10/10/2026) : celui de 4b-4 refusait toute mise à jour par un chauffeur (contrôle de is_verified, colonne calculée qui vaut NULL dans un trigger BEFORE) ; celui de 4b-3 laissait tout passer (current_user vaut le propriétaire dans une fonction exécutée avec ses droits). Les droits de driver_has_expired_documents ont dû être repris deux fois (040 insuffisant, 041 : PUBLIC subsistait).
Correctif : 039 — fonction partagée driver_has_expired_documents(uuid) et trigger control_driver_availability ; 040 et 041 — droits ; 042 — trigger protect_driver_verification_fields (un chauffeur ne peut que remettre un statut en attente) ; 043 — réparation : protect_driver_verification_fields ne contrôle plus is_verified, un statut ne peut passer qu'à pending, toute modification d'une date remet le document en attente, un statut non validé rend le chauffeur indisponible ; control_driver_availability identifie l'appelant par auth.uid() (NULL = système, CRON ou éditeur SQL, libre ; admin libre), refuse de redevenir disponible si une date change dans la même opération, exige 4 statuts validés, aucun document expiré et un solde suffisant. Ordre des triggers BEFORE UPDATE (alphabétique) : control_driver_availability, protect_driver_verification_fields, update_drivers_updated_at.
Migrations : supabase/migrations/20260504000039_driver_availability_control.sql, 20260504000040_restrict_driver_has_expired_documents_execute.sql, 20260504000041_restrict_driver_has_expired_documents_authenticated.sql, 20260504000042_protect_driver_verification_fields.sql, 20260504000043_fix_driver_guards_and_document_dates.sql
Commits : 168ca8c, 528eb56, ce37519, 5f1c0d0, e8d01a7 (08/10 → 11/10/2026)
Confirmé : 15 scénarios locaux et contrôles réels avant et après ✅ — ⚠️ interrupteur « En service » non testé dans l'application (Phase 3.5, GPS) ; gardien prouvé en SQL réel.

**RÉSOLU 70 — Chauffeur bloqué pour document expiré restant bloqué après revalidation : date d'expiration jamais remplacée (étape 3, volet 4b-5)**
Cause : défaut bloquant — au remplacement d'un document, la date d'expiration en base restait périmée ; aucun renouvellement anticipé possible.
Correctif : composant DateOnlyField.tsx (date seule, sans décalage de fuseau ; champ date sur le web, sélecteur natif sur téléphone) ; saveDocumentReplacement (URL, date, statut en une seule écriture, contrôle d'une ligne modifiée) ; bouton « Remplacer » quel que soit le statut (décision D1 : tout document remplacé repasse en attente, chauffeur indisponible jusqu'à la validation) ; écran d'inscription : 2 dates de la carte grise obligatoires, note NB, saveRegistrationDates (sans toucher à driverService.ts) ; base : migration 043 (voir RÉSOLU 69).
Fichiers : frontend/src/components/DateOnlyField.tsx et écrans/services associés (détail par fichier non repris dans les sources)
Commits : ebeb722, 63f7f0d (12/10/2026) ; e8d01a7 (043)
Confirmé : remplacement de l'assurance avec date testé en réel (T4-T5) ✅ — ⚠️ écran d'inscription non testé dans l'application (prochaine inscription de test).

**RÉSOLU 71 — Changement de catégorie ou de véhicule par le chauffeur sans contrôle (étape 3, volet 4b-5)**
Cause : un chauffeur pouvait changer sa catégorie (donc les missions qu'il voit) sans contrôle.
Correctif : toute modification par le chauffeur de la catégorie, marque, modèle, plaque, capacité ou numéro d'immatriculation remet la carte grise en attente (chauffeur indisponible) ; refus de redevenir disponible dans la même opération ; application : bloc « Mon véhicule » et bouton « Changer de véhicule » dans DocumentStatusScreen.tsx, saveVehicleChange (plaque écrite dans license_plate et vehicle_registration_number), consigne de vérification sur la fiche admin, accès aux documents depuis l'écran d'attente (impasse levée).
Migration : supabase/migrations/20260504000044_vehicle_change_requires_validation.sql
Commits : ff7897f, 01d689f (12/10/2026)
Confirmé : changement de véhicule complet testé en réel, de la saisie à la validation des 3 documents (T11-T16d) ✅

**RÉSOLU 72 — Fiche admin non rafraîchie après validation d'un document (étape 3, volet 4b-5)**
Cause : bug de rafraîchissement de la fiche après validation, connu depuis la session 2.12 (DocumentReviewScreen.tsx, modal non rafraîchi après validation du dernier document).
Correctif : corrigé avec l'ajout, sur l'écran admin de validation, des dates de la carte grise et de l'indication « visite technique exigée à partir du … ».
Fichier : frontend/src/screens/admin/DocumentReviewScreen.tsx (écran admin de validation)
Commit : 592d1a5 (12/10/2026)
Confirmé : cycle complet de la carte grise côté admin testé en réel (T6-T10) ✅

**RÉSOLU 73 — Fiche chauffeur : statistiques modifiables par le chauffeur, écriture anon sur drivers (étape 3, volet 5, lot A)**
Cause : failles résiduelles sur la fiche chauffeur laissées par le volet 4b-5.
Correctif : note moyenne et nombres de missions et d'avis non modifiables par le chauffeur ; fiche créée par un utilisateur normalisée (statuts en attente, indisponible, statistiques à 0) ; anon perd l'écriture sur drivers ; update_driver_rating exécutée avec les droits du propriétaire.
Migration : supabase/migrations/20260504000045_driver_row_rights_lot_a.sql
Commit : d6bae44 (13/10/2026)
Confirmé : migration vérifiée en base ✅

**RÉSOLU 74 — Droits des fonctions : chemin de recherche non fixé, droit PUBLIC subsistant (étape 3, volet 5, lot B)**
Cause : chemin de recherche non fixé pour find_nearby_drivers et get_my_role ; droit PUBLIC subsistant sur driver_has_expired_documents ; droits par défaut du schéma public accordés à toute fonction créée.
Correctif : chemin de recherche fixé ; driver_has_expired_documents retirée à PUBLIC, anon, authenticated ; adoption de la règle B4(b) (droits fixés explicitement dans chaque migration, inventaire relancé après) — pas de changement global des droits par défaut (risque de casser get_my_role et les fonctions légitimes).
Migration : supabase/migrations/20260504000046_function_rights_lot_b.sql
Commit : 9acac5a (13/10/2026)
Confirmé : migration vérifiée en base ✅

**RÉSOLU 75 — Contrat de mission modifiable, notes et avis non protégés ; WITH CHECK absent sur UPDATE missions (étape 3, volet 5, lot C)**
Cause : « contrat » de la mission (client, adresses, prix, catégorie, dates, commission) modifiable ; notes et avis non réservés à la bonne partie ; absence de WITH CHECK sur la policy UPDATE de missions (découverte en session 2.14 sexies, reportée à un audit de sécurité).
Correctif : contrat verrouillé par retraits de droits par colonne ; trigger protect_mission_participant_fields (notes et avis réservés à la bonne partie, mission terminée, une seule fois) ; anciennes règles redondantes supprimées — couvre le « WITH CHECK absent sur UPDATE missions ».
Migration : supabase/migrations/20260504000047_missions_rights_lot_c.sql
Commit : 67cc79a (13/10/2026)
Confirmé : migration vérifiée en base ✅

**RÉSOLU 76 — Double acceptation ne pouvant plus attribuer la mission ; offres non protégées (étape 3, volet 5, lot C5)**
Cause : sync_mission_on_offer_accepted s'exécutait avec l'identité de l'utilisateur — après le verrouillage des colonnes du lot C, la double acceptation ne pouvait plus attribuer la mission ; champs des offres non protégés.
Correctif : trigger protect_mission_offer_fields (création seulement sur mission en attente ; mission, chauffeur et dates figés ; accord du client réservé au client, accord du chauffeur au chauffeur) ; sync_mission_on_offer_accepted et process_commission_payment exécutées avec les droits du propriétaire ; ménage des droits sur mission_offers.
Migration : supabase/migrations/20260504000048_mission_offers_lot_c5.sql
Commit : 6434eba (13/10/2026)
Confirmé : migration vérifiée en base ✅ ; négociation testée en réel le 14/10/2026 ✅

**RÉSOLU 77 — Notifications et colis exposés ; fonctions serveur non authentifiées ; CORS de send-push-notification (étape 3, volet 5, lot D-bis)**
Cause : deux règles « tout est permis » sur les notifications ; lecture publique de tous les colis (noms, téléphones) ; fonctions serveur sans authentification ; send-push-notification bloquée par CORS sur le web (constaté depuis la session 2.14).
Correctif : can_notify_profile (vers soi-même, par l'admin, ou entre client et chauffeur d'une même mission ou offre) ; suppression de la lecture publique des colis, suivi par get_public_parcel_tracking(numéro) qui ne renvoie que le colis demandé, téléphone masqué ; register-push-token (profil de l'appelant seulement), send-push-notification (ne prend plus qu'un identifiant de notification, relit le reste en base, notification de moins de 10 minutes), send-tracking-sms (client du colis, un seul SMS par colis) ; CORS corrigé.
Migrations : supabase/migrations/20260504000049_notifications_parcels_lot_dbis.sql, supabase/migrations/20260504000050_tracking_sms_once.sql
Commits : 967a406, 2750835 (13/10/2026)
Confirmé : migrations vérifiées en base ✅ — ⚠️ sonnerie sur téléphone et SMS de suivi non testés en réel.

**RÉSOLU 78 — Anomalie COLORS : couleurs absentes du thème (étape 3, volet 5, lot E)**
Cause : l'objet COLORS (frontend/src/constants/theme.ts) ne définissait que 8 propriétés, alors que plusieurs écrans utilisaient text, textSecondary, surface, border (constat de la session 2.14 septies — 113 erreurs TypeScript COLORS selon le compte rendu du 17/10/2026).
Correctif : couleurs manquantes ajoutées au thème (147 → 34 erreurs TypeScript) ; dans le même lot, « Offre non retenue » déposée par la base chez chaque chauffeur évincé et client prévenu du retrait d'une offre.
Fichier : frontend/src/constants/theme.ts
Migration : supabase/migrations/20260504000051_offer_not_selected_notification.sql
Commit : b066dae (14/10/2026)
Confirmé : tsc --noEmit (147 → 34) ✅ ; test réel du 14/10/2026 ✅

**RÉSOLU 79 — Négociation impossible à faire aboutir dans l'application ; notifications de négociation envoyées depuis le téléphone de l'acteur (étape 3, volet 5, lots E-bis et E-ter)**
Cause : mission_offers absente de la diffusion en direct et offres non chargées à l'ouverture de l'écran (aucune négociation ne pouvait aboutir dans l'application) ; les notifications de la négociation partaient du téléphone de celui qui agit, et rien ne partait hors disponibilité (lecture conditionnée).
Correctif : mission_offers ajoutée à la diffusion en direct et chargement initial des offres ; trigger notify_mission_offer_events : les 7 notifications de la négociation sont déposées par la base chez l'autre partie.
Migrations : supabase/migrations/20260504000052_realtime_mission_offers.sql, supabase/migrations/20260504000053_offer_negotiation_notifications.sql
Commits : 74df2ff, 35d1cc8 (14/10/2026)
Confirmé : test réel du 14/10/2026 (mission de test N2, connexions successives client puis chauffeur) : offre, acceptation, refus, retrait et notifications conformes ✅ — ⚠️ négociation avec plusieurs chauffeurs non testée (Phase 3.5).

**RÉSOLU 80 — Messages et confirmations invisibles sur le web, Alert.alert (session 2.19)**
Cause : Alert.alert ne s'affiche pas sur le web (constaté depuis les sessions 2.8 et 2.13) ; correction générale reportée à la session 2.19 par la décision D9 du volet 4b-5.
Correctif : module commun utils/dialogs.ts (showMessage, confirmAction : fenêtres du navigateur sur le web, natives sur téléphone) ; 25 messages remplacés dans 11 écrans ; complété en session 2.28 (13 anciens messages alignés dans 11 écrans, commit e78b1a6).
Fichier : frontend/src/utils/dialogs.ts (+ 11 écrans)
Commit : 46d52ca (16/10/2026)
Confirmé : confirmations « terminer la mission » et « annuler la mission » fonctionnelles sur le web ✅ (partiel) — ⚠️ non testées sur une mission réelle ; chemin natif non testé ; 3 messages Alert.alert restent dans des écrans e-commerce et de suivi non raccordés.

**RÉSOLU 81 — Écran blanc pour un compte suspendu, bouton Retour absent, doublon de fiche à la reprise de l'inscription chauffeur (session 2.21)**
Cause : un compte suspendu voyait un écran blanc ; la barre de titre de navigation n'existe pas sur le web (piles sans en-tête) et plusieurs écrans n'avaient aucun bouton Retour (dont NotificationCenterScreen.tsx — Anomalie #1) ; la reprise de l'inscription chauffeur créait une seconde fiche (erreur de doublon).
Correctif : composants BackButton (retour, ou accueil du rôle s'il n'y a pas d'écran précédent) et LogoutButton ; écran AccountSuspendedScreen ; 12 écrans corrigés (dont le centre de notifications — précision de l'assistant général) ; l'étape 1 de l'inscription préremplit et met à jour la fiche existante.
Fichiers : 17 fichiers (frontend/src/components/BackButton.tsx, LogoutButton.tsx, frontend/src/screens/auth/AccountSuspendedScreen.tsx et écrans corrigés)
Commit : c090c27 (16/10/2026)
Confirmé : ⚠️ inscription d'un nouveau chauffeur (« Déconnexion » à l'étape 1, « Retour » aux étapes 2 et 3, reprise après l'étape 1), écran « Vérification en cours » et retour de l'écran des offres non testés en réel.

**RÉSOLU 82 — Totaux de l'historique des transactions erronés (session 2.22)**
Cause : défaut d'affichage des totaux de l'historique (voisin du volet 3).
Correctif : totaux calculés sur l'effet réel (solde après − solde avant) ; les lignes de trace « Demande validée » s'affichent « déjà créditée » ; montants non touchés.
Commit : b1701e7 (16/10/2026)
Confirmé : le solde de 4 500 DH du chauffeur de test est juste ✅

**RÉSOLU 83 — Contrôle d'identité du prélèvement anticipé inopérant : un client connecté pouvait déclencher un prélèvement (session 2.23)**
Cause : dans une fonction exécutée avec les droits du propriétaire, l'appelant est toujours vu comme le système — le contrôle d'identité de la migration 029 était inopérant.
Correctif : charge_commission_anticipated réservée au système (service_role) ; fonction process_missions_24h_window() et tâche process-missions-24h (toutes les 5 minutes) : prélèvement anticipé de la commission (solde insuffisant : nouvel essai, alerte unique au chauffeur et aux admins) et annonce unique de la messagerie ; déclenchements retirés de MissionActiveScreen et MissionTrackingScreen.
Migration : supabase/migrations/20260504000054_mission_24h_window_server.sql
Commit : 633d78d (16/10/2026)
Confirmé : migration vérifiée en base ✅ — ⚠️ prélèvement réel 24 h avant, cas « solde insuffisant » et filet de commission en fin de mission non testés (première mission réelle).

**RÉSOLU 84 — Table spatial_ref_sys modifiable par tous via l'API : PostGIS installé dans public (session 2.24)**
Cause : PostGIS installé dans le schéma public — spatial_ref_sys modifiable par tous via l'API (seule erreur critique du Security Advisor).
Correctif : PostGIS déplacé de public vers extensions ; colonnes, index, vue available_drivers (droits retirés à anon et authenticated) et fonctions recréés ; chemin de recherche incluant extensions ; répétition à blanc, annulée, sur la vraie base (seule exception accordée à l'interdiction des REVOKE/ALTER en éditeur SQL) ; ticket au support Supabase envoyé, puis clos le 17/10/2026.
Migration : supabase/migrations/20260504000055_move_postgis_to_extensions.sql
Commit : aa1f8d8 (16/10/2026)
Confirmé : migration vérifiée en base ✅ — recherche de chauffeurs proches non testée en réel (Phase 3.5, GPS).

**RÉSOLU 85 — Avertissements du Security Advisor : chemin de recherche non fixé, droits d'exécution sur des fonctions de déclenchement (session 2.25)**
Cause : avertissements du Security Advisor de Supabase.
Correctif : chemin de recherche fixé pour 9 fonctions ; droit d'exécution retiré sur 4 fonctions de déclenchement ; 8 avertissements acceptés et documentés (get_my_role — nécessaire aux règles d'accès, ne renvoie rien à un visiteur —, get_public_parcel_tracking, can_notify_profile, find_nearby_drivers, pg_net dans public, protection des mots de passe sans objet).
Migration : supabase/migrations/20260504000056_security_advisor_warnings.sql
Commit : 4424a39 (16/10/2026)
Confirmé : migration vérifiée en base ✅

**RÉSOLU 86 — Sonnerie déclenchée par le serveur en erreur 401 (session 2.26)**
Cause : après la mise en place du déclencheur notifications_push_dispatch (migration 057, commit 6a53264), la clé du coffre-fort et la variable d'environnement de send-push-notification avaient des formats différents — erreur 401.
Correctif : la fonction reconnaît le rôle service_role inscrit dans la clé (la passerelle ayant déjà vérifié la signature).
Fichier : supabase/functions/send-push-notification/index.ts
Commit : 6b1026b (17/10/2026)
Confirmé : ⚠️ sonnerie sur un vrai téléphone non testée (aucun téléphone enregistré, Phase 3.4).

**RÉSOLU 87 — Erreurs TypeScript TS1323, TS2352 et TS2322 (session 2.27)**
Cause : TS1323 sur les imports dynamiques (configuration --module du projet) et TS2352 sur getTransactionHistory() (jointure missions renvoyée sous forme de tableau), relevées en session 2.17 ; TS2322 sur onProfileCreated (déclaration de type incomplète dans ProfileSetupScreen.tsx), relevée en session 2.14 septies — toutes préexistantes, sans impact fonctionnel.
Correctif : réglage "module": "esnext" pour TS1323 ; déclaration de l'historique dans walletService.ts pour TS2352 ; une ligne de déclaration de ProfileSetupScreen.tsx pour TS2322 (exception accordée par le porteur sur ce fichier protégé) — erreurs TypeScript 34 → 19, les 19 restantes concernant parcelService.ts.
Fichiers : 5 fichiers, dont frontend/tsconfig.json, frontend/src/services/walletService.ts, frontend/src/screens/auth/ProfileSetupScreen.tsx
Commit : c903c2f (17/10/2026)
Confirmé : tsc --noEmit (34 → 19) ✅ — source : compte rendu du 17/10/2026 et précisions de l'assistant général.

⚠️ Note de numérotation : RÉSOLU 43 (RLS voice-messages) précède chronologiquement RÉSOLU 44-47 (session 2.14 quater), lesquelles précèdent RÉSOLU 48-50 (session 2.14 quinquies), lesquelles précèdent RÉSOLU 51-52 (session 2.14 quinquies bis), lesquelles précèdent RÉSOLU 53-54 (session 2.14 sexies) — suivant l'ordre chronologique réel des découvertes au sein de chaque session. Actualisation du 17/10/2026 (décision du porteur : une entrée par défaut corrigé) : RÉSOLU 55-56 (session 2.14 septies), 57-61 (session 2.17), 62 (étape 2), 63-79 (étape 3 sécurité : volet 1, transitions, choix du chauffeur, volets 3, 4a, 4b-1 à 4b-5, volet 5 — lots E-bis et E-ter regroupés en 79), 80-87 (sessions 2.19 à 2.27), dans l'ordre chronologique des corrections. Aucun RÉSOLU pour la session 2.16 (fonctionnalité, pas correction), ni pour les sessions 2.28 et 2.29 (alignement et ménage).

⚠️ Point non attribué à un RÉSOLU, par choix méthodologique explicite (voir arbitrage du porteur lors de la préparation de cette actualisation) : le WITH CHECK ajouté dès la conception de la table mission_offers (session 2.14 sexies, migration 20260504000021) n'est pas documenté comme un RÉSOLU — il s'agit d'une mesure préventive prise dès la création d'une table nouvelle, en contrepartie explicite du report de la correction du WITH CHECK manquant sur la table missions (voir Section 6, bloc session 2.14 sexies, et Section 18), et non de la correction d'un défaut préexistant sur mission_offers elle-même. ⚠️ ACTUALISÉ (17/10/2026) : le « WITH CHECK absent sur missions » est désormais couvert par les retraits de droits par colonne et le trigger de protection des champs (volet 5, lot C — voir RÉSOLU 75).

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
❌ Création automatique et silencieuse de la demande de remboursement de commission à l'annulation d'une mission (session 2.17) — écartée au profit d'une demande déclenchée par le chauffeur lui-même (requestRefund), l'application effectuant ses vérifications avant transmission à l'admin — parallélisme avec la recharge et double contrôle humain, sur proposition du porteur
❌ Modification globale des droits par défaut du schéma public (étape 3 sécurité, volet 5) — écartée (risque de casser get_my_role et les fonctions légitimes) au profit de la règle B4(b) : droits fixés explicitement dans chaque migration, inventaire relancé après

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
20260504000024_anticipated_commission_charge.sql ✅ Session 2.17 (déploiement initial en échec à cause du rollback mal placé, corrigé — RÉSOLU 58)
20260504000025_create_payment_proofs_bucket.sql ✅ Session 2.17
20260504000026_add_bank_reconciliation_tracking.sql ✅ Session 2.17 (commit becda8d)
20260504000027_add_transactions_update_admin_policy.sql ✅ Session 2.17 (RÉSOLU 61)
20260504000028_protect_profile_role_and_is_active.sql ✅ Étape 2 (03/10/2026)
20260504000029_secure_mission_financial_fields.sql ✅ Étape 3, volet 1
20260504000030_lock_commission_columns_properly.sql ✅ Étape 3, volet 1
20260504000031_restrict_charge_commission_execute.sql ✅ Étape 3, volet 1
20260504000032_control_mission_transitions.sql ✅ Étape 3, volet transitions
20260504000033_create_client_offer_drivers_view.sql ✅ Étape 3, choix du chauffeur
20260504000034_close_drivers_select_available.sql ✅ Étape 3, choix du chauffeur
20260504000035_restrict_voice_messages_delete_update.sql ✅ Étape 3, volet 4a
20260504000036_add_vehicle_registration_expiry_and_service_date.sql ✅ Étape 3, volet 4b-1
20260504000037_block_drivers_expired_documents_cron.sql ✅ Étape 3, volet 4b-2
20260504000038_restrict_block_function_execute.sql ✅ Étape 3, volet 4b-2
20260504000039_driver_availability_control.sql ✅ Étape 3, volet 4b-3
20260504000040_restrict_driver_has_expired_documents_execute.sql ✅ Étape 3, volet 4b-3 (insuffisant)
20260504000041_restrict_driver_has_expired_documents_authenticated.sql ✅ Étape 3, volet 4b-3 (PUBLIC subsistait, traité au volet 5 lot B)
20260504000042_protect_driver_verification_fields.sql ✅ Étape 3, volet 4b-4
20260504000043_fix_driver_guards_and_document_dates.sql ✅ Étape 3, volet 4b-5
20260504000044_vehicle_change_requires_validation.sql ✅ Étape 3, volet 4b-5
20260504000045_driver_row_rights_lot_a.sql ✅ Étape 3, volet 5, lot A
20260504000046_function_rights_lot_b.sql ✅ Étape 3, volet 5, lot B
20260504000047_missions_rights_lot_c.sql ✅ Étape 3, volet 5, lot C
20260504000048_mission_offers_lot_c5.sql ✅ Étape 3, volet 5, lot C5
20260504000049_notifications_parcels_lot_dbis.sql ✅ Étape 3, volet 5, lot D-bis
20260504000050_tracking_sms_once.sql ✅ Étape 3, volet 5, lot D-bis
20260504000051_offer_not_selected_notification.sql ✅ Étape 3, volet 5, lot E
20260504000052_realtime_mission_offers.sql ✅ Étape 3, volet 5, lot E-bis
20260504000053_offer_negotiation_notifications.sql ✅ Étape 3, volet 5, lot E-ter
20260504000054_mission_24h_window_server.sql ✅ Session 2.23
20260504000055_move_postgis_to_extensions.sql ✅ Session 2.24
20260504000056_security_advisor_warnings.sql ✅ Session 2.25
20260504000057_server_push_dispatch.sql ✅ Session 2.26

Aucune migration SQL déployée en session 2.14 (session applicative/service) ni en session 2.14 bis (session investigative).
Aucune migration SQL déployée en sessions 2.14 septies, 2.16, 2.19, 2.21, 2.22, 2.27, 2.28 et 2.29 (actualisation du 17/10/2026).
Noms des migrations 024 à 027 : vérifiés dans le dépôt par l'assistant général ; noms des migrations 028 à 057 : préfixe commun 20260504000 + noms du compte rendu du 17/10/2026 (F.1), format validé par l'assistant général. Migrations 028 à 057 toutes vérifiées en base, chacune avec son rollback dans supabase/rollbacks/, aucun rollback exécuté sur la vraie base (compte rendu du 17/10/2026, F.1).

Prochain timestamp disponible : 20260504000058 (actualisation du 17/10/2026 ; valeur précédente : 20260504000024)

# EDGE FUNCTIONS DÉPLOYÉES

send-push-notification ✅ (CORS bloqué sur web — fonctionnel sur device ; erreur CORS reconfirmée observée lors des tests de la session 2.14 sexies, non investiguée plus avant) — ✅ CORS CORRIGÉ et fonction authentifiée (volet 5, lot D-bis, migration 050 / commit 2750835) : ne prend plus qu'un identifiant de notification, relit le reste en base, notification de moins de 10 minutes ; appelée par le serveur depuis la session 2.26 (déclencheur notifications_push_dispatch via pg_net) ; correctif 401 en session 2.26 (commit 6b1026b, RÉSOLU 86)
register-push-token ✅ — ✅ authentifiée (volet 5, lot D-bis) : profil de l'appelant seulement — ⚠️ appelée par aucun écran à ce jour (aucun téléphone enregistré, constat session 2.29)
check-document-reminders ✅ (CRON opérationnel — session 2.9, 5 exécutions succeeded 18→22/06/2026) — rappels uniquement, le blocage relève de block-expired-documents ; couverture : permis, assurance, visite technique, rappels créés à l'inscription — aucun rappel pour la carte grise, aucune mise à jour au remplacement d'un document
   ⚠️ Lien avec notifyDocumentExpiry non vérifié — non traité en 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, ni 2.14 sexies (hors périmètre de chacune)
send-tracking-sms ✅ — ✅ authentifiée (volet 5, lot D-bis) : client du colis, un seul SMS par colis (migration 050) — ⚠️ non testée (volet e-commerce, fournisseur SMS)

Le workflow « Deploy Supabase FTM » redéploie les 4 fonctions serveur à chaque déploiement (compte rendu du 17/10/2026, A.2). Aucune nouvelle fonction serveur depuis le 09/09/2026.

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
│   ├── package.json ← expo-image-picker ajouté ; expo-av 13.10.6 réinstallé session 2.14 septies (commit 8d8176b, RÉSOLU 56)
│   ├── package-lock.json
│   ├── tsconfig.json ← modifié session 2.27 ("module": "esnext", RÉSOLU 87)
│   └── src/
│       ├── components/
│       │   ├── BackButton.tsx ← NOUVEAU, créé session 2.21 (commit c090c27)
│       │   ├── DateOnlyField.tsx ← NOUVEAU, créé volet 4b-5 (commit ebeb722) — date seule, sans décalage de fuseau
│       │   ├── LogoutButton.tsx ← NOUVEAU, créé session 2.21 (commit c090c27)
│       │   ├── NotificationBell.tsx ← modifié session 2.14
│       │   ├── DateTimeField.tsx ← créé session 2.14 quater (commits 0da3e07 + 829f31e)
│       │   └── VoiceMicButton.tsx ← lu intégralement session 2.14 bis, aucune modification
│       ├── constants/theme.ts ← BORDER_RADIUS ajouté ; couleurs manquantes ajoutées volet 5, lot E (commit b066dae, RÉSOLU 78)
│       ├── lib/supabaseClient.ts
│       ├── navigation/
│       │   └── RootNavigator.tsx ← modifié sessions 2.14, 2.14 sexies (9 modifications cumulées : routes MissionOffer/MissionTracking/Rating/MissionActive ajoutées, ClientHome élargie, wrappers substitués — voir Section 6, RÉSOLU 53/54) ; ⚠️ ne déclare TOUJOURS PAS la route 'CreateParcel' (bug découvert session 2.14 quater, assigné session 2.20) [session 2.20 reportée] ; modifié session 2.14 septies (route VoiceChat client + chauffeur, commit 518c900) ; modifié session 2.17 (driverId transmis à WalletTopup, écrans PendingTransactions/BankReconciliation) ; modifié entre le 03/10 et le 17/10/2026 (407 lignes au commit bcff143 — sessions précises non documentées)
│       ├── screens/
│       │   ├── admin/
│       │   │   ├── AdminDashboardScreen.tsx ← modifié session 2.14 ; modifié sessions 2.16 (déconnexion, commit ad797da) et 2.17 (badges) ; modifié entre le 03/10 et le 17/10/2026
│       │   │   ├── AdminMissionsScreen.tsx ← créé session 2.7 ; modifié session 2.14 quinquies (ajout filtre expired, RÉSOLU 50) ; ⛔ fichier protégé (liste actualisée après le 09/09/2026)
│       │   │   ├── AdminUsersScreen.tsx ← créé session 2.7 ; ⛔ fichier protégé (liste actualisée après le 09/09/2026) — exception session 2.28 (deux lignes et un import)
│       │   │   ├── BankReconciliationScreen.tsx ← NOUVEAU, créé session 2.17 (commit 25f2553)
│       │   │   ├── DocumentReviewScreen.tsx ← modifié volet 4b-5 (commit 592d1a5, RÉSOLU 72)
│       │   │   ├── PendingTransactionsScreen.tsx ← NOUVEAU, créé session 2.17
│       │   │   └── WalletManagementScreen.tsx ← modifié entre le 03/10 et le 17/10/2026 (session non précisée)
│       │   ├── auth/
│       │   │   ├── AccountSuspendedScreen.tsx ← NOUVEAU, créé session 2.21 (commit c090c27)
│       │   │   ├── OTPVerificationScreen.tsx ← modifié entre le 03/10 et le 17/10/2026 (session non précisée)
│       │   │   ├── PhoneInputScreen.tsx
│       │   │   └── ProfileSetupScreen.tsx ← INTOUCHABLE — exception session 2.27 : une ligne de déclaration (TS2322, RÉSOLU 87)
│       │   ├── client/
│       │   │   ├── CreateMissionScreen.tsx ← modifié sessions 2.14 + 2.14 quater (scheduled_pickup_time obligatoire, DateTimeField) ; modifié session 2.16 (déconnexion, commit 61f5a54) ; modifié entre le 03/10 et le 17/10/2026
│       │   │   ├── MissionTrackingScreen.tsx ← modifié session 2.14 quinquies (Volet 2) ; modifié session 2.14 sexies (correction type local + navigation.replace, RÉSOLU 53) ; modifié session 2.14 septies (accès temporisé au canal vocal, commit 9ba34cb) ; déclenchement de l'annonce retiré session 2.23
│       │   │   ├── RatingScreen.tsx ← modifié session 2.14 sexies (correction type local + navigation.replace, RÉSOLU 53) ; modifié entre le 03/10 et le 17/10/2026 (session non précisée)
│       │   │   └── ClientMissionOfferScreen.tsx ← NOUVEAU, créé session 2.14 sexies (commit c886722) — wrapper adaptant route.params/navigation vers les props de MissionOfferScreen
│       │   │   [+ ClientVoiceChatScreen.tsx ← NOUVEAU, créé session 2.14 septies (commit 518c900, réécrit 9ba34cb) — wrapper du canal vocal côté client (mission.client_id), fermeture sur annulation — chemin exact non documenté (dossier client/ supposé)]
│       │   ├── driver/
│       │   │   ├── DocumentStatusScreen.tsx ← modifié volet 4b-5 (« Remplacer » avec date, « Mon véhicule » / « Changer de véhicule » — commits ebeb722, 01d689f)
│       │   │   ├── DriverHomeScreen.tsx ← modifié session 2.14 ; modifié session 2.14 quinquies (Volet 1, commit d1869e4) ; modifié session 2.14 quinquies bis (branchement géospatial, commit 26ebe20) ; modifié sessions 2.14 septies (onOfferCreated, commit 4ee8257) et 2.16 (déconnexion, commit ad62dd6)
│       │   │   ├── MissionActiveScreen.tsx ← route désormais déclarée dans RootNavigator (session 2.14 sexies, RÉSOLU 54) ; modifié sessions 2.14 septies (accès temporisé au canal vocal, 9ba34cb) et 2.17 (prélèvement anticipé fusionné, d3b43ad ; bouton de remboursement, fdf0631) ; déclenchements retirés session 2.23
│       │   │   ├── MissionOfferScreen.tsx ← NOUVEAU, créé session 2.14 sexies (426 lignes, commits be13041 puis 7cf6fd7) — composant PARTAGÉ client/chauffeur, rangé sous driver/ par convention historique du fichier (précision reçue directement de l'assistant de session, information absente du compte-rendu écrit initial) ; modifié choix du chauffeur (commit ba8e61f) et volet 5, lot E-bis (chargement initial) — 491 lignes au commit bcff143
│       │   │   ├── DriverMissionOfferScreen.tsx ← NOUVEAU, créé session 2.14 sexies (commit c886722) — wrapper adaptant route.params/navigation vers les props de MissionOfferScreen
│       │   │   [+ DriverVoiceChatScreen.tsx ← NOUVEAU, créé session 2.14 septies (commit 518c900, réécrit 9ba34cb) — wrapper du canal vocal côté chauffeur (getDriverProfileId), fermeture sur annulation — chemin exact non documenté (dossier driver/ supposé)]
│       │   │   ├── NewMissionModal.tsx ← lu intégralement session 2.14 bis ; modifié session 2.14 sexies (bouton Accepter → champ prix + Proposer ce prix, commit 3d6717e)
│       │   │   ├── ParcelMissionDetailScreen.tsx
│       │   │   ├── TransactionDetailModal.tsx
│       │   │   ├── TransactionHistoryScreen.tsx ← modifié session 2.14 ; modifié session 2.22 (totaux, commit b1701e7, RÉSOLU 82)
│       │   │   ├── WalletDashboardScreen.tsx ← modifié session 2.13 ; modifié session 2.17 (driverId transmis à WalletTopup)
│       │   │   ├── WalletTopupScreen.tsx ← modifié session 2.13 ; modifié session 2.17 (3 modes de paiement, justificatif)
│       │   │   └── onboarding/
│       │   │       ├── DocumentUploadScreen.tsx ← modifié entre le 03/10 et le 17/10/2026 (session non précisée)
│       │   │       ├── LegalDocumentsScreen.tsx ← lu intégralement (2 extraits, gap identifié) session 2.14 quater — RÉFÉRENCE pour DateTimeField, non modifié à l'époque ; modifié entre le 03/10 et le 17/10/2026 (session non précisée)
│       │   │       ├── PendingVerificationScreen.tsx ← modifié sessions 2.13 + 2.14 ; modifié volet 4b-5 (« Mettre à jour mes documents ») et session 2.21 (déconnexion)
│       │   │       └── VehicleInfoScreen.tsx ← modifié entre le 03/10 et le 17/10/2026 (volet 4b-5 / session 2.21 — détail par fichier non documenté)
│       │   ├── ecommerce/
│       │   │   ├── CreateParcelScreen.tsx ← modifié session 2.14 quater (scheduled_pickup_time) ; ⚠️ inaccessible via navigation (bug, session 2.20) — le volet e-commerce sera examiné ultérieurement
│       │   │   ├── ParcelConfirmationScreen.tsx
│       │   │   └── ParcelHistoryScreen.tsx ← appelle navigation.navigate('CreateParcel'), sans effet (route non déclarée)
│       │   ├── mission/
│       │   │   └── VoiceChatScreen.tsx ← confirmé orphelin session 2.14 ; canal conservé, activation désormais possible (dépendance envers 2.14 sexies levée — voir Section 18) — ✅ MONTÉ depuis la session 2.14 septies via ClientVoiceChatScreen.tsx / DriverVoiceChatScreen.tsx ; bandeau anti-partage ajouté (commit b80d910)
│       │   ├── notifications/
│       │   │   └── NotificationCenterScreen.tsx ← modifié session 2.14 ; modifié session 2.17 ; bouton Retour ajouté session 2.21 (Anomalie #1, RÉSOLU 81)
│       │   └── tracking/
│       │       ├── TrackingDetailScreen.tsx
│       │       └── TrackingInputScreen.tsx
│       ├── services/
│       │   ├── adminService.ts ← modifié session 2.17 ; modifié entre le 03/10 et le 17/10/2026
│       │   ├── audioService.ts ← CONFIRMÉ fichier réel du canal vocal, lu intégralement, non modifié à l'époque ; modifié entre le 03/10 et le 17/10/2026 (session non précisée)
│       │   ├── authService.ts ← INTOUCHABLE
│       │   ├── documentService.ts ← modifié entre le 03/10 et le 17/10/2026 (session non précisée)
│       │   ├── driverService.ts ← STABLE INTOUCHABLE
│       │   ├── i18nService.ts
│       │   ├── locationService.ts ← lu en profondeur session 2.14 quinquies, non modifié — startBackgroundTracking() confirmé (intervalle 15s / 50m) ; non modifié non plus en 2.14 quinquies bis (décision explicite de réutiliser la RPC existante plutôt que ce fichier)
│       │   ├── missionService.ts ← modifié sessions 2.14, 2.14 quater, 2.14 quinquies ; modifié session 2.14 quinquies bis (rayon 60km, commit c6a55eb) ; modifié session 2.14 sexies (6 nouvelles fonctions liées aux offres — createMissionOffer, counterMissionOffer, acceptMissionOffer, rejectOfferAcceptance, submitClientCounterOffer, getMissionById — commits 263c287/345b0a3/d163825/7cf6fd7) ; modifié sessions 2.14 septies (getDriverProfileId, commit 24cd5f0), 2.17, étape 3 (getClientOfferDrivers, commit ba8e61f) ; code mort retiré session 2.29
│       │   ├── notificationTemplates.ts ← lu session 2.14 quinquies ; modifié session 2.14 sexies (4 nouvelles fonctions offer_update, commits 2fc0e29/d163825) ; modifié sessions 2.14 septies (notifyVoiceChannelOpened) et 2.17 (4 fonctions wallet, destinations des notifications)
│       │   ├── parcelService.ts ← modifié session 2.14 quater (scheduled_pickup_time) — ⚠️ 19 erreurs TypeScript restantes au 17/10/2026 (volet e-commerce)
│       │   ├── pushNotificationService.ts ← modifié session 2.14 ; modifié session 2.14 sexies (4 nouvelles fonctions offer_update) ; ⚠️ doublon mort NOTIF_ICONS non corrigé, découvert session 2.14 sexies ; modifié session 2.17 (screenMap, handleNotificationTap async) ; ✅ doublon NOTIF_ICONS constaté absent au 17/10/2026
│       │   ├── realtimeService.ts ← lu session 2.14 bis ; modifié session 2.14 sexies (2 nouveaux canaux subscribeToMissionOffers/subscribeToDriverOffers, commit 3e2a07a)
│       │   ├── reminderService.ts
│       │   └── walletService.ts ← modifié session 2.13 ; modifié sessions 2.17, étape 3 volet 3 (commit 65245b1) et 2.27 (déclaration de l'historique) — 997 lignes au commit bcff143 ; canDriverAcceptMission() toujours présente, jamais appelée
│       ├── types/database.ts
│       └── utils/
│           ├── dialogs.ts ← NOUVEAU, créé session 2.19 (commit 46d52ca) — showMessage, confirmAction
│           └── parcelCalculations.ts
├── supabase/
│   ├── config.toml
│   ├── functions/
│   │   ├── check-document-reminders/
│   │   ├── register-push-token/ ← modifiée volet 5, lot D-bis
│   │   ├── send-push-notification/ ← modifiée volet 5, lot D-bis, et session 2.26 (commit 6b1026b)
│   │   └── send-tracking-sms/ ← modifiée volet 5, lot D-bis
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
│   │   ├── 20260504000023_add_unique_pending_offer_constraint.sql ← session 2.14 sexies
│   │   ├── 20260504000024_anticipated_commission_charge.sql ← session 2.17
│   │   ├── 20260504000025_create_payment_proofs_bucket.sql ← session 2.17
│   │   ├── 20260504000026_add_bank_reconciliation_tracking.sql ← session 2.17
│   │   ├── 20260504000027_add_transactions_update_admin_policy.sql ← session 2.17
│   │   ├── 20260504000028_protect_profile_role_and_is_active.sql ← étape 2
│   │   ├── 20260504000029 à 20260504000053 ← étape 3 sécurité (liste complète section « Migrations Supabase déployées »)
│   │   ├── 20260504000054_mission_24h_window_server.sql ← session 2.23
│   │   ├── 20260504000055_move_postgis_to_extensions.sql ← session 2.24
│   │   ├── 20260504000056_security_advisor_warnings.sql ← session 2.25
│   │   └── 20260504000057_server_push_dispatch.sql ← session 2.26
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
│       ├── 20260504000023_add_unique_pending_offer_constraint_rollback.sql ← session 2.14 sexies
│       └── 20260504000024_…_rollback.sql à 20260504000057_…_rollback.sql ← 34 fichiers présents, chacun portant exactement le nom de sa migration suivi de _rollback.sql (ex. 20260504000054_mission_24h_window_server_rollback.sql) — vérifié dans le dépôt par l'assistant général ; sessions 2.17, étape 2, étape 3, 2.23 à 2.26 ; aucun rollback 028 à 057 exécuté sur la vraie base
├── .env.example
├── .gitignore
├── ROADMAP_FTM.md
└── install_*.sh
```

⚠️ Note sur les chemins de MissionOfferScreen.tsx et de ses deux wrappers : ces trois chemins ont été communiqués directement à la présente conversation par l'assistant ayant conduit la session 2.14 sexies, en réponse à une lacune identifiée dans son compte-rendu écrit initial (qui ne les précisait pas). Il s'agit d'une information de première main (l'assistant ayant lui-même créé ces fichiers dans sa session), acceptée comme fait confirmé pour la présente actualisation.

Note : ~59+ fichiers untracked de type .bak* présents dans le dépôt (mécanisme de traçabilité délibéré), dont 4 nouveaux ajoutés en session 2.14 quater, 4 nouveaux ajoutés en session 2.14 quinquies (suffixe .bak.session2.14quinquies), AUCUN nouveau en session 2.14 quinquies bis (écart noté, voir Section 2 et Section 6), et plusieurs nouveaux (avec versionnement .v2/.v3/.v4) en session 2.14 sexies (suffixe .bak.session2.14sexies) — non représentés dans l'arborescence ci-dessus par souci de lisibilité. ⚠️ DÉPASSÉ (17/10/2026) : les 131 copies .bak ont été archivées (FTM_copies_sauvegarde_2026-10-17.tar.gz) puis supprimées du dépôt le 17/10/2026 (session 2.29) — voir section « État technique actuel ».

Note (actualisation du 17/10/2026) : le dépôt ne contient ni app.json ni eas.json (constat session 2.29) — création prévue en Phase 3.4. Les chemins exacts de ClientVoiceChatScreen.tsx et DriverVoiceChatScreen.tsx ne figurent pas dans les sources (placement indicatif ci-dessus). Les empreintes SHA256 et nombres de lignes des fichiers modifiés ou créés entre le 03/10 et le 17/10/2026 figurent dans le compte rendu du 17/10/2026 (partie F.5) et ne sont pas reproduits ici.

# SERVICES EXTERNES — ÉTAT

Twilio SMS : ⏳ pas encore configuré — SMS de suivi de colis : un seul par colis (volet 5, lot D-bis), non testé (volet e-commerce, fournisseur SMS)
FCM Android : ⏳ pas encore configuré
   ⚠️ send-push-notification bloquée par CORS sur web — fonctionnel sur device physique uniquement
   ✅ CORS CORRIGÉ — volet 5, lot D-bis (RÉSOLU 77)
   ⚠️ Dépendance croisée confirmée session 2.14 : les fonctions notify* mission (dont les 4 nouvelles de 2.14 sexies) appellent dispatchPushNotification() → push mobile réel non pleinement opérationnel tant que FCM/APNs non configurés — ⚠️ DÉPASSÉ (17/10/2026) : depuis la session 2.26, c'est le serveur qui déclenche la sonnerie (déclencheur notifications_push_dispatch → send-push-notification via pg_net). Aucun téléphone ne peut encore recevoir de sonnerie : les 4 fonctions d'équipement du téléphone (requestPushPermission, registerPushToken, setupNotificationChannels, setupPushHandlers) ne sont appelées par aucun écran et le dépôt ne contient ni app.json ni eas.json — voir Phase 3.4. Sonnerie prévue pour Android et iPhone (compte Apple Developer payant pour l'iPhone).
APNs iOS : ⏳ pas encore configuré

Storage buckets :
   ✅ driver-documents créé — ✅ RLS ownership chain — session 2.12
   ✅ voice-messages créé — session 2.8
   ✅ RLS ownership CORRIGÉE — session 2.14 ter (RÉSOLU 43 — renvoi corrigé le 17/10/2026, la mention antérieure « RÉSOLU 46 » était erronée) — double chaîne client + chauffeur, indice [2]
   ⚠️ voice-messages non testé fonctionnellement (audioService.ts non intégré UI côté screen — canal orphelin) — test complet reporté Phase 4.4 / session 2.18. Activation planifiée session 2.14 septies, dont la dépendance envers 2.14 sexies est désormais levée (voir Section 18).
   ✅ ACTUALISÉ (17/10/2026) : canal monté en session 2.14 septies (VoiceChatScreen via 2 wrappers, accès temporisé 24 h, bandeau anti-partage, fermeture sur annulation) ; règles durcies au volet 4a (RÉSOLU 67) ; reste le test de bout en bout (Phase 4.4)
   ✅ NOUVEAU — payment-proofs créé — session 2.17 (migration 20260504000025) — opérationnel en test réel

CRON reminders : ✅ OPÉRATIONNEL — session 2.9 — 5 exécutions succeeded 18→22/06/2026
   ⚠️ Lien avec notifyDocumentExpiry non vérifié
   ⚠️ Couverture : aucun rappel pour la carte grise, aucune mise à jour au remplacement d'un document (voir section « État technique actuel »)
CRON block-expired-documents : ✅ NOUVEAU — volet 4b-2 — 7 h — blocage des chauffeurs ayant un document expiré
CRON process-missions-24h : ✅ NOUVEAU — session 2.23 — toutes les 5 minutes — prélèvement anticipé et annonce de la messagerie

Wallet topup : ✅ Mécanisme honnête opérationnel — session 2.13 — reconfirmé intact (données) après sessions 2.14, 2.14 bis, 2.14 ter, 2.14 quinquies, 2.14 quinquies bis ; accès Auth du profil porteur historique supprimé en session 2.14 quater, occupé successivement par différents profils DRIVER depuis (voir Section 3), données du profil historique inchangées. Recharge de 1000 DH testée et confirmée session 2.14 sexies sur le profil DRIVER actif actuel. ⚠️ ACTUALISÉ (17/10/2026) : le profil porteur historique et ses données ont été supprimés en cascade avec son compte Auth ; workflow financier générique depuis la session 2.17 (modes de paiement, validation admin, remboursement, rapprochement bancaire) ; anti double crédit (volet 3) ; solde du chauffeur de test : 4 500 DH.

Realtime transactions/notifications : ✅ subscribeToNewTransactions branché — session 2.14 (INSERT uniquement) — ✅ NotificationBell/Center montés 3 rôles
   ✅ (session 2.14 quinquies) — subscribeToMissionUpdates exploité côté DriverHomeScreen.tsx (Volet 1) — rôle requalifié depuis 2.14 sexies (voir Section 2/3/7)
   ✅ NOUVEAU (session 2.14 sexies) — subscribeToMissionOffers (client) et subscribeToDriverOffers (chauffeur) sur la table mission_offers
   ⚠️ Anomalie #1 : bouton retour manquant sur NotificationCenterScreen — ✅ CORRIGÉE session 2.21
   ✅ NOUVEAU (volet 5, E-bis) — mission_offers ajoutée à la diffusion en direct (migration 052)

Sécurité des vues Supabase exposées : ✅ CORRIGÉE — session 2.14 quinquies (RÉSOLU 48/49) — available_drivers et driver_dashboard ne sont plus accessibles sans authentification. 🆕 Sécurité étendue à la table drivers (SELECT anon révoqué) — session 2.14 quinquies bis (RÉSOLU 52). Recommandation ouverte : audit des permissions GRANT par défaut sur l'ensemble du schéma public (voir Section 18), désormais également motivé par la découverte de l'absence de WITH CHECK sur missions (session 2.14 sexies). ✅ ACTUALISÉ (17/10/2026) : étape 3 sécurité (volets 1 à 5) — droits par colonne sur missions, triggers de protection (profiles, missions, drivers, mission_offers), cas authenticated de drivers_select_available fermé (034), WITH CHECK sur missions couvert (lot C), vue client_offer_drivers (security_invoker), vue available_drivers sans aucun droit pour anon et authenticated (lue seulement par find_nearby_drivers, 2.24), vue public_parcel_tracking sans droit direct (lue par get_public_parcel_tracking) ; audit des droits par défaut traité par méthode (règle B4(b)) plutôt que par changement global ; 8 avertissements du Security Advisor acceptés (2.25).

Géolocalisation avancée : ✅ Infrastructure PostGIS complète (RPC find_nearby_drivers) confirmée existante, active, sécurisée (session 2.14 quinquies) et désormais BRANCHÉE ET DÉPLOYÉE dans le flux de diffusion réel (session 2.14 quinquies bis, RÉSOLU 51) — rayon corrigé à 60 km, cast geography corrigé pour l'encodage HEXEWKB du payload Realtime, comportement fail-open. ⚠️ Test d'exécution complet en conditions réelles (GPS fonctionnel) toujours en attente, non réalisable en Codespaces — Phase 4.x. ✅ PostGIS déplacé dans le schéma extensions (session 2.24). ⚠️ Test réel renvoyé en Phase 3.5 (GPS) par décision du porteur du 17/10/2026 ; ce que renvoie find_nearby_drivers au chauffeur reste à revoir avec le GPS ; sort de findNearbyDrivers (l'accueil chauffeur interroge la base directement) à décider.

Négociation de prix structurée : ✅ NOUVEAU (session 2.14 sexies) — table mission_offers, RLS (3 policies symétriques + WITH CHECK dès conception), 2 triggers (transition, synchronisation missions), index unique partiel, 6 fonctions de service, 2 canaux Realtime, 4 notifications, écran partagé MissionOfferScreen + 2 wrappers de navigation, mécanisme "premier arrivé premier servi" remplacé. Schéma en 2 tours maximum avec double acceptation symétrique obligatoire. ⚠️ Test de bout en bout non réalisé en conditions réelles (nécessite CLIENT + DRIVER simultanés avec GPS fonctionnel) — voir Section 16/17/18. ✅ ACTUALISÉ (17/10/2026) : informations du chauffeur affichées au client (choix du chauffeur) ; offres protégées par trigger (lot C5) ; diffusion en direct et chargement initial (E-bis) ; notifications déposées par la base (E-ter) ; test réel du 14/10/2026 conforme avec un chauffeur — négociation avec plusieurs chauffeurs : Phase 3.5 (GPS) ; acceptMission (ancien mode « premier arrivé, premier servi », code mort) : sort à décider en Phase 3.

Planification par date/heure : ✅ OPÉRATIONNELLE — session 2.14 quater — scheduled_pickup_time obligatoire (NOT NULL + UI), transport classique et e-commerce
   ✅ Volet 2 (expiration mission pending à scheduled_pickup_time dépassé) — implémenté session 2.14 quinquies
   ⚠️ Flux e-commerce non testable en pratique tant que le bug de navigation CreateParcel n'est pas corrigé (session 2.20)
   ⚠️ Session 2.20 reportée : le volet e-commerce sera examiné ultérieurement

Canal vocal sécurisé : ✅ NOUVEAU (session 2.14 septies) — ouverture au croisement de deux conditions (accord de mission conclu ET 24 h avant scheduled_pickup_time ; ouverture immédiate à l'acceptation pour une mission à moins de 24 h), ouvert jusqu'à completed, fermé sur toute annulation ; bandeau anti-partage permanent ; annonce d'ouverture par le serveur depuis la session 2.23 — ⚠️ parcours complet jamais testé (Phase 4.4)

Workflow financier : ✅ NOUVEAU (session 2.17) — recharge avec 3 modes de paiement et justificatif, validation/rejet admin, remboursement de commission sur demande du chauffeur, rapprochement bancaire a posteriori ; commission prélevée par le serveur 24 h avant depuis la session 2.23 — voir section « État technique actuel »

Documents du chauffeur : ✅ NOUVEAU (étape 3, volets 4b-1 à 4b-5) — dates d'expiration surveillées, blocage automatique (block-expired-documents), date à chaque remplacement, changement de véhicule soumis à validation, gardiens de disponibilité et de vérification

Préparation du téléphone et comptes de publication : ⏳ comptes Expo (gratuit), Firebase pour Android (gratuit), Apple Developer pour l'iPhone (payant, décision commerciale du porteur) ; app.json et eas.json à créer ; vérifier qu'Expo Go accepte encore Expo SDK 50 — Phase 3.4

# BUGS RÉSIDUELS

⚠️ CORS send-push-notification Edge Function bloquée par CORS policy sur web — non bloquant web, fonctionnel sur device physique — à corriger pour production. Reconfirmée observée lors des tests DRIVER de la session 2.14 sexies, non investiguée plus avant — à vérifier hors environnement Codespaces (voir Section 18). ✅ CORRIGÉ volet 5, lot D-bis (RÉSOLU 77).

⚠️ Filtres AdminMissionsScreen — affichés mais aucune mission en base — cause confirmée (GPS bloqué environnement web/Codespaces) — reporté phase 4.x — 7 filtres disponibles depuis session 2.14 quinquies (dont expired), reconfirmés intacts sessions 2.14 quinquies bis et 2.14 sexies — test renvoyé en Phase 3.5 (GPS)

⚠️ Realtime driver end-to-end — flux avec 2 fenêtres simultanées non testé explicitement — désormais également pertinent pour le test de bout en bout du parcours de négociation de prix (session 2.14 sexies) — test réel du 14/10/2026 par connexions successives client puis chauffeur (conforme) ; deux comptes ne peuvent pas être connectés en même temps dans le navigateur (un seul onglet)

⚠️ AdminMissions pagination — non testée (0 missions en base)

⚠️ DocumentReviewScreen.tsx — rafraîchissement modal (session 2.12) — non traité faute de temps, reporté à une session ultérieure à assigner — ✅ CORRIGÉ volet 4b-5 (RÉSOLU 72)

⚠️ Profils DRIVER/CLIENT antérieurs orphelins (données intactes, accès Auth occupé par le profil DRIVER actif a53521ca-... depuis session 2.14 sexies) — voir Section 3 pour l'état complet : — ⚠️ DÉPASSÉ (17/10/2026) : suppression Auth = suppression en cascade ; ces profils et leurs données n'existent plus en base (la table drivers ne contient que le chauffeur de test)
   driverId : 2ec2b439-fcdb-443d-8de0-5bee268d30f6 (données en base uniquement, aucun accès Auth actif depuis session 2.14 quater)
   wallet_balance réel : 800.00 DH — 4 demandes en pending (50/200/500/1000 DH) — à ne pas altérer sans décision explicite (preuve de fonctionnement du correctif RÉSOLU 38)
   Profil DRIVER créé en session 2.14 quinquies (300 DH, VUL) — driverId inconnu, orphelin depuis une rotation ultérieure non précisément documentée (voir liste de suivi anomalie #16)
   Profil(s) CLIENT intermédiaire(s) — existence indirectement confirmée par la mention "dont un profil client sans historique de mission" du compte-rendu 2.14 sexies, caractéristiques précises INCONNUES

⚠️ Dossiers Storage orphelins (session 2.12) — driver-documents : 8 orphelins + 1 actif — aucune session de nettoyage planifiée

⚠️ COMPORTEMENT NON EXPLIQUÉ — repr() vs terminal (session 2.9) — statut INCONNU, non bloquant

⚠️ Navigation cross-stack PendingVerification → DriverHome — navigation.replace('DriverHome') cible un écran absent du stack DriverPendingStack — NON traité à ce jour (2.13, 2.14, 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, 2.14 sexies) — bug entier, session à assigner — ⚠️ FUSIONNÉ (17/10/2026) avec le constat « écran d'attente du chauffeur : lecture des statuts à l'ouverture et route de sortie après la validation complète » (compte rendu du 17/10/2026, C.3) — toujours ouvert

⚠️ subscribeToNewTransactions — limitation résiduelle : écoute INSERT uniquement, pas UPDATE

⚠️ AdminUsersScreen.tsx — Alert.alert sans Platform.OS — candidat audit session 2.19 — ✅ aligné sur dialogs.ts session 2.28

⚠️ WalletTopupScreen.tsx ligne 66 — message d'erreur non vérifié — candidat audit session 2.19 — statut individuel après l'audit 2.19/2.28 non documenté

⚠️ Coexistence total_commissions / commissions_current_month — à surveiller lors du chantier reporting financier (Section 18)

⚠️ Risque de pagination totalCredit/totalDebit (TransactionHistoryScreen.tsx) — à surveiller lors du chantier reporting financier (Section 18) — totaux de l'historique recalculés sur l'effet réel en session 2.22 (RÉSOLU 82) ; sort du risque de pagination non documenté

⚠️ Anomalie #1 — Absence de bouton "← Retour" sur NotificationCenterScreen.tsx — non bloquant, à corriger avant Phase 3, candidat audit session 2.19 — reconfirmée en conditions réelles session 2.14 quinquies — ✅ CORRIGÉE session 2.21 (RÉSOLU 81)

⚠️ Fonctions notify* mission non testées fonctionnellement de bout en bout — nécessite un second numéro de test dédié au rôle client (voir Section 18). Point réactualisé session 2.14 sexies : ceci concerne désormais également les 4 nouvelles fonctions notify* liées à la négociation de prix, ainsi que le test complet du parcours de négociation lui-même. ✅ Partiellement levé (17/10/2026) : compte CLIENT dédié depuis le 03/10/2026 ; négociation testée en réel le 14/10/2026 ; sonnerie sur téléphone non testée.

⚠️ Cloche NotificationBell côté Client non testée en conditions réelles — reportée avec le test des fonctions notify* mission

⚠️ Chemin natif (hors web) non testé — Alert.alert/Platform.OS (RÉSOLU 42) — à vérifier Phase 4 — tous les tests à ce jour réalisés sur le web ; module dialogs.ts (2.19) à vérifier sur téléphone

⚠️ Point de sécurité cancelMission/userId — le renommage de paramètre (_userId → userId) est confirmé effectif dans le code, mais AUCUNE vérification d'autorisation n'a été ajoutée — le point de sécurité de fond reste entier, rattaché à la session 2.17 (décision actée session 2.14, reconfirmée pertinente session 2.14 quater, RECONFIRMÉE PRÉEXISTANTE ET NON AGGRAVÉE session 2.14 sexies — lecture directe de missionService.ts, § Partie 1 investigation). ✅ CORRIGÉ (étape 3, volet transitions, migration 032 : le trigger control_mission_status_transition vérifie l'identité — RÉSOLU 64).

⚠️ notifyDocumentExpiry — en attente, lien check-document-reminders non vérifié — non traité en 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis, ni 2.14 sexies — non documenté depuis le 09/09/2026 : dernier statut connu inchangé

⚠️ Bug de reconnexion clientProfileId vide (RootNavigator.tsx) — découverte annexe session 2.14, hors périmètre, session future non assignée — non documenté depuis le 09/09/2026 : dernier statut connu inchangé
⚠️ NOTE DE RAPPROCHEMENT (signalée, non tranchée — actualisation du 09/09/2026) : cette entrée, issue de la session 2.14 d'origine et décrivant un "bug de reconnexion", touche le même fichier (RootNavigator.tsx) et la même donnée (clientProfileId) que le défaut corrigé par RÉSOLU 53 (session 2.14 sexies — routes MissionTracking/Rating jamais déclarées, ClientHome typée undefined sans clientProfileId). Il est possible qu'il s'agisse du même défaut structurel, auquel cas cette entrée devrait être requalifiée en résolue ; il est tout aussi possible qu'il s'agisse d'un problème distinct (le mécanisme de découverte documenté pour RÉSOLU 53 ne mentionne aucun scénario de reconnexion). Ce rapprochement n'a pas pu être vérifié faute d'accès au compte-rendu original de la session 2.14 — voir RÉSOLU 53, Section 10, pour la note symétrique.

⚠️ Robustesse topupWallet/refundWallet (échec silencieux insertion transaction) — découverte annexe session 2.14, à vérifier lecture directe début session 2.17 — ✅ CORRIGÉE session 2.17 (RÉSOLU 57) ; reste le crédit atomique en base (option 2 du volet 3)

⚠️ VoiceChatScreen.tsx orphelin + dossier ecommerce/ — canal conservé, activation désormais possible : la dépendance de la session 2.14 septies envers la clôture de 2.14 sexies est levée (voir Section 18) ; dossier ecommerce/ reste non exploré en profondeur au-delà du périmètre strict de 2.14 quater — ✅ VoiceChatScreen.tsx monté en session 2.14 septies ; dossier ecommerce/ : le volet e-commerce sera examiné ultérieurement

⚠️ NOUVEAU (session 2.14 ter) — Correction de cohérence documentaire, décompte transactions pending driver test historique : corrigé en 4 demandes (50/200/500/1000 DH), confirmé par lecture directe des dates de création.

⚠️ NOUVEAU (session 2.14 quater) — Route de navigation CreateParcel manquante : assignée à la session 2.20. Reconfirmée hors périmètre en session 2.14 sexies (extension e-commerce du mécanisme de négociation également reportée à cette même session 2.20). Session 2.20 reportée : le volet e-commerce sera examiné ultérieurement.

⚠️ NOUVEAU (session 2.14 quater) — Points d'enrichissement fonctionnel non traités liés à scheduled_pickup_time : notifyRecipientBySMS et getClientParcels — piste non assignée, à arbitrer.

⚠️ NOUVEAU (session 2.14 quater) — Points techniques mineurs DateTimeField.tsx (décalage fuseau horaire, borne min figée, cas limite '' vs null, comportement iOS spinner) — non bloquants, consignés pour référence future.

⚠️ NOUVEAU (session 2.14 quinquies) — Volet 2, limite assumée : une mission pending expirée reste techniquement en base tant qu'aucun écran client ne la consulte — compromis explicitement accepté, à réévaluer si le volume réel augmente.

⚠️ NOUVEAU (session 2.14 quinquies bis) — Cas authenticated de la policy drivers_select_available : reste permissive pour tout utilisateur connecté, sans filtre sur le chauffeur concerné — décision produit à trancher (voulu ou oubli), non traité en session 2.14 sexies. ✅ CORRIGÉ (étape 3, choix du chauffeur, migration 034 — RÉSOLU 65).

⚠️ NOUVEAU (session 2.14 quinquies bis) — Cause de l'incident réseau/tunnel Codespaces observé lors des tests de la session 2.14 sexies (7.1 du compte-rendu source) : non identifiée avec certitude, contournée par redémarrage complet de la machine du porteur — à surveiller si le problème se reproduit. [Précision : cet incident est bien survenu au cours de la session 2.14 sexies, et non 2.14 quinquies bis — vérifié lors de la rédaction du présent document par relecture directe des trois sources reçues.]

⚠️ NOUVEAU (session 2.14 sexies) — Countdown serveur par tour (négociation de prix) : arbitrage explicitement laissé ouvert par le porteur, ni intégré ni définitivement écarté — mécanisme d'expiration existant (30s, sans CRON) confirmé transposable si besoin futur. Non documenté depuis le 09/09/2026 : dernier statut connu inchangé.

⚠️ NOUVEAU (session 2.14 sexies) — WITH CHECK absent sur la policy UPDATE de la table missions (et missions_update_admin) : confirmé NULL par lecture directe (pg_policies). Décision explicite du porteur de reporter la correction à une session future d'audit sécurité — à rattacher à la recommandation déjà existante "audit des permissions GRANT par défaut sur le schéma public" (voir Section 18). ✅ COUVERT (volet 5, lot C — RÉSOLU 75).

⚠️ NOUVEAU (session 2.14 sexies) — Doublon mort NOTIF_ICONS dans pushNotificationService.ts, jamais importé nulle part (confirmé par grep global) — préexistant, hors périmètre, non corrigé. ✅ Constaté absent du code au 17/10/2026 (session non précisée — précision de l'assistant général).

⚠️ NOUVEAU (session 2.14 sexies) — Avertissement gotrue-js "Lock ... was not released" observé lors du test DRIVER — comportement interne de la bibliothèque Supabase, récupération automatique documentée, sans impact observé, non investigué plus avant.

⚠️ NOUVEAU (actualisation du 09/09/2026) — Chaînon de rotation du numéro de test partagé non documenté entre les sessions 2.14 quinquies bis et 2.14 sexies — voir Section 2 et liste de suivi anomalie #16 (Section 6).
   Sans objet pour la suite depuis la création du compte CLIENT dédié (03/10/2026).

⚠️ NOUVEAU (session 2.14 septies) — expo-av en fin de vie : API dépréciées par Expo au profit d'expo-audio/expo-video, retrait définitif annoncé avec SDK 55 — réinstallé (13.10.6) et valide pour SDK 50, mais dette technique : migration à prévoir avant toute montée vers SDK 55+.

⚠️ NOUVEAU (session 2.14 septies) — Note mineure : getDriverProfileId() appelée indépendamment dans DriverVoiceChatScreen.tsx et dans le useEffect de notification de MissionActiveScreen.tsx — appel réseau dupliqué évitable, non bloquant (le déclenchement côté MissionActiveScreen a été retiré en session 2.23 ; persistance de cette redondance non documentée).

⚠️ NOUVEAU (session 2.14 septies) — Anomalies TypeScript TS2322 (onProfileCreated, RootNavigator.tsx) et TS2339 (COLORS, erreurs dans 21 fichiers) — ✅ CORRIGÉES : COLORS au volet 5, lot E (RÉSOLU 78) ; TS2322 en session 2.27 (RÉSOLU 87). Restent 19 erreurs, toutes dans parcelService.ts (volet e-commerce).

⚠️ NOUVEAU (session 2.16) — Avertissement console props.pointerEvents is deprecated. Use style.pointerEvents (rendu de l'écran d'authentification) — classé anomalie préexistante propre à React Native sur le web, sans conséquence (compte rendu du 17/10/2026, partie E, avec les avertissements orange shadow* et « Cannot record touch end ») — origine non localisée.

⚠️ NOUVEAU (session 2.16) — États clientProfileId / driverProfileId / driverVehicleCategory non réinitialisés sur SIGNED_OUT — structurellement inoffensif dans l'état actuel (aucun chemin d'affichage), à revoir si l'architecture de navigation évolue.

⚠️ NOUVEAU (session 2.17) — TS2352 (getTransactionHistory) et TS1323 (imports dynamiques) — ✅ CORRIGÉES session 2.27 (RÉSOLU 87).

⚠️ NOUVEAU (session 2.17) — canDriverAcceptMission() (walletService.ts) : existe depuis le commit fondateur du wallet, jamais appelée — redondante avec le blocage existant tant que le seuil (100 DH) reste supérieur à la commission maximale (50 DH) ; toujours présente et jamais appelée au 17/10/2026 (précision de l'assistant général).

⚠️ NOUVEAU (session 2.17) — processed_at non renseigné sur les lignes pending devenues completed via validatePendingTransaction() — cosmétique, sans impact réel (trace complète dans la transaction créée par le crédit).

⚠️ NOUVEAU (session 2.17) — Écart de nombre de transactions pending historique/actuel (4 contre 1) — non résolu ; hypothèse non vérifiée : lien possible avec la suppression en cascade des profils historiques.

⚠️ NOUVEAU (session 2.17) — Solde du chauffeur de test gonflé par trois crédits successifs d'une même demande (4 000 DH au lieu de 2 000 DH) — donnée de test conservée par décision du porteur ; 4 500 DH au 17/10/2026, solde confirmé juste par la session 2.22.

⚠️ NOUVEAU (étape 3 et sessions 2.19 à 2.29 — compte rendu du 17/10/2026, C.3, C.4 et partie E) :
   Rappels d'expiration absents pour la carte grise et non mis à jour au remplacement d'un document
   Inscription : capacité laissée vide (0 envoyé, contrainte > 0) ; plaque saisie deux fois (numéro unique)
   Fichier orphelin dans le stockage si l'enregistrement échoue après l'envoi d'un document
   Suivi public d'un colis en direct (diffusion limitée au statut) — volet e-commerce
   Erreur 406 côté client en touchant une notification d'offre (recherche inutile d'une fiche chauffeur) — bavarde, sans conséquence
   Verrou de session si l'application est ouverte dans plusieurs onglets ; horloge de l'ordinateur du porteur en avance d'environ 25 minutes
   3 messages Alert.alert restent dans des écrans e-commerce et de suivi non raccordés à la navigation
   19 erreurs TypeScript dans parcelService.ts — avec le volet e-commerce
   Erreur rouge de la console du navigateur notée en 2.27, non identifiée, non réapparue en 2.28 et 2.29
   Robustesse du portefeuille : topupWallet calcule le solde par « lire → ajouter → réécrire » (crédit atomique en base non traité)
   Solde insuffisant au moment du prélèvement : une règle plus stricte (annulation ou réattribution de la mission) reste une décision métier

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

**SESSION 2.14 septies — TESTS EFFECTUÉS ET CONFIRMÉS ✅ :**

Contexte : GPS non branché (Codespaces), un seul numéro de test partagé à l'époque (client et chauffeur ne pouvant être actifs simultanément).

| Rôle | Résultat | Détail |
|---|---|---|
| ADMIN | ✅ Validé sans réserve | Dashboard fonctionnel (KPIs cohérents : Chauffeurs Total 1/1 vérifié, Missions Total 0), console propre, séquence d'authentification normale ; 7 avertissements d'accessibilité génériques (« form field element should have an id or name attribute »), du type déjà documenté et accepté en 2.14 sexies. |
| DRIVER | ✅ (partiel) | Fonctionnel via deux lancements de serveur réussis (bundling, session chargée, profil affiché sans erreur) — pas un test de non-régression interactif complet, le flux de négociation restant bloqué par l'absence de mission réelle diffusable (GPS). |

**SESSION 2.14 septies — TESTS NON EFFECTUÉS (justifiés) :**
- CLIENT : explicitement écarté par le porteur (coût de reconstitution du profil DRIVER actuel jugé disproportionné, la rotation aurait fait perdre ce profil).
- Parcours complet du canal vocal (ouverture réelle à 24 h, envoi/réception d'un message vocal, fermeture sur annulation) et bouton « 💰 Proposer ce prix » par un clic réel : reportés à la Phase 4.4 / Phase 3.5 (appareil physique, GPS réel, deux comptes actifs).

**SESSION 2.16 — TESTS EFFECTUÉS ET CONFIRMÉS ✅ :**

Ordre de principe DRIVER → ADMIN → CLIENT ; tests en conditions réelles avec captures d'écran du porteur.

| Rôle | Résultat | Détail |
|---|---|---|
| ADMIN | ✅ Validé sans réserve | Bouton visible, confirmation window.confirm affichée et fonctionnelle, chaîne complète en console (Sign out initiated → SIGNED_OUT → Signed out successfully), redirection effective vers l'écran d'authentification. Testé avant le chauffeur par simple coïncidence d'état (compte déjà connecté). |
| DRIVER | ✅ Validé sans réserve | Même chaîne complète confirmée en console, sur le profil chauffeur actif (profileId 309967af-...). |

**SESSION 2.16 — TESTS NON EFFECTUÉS (justifiés) :**
- CLIENT : non réalisé, décision du porteur, pour préserver l'accès Auth du profil chauffeur actif (a53521ca-..., wallet 1000 DH, 4/4 documents) — une déconnexion ne supprime aucune donnée, mais une rotation vers CLIENT l'aurait fait perdre. Le code CLIENT suit le même patron ; risque jugé minime, non confirmé par un test réel.

**SESSION 2.17 — TESTS EFFECTUÉS ET CONFIRMÉS ✅ :**

| Rôle | Résultat | Détail |
|---|---|---|
| ADMIN | ✅ | Dashboard, badges de comptage (Demandes financières, Rapprochement bancaire) fonctionnels, réagissant en temps réel aux vraies données. |
| DRIVER | ✅ | Recharge avec sélection du mode de paiement (Virement), upload du justificatif réussi (bucket payment-proofs opérationnel), soumission de la demande. |
| Cycle complet | ✅ | Recharge par virement : demande côté chauffeur → visible côté admin avec mode de paiement et justificatif consultable → validation → crédit réel → disparition de la liste des demandes en attente → apparition dans l'écran de rapprochement bancaire (filtre excluant les 3 transactions cash_agent) → confirmation du rapprochement → notification finale. Obtenu après découverte et correction du bug critique RÉSOLU 61 (validation sans effet, policy UPDATE manquante). |

**SESSION 2.17 — TESTS NON EFFECTUÉS (justifiés) :**
- CLIENT : non testé, décision du porteur, après vérification qu'aucun fichier propre à l'univers client n'a été modifié.
- Rejet d'une demande (rejectPendingTransaction()) : couvert techniquement par la policy UPDATE, mais aucun clic réel sur « Rejeter ».
- Correction du screenMap (redirection des notifications) : vérifiée par lecture de code et tsc uniquement.
- notifyDriverLowBalance() : jamais déclenchée réellement (passage du solde sous 100 DH non provoqué).
- Prérequis « non négociable » du Point 7 : reporté après l'abonnement aux services externes, avant la mise en production.
- Notifications push réelles en conditions natives (CORS à l'époque, appareil physique).
- Remboursement (requestRefund) : aucun test réel documenté.

**ÉTAPE 3 SÉCURITÉ — TESTS EFFECTUÉS ET CONFIRMÉS ✅ (compte rendu du 17/10/2026, B.9 et B.10) :**

| Périmètre | Résultat | Détail |
|---|---|---|
| Volet 4b-5 — gardiens (043) | ✅ | 15 scénarios locaux et contrôles réels avant et après sur la vraie base |
| Volet 4b-5 — remplacement de l'assurance avec date | ✅ | Tests réels T4-T5 |
| Volet 4b-5 — cycle de la carte grise côté admin | ✅ | Tests réels T6-T10 |
| Volet 4b-5 — changement de véhicule complet | ✅ | Tests réels T11-T16d, de la saisie à la validation des 3 documents |
| Volet 5 — négociation | ✅ | Test réel du 14/10/2026 : mission de test N2 créée en base, connexions successives client puis chauffeur — offre, acceptation, refus, retrait et notifications conformes après E-bis et E-ter ; ménage final : 0 mission, 0 offre, notifications d'origine intactes |
| Migrations 028 à 057 | ✅ | Toutes vérifiées en base (contrôles « avant » et « après » dans une transaction annulée) |

**SESSIONS 2.19 À 2.29 — TESTS :** détail session par session non documenté dans les sources de la présente actualisation (il figure dans le compte rendu « Sessions 2.19 à 2.29 », non transmis) ; tous les tests ont été faits sur le web (Codespaces), aucun sur téléphone.

**ÉTAPE 3 ET SESSIONS 2.19 À 2.29 — TESTS NON EFFECTUÉS (réserves consolidées — compte rendu du 17/10/2026, partie D) :**

Deux comptes ne peuvent pas être connectés en même temps ; la création de mission et la disponibilité dépendent du GPS, non disponible dans Codespaces.

| Point non testé en réel | Origine | Quand |
|---|---|---|
| Création de mission, recherche de chauffeurs proches, position | Volets 1-2, 2.24 | Phase 3.5 (GPS) |
| Négociation complète avec plusieurs chauffeurs ; « Offre non retenue » en concurrence | Volet 5 | Phase 3.5 (GPS) |
| Interrupteur « En service » et gardien de disponibilité (prouvé en SQL réel) | 4b-3, 043 | Phase 3.5 (GPS) |
| Prélèvement réel 24 h avant, cas « solde insuffisant » ; filet de commission en fin de mission | 2.23, C5 | Première mission réelle |
| Confirmations « terminer » et « annuler la mission » sur le web | 2.19 | Première mission réelle |
| Sonnerie sur un vrai téléphone ; enregistrement par register-push-token | Volet 5, 2.26 | Phase 3.4 (après raccordement) |
| SMS de suivi de colis (un seul par colis) | Volet 5 | Volet e-commerce, fournisseur SMS |
| Inscription d'un nouveau chauffeur : dates de la carte grise, note NB, capacité vide, « Déconnexion » à l'étape 1, « Retour » aux étapes 2 et 3, reprise après l'étape 1, création du profil | 4b-5, 2.21, 2.27 | Prochaine inscription de test |
| Écran « Vérification en cours » et sa déconnexion ; écran des offres (retour) | 2.21 | Prochaine inscription ou mission |
| Vérification des documents par l'admin avec un message ; messages d'erreur rares des 11 écrans alignés | 2.19, 2.28 | Au fil des tests |
| Double clic réel sur « Valider » une recharge | Volet 3 | Dès accord du porteur |
| Exécution manuelle de block_drivers_with_expired_documents() (faisable sans GPS) | 4b-2 | Dès accord du porteur |
| Affichage réel des informations du chauffeur au client | Choix du chauffeur | Phase 3.5 (GPS) |
| Canal vocal de bout en bout | 2.14 septies, 2.23 | Phase 4.4 |

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

**2.14 septies ✅ COMPLET (avec réserves) — Piste 4, activation du canal vocal sécurisé (14/09/2026)** [statut au 09/09/2026 : ⏳ dépendance désormais levée]
   → RLS déjà déployée depuis 2.14 ter — reste : logique de contrôle d'accès VoiceMicButton.tsx, montage du canal, notification de message reçu, avertissement anti-partage de coordonnées [périmètre au 09/09/2026]
   → Sa dépendance unique (livraison effective de 2.14 sexies) est levée depuis la clôture de cette session — peut démarrer dès qu'une session lui sera dédiée [au 09/09/2026]
   → Accès temporisé (accord conclu ET 24 h avant scheduled_pickup_time), route VoiceChat et 2 wrappers, bandeau anti-partage, fermeture sur annulation, notifyVoiceChannelOpened ✅ (notification d'ouverture du canal ; aucune notification de réception d'un message vocal documentée)
   → Correctifs annexes : onOfferCreated jamais fourni (RÉSOLU 55), expo-av réinstallé (RÉSOLU 56)
   → Tests : ADMIN ✅ ; DRIVER partiel ; CLIENT non testé (décision assumée)
   → ⚠️ Parcours complet du canal vocal jamais testé — Phase 4.4
   → ⚠️ expo-av en fin de vie (SDK 55) — dette technique

2.15 ⏳ TrackingDetailScreen — REPORTÉE par décision du porteur avant la session 2.16 ; non reprogrammée au 17/10/2026

2.16 ✅ COMPLET (avec réserves) — Bouton déconnexion 3 rôles (14/09/2026)
   → handleSignOut() (authService.ts, non modifié) branché sur les 3 écrans d'accueil, confirmation préalable ✅
   → Tests ADMIN ✅ et DRIVER ✅ ; CLIENT non testé (décision assumée)
   → Suites : LogoutButton (2.21), messages alignés sur dialogs.ts (2.28)
   → ⚠️ Avertissement pointerEvents — anomalie préexistante sans conséquence

2.17 ✅ COMPLET — Réforme timing commission + workflow financier générique (14-19/09/2026)
   → Prélèvement anticipé de la commission (migration 024) ; workflow générique : 3 modes de paiement, justificatif (bucket payment-proofs, migration 025), PendingTransactionsScreen ✅
   → Remboursement sur demande du chauffeur ; rapprochement bancaire (migration 026, BankReconciliationScreen) ✅
   → Alerte de solde bas réparée (RÉSOLU 59) ; redirections des notifications (RÉSOLU 60)
   → Bug critique corrigé : transactions sans policy UPDATE (migration 027, RÉSOLU 61)
   → ⚠️ Rejet, screenMap, notifyDriverLowBalance, remboursement : non testés en réel

2.18 ⏳ Test fonctionnel complet voice-messages (Phase 4.4, RLS déjà déployée depuis 2.14 ter) — REQUALIFIÉE : canal vocal de bout en bout → Phase 4.4

ÉTAPE 2 ✅ CLOSE — Faille du rôle admin (03/10/2026, migration 028, RÉSOLU 62)

ÉTAPE 3 SÉCURITÉ ✅ CLOSE (avec réserves) — 05/10 → 14/10/2026
   → Volet 1 (protection financière), transitions, choix du chauffeur, volet 3 (double crédit), volet 4a (messages vocaux), volets 4b-1 à 4b-5 (documents, gardiens, changement de véhicule), volet 5 (lots A à E-ter) ✅ — migrations 029 à 053, RÉSOLU 63 à 79
   → Test réel du 14/10/2026 conforme (négociation avec un chauffeur)
   → ⏳ Volet 6 — configuration de la connexion : jamais examiné
   → ⚠️ Réserves de test consolidées en section « Tests de non-régression »

2.19 ✅ COMPLET — Audit systématique Alert.alert() (16/10/2026) — module utils/dialogs.ts, 25 messages dans 11 écrans (RÉSOLU 80) [prévu ⏳ au 09/09/2026]

2.20 ⏳ Correction route CreateParcel manquante + test flux e-commerce complet — reconfirmée comme périmètre également pour l'extension e-commerce du mécanisme de négociation (reportée depuis session 2.14 sexies)
   → ⚠️ ACTUALISÉ (17/10/2026) : REPORTÉE — le volet e-commerce sera examiné ultérieurement

2.21 ✅ COMPLET — BackButton, LogoutButton, AccountSuspendedScreen, reprise de l'inscription chauffeur (16/10/2026, RÉSOLU 81)
2.22 ✅ COMPLET — Totaux de l'historique des transactions (16/10/2026, RÉSOLU 82)
2.23 ✅ COMPLET — Prélèvement et messagerie par le serveur (16/10/2026, migration 054, RÉSOLU 83)
2.24 ✅ COMPLET — PostGIS dans extensions (16/10/2026, migration 055, RÉSOLU 84)
2.25 ✅ COMPLET — Avertissements du Security Advisor (16/10/2026, migration 056, RÉSOLU 85)
2.26 ✅ COMPLET — Sonnerie déclenchée par le serveur (16-17/10/2026, migration 057, RÉSOLU 86)
2.27 ✅ COMPLET — Erreurs TypeScript 34 → 19 (17/10/2026, RÉSOLU 87)
2.28 ✅ COMPLET — 13 anciens messages alignés sur dialogs.ts (17/10/2026)
2.29 ✅ COMPLET — Retrait du code mort, ménage des 131 copies .bak (17/10/2026)
   → ⚠️ Réserves de test des sessions 2.19 à 2.29 : voir section « Tests de non-régression »
   → PROCHAINE ÉTAPE : Phase 3, GPS compris (3.4 et 3.5 ci-dessous)

PHASE 3 — SERVICES EXTERNES
3.1 ⏳ Twilio SMS / 3.2 ⏳ FCM Android / 3.3 ⏳ APNs iOS
⚠️ DÉCISION DU PORTEUR (17/10/2026) : la phase GPS est traitée dans le cadre de la Phase 3, suivie des tests sur téléphone (Phase 4) et des versions installables (Phase 5). Les mentions historiques « Phase 4.x » des blocs antérieurs relatives au GPS sont conservées telles quelles et renvoient désormais à la Phase 3.5.
3.4 ⏳ Préparation du téléphone (compte rendu du 17/10/2026, C.2)
   → Raccorder à l'ouverture de l'application les 4 fonctions d'équipement du téléphone (autorisation, enregistrement de l'adresse de sonnerie via register-push-token, catégories Android, réaction au toucher d'une notification), sans effet sur la version web
   → Créer app.json et eas.json (nom, identifiants Android et iPhone, numéro de projet) ; comptes : Expo (gratuit), Firebase pour Android (gratuit), Apple Developer pour l'iPhone (payant, décision commerciale du porteur)
   → Vérifier en début de phase que l'Expo Go des magasins accepte encore Expo SDK 50 ; sinon produire une version de test (Phase 5) avant les tests sur téléphone
   → Tester la sonnerie sur un vrai téléphone et l'enregistrement par register-push-token
3.5 ⏳ GPS (compte rendu du 17/10/2026, C.2)
   → Création réelle de mission, recherche de chauffeurs proches, interrupteur « En service » et gardien de disponibilité, négociation avec plusieurs chauffeurs (y compris « Offre non retenue » en concurrence), prélèvement réel 24 h avant (y compris « solde insuffisant »), suivi de position pendant la course
   → Éléments déplacés depuis 4.3 : diffusion géospatiale réelle (RÉSOLU 51), soumission complète du flux transport avec scheduled_pickup_time, Volet 1 (fermeture automatique du modal), filtre admin expired, parcours de négociation de bout en bout, affichage réel des informations du chauffeur au client
   → Décider du sort de acceptMission (ancien mode « premier arrivé, premier servi ») et de findNearbyDrivers (l'accueil chauffeur interroge la base directement) ; revoir ce que renvoie find_nearby_drivers au chauffeur

PHASE 4 — TESTS DEVICE PHYSIQUE
4.1 ⏳ Tests Expo Go Android / 4.2 ⏳ Tests Expo Go iOS
4.3 ⏳ Tests utilisateurs réels — inclut désormais : chemin natif Alert.alert() (RÉSOLU 42), test complet des fonctions notify* mission + cloche Client, soumission complète du flux transport avec scheduled_pickup_time, test fonctionnel complet du Volet 1 (fermeture auto du modal), de la diffusion géospatiale réelle (branchée depuis 2.14 quinquies bis, RÉSOLU 51) et du filtre admin expired, ET (nouveau, session 2.14 sexies) test complet du parcours de négociation de prix de bout en bout (offre → contre-offre → double acceptation → MissionActive/MissionTracking) — en environnement disposant d'une géolocalisation fonctionnelle et de plusieurs comptes actifs simultanément (CLIENT + DRIVER) — non réalisable en Codespaces — ⚠️ ACTUALISÉ (17/10/2026) : les éléments GPS ci-dessus sont déplacés en Phase 3.5 par décision du porteur ; 4.3 conserve les tests sur téléphone hors GPS (chemin natif des messages — dialogs.ts —, fonctions notify* et cloche Client sur téléphone)
4.4 ⏳ Intégrer messages vocaux dans MissionTrackingScreen (audioService.ts + bucket voice-messages prêts, RLS sécurisée depuis 2.14 ter) — UI à construire — inclut le test fonctionnel complet de la clause RLS voice-messages en conditions réelles — ⚠️ ACTUALISÉ (17/10/2026) : « UI à construire » DÉPASSÉ (canal monté en session 2.14 septies) ; 4.4 = canal vocal de bout en bout (ouverture réelle à 24 h, envoi/réception d'un message vocal, fermeture sur annulation), y compris le test fonctionnel de la RLS voice-messages ; ancienne session 2.18 requalifiée

PHASE 5 — BUILD EAS
5.1 à 5.3 ⏳ — Environnement de staging à évaluer avant cette phase (proposé session 2.13), non déclenché
   → Si l'Expo Go des magasins n'accepte plus Expo SDK 50 (vérification en début de Phase 3), produire une version de test (Phase 5) avant les tests sur téléphone — compte rendu du 17/10/2026, C.2

PHASE 6 — AMÉLIORATIONS POST-TESTS
6.1 à 6.5 ⏳/✅ [statuts inchangés, voir Section 6] — ✅ ACTUALISÉ (17/10/2026) : 6.1, 6.2, 6.3 et 6.5 ✅ session 2.17 ; 6.4 ✅ session 2.16 — voir section « Modifications commitées — détail »
6.6 ✅/✅ SÉCURITÉ — RLS Storage : driver-documents ✅ (2.12), voice-messages ✅ CORRIGÉE (2.14 ter) — reste test fonctionnel Phase 4.4 — ✅ volet 4a (RÉSOLU 67)

PHASE 7 — PUBLICATION
7.1 ⏳ Google Play Store / 7.2 ⏳ Apple App Store

# RECOMMANDATIONS STRATÉGIQUES EN ATTENTE D'ARBITRAGE PORTEUR

(issues des sessions 2.13, 2.14, 2.14 bis, 2.14 ter, 2.14 quater, 2.14 quinquies, 2.14 quinquies bis et 2.14 sexies, non déclenchées dans l'immédiat)
(complétées le 17/10/2026 par les sessions 2.14 septies, 2.16, 2.17, l'étape 3 sécurité et les sessions 2.19 à 2.29 — volet e-commerce : le volet e-commerce sera examiné ultérieurement)

✅ RÉSOLUE — Correction de sécurité RLS voice-messages : traitée en session 2.14 ter (RÉSOLU 43). Reste seulement le test fonctionnel en Phase 4.4/session 2.18. Règles durcies au volet 4a (RÉSOLU 67) ; session 2.18 requalifiée en Phase 4.4 (canal vocal de bout en bout).
✅ RÉSOLUE — Correction de sécurité vues available_drivers/driver_dashboard : traitée en session 2.14 quinquies (RÉSOLU 48/49).
✅ RÉSOLUE — Correction de sécurité accès anon sur la table drivers : traitée en session 2.14 quinquies bis (RÉSOLU 52). Le cas authenticated de la même policy reste ouvert (voir ci-dessous). ✅ Cas authenticated fermé depuis (migration 034, RÉSOLU 65).
✅ RÉSOLUE — Devenir sémantique de negotiated_price : tranché concrètement par le trigger sync_mission_on_offer_accepted() en session 2.14 sexies — le prix affiché devient le prix réellement négocié à l'acceptation finale d'une offre (voir Section 2, Section 6).
✅ RÉSOLUE (session 2.19, complétée en 2.28 — RÉSOLU 80) — Audit systématique Alert.alert() — tous les usages du projet — idéalement session 2.19, avant Phase 3 active. Portée élargie : chemin natif non testé pour 3 fichiers déjà corrigés.
Environnement de staging — à évaluer avant Phase 5 (Build EAS) — décision et calendrier à trancher par le porteur.
Refonte du reporting financier — trois mécanismes de calcul non harmonisés — étude de faisabilité à programmer, hors périmètre 2.13.
Notification admin en temps réel sur nouvelle demande de recharge — renvoyée à la session 2.17. Session 2.17 : badge de comptage « Demandes financières » réagissant en temps réel aux données ; notification admin dédiée non documentée.
✅ RÉSOLUE (03/10/2026 — compte CLIENT +212600000002) — Second numéro de test dédié au rôle client — nécessaire pour le test complet des fonctions notify* mission, de la cloche côté client, ET désormais du parcours de négociation de prix de bout en bout (session 2.14 sexies). Point réactualisé : le numéro partagé étant actuellement DRIVER, cette recommandation reste pleinement d'actualité et voit son urgence renforcée par le nouveau mécanisme de négociation.
✅ RÉSOLUE (session 2.21, RÉSOLU 81) — Anomalie #1 — bouton "← Retour" manquant NotificationCenterScreen.tsx — non bloquante, rattachement session 2.19 ou point autonome, décision du porteur.
notifyDocumentExpiry — lien check-document-reminders non vérifié — à statuer isolément, session future. (Non documenté depuis le 09/09/2026 : statut inchangé.)
Bug de reconnexion clientProfileId vide (RootNavigator.tsx) — à documenter, session future non assignée. Voir note de rapprochement non tranchée avec RÉSOLU 53 (Section 10) et Section 16.
✅ RÉSOLUE (session 2.17, RÉSOLU 57) — Robustesse topupWallet/refundWallet — à vérifier par lecture directe en tout début de session 2.17. Reste le crédit atomique en base (voir NOUVELLE ci-dessous).
subscribeToDriverLocation (realtimeService.ts) — suivi de position en temps réel, non exploité, aucune session dédiée proposée à ce stade. Suivi de position pendant la course : Phase 3.5 (GPS).
✅ SANS OBJET (actualisation du 17/10/2026 : suppression en cascade, ces profils n'existent plus en base) — Décision sur la reconstitution ou l'abandon des profils DRIVER historiques orphelins (2ec2b439-..., wallet 800 DH ; profil créé en 2.14 quinquies, driverId inconnu) — décision et calendrier à trancher par le porteur. Point inchangé à l'issue des sessions 2.14 quinquies bis et 2.14 sexies.
Enrichissement fonctionnel scheduled_pickup_time (notifyRecipientBySMS, getClientParcels) — piste non assignée, à arbitrer.
Correction route CreateParcel — voir session 2.20 déjà créée pour ce traitement, reconfirmée devoir couvrir également l'extension e-commerce du mécanisme de négociation (session 2.14 sexies). Session 2.20 reportée : le volet e-commerce sera examiné ultérieurement.
✅ RÉSOLUE (étape 3, volet transitions, migration 032 — RÉSOLU 64) — Point de sécurité cancelMission/userId — vérification d'autorisation absente ; recommandation reconfirmée pour la session 2.17 (déjà actée session 2.14, reconfirmée pertinente 2.14 quater, reconfirmée préexistante et non aggravée 2.14 sexies).
✅ TRAITÉE PAR MÉTHODE (étape 3 sécurité : règle B4(b) — droits fixés dans chaque migration, inventaire relancé après ; pas de changement global des droits par défaut) — Audit des permissions par défaut (GRANT) sur l'ensemble du schéma public — constat initial lors de l'investigation de la faille sur available_drivers/driver_dashboard (session 2.14 quinquies), étendu par la découverte de l'exposition anon sur drivers (session 2.14 quinquies bis) puis par l'absence de WITH CHECK sur missions (session 2.14 sexies) — à programmer, aucune session dédiée assignée à ce stade. Ce point regroupe désormais plusieurs découvertes distinctes de sessions successives — voir NOUVELLE recommandation "cas authenticated de drivers_select_available" et "WITH CHECK absent sur missions" ci-dessous, qui s'y rattachent sans lui être fondues, chacune ayant sa propre origine et son propre statut.
Renforcement méthodologique CI/exécution réelle : après toute séquence de plusieurs commandes sed sur un même fichier, relecture structurelle complète + test d'exécution réelle obligatoires avant tout commit — règle consolidée Section 2, recommandation de vigilance continue.
✅ RÉSOLUE (migration 034, RÉSOLU 65) — NOUVELLE (session 2.14 quinquies bis) — Cas authenticated de la policy drivers_select_available : reste permissive pour tout utilisateur connecté sans filtre d'identité — décision produit à trancher (voulu ou oubli), non traité en session 2.14 sexies.
NOUVELLE (session 2.14 quinquies bis) — Test d'exécution réel du Volet A (diffusion géospatiale) : à réaliser en priorité dès qu'un environnement GPS fonctionnel sera disponible (device physique, Phase 4.x). → Phase 3.5 (GPS).
NOUVELLE (session 2.14 sexies) — Countdown serveur par tour (négociation de prix) : arbitrage à trancher — mécanisme existant d'expiration confirmé transposable si le porteur souhaite le réintégrer. (Non documenté depuis le 09/09/2026 : statut inchangé.)
✅ RÉSOLUE (volet 5, lot C — RÉSOLU 75) — NOUVELLE (session 2.14 sexies) — WITH CHECK absent sur la policy UPDATE de la table missions : décision explicite du porteur de reporter à une session future d'audit sécurité — à rattacher à la recommandation "audit des permissions GRANT par défaut" ci-dessus.
✅ SANS OBJET (constaté absent au 17/10/2026) — NOUVELLE (session 2.14 sexies) — Doublon mort NOTIF_ICONS dans pushNotificationService.ts : nettoyage possible dans une session future touchant ce fichier. [Coquille « NOT_ICONS » corrigée le 17/10/2026.]
NOUVELLE (session 2.14 sexies) — Cause de l'incident réseau/tunnel Codespaces : à surveiller, documenter précisément les conditions de déclenchement si récurrent, pour investigation dédiée.
✅ RÉSOLUE (volet 5, lot D-bis — RÉSOLU 77) — NOUVELLE (session 2.14 sexies) — Erreur CORS send-push-notification : à vérifier si elle se manifeste aussi hors environnement Codespaces (device physique), auquel cas investigation dédiée sur la configuration CORS de l'Edge Function.
NOUVELLE (session 2.14 sexies) — Test de bout en bout du parcours de négociation de prix complet : à programmer dès que possible, environnement GPS fonctionnel + plusieurs comptes simultanés (device physique).
   → Test réel du 14/10/2026 conforme avec un chauffeur ; négociation avec plusieurs chauffeurs : Phase 3.5 (GPS).
NOUVELLE (session 2.14 septies) — Migration d'expo-av vers expo-audio/expo-video à anticiper avant toute montée vers Expo SDK 55+.
NOUVELLE (session 2.16) — Réinitialisation explicite des états de profil sur SIGNED_OUT : par précaution, si RootNavigator.tsx est restructuré.
NOUVELLE (session 2.16) — Avertissement pointerEvents : origine non localisée ; classé sans conséquence (anomalie préexistante de React Native sur le web, compte rendu du 17/10/2026) — aucune action requise à ce stade.
NOUVELLE (session 2.16) — Test CLIENT du bouton de déconnexion : désormais possible avec le compte CLIENT dédié ; non documenté à ce jour.
NOUVELLE (session 2.17) — processed_at : à renseigner dans validatePendingTransaction() lors d'une prochaine intervention sur ce fichier.
NOUVELLE (session 2.17) — Tests réels à programmer : rejet d'une demande (rejectPendingTransaction) ; redirections des notifications (5 destinations ajoutées ou corrigées, en particulier MissionOfferScreen) ; notifyDriverLowBalance() (passage du solde sous 100 DH, contenu du message, absence de répétition) ; remboursement (requestRefund) ; prérequis notifications missions (Point 7) dès l'abonnement aux services externes, avant toute mise en production.
NOUVELLE (session 2.17) — canDriverAcceptMission() : code mort, redondant tant que le seuil (100 DH) reste supérieur à la commission maximale (50 DH) — à reconsidérer si l'un de ces paramètres change.
NOUVELLE (étape 3, volet 6) — Configuration de la connexion : jamais examinée.
NOUVELLE (étape 3) — Robustesse du portefeuille : crédit atomique en base (topupWallet, recharge directe par l'admin) — option 2 du volet 3.
NOUVELLE (étape 3) — Plaque du véhicule visible par le client 24 h avant la mission (sur le modèle du canal vocal et de la tâche 2.23).
NOUVELLE (étape 3) — Nom du chauffeur affiché au client : quand l'inscription séparera nom et prénom (ProfileSetupScreen.tsx, fichier protégé).
NOUVELLE (étape 3) — Champs obligatoires à l'inscription avant la production (dates de la carte grise déjà obligatoires) ; plaque saisie une seule fois ; capacité laissée vide ; rappels d'expiration pour la carte grise et mise à jour au remplacement ; écran d'attente (lecture des statuts, route de sortie) ; fichier orphelin dans le stockage.
NOUVELLE (session 2.23) — Solde insuffisant au moment du prélèvement : une règle plus stricte (annulation ou réattribution de la mission) reste une décision métier.
NOUVELLE (Phase 3) — Sort de acceptMission (ancien mode « premier arrivé, premier servi », code mort) et de findNearbyDrivers (l'accueil chauffeur interroge la base directement) ; réexamen de ce que renvoie find_nearby_drivers au chauffeur avec le GPS.
NOUVELLE (session 2.25) — 8 avertissements acceptés du Security Advisor : à réexaminer si le fonctionnement concerné évolue (par exemple le suivi public des colis).
NOUVELLE (étape 3) — Tests réels faisables sans GPS, dès accord du porteur : double clic réel sur « Valider » une recharge ; exécution manuelle de block_drivers_with_expired_documents().
NOUVELLE (session 2.27) — Erreur rouge de la console du navigateur notée en 2.27, non identifiée, non réapparue en 2.28 et 2.29 — à surveiller.
Volet e-commerce : le volet e-commerce sera examiné ultérieurement.

# 18. ANNEXE — INVESTIGATION SESSION 2.14 — PROCESSUS DE CRÉATION DE MISSION : ÉTAT ACTUEL ET PISTES D'AMÉLIORATION

[Contenu inchangé — reprise intégrale du point zéro de l'investigation, préservé tel quel sans réécriture, y compris l'avertissement de numérotation entre les deux systèmes Piste 1-4. Voir version du 25/08/2026, qui renvoyait elle-même à la version du 11/08/2026 pour le texte complet des sections § 1 à § 5 et du § TRI — ce texte complet n'a pas été retransmis à la présente conversation dans le cadre de cette actualisation (voir liste de suivi anomalie #18, Section 6).]

Mise à jour de statut (session 2.14 quater) : la Piste "Planification par date/heure" est désormais traitée — voir Section 6, bloc "SESSION 2.14 quater", et RÉSOLU 47.

Mise à jour de statut (session 2.14 quinquies) : la Piste "Diffusion optimisée" (§ TRI, Piste 1) est partiellement traitée — infrastructure sécurisée et cartographiée, Volets 1 et 2 implémentés et déployés.

Mise à jour de statut (session 2.14 quinquies bis) : la Piste "Diffusion optimisée" (§ TRI, Piste 1) est désormais intégralement traitée — le branchement du filtrage réel par distance a été réalisé et déployé (RÉSOLU 51), avec réserve du test d'exécution en conditions réelles (GPS), non réalisable en Codespaces.

Mise à jour de statut (session 2.14 sexies) : la Piste "Négociation de prix structurée" (§ TRI, Piste 2) est désormais traitée — table mission_offers, schéma en 2 tours avec double acceptation symétrique, mécanisme intégralement implémenté et déployé (voir Section 6, bloc "SESSION 2.14 sexies"), avec réserve du test de bout en bout en conditions réelles, non réalisable en Codespaces.

Mise à jour de statut (session 2.14 septies) : la Piste 4 « canal vocal » est désormais traitée — accès temporisé (24 h), bandeau anti-partage, fermeture sur annulation (voir section « Modifications commitées — détail », bloc « SESSION 2.14 septies »), avec réserve du test de bout en bout (Phase 4.4).

Mise à jour de statut (actualisation du 17/10/2026) : négociation testée en réel le 14/10/2026 avec un chauffeur (étape 3, volet 5) ; réserves GPS des Pistes 1 et 2 renvoyées en Phase 3.5 (décision du porteur du 17/10/2026).

# 18 bis. ANNEXE — SESSION 2.14 bis — SYNTHÈSE DE L'INVESTIGATION ET PLAN D'ACTION (PROCESSUS DE CRÉATION DE MISSION)

[Contenu inchangé — reprise intégrale.]

Synthèse ultra-condensée pour navigation rapide — MISE À JOUR :
Piste 1 (diffusion) : ✅ TRAITÉE INTÉGRALEMENT — infrastructure sécurisée et cartographiée (session 2.14 quinquies, RÉSOLU 48/49/50), branchement du filtrage réel par distance réalisé et déployé (session 2.14 quinquies bis, RÉSOLU 51) — réserve : test d'exécution en conditions réelles (GPS), Phase 4.x — renvoyé en Phase 3.5 (GPS), décision du porteur du 17/10/2026
Piste 2 (négociation) : ✅ TRAITÉE — nouvelle table mission_offers, schéma en 2 tours, double acceptation symétrique, mécanisme intégralement implémenté et déployé (session 2.14 sexies, RÉSOLU 53/54) — réserve : test de bout en bout en conditions réelles, Phase 4.x — test réel du 14/10/2026 conforme avec un chauffeur (volet 5, RÉSOLU 79) ; négociation avec plusieurs chauffeurs : Phase 3.5 (GPS)
Piste 3 (planification) : ✅ TRAITÉE, session 2.14 quater (voir RÉSOLU 47)
Piste 4 (canal vocal) : ✅ TRAITÉE, session 2.14 septies (14/09/2026) — accès temporisé 24 h, bandeau anti-partage, fermeture sur annulation ; annonce par le serveur depuis 2.23 — réserve : test de bout en bout, Phase 4.4 [statut au 09/09/2026 : « conservé, activation en dernier — ⏳ 2.14 septies, dépendance désormais UNIQUE ET LEVÉE (2.14 sexies clôturée) — prêt à démarrer »]
Hors piste : sécurité voice-messages — ✅ TRAITÉE, session 2.14 ter (RÉSOLU 43) ; sécurité available_drivers/driver_dashboard — ✅ TRAITÉE, session 2.14 quinquies (RÉSOLU 48/49) ; sécurité table drivers (accès anon) — ✅ TRAITÉE, session 2.14 quinquies bis (RÉSOLU 52) ; sécurité WITH CHECK missions — ⏳ EN ATTENTE, reportée à une session future d'audit sécurité (session 2.14 sexies) → ✅ COUVERTE, volet 5 lot C (RÉSOLU 75) ; étape 3 sécurité (volets 1 à 5) — ✅ CLOSE (RÉSOLU 62 à 79)

⚠️ NOTE (actualisation du 09/09/2026) — Référent "Bloc A" : le compte-rendu de la session 2.14 quinquies bis mentionne une réserve jamais levée portant sur le « texte complet de l'annexe ROADMAP (Bloc A) », suggérant une correspondance possible avec une distinction "Bloc A"/"Bloc B" qui existerait dans le "§ TRI" évoqué en Section 18 ci-dessus. Cette correspondance a été suggérée lors de la préparation de la présente actualisation, mais n'a pas pu être vérifiée par lecture directe du texte intégral du § TRI, celui-ci n'ayant pas été retransmis à la présente conversation (voir liste de suivi anomalie #18, Section 6). Elle n'est donc pas retenue comme fait établi dans le présent document.

# TEMPLATE DÉBUT DE SESSION CLAUDE

PROJET : Fast Trans Maroc (FTM)
STACK : Expo SDK 50 (50.0.21) / React Native 0.73.4 / TypeScript — PostgreSQL 17.6, PostGIS 3.3.7 (schéma extensions)
SUPABASE : ustckqnecsilxqlyjute
GITHUB : ELALAMIGIT61/FAST-TRANS-MAROC-FTM
HEAD DE RÉFÉRENCE : bcff143 (17/10/2026) — à la reprise : git --no-pager log --oneline -1 doit afficher bcff143, et git status --short doit être vide

RÈGLES CRITIQUES :
NE JAMAIS npm audit fix --force
SDK 50 stable — 39 vulnerabilities outils dev (63 observées en session 2.14 septies, même catégorie — ne jamais corriger avec --force)
.env dans frontend/
1 terminal de travail uniquement
Vérifier pwd avant tout npx expo start
Vérifier texte exact via sed avant replace()
Si replace() échoue → réécrire fichier entier
Vérifier contenu exact via repr() Python (jamais cat)
Tout texte avec caractère spécial bash (!, `, $, ) → heredoc à délimiteur quoté, jamais python3 -c "..." — ⚠️ depuis l'étape 3 : longs collages heredoc proscrits (tronqués par le terminal du navigateur) ; nouveaux fichiers livrés par paquet base64 contrôlé, fichiers existants modifiés par script à ancres
NE JAMAIS exécuter de commande SQL de modification de schéma directement en SQL Editor — toujours via fichier de migration + GitHub Actions — seule exception accordée : répétition à blanc, annulée, de la migration 055 (session 2.24)
Indexation storage.foldername() : vérifier l'indice par simulation, ne jamais le copier d'un pattern à convention de chemin différente
Lecture intégrale obligatoire, y compris pour les fichiers de référence/modèle non modifiés
CI vert (Vérification Qualité Code) ne garantit pas que le code compile/s'exécute réellement : après toute séquence de plusieurs sed sur un même fichier, relecture structurelle complète + test d'exécution réel obligatoires (règle consolidée session 2.14 quinquies)
NOUVEAU — Vérification systématique de git status avant tout commit (règle consolidée session 2.14 sexies, a permis de détecter une omission réelle de fichier)
git pull --rebase avant tout push (⚠️ procédure de déploiement décrite comme non utilisée depuis le volet 4b-5 — voir section « Règles critiques »)
Migrations via GitHub uniquement
NE JAMAIS modifier authService.ts / ProfileSetupScreen.tsx / driverService.ts / wallet_update_admin / AdminUsersScreen.tsx / AdminMissionsScreen.tsx (exceptions accordées : une ligne de ProfileSetupScreen.tsx en 2.27 ; deux lignes et un import de AdminUsersScreen.tsx en 2.28)
NE JAMAIS modifier les 3 workflows GitHub Actions (check_supabase, deploy_supabase, lint_code)
NE JAMAIS supprimer les comptes de test admin (+212600000001) et chauffeur (+212600000000) sans décision explicite du porteur
RootNavigator.tsx : très fréquemment modifié (9 modifications rien qu'en session 2.14 sexies) — non classé ⛔ officiellement, mais à traiter avec vigilance accrue vu le volume cumulé de changements
Backup obligatoire avant toute modification — ⚠️ REMPLACÉ : script Python à empreinte SHA256 et ancres uniques (count == 1), arrêt « rien n'a été modifié » au moindre écart ; plus de copies .bak (131 archivées et supprimées le 17/10/2026)
Ne jamais retester ce qui est écarté / Ne jamais modifier ce qui fonctionne
vault.create_secret(valeur, nom, desc) — valeur EN PREMIER
timeout_milliseconds := 30000 pour net.http_post
cron.unschedule() WHERE EXISTS avant tout cron.schedule()
Alert.alert() ne s'affiche pas sur web — toujours Platform.OS === 'web' ? window.alert(...) : Alert.alert(...) (3 fichiers corrigés : AdminUsersScreen, WalletTopupScreen, PendingVerificationScreen — chemin natif non testé) — ✅ depuis la session 2.19 : utiliser utils/dialogs.ts (showMessage, confirmAction)
DateTimeField.tsx : nécessite le même traitement différencié web/natif — voir RÉSOLU 44/45/46
✅ Vues available_drivers / driver_dashboard SÉCURISÉES (session 2.14 quinquies) — voir RÉSOLU 48/49
✅ Table drivers SÉCURISÉE pour le rôle anon (session 2.14 quinquies bis) — voir RÉSOLU 52 — ⚠️ cas authenticated de drivers_select_available toujours ouvert → ✅ fermé depuis (migration 034, RÉSOLU 65)
✅ Diffusion géospatiale par distance réelle BRANCHÉE ET DÉPLOYÉE (session 2.14 quinquies bis) — rayon 60km, cast geography HEXEWKB corrigé, fail-open — voir RÉSOLU 51 — ⚠️ test d'exécution en conditions réelles (GPS) toujours en attente → Phase 3.5
✅ Mécanisme de négociation de prix structuré OPÉRATIONNEL (session 2.14 sexies) — table mission_offers, 2 tours max, double acceptation symétrique obligatoire — voir Section 6/9/15 — ⚠️ test de bout en bout en conditions réelles toujours en attente ; countdown serveur par tour toujours en arbitrage ouvert — ✅ test réel du 14/10/2026 conforme (un chauffeur) après le volet 5 (E-bis/E-ter)
⚠️ Numéro de test partagé +212600000000 : ACTUELLEMENT EN RÔLE DRIVER depuis session 2.14 sexies — nouveau profil a53521ca-c776-4b57-8370-5d934f2bb416 (is_verified = true, wallet 1000 DH, catégorie VUL, 4 documents validés). Tous les profils antérieurs (2ec2b439-..., profil de 2.14 quinquies, profil(s) CLIENT intermédiaire(s)) restent orphelins d'accès Auth, données intactes en base. Un seul rôle actif à la fois — envisager un second numéro dédié au rôle Client avant toute session nécessitant un parcours de mission complet (Client + Driver simultanés), désormais également requis pour tester le mécanisme de négociation de prix de bout en bout. ⚠️ DÉPASSÉ (17/10/2026) : 3 comptes de test — ADMIN +212600000001 ; CHAUFFEUR +212600000000 (driverId a53521ca-c776-4b57-8370-5d934f2bb416, profileId 309967af-404b-4658-9c1a-a52b6cd16204, N2 Moyen, 4 500 DH, non disponible) ; CLIENT +212600000002 (profileId 08672d5c-96f1-42f0-81ab-bb74611ae95c, créé le 03/10/2026) — code 123456, valides jusqu'au 31/12/2026, à retirer avant la production ; un seul onglet (deux comptes ne peuvent pas être connectés en même temps) ; suppression Auth = suppression en cascade (les profils antérieurs n'existent plus).
✅ RLS voice-messages CORRIGÉE (session 2.14 ter) — reste le test fonctionnel en Phase 4.4/session 2.18 — ✅ canal monté (2.14 septies), règles durcies (volet 4a) ; test de bout en bout en Phase 4.4
✅ scheduled_pickup_time OBLIGATOIRE (NOT NULL) depuis session 2.14 quater — transport ET e-commerce
✅ Volets 1 (fermeture auto modal, rôle requalifié depuis 2.14 sexies) et 2 (expiration mission pending) OPÉRATIONNELS depuis session 2.14 quinquies
⚠️ Bug découvert : route 'CreateParcel' non déclarée en navigation — session 2.20 à traiter (couvre également l'extension e-commerce de la négociation) — session 2.20 reportée : le volet e-commerce sera examiné ultérieurement
⚠️ WITH CHECK absent sur la policy UPDATE de missions — décision explicite du porteur de report à une session future d'audit sécurité (session 2.14 sexies) → ✅ COUVERT, volet 5 lot C (RÉSOLU 75)
Chantier "amélioration processus de création de mission" : 2.14 ter ✅, 2.14 quater ✅, 2.14 quinquies ✅, 2.14 quinquies bis ✅, 2.14 sexies ✅ (avec réserves) — chantier des 8 sessions désormais COMPLET ; reste 2.14 septies (dépendance levée, prête à démarrer) — voir Section 6/18/18 bis pour détails → ✅ 2.14 septies CLÔTURÉE le 14/09/2026 : chantier complet
✅ Session 2.16 : déconnexion 3 rôles (puis LogoutButton en 2.21) — ✅ Session 2.17 : commission anticipée, workflow financier générique, rapprochement bancaire
✅ Étape 2 (rôle admin) et étape 3 sécurité (volets 1 à 5) CLOSES — ⏳ volet 6 (configuration de la connexion) jamais examiné
✅ Sessions 2.19, 2.21 à 2.29 CLOSES (16-17/10/2026) — 2.15 et 2.20 reportées, 2.18 requalifiée (Phase 4.4)
NOUVEAU — Règle B4(b) : toute nouvelle fonction ou vue reçoit par défaut tous les droits pour anon et authenticated — fixer les droits explicitement dans la migration qui la crée, puis relancer l'inventaire
NOUVEAU — Écriture en base : toujours vérifier le nombre de lignes modifiées (une écriture bloquée par RLS échoue en silence)
NOUVEAU — tsc --noEmit après toute modification, comparé à la référence (19 erreurs, toutes dans parcelService.ts) — jamais en absolu
NOUVEAU — Rollbacks dans supabase/rollbacks/, jamais dans migrations/ (incident 2.17, RÉSOLU 58) ; échec CI « rate limit exceeded » → « Re-run failed jobs »
NOUVEAU — Une commande à la fois ; tests sur la vraie base dans une transaction annulée ; copie locale de la base pour tester chaque migration (avant, après, après rollback)
Commission : prélevée par le SERVEUR 24 h avant la date prévue (tâche process-missions-24h, session 2.23) ; sonnerie déclenchée par le SERVEUR (session 2.26) — aucun téléphone encore enregistré (ni app.json ni eas.json)
PROCHAINE ÉTAPE : Phase 3 (3.1 Twilio, 3.2 FCM, 3.3 APNs, 3.4 préparation du téléphone, 3.5 GPS) — vérifier en début de phase qu'Expo Go accepte encore Expo SDK 50
Volet e-commerce : le volet e-commerce sera examiné ultérieurement
Prochain timestamp migration : 20260504000058 (024 à 057 consommés au 17/10/2026)

OBJECTIF SESSION : [Décrire précisément]

ERREUR ACTUELLE : [Coller l'erreur si applicable]
