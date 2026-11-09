-- Migration 20260504000078 - point B1, lot B1-a : partie serveur des adresses
-- (conception validee par le porteur le 09/11/2026 ; aucun appel a Google dans ce lot)
--
-- 1. Repere du depart et de l'arrivee (facultatifs) : saisis a la creation de la
--    mission, ranges aussitot dans la partie verrouillee (memes regles de lecture
--    que l'adresse exacte : client, admin, chauffeur retenu apres le prelevement
--    de la commission).
-- 2. Position reelle du chauffeur : quand la mission passe « en cours »
--    (chargement) puis « terminee » (livraison), le serveur note la derniere
--    position connue du chauffeur et son heure. Lisible par l'admin seulement.
--    Ne bloque jamais le changement d'etat.
-- 3. Adresses enregistrees du client (« Mes adresses ») : 5 au plus (reglable),
--    creees seulement a la demande du client a la fin d'une mission terminee ;
--    point appris = position du chauffeur, retenu seulement s'il est a moins de
--    300 m de l'epingle du client et date de moins de 5 minutes (reglables) ;
--    supprimables par le client ; effacees apres 12 mois sans usage (reglable).
-- 4. Effacement des donnees Google : 30 jours (au plus) apres la fin d'une
--    mission terminee, annulee ou expiree, les points exacts et le quartier sont
--    effaces ; le point approche de la fiche devient tres grossier (environ
--    10 km). Le texte tape par le client (adresse, ville, repere) et les
--    positions du chauffeur sont gardes.
-- 5. Reglages de l'admin : mode de saisie des adresses (0 = adresse tapee +
--    epingle, 1 = mixte, 2 = suggestions), nombre d'adresses enregistrees,
--    duree sans usage, distance et anciennete du point appris, delai
--    d'effacement des donnees Google (30 jours au plus).

-- 1. Reperes
ALTER TABLE public.missions
  ADD COLUMN IF NOT EXISTS pickup_landmark text,
  ADD COLUMN IF NOT EXISTS dropoff_landmark text;
ALTER TABLE public.missions DROP CONSTRAINT IF EXISTS missions_landmarks_length;
ALTER TABLE public.missions ADD CONSTRAINT missions_landmarks_length
  CHECK (char_length(coalesce(pickup_landmark, '')) <= 200 AND char_length(coalesce(dropoff_landmark, '')) <= 200);
REVOKE UPDATE (pickup_landmark, dropoff_landmark) ON public.missions FROM anon, authenticated;

ALTER TABLE public.mission_exact_locations
  ADD COLUMN IF NOT EXISTS pickup_landmark text,
  ADD COLUMN IF NOT EXISTS dropoff_landmark text,
  ADD COLUMN IF NOT EXISTS google_data_purged_at timestamptz;

CREATE OR REPLACE FUNCTION public.hide_mission_exact_location()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
  INSERT INTO mission_exact_locations (mission_id, pickup_address, pickup_location, pickup_lat, pickup_lng,
                                       dropoff_address, dropoff_location, dropoff_lat, dropoff_lng, description,
                                       pickup_landmark, dropoff_landmark)
  VALUES (NEW.id, NEW.pickup_address, NEW.pickup_location,
          ST_Y(NEW.pickup_location::geometry), ST_X(NEW.pickup_location::geometry),
          NEW.dropoff_address, NEW.dropoff_location,
          ST_Y(NEW.dropoff_location::geometry), ST_X(NEW.dropoff_location::geometry),
          nullif(btrim(coalesce(NEW.description, '')), ''),
          nullif(btrim(coalesce(NEW.pickup_landmark, '')), ''),
          nullif(btrim(coalesce(NEW.dropoff_landmark, '')), ''))
  ON CONFLICT (mission_id) DO NOTHING;

  -- Migration 077 (R-DESC) : description dans la partie verrouillee
  NEW.has_description := nullif(btrim(coalesce(NEW.description, '')), '') IS NOT NULL;
  NEW.description := NULL;
  -- Migration 078 (B1) : reperes dans la partie verrouillee
  NEW.pickup_landmark := NULL;
  NEW.dropoff_landmark := NULL;

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

