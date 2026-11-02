-- Migration 20260504000072 - point A1 : masquage de l'adresse exacte avant le
-- prelevement de la commission (accord du porteur du 02/11/2026)
--
-- Constat : un chauffeur « Disponible » pouvait lire la fiche complete de toute
-- mission en attente de sa categorie (regle missions_select_pending_for_drivers),
-- adresse et point exacts compris, meme si l'ecran ne les montrait pas.
--
-- Regles validees :
-- - avant le prelevement de la commission, le chauffeur ne connait que le
--   quartier et la ville (ou la ville seule), une position approchee (environ
--   1 km) et la distance arrondie au kilometre ;
-- - l'adresse et le point exacts sont lisibles par le client de la mission,
--   l'admin, et le chauffeur retenu une fois la commission prelevee (24 h avant,
--   ou tout de suite si l'accord est conclu a moins de 24 h) ;
-- - le client voit le prenom et la plaque du chauffeur au prelevement de la
--   commission ; jamais le telephone.
--
-- 1. Colonnes missions.pickup_district et missions.dropoff_district (quartier
--    deduit par le telephone du client a la creation ; non modifiables ensuite).
-- 2. Table mission_exact_locations : adresse et point exacts (partie
--    verrouillee), lecture seule selon la regle ci-dessus, aucune ecriture par
--    un utilisateur.
-- 3. A la creation d'une mission, le serveur range l'adresse et le point exacts
--    dans la partie verrouillee et ne laisse dans la fiche que « quartier,
--    ville », le point approche et la distance arrondie (dernier declencheur
--    avant insertion, apres le calcul de la distance). La fiche diffusee en
--    direct aux chauffeurs ne contient donc jamais l'adresse exacte.
-- 4. Missions existantes (donnees de test) : meme traitement.
-- 5. Rayon de diffusion : calcule sur le point exact (inchange pour le chauffeur).
-- 6. Notification « Nouvelle mission » : quartier et ville.
-- 7. Notification « Commission prelevee » : mention de l'adresse visible.
-- 8. Fonction get_mission_driver_identity : prenom et plaque pour le client.
-- 9. Petite correction : la notification « Mission expiree » du client disait
--    « Aucun chauffeur n'a ete trouve » meme quand des offres avaient ete faites.

-- 1. Quartier
ALTER TABLE public.missions
  ADD COLUMN IF NOT EXISTS pickup_district text,
  ADD COLUMN IF NOT EXISTS dropoff_district text;

REVOKE UPDATE (pickup_district, dropoff_district) ON public.missions FROM anon, authenticated;

