-- Migration 20260504000059 - point A1, correction 24 : expiration des missions
-- en attente par le serveur (accord du porteur du 24/10/2026, choix (a) pour
-- les offres)
--
-- Constat (24/10/2026, test sur deux telephones) : une mission en attente dont
-- l'heure de prise en charge est depassee ne passait en « expiree » que si le
-- client ouvrait son ecran de suivi (controle fait par l'application). Sinon
-- elle restait « en attente » indefiniment (FTM202610232636).
--
-- 1. Fonction expire_overdue_missions() : passe en « expired » toute mission
--    « pending » dont scheduled_pickup_time est depasse (meme regle que
--    l'application). Executable par le systeme uniquement.
-- 2. Trigger missions_on_expired (apres le passage pending -> expired, quelle
--    qu'en soit l'origine : tache planifiee ou application) :
--    a. les offres encore en attente passent a « not_selected » et leurs
--       chauffeurs recoivent « Offre non retenue » (mission expiree) ; ces
--       changements etant faits par un trigger, la notification generique de
--       la migration 053 ne part pas (pg_trigger_depth() > 1) ;
--    b. si l'expiration vient de la tache planifiee (aucun utilisateur
--       connecte), le client recoit « Mission expiree », une seule fois
--       (le passage pending -> expired n'a lieu qu'une fois). Quand c'est
--       l'application du client qui expire la mission, il la voit deja a
--       l'ecran : pas de notification.
--    La sonnerie des notifications est assuree par la migration 057.
-- 3. Tache planifiee « expire-overdue-missions » toutes les 5 minutes.
-- L'application est inchangee (son controle reste une double securite).

-- 1
CREATE OR REPLACE FUNCTION public.expire_overdue_missions()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.missions
  SET status = 'expired'
  WHERE status = 'pending'
    AND scheduled_pickup_time IS NOT NULL
    AND scheduled_pickup_time < now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;

-- 2
CREATE OR REPLACE FUNCTION public.on_mission_expired()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_number text := coalesce(NEW.mission_number, '');
BEGIN
  -- a. Offres en attente : non retenues, chauffeurs prevenus
  WITH closed AS (
    UPDATE public.mission_offers
    SET status = 'not_selected'
    WHERE mission_id = NEW.id
      AND status = 'pending'
    RETURNING driver_id
  )
  INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
  SELECT DISTINCT d.profile_id,
         'offer_update',
         'ℹ️ Offre non retenue',
         'La mission ' || v_number || ' a expiré sans être confirmée.',
         jsonb_build_object('mission_id', NEW.id, 'screen', 'DriverHomeScreen'),
         false
  FROM closed c
  JOIN public.drivers d ON d.id = c.driver_id
  WHERE d.profile_id IS NOT NULL;

  -- b. Client prevenu quand l'expiration vient du serveur
  IF auth.uid() IS NULL AND NEW.client_id IS NOT NULL THEN
    INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
    VALUES (
      NEW.client_id,
      'mission_expired',
      '⏱️ Mission expirée',
      'Aucun chauffeur n''a été trouvé pour la mission ' || v_number || ' avant l''heure prévue.',
      jsonb_build_object('mission_id', NEW.id, 'screen', 'MissionTrackingScreen'),
      false
    );
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS missions_on_expired ON public.missions;
CREATE TRIGGER missions_on_expired
  AFTER UPDATE OF status ON public.missions
  FOR EACH ROW
  WHEN (OLD.status = 'pending' AND NEW.status = 'expired')
  EXECUTE FUNCTION public.on_mission_expired();

-- Droits : systeme uniquement
REVOKE EXECUTE ON FUNCTION public.expire_overdue_missions() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.expire_overdue_missions() TO service_role;
REVOKE EXECUTE ON FUNCTION public.on_mission_expired() FROM PUBLIC, anon, authenticated;

-- 3. Tache planifiee toutes les 5 minutes
SELECT cron.unschedule('expire-overdue-missions')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire-overdue-missions');

SELECT cron.schedule(
  'expire-overdue-missions',
  '*/5 * * * *',
  $$ SELECT public.expire_overdue_missions(); $$
);
