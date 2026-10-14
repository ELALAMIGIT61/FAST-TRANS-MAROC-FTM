-- Migration 20260504000053 - volet 5, lot E-ter : notifications de la negociation par la base
-- (decisions du porteur du 14/10/2026)
--
-- Constat : les notifications de la negociation etaient envoyees par le
-- telephone de celui qui agit. Pour trouver le destinataire, il devait relire
-- la mission ou la fiche chauffeur, ce que les regles d'acces n'autorisent que
-- si le chauffeur est disponible : hors disponibilite, rien ne partait, sans
-- erreur visible. La contre-proposition du client utilisait en plus un mauvais
-- identifiant et n'a jamais fonctionne.
--
-- Correction : un trigger AFTER INSERT OR UPDATE sur mission_offers, execute
-- avec les droits du proprietaire, depose lui-meme la notification chez
-- l'autre partie :
--   - nouvelle offre du chauffeur              -> client
--   - contre-proposition du client (tour 1)    -> chauffeur
--   - contre-proposition du chauffeur (tour 2) -> client
--   - accord du client (en attente)            -> chauffeur
--   - accord du chauffeur (en attente)         -> client
--   - retrait par le chauffeur                 -> client  ("Offre retiree")
--   - refus par le client                      -> chauffeur ("Le client n'a pas
--                                                 retenu votre offre ...")
-- Les offres passees a not_selected par l'acceptation d'une autre offre sont
-- notifiees par sync_mission_on_offer_accepted (migration 051) et ignorees ici
-- (pg_trigger_depth() > 1). Notifications visibles dans la cloche ; la sonnerie
-- du telephone fera l'objet d'un lot "sonnerie declenchee par le serveur".

CREATE OR REPLACE FUNCTION public.notify_mission_offer_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_client_profile uuid;
  v_mission_number text;
  v_driver_profile uuid;
  v_driver_user    uuid;
  v_driver_name    text;
  v_price          text;
  v_data           jsonb;
  v_target         uuid;
  v_title          text;
  v_body           text;
BEGIN
  -- Changements provoques par un autre trigger (ex. offres non retenues lors
  -- d'une acceptation) : deja notifies par la migration 051.
  IF pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

  SELECT m.client_id, m.mission_number INTO v_client_profile, v_mission_number
  FROM missions m WHERE m.id = NEW.mission_id;
  SELECT d.profile_id, p.user_id, coalesce(nullif(p.full_name, ''), 'Un chauffeur')
    INTO v_driver_profile, v_driver_user, v_driver_name
  FROM drivers d LEFT JOIN profiles p ON p.id = d.profile_id
  WHERE d.id = NEW.driver_id;

  v_price := trim_scale(NEW.offered_price)::text;
  v_data  := jsonb_build_object('mission_id', NEW.mission_id, 'offered_price', NEW.offered_price,
                                'screen', 'MissionOfferScreen');
  v_mission_number := coalesce(v_mission_number, '');

  IF TG_OP = 'INSERT' THEN
    v_target := v_client_profile;
    v_title  := '💰 Nouvelle offre de prix';
    v_body   := v_driver_name || ' propose ' || v_price || ' DH pour la mission ' || v_mission_number || '.';

  ELSIF OLD.status = 'pending' AND NEW.status = 'not_selected' THEN
    IF v_driver_user IS NOT NULL AND auth.uid() = v_driver_user THEN
      v_target := v_client_profile;
      v_title  := 'ℹ️ Offre retirée';
      v_body   := 'Le chauffeur a retiré son offre pour la mission ' || v_mission_number
                  || '. Vous pouvez choisir une autre offre.';
    ELSE
      v_target := v_driver_profile;
      v_title  := 'ℹ️ Offre non retenue';
      v_body   := 'Le client n''a pas retenu votre offre pour la mission ' || v_mission_number || '.';
      v_data   := jsonb_build_object('mission_id', NEW.mission_id, 'screen', 'DriverHomeScreen');
    END IF;

  ELSIF NEW.status = 'pending' AND NEW.offered_price IS DISTINCT FROM OLD.offered_price THEN
    IF OLD.round_number = 1 AND NEW.round_number = 2 THEN
      v_target := v_client_profile;
      v_title  := '💰 Réponse du chauffeur';
      v_body   := v_driver_name || ' propose ' || v_price || ' DH pour la mission ' || v_mission_number || '.';
    ELSE
      v_target := v_driver_profile;
      v_title  := '💰 Contre-offre du client';
      v_body   := 'Le client propose ' || v_price || ' DH pour la mission ' || v_mission_number || '.';
    END IF;

  ELSIF NEW.status = 'pending' AND NEW.client_accepted AND NOT OLD.client_accepted AND NOT NEW.driver_accepted THEN
    v_target := v_driver_profile;
    v_title  := '✅ Confirmation attendue';
    v_body   := 'L''autre partie a accepté ' || v_price || ' DH pour la mission ' || v_mission_number
                || '. Confirmez pour conclure.';

  ELSIF NEW.status = 'pending' AND NEW.driver_accepted AND NOT OLD.driver_accepted AND NOT NEW.client_accepted THEN
    v_target := v_client_profile;
    v_title  := '✅ Confirmation attendue';
    v_body   := 'L''autre partie a accepté ' || v_price || ' DH pour la mission ' || v_mission_number
                || '. Confirmez pour conclure.';
  END IF;

  IF v_target IS NOT NULL THEN
    INSERT INTO notifications (profile_id, type, title, body, data, is_read)
    VALUES (v_target, 'offer_update', v_title, v_body, v_data, false);
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.notify_mission_offer_events() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS notify_mission_offer_events_trigger ON public.mission_offers;
CREATE TRIGGER notify_mission_offer_events_trigger
  AFTER INSERT OR UPDATE ON public.mission_offers
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_mission_offer_events();
