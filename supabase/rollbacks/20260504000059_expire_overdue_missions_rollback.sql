-- Rollback de la migration 20260504000059 (point A1, correction 24)
-- Retire la tache planifiee, le trigger et les deux fonctions. L'expiration
-- redevient faite par l'application seule (ecran de suivi du client).
-- NE JAMAIS placer ce fichier dans supabase/migrations/.

SELECT cron.unschedule('expire-overdue-missions')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire-overdue-missions');

DROP TRIGGER IF EXISTS missions_on_expired ON public.missions;
DROP FUNCTION IF EXISTS public.on_mission_expired();
DROP FUNCTION IF EXISTS public.expire_overdue_missions();
