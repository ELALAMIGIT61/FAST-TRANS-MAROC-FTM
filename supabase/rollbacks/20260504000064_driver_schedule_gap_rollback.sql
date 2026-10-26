-- Rollback de la migration 20260504000064 (ecart minimum entre missions).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
DROP TRIGGER IF EXISTS check_driver_schedule_conflict ON public.mission_offers;
DROP FUNCTION IF EXISTS public.check_driver_schedule_conflict();
DROP TABLE IF EXISTS public.app_settings;
