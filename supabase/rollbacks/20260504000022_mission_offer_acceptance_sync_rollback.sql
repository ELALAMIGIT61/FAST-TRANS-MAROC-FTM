-- Rollback migration 20260504000022
-- Session 2.14 sexies
--
-- Supprime le trigger de synchronisation automatique missions <-
-- mission_offers et la fonction associee. N'affecte pas les donnees
-- deja synchronisees par ce trigger avant son execution (les missions
-- deja attribuees le restent).
--
-- ATTENTION : apres ce rollback, l'acceptation finale d'une offre
-- (client_accepted ET driver_accepted = true) ne mettra plus a jour
-- automatiquement missions.driver_id/status/negotiated_price, ni ne
-- clora les autres offres concurrentes. Ce comportement devra alors
-- etre gere manuellement ou reimplemente cote applicatif.

DROP TRIGGER IF EXISTS sync_mission_on_offer_accepted_trigger ON public.mission_offers;
DROP FUNCTION IF EXISTS public.sync_mission_on_offer_accepted();
