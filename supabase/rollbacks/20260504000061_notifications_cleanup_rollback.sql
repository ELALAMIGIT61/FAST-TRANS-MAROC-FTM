-- Rollback de la migration 20260504000061 (point A1, F7)
-- Retire la tache de nettoyage, la fonction et le droit de suppression des
-- utilisateurs (la policy admin existante est conservee).
-- NE JAMAIS placer ce fichier dans supabase/migrations/.

SELECT cron.unschedule('purge-old-notifications')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-old-notifications');

DROP FUNCTION IF EXISTS public.purge_old_notifications();
DROP POLICY IF EXISTS notifications_delete_own ON public.notifications;
