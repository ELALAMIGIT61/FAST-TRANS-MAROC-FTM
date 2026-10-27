-- Rollback de la migration 20260504000069 (notifications de la vie d'une mission, F8).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Attention : sans cette migration, ces notifications ne partent plus (l'application
-- corrigee ne les envoie plus elle-meme).
DROP TRIGGER IF EXISTS missions_status_notifications ON public.missions;
DROP FUNCTION IF EXISTS public.on_mission_status_notify();