-- 2. Position reelle du chauffeur
CREATE TABLE IF NOT EXISTS public.mission_driver_positions (
  mission_id          uuid PRIMARY KEY REFERENCES public.missions(id) ON DELETE CASCADE,
  driver_id           uuid REFERENCES public.drivers(id) ON DELETE SET NULL,
  pickup_lat          double precision,
  pickup_lng          double precision,
  pickup_position_at  timestamptz,
  pickup_recorded_at  timestamptz,
  dropoff_lat         double precision,
  dropoff_lng         double precision,
  dropoff_position_at timestamptz,
  dropoff_recorded_at timestamptz
);
ALTER TABLE public.mission_driver_positions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.mission_driver_positions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.mission_driver_positions TO authenticated;
DROP POLICY IF EXISTS mission_driver_positions_select_admin ON public.mission_driver_positions;
CREATE POLICY mission_driver_positions_select_admin ON public.mission_driver_positions
  FOR SELECT TO authenticated USING (public.get_my_role() = 'admin');

CREATE OR REPLACE FUNCTION public.record_mission_driver_position()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_loc extensions.geography;
  v_at  timestamptz;
BEGIN
  BEGIN
    SELECT d.current_location, d.last_location_update INTO v_loc, v_at
    FROM drivers d WHERE d.id = NEW.driver_id;
    IF v_loc IS NULL THEN
      RETURN NULL;
    END IF;
    IF NEW.status = 'in_progress' THEN
      INSERT INTO mission_driver_positions (mission_id, driver_id, pickup_lat, pickup_lng, pickup_position_at, pickup_recorded_at)
      VALUES (NEW.id, NEW.driver_id, ST_Y(v_loc::geometry), ST_X(v_loc::geometry), v_at, now())
      ON CONFLICT (mission_id) DO UPDATE
        SET driver_id = EXCLUDED.driver_id, pickup_lat = EXCLUDED.pickup_lat, pickup_lng = EXCLUDED.pickup_lng,
            pickup_position_at = EXCLUDED.pickup_position_at, pickup_recorded_at = EXCLUDED.pickup_recorded_at;
    ELSIF NEW.status = 'completed' THEN
      INSERT INTO mission_driver_positions (mission_id, driver_id, dropoff_lat, dropoff_lng, dropoff_position_at, dropoff_recorded_at)
      VALUES (NEW.id, NEW.driver_id, ST_Y(v_loc::geometry), ST_X(v_loc::geometry), v_at, now())
      ON CONFLICT (mission_id) DO UPDATE
        SET driver_id = EXCLUDED.driver_id, dropoff_lat = EXCLUDED.dropoff_lat, dropoff_lng = EXCLUDED.dropoff_lng,
            dropoff_position_at = EXCLUDED.dropoff_position_at, dropoff_recorded_at = EXCLUDED.dropoff_recorded_at;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'record_mission_driver_position: % (mission %)', SQLERRM, NEW.id;
  END;
  RETURN NULL;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.record_mission_driver_position() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS missions_record_driver_position ON public.missions;
CREATE TRIGGER missions_record_driver_position
  AFTER UPDATE OF status ON public.missions
  FOR EACH ROW
  WHEN (NEW.status IS DISTINCT FROM OLD.status
        AND NEW.status IN ('in_progress', 'completed')
        AND NEW.driver_id IS NOT NULL)
  EXECUTE FUNCTION public.record_mission_driver_position();

