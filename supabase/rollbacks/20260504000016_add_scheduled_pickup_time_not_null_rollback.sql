-- Rollback pour migration 20260504000016_add_scheduled_pickup_time_not_null.sql
-- Session 2.14 quater — Contrainte NOT NULL sur missions.scheduled_pickup_time
--
-- ATTENTION : ce rollback SQL seul est insuffisant en cas de déploiement partiel.
-- Il retire uniquement la contrainte NOT NULL en base. Si le code applicatif modifié
-- dans cette session (CreateMissionScreen.tsx, CreateParcelScreen.tsx, missionService.ts,
-- parcelService.ts) a déjà été déployé, ces fichiers continueront d'exiger et de
-- transmettre scheduled_pickup_time côté TypeScript, indépendamment de ce rollback.
-- Un rollback complet nécessite un git revert coordonné du code applicatif correspondant.
-- Ne jamais exécuter ce rollback seul sans vérifier l'état du code applicatif en parallèle.
--
-- En cas de rollback complet nécessaire : exécuter D'ABORD ce rollback SQL,
-- PUIS le git revert du code applicatif — jamais l'inverse, sous peine de
-- bloquer toute création de mission (code ne transmettant plus le champ,
-- contrainte NOT NULL toujours active en base).

ALTER TABLE missions ALTER COLUMN scheduled_pickup_time DROP NOT NULL;
