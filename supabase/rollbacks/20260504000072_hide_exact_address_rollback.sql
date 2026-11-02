-- Rollback de la migration 20260504000072 (masquage de l'adresse exacte).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Remet l'adresse et le point exacts dans la fiche des missions, puis retire
-- la partie verrouillee et remet les fonctions dans leur version precedente
-- (migrations 066, 068 et 063).
SET CONSTRAINTS ALL IMMEDIATE;
UPDATE public.missions m
SET pickup_address = e.pickup_address, pickup_location = e.pickup_location,
    dropoff_address = e.dropoff_address, dropoff_location = e.dropoff_location
FROM public.mission_exact_locations e
WHERE e.mission_id = m.id;

DROP TRIGGER IF EXISTS zz_hide_mission_exact_location ON public.missions;
DROP FUNCTION IF EXISTS public.hide_mission_exact_location();
DROP FUNCTION IF EXISTS public.get_mission_driver_identity(uuid);
DROP TABLE IF EXISTS public.mission_exact_locations;
DROP FUNCTION IF EXISTS public.can_read_mission_exact_location(uuid);

-- Version de la migration 066
CREATE OR REPLACE FUNCTION public.mission_in_driver_range(p_driver_id uuid, p_mission_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_radius numeric;
  v_point extensions.geography;
  v_category text;
  v_driver_location extensions.geography;
BEGIN
  SELECT m.pickup_location, m.vehicle_category::text INTO v_point, v_category
  FROM missions m WHERE m.id = p_mission_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  SELECT s.value INTO v_radius
  FROM app_settings s WHERE s.key = 'broadcast_radius_km_' || v_category;
  v_radius := coalesce(v_radius, 0);
  IF v_radius <= 0 THEN
    RETURN true;
  END IF;

  SELECT d.current_location INTO v_driver_location FROM drivers d WHERE d.id = p_driver_id;
  IF v_driver_location IS NULL OR v_point IS NULL THEN
    RETURN false;
  END IF;
  RETURN ST_DWithin(v_driver_location, v_point, v_radius * 1000);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.mission_in_driver_range(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- Version de la migration 068
CREATE OR REPLACE FUNCTION public.on_mission_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_body text;
BEGIN
  v_body := coalesce(NEW.pickup_city, '?') || ' → ' || coalesce(NEW.dropoff_city, '?')
    || CASE WHEN NEW.scheduled_pickup_time IS NULL THEN ''
            ELSE ', le ' || to_char(NEW.scheduled_pickup_time AT TIME ZONE 'UTC', 'DD/MM "à" HH24"h"MI') END
    || CASE WHEN NEW.cargo_weight_kg IS NULL AND NEW.cargo_volume_m3 IS NULL THEN ''
            ELSE ' — ' || concat_ws(', ',
                   CASE WHEN NEW.cargo_weight_kg IS NOT NULL
                        THEN trim_scale(NEW.cargo_weight_kg)::text || ' kg' END,
                   CASE WHEN NEW.cargo_volume_m3 IS NOT NULL
                        THEN replace(trim_scale(NEW.cargo_volume_m3)::text, '.', ',') || ' m³' END) END
    || '. Touchez pour voir la mission et faire une offre.';

  BEGIN
    INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
    SELECT d.profile_id,
           'new_mission',
           '🚚 Nouvelle mission',
           v_body,
           jsonb_build_object('mission_id', NEW.id, 'mission_number', NEW.mission_number,
                              'screen', 'NewMissionModal'),
           false
    FROM drivers d
    JOIN profiles p ON p.id = d.profile_id
    WHERE d.vehicle_category = NEW.vehicle_category
      AND d.is_verified = true
      AND d.is_available = true
      AND p.is_active = true
      AND d.profile_id IS DISTINCT FROM NEW.client_id
      AND public.mission_in_driver_range(d.id, NEW.id)
      AND NOT public.driver_schedule_conflict(d.id, NEW.id);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'on_mission_created: notifications non envoyees pour la mission % (%)',
      NEW.mission_number, SQLERRM;
  END;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.on_mission_created() FROM PUBLIC, anon, authenticated;

-- Version de la migration 063
CREATE OR REPLACE FUNCTION public.notify_commission_charged()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_profile uuid;
BEGIN
  SELECT d.profile_id INTO v_profile FROM public.drivers d WHERE d.id = NEW.driver_id;
  IF v_profile IS NOT NULL THEN
    INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
    VALUES (
      v_profile,
      'commission_charged',
      '💰 Commission prélevée',
      'Commission de ' || coalesce(trim_scale(NEW.commission_amount)::text, '?')
        || ' DH prélevée pour la mission ' || coalesce(NEW.mission_number, '') || '.',
      jsonb_build_object('mission_id', NEW.id, 'screen', 'WalletDashboardScreen'),
      false
    );
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.notify_commission_charged() FROM PUBLIC, anon, authenticated;

DROP FUNCTION IF EXISTS public.approx_place_label(text, text);
DROP FUNCTION IF EXISTS public.approx_point(extensions.geography);
ALTER TABLE public.missions DROP COLUMN IF EXISTS pickup_district;
ALTER TABLE public.missions DROP COLUMN IF EXISTS dropoff_district;

-- Version de la migration 059
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

REVOKE EXECUTE ON FUNCTION public.on_mission_expired() FROM PUBLIC, anon, authenticated;
