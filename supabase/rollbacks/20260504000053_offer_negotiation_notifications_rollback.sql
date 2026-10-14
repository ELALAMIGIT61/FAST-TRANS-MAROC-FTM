-- Rollback de la migration 20260504000053 (volet 5, lot E-ter)
-- A appliquer apres avoir remis l'ancienne version de missionService.ts
-- (sinon plus aucune notification de negociation ne serait envoyee).

DROP TRIGGER IF EXISTS notify_mission_offer_events_trigger ON public.mission_offers;
DROP FUNCTION IF EXISTS public.notify_mission_offer_events();
