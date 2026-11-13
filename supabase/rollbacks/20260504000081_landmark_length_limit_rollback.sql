-- Rollback de la migration 20260504000081 (limite de longueur du repere).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Retire la regle des 200 caracteres sur les reperes de la partie verrouillee ;
-- aucune donnee n'est modifiee. L'application continue de limiter la saisie.

ALTER TABLE public.mission_exact_locations
  DROP CONSTRAINT IF EXISTS mission_exact_locations_landmarks_length;
