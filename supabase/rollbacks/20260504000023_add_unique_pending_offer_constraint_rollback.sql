-- Rollback migration 20260504000023
-- Retire l'index unique partiel sur mission_offers (mission_id, driver_id)
-- WHERE status = 'pending'.
-- ATTENTION : après ce rollback, un même chauffeur pourra à nouveau créer
-- plusieurs offres 'pending' simultanées sur la même mission — réintroduit
-- le risque d'ambiguïté sur le calcul de round_number identifié en 2.14 sexies.

DROP INDEX IF EXISTS public.mission_offers_unique_pending_offer_per_driver;
