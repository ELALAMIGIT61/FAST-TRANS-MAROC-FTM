-- Migration 20260504000061 - point A1, F7 : suppression et nettoyage des
-- notifications (decision du porteur du 25/10/2026)
--
-- Constat : les notifications s'accumulaient sans fin. Clients et chauffeurs
-- ne pouvaient que les marquer comme lues ; aucune suppression, aucun menage.
--
-- 1. Policy notifications_delete_own : chaque utilisateur peut supprimer ses
--    propres notifications (et seulement les siennes).
-- 2. Fonction purge_old_notifications() (systeme uniquement) :
--    - notification liee a une mission (data.mission_id) : supprimee 30 jours
--      apres la fin de la mission (terminee, annulee ou expiree) ; jamais tant
--      que la mission est en attente, acceptee ou en cours ;
--    - notification sans mission (ou mission introuvable) : supprimee 30 jours
--      apres avoir ete lue, et dans tous les cas apres 90 jours.
--    Les traces financieres (transactions du wallet) ne sont pas concernees.
-- 3. Tache planifiee « purge-old-notifications » chaque nuit a 03:17 (UTC).

-- 1
DROP POLICY IF EXISTS notifications_delete_own ON public.notifications;
CREATE POLICY notifications_delete_own
  ON public.notifications FOR DELETE
  TO authenticated
  USING (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

-- 2
CREATE OR REPLACE FUNCTION public.purge_old_notifications()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_count integer;
BEGIN
  DELETE FROM public.notifications
  WHERE id IN (
    SELECT n.id
    FROM public.notifications n
    LEFT JOIN public.missions m ON m.id::text = n.data->>'mission_id'
    WHERE CASE
      WHEN m.id IS NOT NULL THEN
        m.status IN ('completed', 'cancelled_client', 'cancelled_driver', 'expired')
        AND coalesce(m.completed_at, m.updated_at) < now() - interval '30 days'
      ELSE
        (n.is_read AND coalesce(n.read_at, n.created_at) < now() - interval '30 days')
        OR n.created_at < now() - interval '90 days'
    END
  );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.purge_old_notifications() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.purge_old_notifications() TO service_role;

-- 3
SELECT cron.unschedule('purge-old-notifications')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-old-notifications');

SELECT cron.schedule(
  'purge-old-notifications',
  '17 3 * * *',
  $$ SELECT public.purge_old_notifications(); $$
);
