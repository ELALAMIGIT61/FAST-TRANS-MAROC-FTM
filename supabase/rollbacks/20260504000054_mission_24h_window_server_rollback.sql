-- Rollback de la migration 20260504000054 (session 2.23)
-- Retablit l'etat anterieur, faille comprise (prelevement declenchable par tout
-- utilisateur connecte) : a n'utiliser qu'en cas de blocage, et avec la version
-- precedente de l'application (declenchement par l'ecran de la mission).

SELECT cron.unschedule('process-missions-24h')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-missions-24h');

DROP FUNCTION IF EXISTS public.process_missions_24h_window();

GRANT EXECUTE ON FUNCTION public.charge_commission_anticipated(uuid) TO authenticated;

ALTER TABLE public.missions
  DROP COLUMN IF EXISTS voice_channel_notified_at,
  DROP COLUMN IF EXISTS commission_alert_sent_at;
