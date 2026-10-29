-- Rollback de la migration 20260504000071 (F9 : missions conclues non demarrees
-- et missions en cours non cloturees).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Les missions deja cloturees automatiquement gardent leur etat.
SELECT cron.unschedule('process-overdue-missions')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-overdue-missions');
DROP FUNCTION IF EXISTS public.process_overdue_missions();
ALTER TABLE public.missions DROP COLUMN IF EXISTS start_reminder_sent_at;
ALTER TABLE public.missions DROP COLUMN IF EXISTS auto_closed_at;
DELETE FROM public.app_settings
WHERE key LIKE 'start_reminder_hours_%'
   OR key LIKE 'not_started_close_hours_%'
   OR key LIKE 'in_progress_close_hours_%';
