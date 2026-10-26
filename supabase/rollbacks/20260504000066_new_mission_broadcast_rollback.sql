-- Rollback de la migration 20260504000066 (notification « Nouvelle mission », F1).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
DROP TRIGGER IF EXISTS missions_on_created ON public.missions;
DROP FUNCTION IF EXISTS public.on_mission_created();
DROP FUNCTION IF EXISTS public.driver_mission_in_range(uuid);
DROP FUNCTION IF EXISTS public.driver_schedule_conflict(uuid, uuid);
DROP FUNCTION IF EXISTS public.mission_in_driver_range(uuid, uuid);
DELETE FROM public.app_settings WHERE key LIKE 'broadcast_radius_km_%';
