-- Rollback de la migration 20260504000070 (ecran « Missions disponibles », F2).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
DROP FUNCTION IF EXISTS public.driver_pending_offers();
DROP FUNCTION IF EXISTS public.driver_open_missions();
