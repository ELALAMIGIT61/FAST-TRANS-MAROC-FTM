-- Migration 20260504000077 - point A1 : corrections issues de la verification
-- finale A5 sur la version preview (decisions du porteur du 04/11/2026)
-- 1. Notification « Accord conclu » a la partie qui avait accepte en premier
--    (jusqu'ici, seule la partie qui confirmait savait que l'accord etait conclu).
-- 2. Notification « Nouveau message vocal » (fonction notify_voice_message,
--    appelee par l'application apres l'envoi d'un message).
-- 3. Rappels de notation au client : 24 h puis 72 h apres la fin de la mission,
--    entre 9 h et 21 h (heure du Maroc), reglables (0 = desactive) ; aucun
--    rappel si le client a deja note.
-- 4. Delai maximum pour noter : 7 jours apres la fin de la mission, reglable ;
--    au-dela, le serveur refuse la note.
-- 5. R-DESC : la description de la mission est rangee dans la partie
--    verrouillee (comme l'adresse exacte) : visible du client, de l'admin et du
--    chauffeur retenu apres le prelevement de la commission ; colonne
--    missions.has_description pour annoncer qu'il y en a une.
-- 6. R-WAL : fonction admin_wallet_status (solde, engage, disponible, minimum)
--    pour l'ecran admin « Gestion des wallets ».
-- Donnees existantes : les descriptions deja saisies (donnees de test) passent
-- dans la partie verrouillee.

-- 1. Reglages
INSERT INTO public.app_settings (key, value, description) VALUES
  ('rating_reminder_hours_first', 24, 'Heures apres la fin de la mission avant le 1er rappel de notation au client (0 = pas de rappel)'),
  ('rating_reminder_hours_second', 72, 'Heures apres la fin de la mission avant le 2e rappel de notation au client (0 = pas de rappel)'),
  ('rating_window_days', 7, 'Nombre de jours apres la fin de la mission pendant lesquels le client peut noter le chauffeur')
ON CONFLICT (key) DO NOTHING;

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
  IF NEW.key = 'rating_window_days' AND NEW.value < 1 THEN
    RAISE EXCEPTION 'reglage_invalide: le délai pour noter doit être d''au moins 1 jour' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'rating_reminder_hours_first' AND NEW.value > 0 THEN
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'rating_reminder_hours_second';
    IF v_other IS NOT NULL AND v_other > 0 AND NEW.value >= v_other THEN
      RAISE EXCEPTION 'reglage_invalide: le 1er rappel (% h) doit venir avant le 2e (% h)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  IF NEW.key = 'rating_reminder_hours_second' AND NEW.value > 0 THEN
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'rating_reminder_hours_first';
    IF v_other IS NOT NULL AND v_other > 0 AND NEW.value <= v_other THEN
      RAISE EXCEPTION 'reglage_invalide: le 2e rappel (% h) doit venir après le 1er (% h)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
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

-- 2. Colonnes (remplies par le serveur)
ALTER TABLE public.missions
  ADD COLUMN IF NOT EXISTS rating_reminder_1_sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS rating_reminder_2_sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS has_description boolean NOT NULL DEFAULT false;
ALTER TABLE public.mission_exact_locations ADD COLUMN IF NOT EXISTS description text;

-- 3. Description dans la partie verrouillee (R-DESC)
CREATE OR REPLACE FUNCTION public.hide_mission_exact_location()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
  INSERT INTO mission_exact_locations (mission_id, pickup_address, pickup_location, pickup_lat, pickup_lng,
                                       dropoff_address, dropoff_location, dropoff_lat, dropoff_lng, description)
  VALUES (NEW.id, NEW.pickup_address, NEW.pickup_location,
          ST_Y(NEW.pickup_location::geometry), ST_X(NEW.pickup_location::geometry),
          NEW.dropoff_address, NEW.dropoff_location,
          ST_Y(NEW.dropoff_location::geometry), ST_X(NEW.dropoff_location::geometry),
          nullif(btrim(coalesce(NEW.description, '')), ''))
  ON CONFLICT (mission_id) DO NOTHING;

  -- Migration 077 (R-DESC) : description dans la partie verrouillee
  NEW.has_description := nullif(btrim(coalesce(NEW.description, '')), '') IS NOT NULL;
  NEW.description := NULL;

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

-- Description modifiee apres la creation : rangee elle aussi dans la partie verrouillee
CREATE OR REPLACE FUNCTION public.hide_mission_description_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.description IS NOT NULL THEN
    UPDATE mission_exact_locations
    SET description = nullif(btrim(NEW.description), '')
    WHERE mission_id = NEW.id;
    NEW.has_description := nullif(btrim(NEW.description), '') IS NOT NULL;
    NEW.description := NULL;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.hide_mission_description_update() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS zz_hide_mission_description ON public.missions;
CREATE TRIGGER zz_hide_mission_description
  BEFORE UPDATE OF description ON public.missions
  FOR EACH ROW EXECUTE FUNCTION public.hide_mission_description_update();

-- Descriptions deja saisies (donnees de test)
UPDATE public.mission_exact_locations e
SET description = nullif(btrim(m.description), '')
FROM public.missions m
WHERE m.id = e.mission_id AND m.description IS NOT NULL;
UPDATE public.missions SET description = description WHERE description IS NOT NULL;

-- 4. Accord conclu
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
  v_type           text := 'offer_update';
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

  -- Migration 077 : accord conclu, la partie qui avait accepte en premier est prevenue
  ELSIF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    v_type  := 'mission_accepted';
    v_title := '✅ Accord conclu';
    v_body  := 'La mission ' || v_mission_number || ' est confirmée à ' || v_price || ' DH.';
    IF v_driver_user IS NOT NULL AND auth.uid() = v_driver_user THEN
      v_target := v_client_profile;
      v_data   := jsonb_build_object('mission_id', NEW.mission_id, 'screen', 'MissionTrackingScreen');
    ELSE
      v_target := v_driver_profile;
      v_data   := jsonb_build_object('mission_id', NEW.mission_id, 'screen', 'MissionActiveScreen');
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
    VALUES (v_target, v_type, v_title, v_body, v_data, false);
  END IF;

  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.notify_mission_offer_events() FROM PUBLIC, anon, authenticated;

-- 5. Notification « Nouveau message vocal »
CREATE OR REPLACE FUNCTION public.notify_voice_message(p_mission_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_mission  missions;
  v_client_user uuid;
  v_driver_profile uuid;
  v_driver_user uuid;
  v_target uuid;
BEGIN
  SELECT * INTO v_mission FROM missions WHERE id = p_mission_id;
  IF v_mission.id IS NULL
     OR v_mission.status NOT IN ('accepted', 'in_progress')
     OR v_mission.commission_charged_at IS NULL THEN
    RETURN;
  END IF;
  SELECT p.user_id INTO v_client_user FROM profiles p WHERE p.id = v_mission.client_id;
  SELECT d.profile_id, p.user_id INTO v_driver_profile, v_driver_user
  FROM drivers d JOIN profiles p ON p.id = d.profile_id WHERE d.id = v_mission.driver_id;

  IF auth.uid() IS NOT NULL AND auth.uid() = v_client_user THEN
    v_target := v_driver_profile;
  ELSIF auth.uid() IS NOT NULL AND auth.uid() = v_driver_user THEN
    v_target := v_mission.client_id;
  ELSE
    RETURN;
  END IF;

  -- Pas plus d'une notification non lue par minute et par mission
  IF EXISTS (SELECT 1 FROM notifications n
             WHERE n.profile_id = v_target AND n.type = 'voice_message' AND NOT n.is_read
               AND n.data->>'mission_id' = p_mission_id::text
               AND n.created_at > now() - interval '1 minute') THEN
    RETURN;
  END IF;

  INSERT INTO notifications (profile_id, type, title, body, data, is_read)
  VALUES (v_target, 'voice_message', '🎤 Nouveau message vocal',
          'Mission ' || coalesce(v_mission.mission_number, '') || ' : touchez pour écouter.',
          jsonb_build_object('mission_id', p_mission_id, 'screen', 'VoiceChat'), false);
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.notify_voice_message(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.notify_voice_message(uuid) TO authenticated;

-- 6. Delai maximum pour noter
CREATE OR REPLACE FUNCTION public.rating_window_days()
 RETURNS integer
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(1, coalesce((SELECT s.value FROM app_settings s WHERE s.key = 'rating_window_days'), 7))::integer;
$function$;
REVOKE EXECUTE ON FUNCTION public.rating_window_days() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rating_window_days() TO authenticated;

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
    -- Migration 077 : delai maximum pour noter
    IF current_user IN ('authenticated', 'anon')
       AND coalesce(OLD.completed_at, OLD.auto_closed_at, OLD.actual_dropoff_time, OLD.updated_at)
           < now() - make_interval(days => public.rating_window_days()) THEN
      RAISE EXCEPTION 'notation_expiree: le délai de % jours pour noter cette mission est dépassé.',
        public.rating_window_days() USING ERRCODE = '42501';
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

-- 7. Rappels de notation (tache planifiee toutes les 15 minutes)
CREATE OR REPLACE FUNCTION public.process_rating_reminders()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_first  numeric := coalesce((SELECT value FROM app_settings WHERE key = 'rating_reminder_hours_first'), 24);
  v_second numeric := coalesce((SELECT value FROM app_settings WHERE key = 'rating_reminder_hours_second'), 72);
  v_days   integer := public.rating_window_days();
  v_hour   integer := extract(hour FROM now() AT TIME ZONE 'Africa/Casablanca')::integer;
  v_n1 integer := 0;
  v_n2 integer := 0;
BEGIN
  -- Pas de rappel la nuit : seulement de 9 h a 21 h (heure du Maroc)
  IF v_hour < 9 OR v_hour >= 21 THEN
    RETURN 0;
  END IF;

  -- 2e rappel (le 1er est alors considere comme fait)
  IF v_second > 0 THEN
    WITH due AS (
      UPDATE missions m
      SET rating_reminder_2_sent_at = now(),
          rating_reminder_1_sent_at = coalesce(m.rating_reminder_1_sent_at, now())
      WHERE m.status = 'completed' AND m.client_id IS NOT NULL
        AND m.rating_punctuality IS NULL AND m.client_rating IS NULL
        AND m.rating_reminder_2_sent_at IS NULL
        AND coalesce(m.completed_at, m.auto_closed_at, m.actual_dropoff_time, m.updated_at)
            <= now() - make_interval(secs => v_second * 3600)
        AND coalesce(m.completed_at, m.auto_closed_at, m.actual_dropoff_time, m.updated_at)
            > now() - make_interval(days => v_days)
      RETURNING m.id, m.client_id, m.mission_number
    ), ins AS (
      INSERT INTO notifications (profile_id, type, title, body, data, is_read)
      SELECT d.client_id, 'rating_reminder', '⭐ Dernier rappel',
             'Notez votre chauffeur en 10 secondes. Après ' || v_days || ' jours, la notation de la mission '
               || coalesce(d.mission_number, '') || ' ne sera plus possible.',
             jsonb_build_object('mission_id', d.id, 'screen', 'RatingScreen'), false
      FROM due d
      RETURNING 1
    )
    SELECT count(*) INTO v_n2 FROM ins;
  END IF;

  -- 1er rappel
  IF v_first > 0 THEN
    WITH due AS (
      UPDATE missions m
      SET rating_reminder_1_sent_at = now()
      WHERE m.status = 'completed' AND m.client_id IS NOT NULL
        AND m.rating_punctuality IS NULL AND m.client_rating IS NULL
        AND m.rating_reminder_1_sent_at IS NULL AND m.rating_reminder_2_sent_at IS NULL
        AND coalesce(m.completed_at, m.auto_closed_at, m.actual_dropoff_time, m.updated_at)
            <= now() - make_interval(secs => v_first * 3600)
        AND coalesce(m.completed_at, m.auto_closed_at, m.actual_dropoff_time, m.updated_at)
            > now() - make_interval(days => v_days)
      RETURNING m.id, m.client_id, m.mission_number
    ), ins AS (
      INSERT INTO notifications (profile_id, type, title, body, data, is_read)
      SELECT d.client_id, 'rating_reminder', '⭐ Comment s''est passée votre mission ?',
             'Votre avis sur la mission ' || coalesce(d.mission_number, '')
               || ' aide les autres clients à choisir leur chauffeur.',
             jsonb_build_object('mission_id', d.id, 'screen', 'RatingScreen'), false
      FROM due d
      RETURNING 1
    )
    SELECT count(*) INTO v_n1 FROM ins;
  END IF;

  RETURN v_n1 + v_n2;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.process_rating_reminders() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_rating_reminders() TO service_role;

SELECT cron.unschedule('process-rating-reminders')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-rating-reminders');
SELECT cron.schedule(
  'process-rating-reminders',
  '*/15 * * * *',
  $$ SELECT public.process_rating_reminders(); $$
);

-- 7b. Liste « Missions disponibles » : indicateur de description (R-DESC)
DROP FUNCTION IF EXISTS public.driver_open_missions();
CREATE FUNCTION public.driver_open_missions()
 RETURNS TABLE(id uuid, mission_number character varying, mission_type mission_type, vehicle_category vehicle_category, pickup_address text, pickup_city character varying, dropoff_address text, dropoff_city character varying, scheduled_pickup_time timestamp with time zone, estimated_distance_km numeric, needs_loading_help boolean, commission_amount numeric, cargo_weight_kg numeric, cargo_volume_m3 numeric, description text, status mission_status, created_at timestamp with time zone, client_completed_missions integer, client_cancelled_missions integer, client_late_cancelled_missions integer, client_window_months integer, client_is_new boolean, has_description boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT m.id, m.mission_number, m.mission_type, m.vehicle_category,
         m.pickup_address, m.pickup_city, m.dropoff_address, m.dropoff_city,
         m.scheduled_pickup_time, m.estimated_distance_km, m.needs_loading_help,
         m.commission_amount, m.cargo_weight_kg, m.cargo_volume_m3,
         m.description, m.status, m.created_at,
         r.completed_missions, r.cancelled_missions, r.late_cancelled_missions, r.window_months, r.is_new, m.has_description
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

-- 8. Solde disponible des chauffeurs pour l'admin (R-WAL)
CREATE OR REPLACE FUNCTION public.admin_wallet_status()
 RETURNS TABLE(driver_id uuid, balance numeric, engaged numeric, available numeric, minimum numeric)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin') THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT w.driver_id, w.balance, public.driver_engaged_commissions(w.driver_id),
         public.driver_available_balance(w.driver_id), public.driver_minimum_balance(w.driver_id)
  FROM wallet w;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.admin_wallet_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_wallet_status() TO authenticated;