-- 2. Partie verrouillee
CREATE TABLE IF NOT EXISTS public.mission_exact_locations (
  mission_id       uuid PRIMARY KEY
                   REFERENCES public.missions(id) ON DELETE CASCADE
                   DEFERRABLE INITIALLY DEFERRED,
  pickup_address   text,
  pickup_location  extensions.geography(Point, 4326),
  pickup_lat       double precision,
  pickup_lng       double precision,
  dropoff_address  text,
  dropoff_location extensions.geography(Point, 4326),
  dropoff_lat      double precision,
  dropoff_lng      double precision,
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.mission_exact_locations ENABLE ROW LEVEL SECURITY;

-- Qui peut lire l'adresse exacte d'une mission ?
CREATE OR REPLACE FUNCTION public.can_read_mission_exact_location(p_mission_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM missions m
    LEFT JOIN profiles pc ON pc.id = m.client_id
    LEFT JOIN drivers d ON d.id = m.driver_id
    LEFT JOIN profiles pd ON pd.id = d.profile_id
    WHERE m.id = p_mission_id
      AND (pc.user_id = auth.uid()
           OR (pd.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL))
  )
  OR EXISTS (SELECT 1 FROM profiles pa WHERE pa.user_id = auth.uid() AND pa.role = 'admin');
$function$;

REVOKE EXECUTE ON FUNCTION public.can_read_mission_exact_location(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_read_mission_exact_location(uuid) TO authenticated;

DROP POLICY IF EXISTS mission_exact_locations_select ON public.mission_exact_locations;
CREATE POLICY mission_exact_locations_select
  ON public.mission_exact_locations FOR SELECT TO authenticated
  USING (public.can_read_mission_exact_location(mission_id));

REVOKE ALL ON public.mission_exact_locations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.mission_exact_locations TO authenticated;

-- Libelle et point approches
CREATE OR REPLACE FUNCTION public.approx_place_label(p_district text, p_city text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN nullif(btrim(p_district), '') IS NOT NULL
         AND lower(btrim(p_district)) IS DISTINCT FROM lower(btrim(coalesce(p_city, '')))
      THEN btrim(p_district) || coalesce(', ' || nullif(btrim(p_city), ''), '')
    ELSE coalesce(nullif(btrim(p_city), ''), 'Ville non indiquée')
  END;
$function$;

CREATE OR REPLACE FUNCTION public.approx_point(p_point extensions.geography)
RETURNS extensions.geography
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
  SELECT CASE WHEN p_point IS NULL THEN NULL ELSE
    ST_SetSRID(ST_MakePoint(round(ST_X(p_point::geometry)::numeric, 2)::double precision,
                            round(ST_Y(p_point::geometry)::numeric, 2)::double precision), 4326)::geography
  END;
$function$;

REVOKE EXECUTE ON FUNCTION public.approx_place_label(text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.approx_point(extensions.geography) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approx_place_label(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approx_point(extensions.geography) TO authenticated;

-- 3. Rangement a la creation (nom choisi pour passer apres les autres
--    declencheurs « avant insertion », dont le calcul de la distance)
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

REVOKE EXECUTE ON FUNCTION public.hide_mission_exact_location() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS zz_hide_mission_exact_location ON public.missions;
CREATE TRIGGER zz_hide_mission_exact_location
  BEFORE INSERT ON public.missions
  FOR EACH ROW
  EXECUTE FUNCTION public.hide_mission_exact_location();

-- 4. Missions existantes (donnees de test)
INSERT INTO public.mission_exact_locations (mission_id, pickup_address, pickup_location, pickup_lat, pickup_lng,
                                            dropoff_address, dropoff_location, dropoff_lat, dropoff_lng)
SELECT m.id, m.pickup_address, m.pickup_location,
       extensions.ST_Y(m.pickup_location::extensions.geometry), extensions.ST_X(m.pickup_location::extensions.geometry),
       m.dropoff_address, m.dropoff_location,
       extensions.ST_Y(m.dropoff_location::extensions.geometry), extensions.ST_X(m.dropoff_location::extensions.geometry)
FROM public.missions m
ON CONFLICT (mission_id) DO NOTHING;

UPDATE public.missions m
SET pickup_address   = public.approx_place_label(m.pickup_district, m.pickup_city),
    dropoff_address  = public.approx_place_label(m.dropoff_district, m.dropoff_city),
    pickup_location  = public.approx_point(m.pickup_location),
    dropoff_location = public.approx_point(m.dropoff_location),
    estimated_distance_km = CASE WHEN m.estimated_distance_km IS NULL THEN NULL
                                 ELSE greatest(round(m.estimated_distance_km), 1) END;

-- 5. Rayon de diffusion : point exact
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
  SELECT coalesce(e.pickup_location, m.pickup_location), m.vehicle_category::text INTO v_point, v_category
  FROM missions m
  LEFT JOIN mission_exact_locations e ON e.mission_id = m.id
  WHERE m.id = p_mission_id;
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

-- 6. Notification « Nouvelle mission » : quartier et ville (ou ville seule)
CREATE OR REPLACE FUNCTION public.on_mission_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_body text;
BEGIN
  v_body := public.approx_place_label(NEW.pickup_district, NEW.pickup_city)
    || ' → ' || public.approx_place_label(NEW.dropoff_district, NEW.dropoff_city)
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

-- 7. Notification « Commission prelevee »
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
        || ' DH prélevée pour la mission ' || coalesce(NEW.mission_number, '') || '. '
        || 'L''adresse exacte du chargement est maintenant visible dans la mission.',
      jsonb_build_object('mission_id', NEW.id, 'screen', 'WalletDashboardScreen'),
      false
    );
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.notify_commission_charged() FROM PUBLIC, anon, authenticated;

-- 8. Prenom et plaque du chauffeur pour le client, au prelevement de la commission
CREATE OR REPLACE FUNCTION public.get_mission_driver_identity(p_mission_id uuid)
RETURNS TABLE (first_name text, license_plate text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT split_part(btrim(pd.full_name), ' ', 1)::text, d.license_plate::text
  FROM missions m
  JOIN profiles pc ON pc.id = m.client_id
  JOIN drivers d ON d.id = m.driver_id
  JOIN profiles pd ON pd.id = d.profile_id
  WHERE m.id = p_mission_id
    AND pc.user_id = auth.uid()
    AND m.commission_charged_at IS NOT NULL;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_mission_driver_identity(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_mission_driver_identity(uuid) TO authenticated;

-- 9. Notification « Mission expiree » du client (texte juste qu'il y ait eu des offres ou non)
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
      'Aucun accord n''a été conclu avec un chauffeur pour la mission ' || v_number || ' avant l''heure prévue.',
      jsonb_build_object('mission_id', NEW.id, 'screen', 'MissionTrackingScreen'),
      false
    );
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.on_mission_expired() FROM PUBLIC, anon, authenticated;
