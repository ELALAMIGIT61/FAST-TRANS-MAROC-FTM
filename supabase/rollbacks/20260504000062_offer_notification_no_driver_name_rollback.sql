-- Rollback de la migration 20260504000062 (point A1)
-- Restaure la fonction notify_mission_offer_events telle que definie par la
-- migration 053 (nom du chauffeur dans les notifications d'offre).
-- NE JAMAIS placer ce fichier dans supabase/migrations/.

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
