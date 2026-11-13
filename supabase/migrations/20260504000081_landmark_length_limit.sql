-- Migration 20260504000081 - limite de longueur du repere (suite du lot 5)
-- (validee par le porteur le 13/11/2026 ; aucun fichier protege modifie)
--
-- Constat du lot 5 : la limite de 200 caracteres du repere portait sur la table
-- missions, mais le serveur retire le repere de la fiche publique AVANT ce
-- controle et le range dans la partie verrouillee (mission_exact_locations),
-- qui n'avait pas de limite. Un repere de plus de 200 caracteres envoye hors de
-- l'application etait donc accepte.
-- Correction : meme limite (200 caracteres) sur les deux reperes de la partie
-- verrouillee. Une mission envoyee avec un repere trop long est refusee.
-- Aucune fonction, aucun droit et aucune donnee ne sont modifies.
-- Controle avant du 13/11/2026 : 25 lignes, 0 repere, 0 repere trop long.

ALTER TABLE public.mission_exact_locations
  DROP CONSTRAINT IF EXISTS mission_exact_locations_landmarks_length;
ALTER TABLE public.mission_exact_locations
  ADD CONSTRAINT mission_exact_locations_landmarks_length
  CHECK (char_length(coalesce(pickup_landmark, '')) <= 200
         AND char_length(coalesce(dropoff_landmark, '')) <= 200);