-- 3. Adresses enregistrees du client
CREATE TABLE IF NOT EXISTS public.client_saved_addresses (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id         uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  label             text CHECK (label IS NULL OR char_length(label) BETWEEN 1 AND 40),
  address           text NOT NULL CHECK (char_length(address) <= 300),
  city              text NOT NULL,
  landmark          text CHECK (landmark IS NULL OR char_length(landmark) <= 200),
  lat               double precision,
  lng               double precision,
  point_source      text CHECK (point_source IS NULL OR point_source = 'driver'),
  source_mission_id uuid REFERENCES public.missions(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  last_used_at      timestamptz NOT NULL DEFAULT now(),
  CHECK ((lat IS NULL) = (lng IS NULL))
);
CREATE INDEX IF NOT EXISTS client_saved_addresses_client_idx ON public.client_saved_addresses (client_id);
ALTER TABLE public.client_saved_addresses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.client_saved_addresses FROM PUBLIC, anon, authenticated;
GRANT SELECT, DELETE ON public.client_saved_addresses TO authenticated;
GRANT UPDATE (label) ON public.client_saved_addresses TO authenticated;

DROP POLICY IF EXISTS client_saved_addresses_select ON public.client_saved_addresses;
CREATE POLICY client_saved_addresses_select ON public.client_saved_addresses
  FOR SELECT TO authenticated
  USING (client_id IN (SELECT p.id FROM profiles p WHERE p.user_id = auth.uid())
         OR public.get_my_role() = 'admin');
DROP POLICY IF EXISTS client_saved_addresses_update_own ON public.client_saved_addresses;
CREATE POLICY client_saved_addresses_update_own ON public.client_saved_addresses
  FOR UPDATE TO authenticated
  USING (client_id IN (SELECT p.id FROM profiles p WHERE p.user_id = auth.uid()))
  WITH CHECK (client_id IN (SELECT p.id FROM profiles p WHERE p.user_id = auth.uid()));
DROP POLICY IF EXISTS client_saved_addresses_delete_own ON public.client_saved_addresses;
CREATE POLICY client_saved_addresses_delete_own ON public.client_saved_addresses
  FOR DELETE TO authenticated
  USING (client_id IN (SELECT p.id FROM profiles p WHERE p.user_id = auth.uid()));

-- Valeur d'un reglage (valeur par defaut si absent)
CREATE OR REPLACE FUNCTION public.app_setting_value(p_key text, p_default numeric)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT s.value FROM app_settings s WHERE s.key = p_key), p_default);
$function$;
REVOKE EXECUTE ON FUNCTION public.app_setting_value(text, numeric) FROM PUBLIC, anon, authenticated;

-- Enregistrer l'adresse de chargement (p_which = 'pickup') ou de livraison
-- ('dropoff') d'une mission terminee, a la demande du client de la mission.
CREATE OR REPLACE FUNCTION public.save_mission_address(p_mission_id uuid, p_which text, p_label text DEFAULT NULL)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_profile   uuid;
  v_m         missions%ROWTYPE;
  v_e         mission_exact_locations%ROWTYPE;
  v_p         mission_driver_positions%ROWTYPE;
  v_address   text;
  v_city      text;
  v_landmark  text;
  v_client_pt extensions.geography;
  v_drv_lat   double precision;
  v_drv_lng   double precision;
  v_drv_at    timestamptz;
  v_drv_rec   timestamptz;
  v_lat       double precision;
  v_lng       double precision;
  v_label     text := nullif(btrim(coalesce(p_label, '')), '');
  v_existing  uuid;
  v_count     integer;
  v_max       numeric := public.app_setting_value('saved_addresses_max', 5);
  v_dist_m    numeric := public.app_setting_value('learned_point_max_distance_m', 300);
  v_age_min   numeric := public.app_setting_value('learned_point_max_age_minutes', 5);
  v_id        uuid;
