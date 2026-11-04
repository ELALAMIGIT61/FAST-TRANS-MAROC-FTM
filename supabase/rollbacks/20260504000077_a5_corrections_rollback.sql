-- Rollback de la migration 20260504000077 (corrections A5).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Les descriptions rangees dans la partie verrouillee sont remises dans la fiche
-- de la mission avant la suppression de la colonne.

SELECT cron.unschedule('process-rating-reminders')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-rating-reminders');
DROP FUNCTION IF EXISTS public.process_rating_reminders();
DROP FUNCTION IF EXISTS public.admin_wallet_status();
DROP FUNCTION IF EXISTS public.notify_voice_message(uuid);
DROP TRIGGER IF EXISTS zz_hide_mission_description ON public.missions;
DROP FUNCTION IF EXISTS public.hide_mission_description_update();
DROP FUNCTION IF EXISTS public.driver_open_missions();

CREATE FUNCTION public.driver_open_missions()
 RETURNS TABLE(id uuid, mission_number character varying, mission_type mission_type, vehicle_category vehicle_category, pickup_address text, pickup_city character varying, dropoff_address text, dropoff_city character varying, scheduled_pickup_time timestamp with time zone, estimated_distance_km numeric, needs_loading_help boolean, commission_amount numeric, cargo_weight_kg numeric, cargo_volume_m3 numeric, description text, status mission_status, created_at timestamp with time zone, client_completed_missions integer, client_cancelled_missions integer, client_late_cancelled_missions integer, client_window_months integer, client_is_new boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT m.id, m.mission_number, m.mission_type, m.vehicle_category,
         m.pickup_address, m.pickup_city, m.dropoff_address, m.dropoff_city,
         m.scheduled_pickup_time, m.estimated_distance_km, m.needs_loading_help,
         m.commission_amount, m.cargo_weight_kg, m.cargo_volume_m3,
         m.description, m.status, m.created_at,
         r.completed_missions, r.cancelled_missions, r.late_cancelled_missions, r.window_months, r.is_new
  FROM drivers d
  JOIN profiles p ON p.id = d.profile_id
  JOIN missions m ON m.vehicle_category = d.vehicle_category
  LEFT JOIN LATERAL public.client_cancel_record(m.client_id) r ON true
  WHERE p.user_id = auth.uid()
    AND d.is_verified = true
    AND d.is_available = true
    AND p.is_active = true
    AND public.driver_balance_ok(d.id)
    AND m.status = 'pending'
    AND m.scheduled_pickup_time > now()
    AND m.client_id IS DISTINCT FROM d.profile_id
    AND public.mission_in_driver_range(d.id, m.id)
    AND NOT public.driver_schedule_conflict(d.id, m.id)
    AND NOT EXISTS (
      SELECT 1 FROM mission_offers o
      WHERE o.mission_id = m.id AND o.driver_id = d.id AND o.status = 'pending'
    )
  ORDER BY m.scheduled_pickup_time ASC;
$function$;
REVOKE EXECUTE ON FUNCTION public.driver_open_missions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.driver_open_missions() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.hide_mission_exact_location()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
  INSERT INTO mission_exact_locations (mission_id, pickup_address, pickup_location, pickup_lat, pickup_lng,
                                       dropoff_address, dropoff_location, dropoff_lat, dropoff_lng)
  VALUES (NEW.id, NEW.pickup_address, NEW.pickup_location,
          ST_Y(NEW.pickup_location::geometry), ST_X(NEW.pickup_location::geometry),
          NEW.dropoff_address, NEW.dropoff_location,
          ST_Y(NEW.dropoff_location::geometry), ST_X(NEW.dropoff_location::geometry))
  ON CONFLICT (mission_id) DO NOTHING;

  NEW.pickup_district  := nullif(btrim(NEW.pickup_district), '');
  NEW.dropoff_district := nullif(btrim(NEW.dropoff_district), '');
  NEW.pickup_address   := approx_place_label(NEW.pickup_district, NEW.pickup_city);
  NEW.dropoff_address  := approx_place_label(NEW.dropoff_district, NEW.dropoff_city);
  NEW.pickup_location  := approx_point(NEW.pickup_location);
  NEW.dropoff_location := approx_point(NEW.dropoff_location);
  IF NEW.estimated_distance_km IS NOT NULL THEN
    NEW.estimated_distance_km := greatest(round(NEW.estimated_distance_km), 1);
  END IF;
  RETURN NEW;
END;
$function$;

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
    v_body   := 'Un chauffeur propose ' || v_price || ' DH pour la mission ' || v_mission_number || '.';

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
      v_body   := 'Un chauffeur propose ' || v_price || ' DH pour la mission ' || v_mission_number || '.';
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

CREATE OR REPLACE FUNCTION public.check_criteria_ratings()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Le statut de l'avis n'est jamais modifiable directement par un utilisateur
  -- (l'admin passe par moderate_review).
  IF current_user IN ('authenticated', 'anon') THEN
    NEW.review_status := OLD.review_status;
    NEW.review_moderated_at := OLD.review_moderated_at;
  END IF;

  IF NEW.rating_punctuality IS DISTINCT FROM OLD.rating_punctuality
     OR NEW.rating_care IS DISTINCT FROM OLD.rating_care
     OR NEW.rating_service IS DISTINCT FROM OLD.rating_service THEN
    IF OLD.rating_punctuality IS NOT NULL OR OLD.rating_care IS NOT NULL OR OLD.rating_service IS NOT NULL THEN
      RAISE EXCEPTION 'La note de cette mission a déjà été donnée : elle est définitive.'
        USING ERRCODE = '42501';
    END IF;
    IF NEW.rating_punctuality IS NULL OR NEW.rating_care IS NULL OR NEW.rating_service IS NULL THEN
      RAISE EXCEPTION 'Merci de noter les 3 critères : ponctualité, soin de la marchandise et services.'
        USING ERRCODE = '22023';
    END IF;
    -- Note globale interne = moyenne arrondie des 3 criteres
    NEW.client_rating := round((NEW.rating_punctuality + NEW.rating_care + NEW.rating_service) / 3.0)::integer;
  END IF;

  -- Un commentaire donne avec la notation par criteres passe a moderer
  IF NEW.client_review IS DISTINCT FROM OLD.client_review
     AND NEW.rating_punctuality IS NOT NULL
     AND nullif(btrim(coalesce(NEW.client_review, '')), '') IS NOT NULL THEN
    NEW.review_status := 'pending';
    NEW.review_moderated_at := NULL;
  END IF;

  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.check_criteria_ratings() FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.rating_window_days();

CREATE OR REPLACE FUNCTION public.validate_app_setting()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cat text;
  v_other numeric;
BEGIN
  IF NEW.value < 0 THEN
    RAISE EXCEPTION 'reglage_invalide: la valeur ne peut pas être négative' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'client_cancel_window_months' AND NEW.value < 1 THEN
    RAISE EXCEPTION 'reglage_invalide: la période doit être d''au moins 1 mois' USING ERRCODE = '22023';
  END IF;
  IF NEW.key LIKE 'commission\_amount\_%' THEN
    IF NEW.value < 1 THEN
      RAISE EXCEPTION 'reglage_invalide: la commission doit être d''au moins 1 DH' USING ERRCODE = '22023';
    END IF;
    v_cat := substr(NEW.key, length('commission_amount_') + 1);
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'min_balance_' || v_cat;
    IF v_other IS NOT NULL AND NEW.value > v_other THEN
      RAISE EXCEPTION 'reglage_invalide: la commission (% DH) ne peut pas dépasser le solde minimum de la catégorie (% DH)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  IF NEW.key LIKE 'min\_balance\_%' THEN
    v_cat := substr(NEW.key, length('min_balance_') + 1);
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'commission_amount_' || v_cat;
    IF v_other IS NOT NULL AND NEW.value < v_other THEN
      RAISE EXCEPTION 'reglage_invalide: le solde minimum (% DH) ne peut pas être inférieur à la commission de la catégorie (% DH)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.validate_app_setting() FROM PUBLIC, anon, authenticated;

UPDATE public.missions m SET description = e.description
FROM public.mission_exact_locations e
WHERE e.mission_id = m.id AND e.description IS NOT NULL;
ALTER TABLE public.mission_exact_locations DROP COLUMN IF EXISTS description;
ALTER TABLE public.missions
  DROP COLUMN IF EXISTS rating_reminder_1_sent_at,
  DROP COLUMN IF EXISTS rating_reminder_2_sent_at,
  DROP COLUMN IF EXISTS has_description;
DELETE FROM public.app_settings WHERE key IN ('rating_reminder_hours_first', 'rating_reminder_hours_second', 'rating_window_days');
