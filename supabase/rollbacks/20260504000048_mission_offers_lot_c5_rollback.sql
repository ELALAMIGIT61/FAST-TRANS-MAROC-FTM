-- Rollback de la migration 20260504000048 (volet 5, lot C5)
-- Restaure : suppression du gardien des offres, sync_mission_on_offer_accepted
-- et process_commission_payment en SECURITY INVOKER sans chemin fixe, droits
-- d'origine sur mission_offers.
-- ATTENTION : retablit l'etat ou la double acceptation n'attribue pas la mission.
-- A executer uniquement sur decision du porteur.

DROP TRIGGER IF EXISTS protect_mission_offer_fields ON public.mission_offers;
DROP FUNCTION IF EXISTS public.protect_mission_offer_fields();

ALTER FUNCTION public.sync_mission_on_offer_accepted() SECURITY INVOKER;
ALTER FUNCTION public.sync_mission_on_offer_accepted() RESET search_path;

ALTER FUNCTION public.process_commission_payment() SECURITY INVOKER;
ALTER FUNCTION public.process_commission_payment() RESET search_path;

GRANT INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.mission_offers TO anon;
GRANT DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.mission_offers TO authenticated;