BEGIN
  SELECT p.id INTO v_profile FROM profiles p WHERE p.user_id = auth.uid();
  SELECT * INTO v_m FROM missions m WHERE m.id = p_mission_id;
  IF NOT FOUND OR v_profile IS NULL OR v_m.client_id IS DISTINCT FROM v_profile THEN
    RAISE EXCEPTION 'adresse_refusee: mission introuvable' USING ERRCODE = '42501';
  END IF;
  IF v_m.status <> 'completed' THEN
    RAISE EXCEPTION 'adresse_refusee: seule l''adresse d''une mission terminée peut être enregistrée' USING ERRCODE = '22023';
  END IF;
  IF p_which NOT IN ('pickup', 'dropoff') THEN
    RAISE EXCEPTION 'adresse_refusee: adresse de chargement ou de livraison' USING ERRCODE = '22023';
  END IF;
  IF v_label IS NOT NULL AND char_length(v_label) > 40 THEN
    RAISE EXCEPTION 'adresse_refusee: le nom de l''adresse est limité à 40 caractères' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_e FROM mission_exact_locations e WHERE e.mission_id = p_mission_id;
  SELECT * INTO v_p FROM mission_driver_positions dp WHERE dp.mission_id = p_mission_id;
  IF p_which = 'pickup' THEN
    v_address := v_e.pickup_address; v_city := v_m.pickup_city; v_landmark := v_e.pickup_landmark;
    v_client_pt := v_e.pickup_location;
    v_drv_lat := v_p.pickup_lat; v_drv_lng := v_p.pickup_lng; v_drv_at := v_p.pickup_position_at; v_drv_rec := v_p.pickup_recorded_at;
  ELSE
    v_address := v_e.dropoff_address; v_city := v_m.dropoff_city; v_landmark := v_e.dropoff_landmark;
    v_client_pt := v_e.dropoff_location;
    v_drv_lat := v_p.dropoff_lat; v_drv_lng := v_p.dropoff_lng; v_drv_at := v_p.dropoff_position_at; v_drv_rec := v_p.dropoff_recorded_at;
  END IF;
  v_address := nullif(btrim(coalesce(v_address, '')), '');
  IF v_address IS NULL OR nullif(btrim(coalesce(v_city, '')), '') IS NULL THEN
    RAISE EXCEPTION 'adresse_refusee: adresse indisponible pour cette mission' USING ERRCODE = '22023';
  END IF;

  -- Point appris : position du chauffeur, recente et proche de l'epingle du client
  IF v_drv_lat IS NOT NULL AND v_drv_at IS NOT NULL AND v_drv_rec IS NOT NULL AND v_client_pt IS NOT NULL
     AND v_drv_at >= v_drv_rec - make_interval(mins => v_age_min::int)
     AND ST_Distance(v_client_pt, ST_SetSRID(ST_MakePoint(v_drv_lng, v_drv_lat), 4326)::geography) <= v_dist_m THEN
    v_lat := v_drv_lat; v_lng := v_drv_lng;
  END IF;

  SELECT a.id INTO v_existing FROM client_saved_addresses a
  WHERE a.client_id = v_profile AND lower(a.address) = lower(v_address) AND lower(a.city) = lower(v_city)
  LIMIT 1;
  IF v_existing IS NOT NULL THEN
    UPDATE client_saved_addresses a
    SET label = coalesce(v_label, a.label),
        landmark = coalesce(v_landmark, a.landmark),
        lat = coalesce(v_lat, a.lat), lng = coalesce(v_lng, a.lng),
        point_source = CASE WHEN v_lat IS NOT NULL THEN 'driver' ELSE a.point_source END,
        source_mission_id = CASE WHEN v_lat IS NOT NULL THEN p_mission_id ELSE a.source_mission_id END,
        last_used_at = now()
    WHERE a.id = v_existing;
    RETURN v_existing;
  END IF;

  SELECT count(*) INTO v_count FROM client_saved_addresses a WHERE a.client_id = v_profile;
  IF v_count >= v_max THEN
    RAISE EXCEPTION 'adresses_max: vous avez déjà % adresses enregistrées ; supprimez-en une pour en ajouter une autre',
      v_count USING ERRCODE = '22023';
  END IF;

  INSERT INTO client_saved_addresses (client_id, label, address, city, landmark, lat, lng, point_source, source_mission_id)
  VALUES (v_profile, v_label, v_address, v_city, v_landmark, v_lat, v_lng,
          CASE WHEN v_lat IS NOT NULL THEN 'driver' END,
          CASE WHEN v_lat IS NOT NULL THEN p_mission_id END)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.save_mission_address(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_mission_address(uuid, text, text) TO authenticated;

-- Adresse enregistree reutilisee : date de dernier usage
CREATE OR REPLACE FUNCTION public.use_saved_address(p_id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  UPDATE client_saved_addresses a SET last_used_at = now()
  WHERE a.id = p_id
    AND a.client_id IN (SELECT p.id FROM profiles p WHERE p.user_id = auth.uid());
$function$;
REVOKE EXECUTE ON FUNCTION public.use_saved_address(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.use_saved_address(uuid) TO authenticated;

-- 4. Effacements automatiques
CREATE OR REPLACE FUNCTION public.purge_google_location_data()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_days integer := least(greatest(public.app_setting_value('google_data_retention_days', 30), 1), 30)::int;
  v_ids  uuid[];
BEGIN
  SELECT coalesce(array_agg(m.id), '{}') INTO v_ids
  FROM missions m
  JOIN mission_exact_locations e ON e.mission_id = m.id
  WHERE e.google_data_purged_at IS NULL
    AND m.status IN ('completed', 'cancelled_client', 'cancelled_driver', 'expired')
    AND coalesce(m.completed_at, m.cancelled_at, m.auto_closed_at, m.updated_at) < now() - make_interval(days => v_days);

  IF cardinality(v_ids) = 0 THEN
    RETURN 0;
  END IF;

  UPDATE mission_exact_locations e
  SET pickup_location = NULL, pickup_lat = NULL, pickup_lng = NULL,
      dropoff_location = NULL, dropoff_lat = NULL, dropoff_lng = NULL,
      google_data_purged_at = now()
  WHERE e.mission_id = ANY (v_ids);

  UPDATE missions m
  SET pickup_district = NULL,
      dropoff_district = NULL,
      pickup_address = approx_place_label(NULL, m.pickup_city),
      dropoff_address = approx_place_label(NULL, m.dropoff_city),
      pickup_location = ST_SetSRID(ST_MakePoint(round(ST_X(m.pickup_location::geometry)::numeric, 1)::float8,
                                                round(ST_Y(m.pickup_location::geometry)::numeric, 1)::float8), 4326)::geography,
      dropoff_location = ST_SetSRID(ST_MakePoint(round(ST_X(m.dropoff_location::geometry)::numeric, 1)::float8,
                                                 round(ST_Y(m.dropoff_location::geometry)::numeric, 1)::float8), 4326)::geography
  WHERE m.id = ANY (v_ids);

  RETURN cardinality(v_ids);
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.purge_google_location_data() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_google_location_data() TO service_role;

CREATE OR REPLACE FUNCTION public.purge_unused_saved_addresses()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_months integer := greatest(public.app_setting_value('saved_addresses_unused_months', 12), 1)::int;
  v_count  integer;
BEGIN
  DELETE FROM client_saved_addresses a WHERE a.last_used_at < now() - make_interval(months => v_months);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.purge_unused_saved_addresses() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_unused_saved_addresses() TO service_role;

SELECT cron.unschedule('purge-google-location-data')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-google-location-data');
SELECT cron.schedule(
  'purge-google-location-data',
  '23 3 * * *',
  $$ SELECT public.purge_google_location_data(); $$
);
SELECT cron.unschedule('purge-unused-saved-addresses')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-unused-saved-addresses');
SELECT cron.schedule(
  'purge-unused-saved-addresses',
  '29 3 * * *',
  $$ SELECT public.purge_unused_saved_addresses(); $$
);

-- 5. Reglages
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
  -- Migration 078 (B1) : reglages des adresses
  IF NEW.key = 'address_entry_mode' AND NEW.value NOT IN (0, 1, 2) THEN
    RAISE EXCEPTION 'reglage_invalide: mode de saisie : 0 (adresse tapée + épingle), 1 (mixte) ou 2 (suggestions)' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'saved_addresses_max' AND (NEW.value < 1 OR NEW.value > 20 OR NEW.value <> trunc(NEW.value)) THEN
    RAISE EXCEPTION 'reglage_invalide: le nombre d''adresses enregistrées doit être un entier de 1 à 20' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'saved_addresses_unused_months' AND NEW.value < 1 THEN
    RAISE EXCEPTION 'reglage_invalide: la durée doit être d''au moins 1 mois' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'learned_point_max_distance_m' AND NEW.value < 10 THEN
    RAISE EXCEPTION 'reglage_invalide: la distance doit être d''au moins 10 m' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'learned_point_max_age_minutes' AND NEW.value < 1 THEN
    RAISE EXCEPTION 'reglage_invalide: l''ancienneté doit être d''au moins 1 minute' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'google_data_retention_days' AND (NEW.value < 1 OR NEW.value > 30) THEN
    RAISE EXCEPTION 'reglage_invalide: les données Google doivent être effacées en 30 jours au plus (au moins 1 jour)' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$function$;

INSERT INTO public.app_settings (key, value, description) VALUES
  ('address_entry_mode', 0, 'Saisie des adresses : 0 = adresse tapée + épingle, 1 = mixte, 2 = suggestions'),
  ('saved_addresses_max', 5, 'Nombre maximum d''adresses enregistrées par client'),
  ('saved_addresses_unused_months', 12, 'Adresse enregistrée effacée après ce nombre de mois sans usage'),
  ('learned_point_max_distance_m', 300, 'Distance maximale (m) entre la position du chauffeur et l''épingle du client pour apprendre le point'),
  ('learned_point_max_age_minutes', 5, 'Ancienneté maximale (minutes) de la position du chauffeur pour apprendre le point'),
  ('google_data_retention_days', 30, 'Effacement des données Google (points, quartier) après la fin de la mission, en jours (30 au plus)')
ON CONFLICT (key) DO NOTHING;
