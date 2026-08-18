-- Migration 20260504000016 — Session 2.14 quater
-- Rendre scheduled_pickup_time obligatoire (contrainte NOT NULL) sur la table missions.
--
-- Contexte : le champ scheduled_pickup_time existait déjà (nullable) mais n'était jamais
-- renseigné par le code applicatif jusqu'à cette session. La table missions est vide en
-- production au moment de cette migration (0 ligne) — aucune donnée existante à migrer
-- ou à traiter avant l'ajout de la contrainte.
--
-- Portée : cette contrainte s'applique à TOUTE insertion dans missions, y compris le flux
-- e-commerce (mission_type = 'ecommerce_parcel'), par dérogation explicite du porteur au
-- Bloc 6 du prompt de mission (voir compte-rendu de session pour justification).
--
-- Prérequis applicatif : le code doit transmettre scheduled_pickup_time à l'insertion
-- avant l'exécution de cette migration (CreateMissionScreen.tsx, CreateParcelScreen.tsx,
-- missionService.ts, parcelService.ts déjà modifiés dans cette session).

ALTER TABLE missions ALTER COLUMN scheduled_pickup_time SET NOT NULL;
