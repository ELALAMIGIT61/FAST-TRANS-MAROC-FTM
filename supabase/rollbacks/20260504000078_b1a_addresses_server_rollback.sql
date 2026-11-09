-- Rollback de la migration 20260504000078 (B1-a, partie serveur des adresses).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Attention : les reperes, les positions des chauffeurs et les adresses
-- enregistrees sont perdus ; les donnees Google deja effacees ne reviennent pas.

SELECT cron.unschedule('purge-google-location-data')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-google-location-data');
SELECT cron.unschedule('purge-unused-saved-addresses')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-unused-saved-addresses');

DROP FUNCTION IF EXISTS public.purge_google_location_data();
DROP FUNCTION IF EXISTS public.purge_unused_saved_addresses();
DROP FUNCTION IF EXISTS public.save_mission_address(uuid, text, text);
DROP FUNCTION IF EXISTS public.use_saved_address(uuid);

DROP TRIGGER IF EXISTS missions_record_driver_position ON public.missions;
DROP FUNCTION IF EXISTS public.record_mission_driver_position();

DROP TABLE IF EXISTS public.client_saved_addresses;
DROP TABLE IF EXISTS public.mission_driver_positions;

DELETE FROM public.app_settings
WHERE key IN ('address_entry_mode', 'saved_addresses_max', 'saved_addresses_unused_months',
              'learned_point_max_distance_m', 'learned_point_max_age_minutes', 'google_data_retention_days');

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

DROP FUNCTION IF EXISTS public.app_setting_value(text, numeric);

ALTER TABLE public.mission_exact_locations
  DROP COLUMN IF EXISTS pickup_landmark,
  DROP COLUMN IF EXISTS dropoff_landmark,
  DROP COLUMN IF EXISTS google_data_purged_at;

ALTER TABLE public.missions DROP CONSTRAINT IF EXISTS missions_landmarks_length;
ALTER TABLE public.missions
  DROP COLUMN IF EXISTS pickup_landmark,
  DROP COLUMN IF EXISTS dropoff_landmark;
