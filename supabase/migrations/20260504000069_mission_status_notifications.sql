-- Migration 20260504000069 - point A1, F8 : notifications de la vie d'une
-- mission envoyees par le serveur (accord du porteur du 27/10/2026)
--
-- Constat (test du 27/10/2026, mission FTM202610272868) : la notification
-- « Mission terminee ! Evaluez votre chauffeur » n'est jamais arrivee chez le
-- client. Ces notifications etaient deposees par l'application de l'autre
-- partie, qui relisait ensuite la notification ecrite ; la securite du serveur
-- interdisant (a juste titre) de lire les notifications d'autrui, l'operation
-- entiere etait refusee. Concerne : mission demarree, terminee, annulee
-- (mission acceptee). Le client ne pouvait donc plus noter la mission.
--
-- 1. Trigger missions_status_notifications (apres changement de statut) :
--    - acceptee -> en cours : client « Chargement en cours » ;
--    - en cours -> terminee : client « Mission terminee ! Evaluez votre
--      chauffeur » (ouvre la notation), chauffeur « Mission cloturee » ;
--    - acceptee -> annulee par le client : chauffeur prevenu (ouvre la
--      mission annulee, d'ou il peut demander le remboursement de la
--      commission si elle a ete prelevee) ;
--    - acceptee -> annulee par le chauffeur : client prevenu.
--    Les annulations de missions en attente (offres fermees) et la perte du
--    remboursement restent traitees par la migration 065.
--    La sonnerie est assuree par la migration 057. Une erreur ici n'empeche
--    jamais le changement de statut.
-- L'application n'envoie plus ces notifications elle-meme.
-- Aucune donnee existante modifiee.

CREATE OR REPLACE FUNCTION public.on_mission_status_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_number text := coalesce(NEW.mission_number, '');
  v_driver_profile uuid;
BEGIN
  SELECT d.profile_id INTO v_driver_profile FROM drivers d WHERE d.id = NEW.driver_id;

  BEGIN
    IF OLD.status = 'accepted' AND NEW.status = 'in_progress' AND NEW.client_id IS NOT NULL THEN
      INSERT INTO notifications (profile_id, type, title, body, data, is_read)
      VALUES (NEW.client_id, 'mission_started', '🚛 Chargement en cours',
              'Votre mission ' || v_number || ' a démarré. Trajet en cours vers '
                || coalesce(NEW.dropoff_city, 'la destination') || '.',
              jsonb_build_object('mission_id', NEW.id, 'screen', 'MissionTrackingScreen'), false);

    ELSIF OLD.status = 'in_progress' AND NEW.status = 'completed' THEN
      IF NEW.client_id IS NOT NULL THEN
        INSERT INTO notifications (profile_id, type, title, body, data, is_read)
        VALUES (NEW.client_id, 'mission_completed', '🏁 Mission terminée !',
                'Mission ' || v_number || ' livrée à ' || coalesce(NEW.dropoff_city, 'destination')
                  || '. Évaluez votre chauffeur.',
                jsonb_build_object('mission_id', NEW.id, 'screen', 'RatingScreen'), false);
      END IF;
      IF v_driver_profile IS NOT NULL THEN
        INSERT INTO notifications (profile_id, type, title, body, data, is_read)
        VALUES (v_driver_profile, 'mission_completed', '✅ Mission clôturée',
                'Mission ' || v_number || ' clôturée. Merci !',
                jsonb_build_object('mission_id', NEW.id, 'screen', 'DriverHomeScreen'), false);
      END IF;

    ELSIF OLD.status = 'accepted' AND NEW.status = 'cancelled_client' AND v_driver_profile IS NOT NULL THEN
      INSERT INTO notifications (profile_id, type, title, body, data, is_read)
      VALUES (v_driver_profile, 'mission_cancelled', '❌ Mission annulée',
              'La mission ' || v_number || ' a été annulée par le client.'
                || CASE WHEN NEW.commission_charged_at IS NOT NULL
                        THEN ' Vous pouvez demander le remboursement de la commission depuis la mission.'
                        ELSE '' END,
              jsonb_build_object('mission_id', NEW.id, 'screen', 'MissionActiveScreen'), false);

    ELSIF OLD.status = 'accepted' AND NEW.status = 'cancelled_driver' AND NEW.client_id IS NOT NULL THEN
      INSERT INTO notifications (profile_id, type, title, body, data, is_read)
      VALUES (NEW.client_id, 'mission_cancelled', '❌ Mission annulée',
              'La mission ' || v_number || ' a été annulée par le chauffeur. Vous pouvez créer une nouvelle mission.',
              jsonb_build_object('mission_id', NEW.id, 'screen', 'MissionTrackingScreen'), false);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'on_mission_status_notify: notification non envoyee pour la mission % (%)', v_number, SQLERRM;
  END;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.on_mission_status_notify() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS missions_status_notifications ON public.missions;
CREATE TRIGGER missions_status_notifications
  AFTER UPDATE OF status ON public.missions
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.on_mission_status_notify();
