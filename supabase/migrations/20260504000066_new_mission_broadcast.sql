-- Migration 20260504000066 - point A1, F1 : notification « Nouvelle mission »
-- envoyee par le serveur (accord du porteur du 26/10/2026)
--
-- Constat : un chauffeur n'apprenait une nouvelle mission que s'il avait
-- l'application ouverte sur son accueil. Application fermee ou telephone en
-- veille : rien. Le modele de notification « Nouvelle mission » existait dans
-- l'application mais n'etait jamais envoye (et l'application du client n'a
-- pas le droit de notifier les chauffeurs, a juste titre).
-- Par ailleurs, le rayon de 60 km, decide pour les VUL (session 2.14
-- quinquies bis), etait applique par l'application a toutes les categories.
--
-- Regles validees :
-- - sont prevenus les chauffeurs de la meme categorie que la mission, aux
--   documents verifies, en mode « disponible » (compte actif) ;
-- - rayon de diffusion par categorie, autour du point de chargement, mesure
--   depuis la derniere position connue du chauffeur : VUL 60 km, N2 Moyen et
--   N2 Grand sans limite (valeur 0) ; reglable par l'admin (app_settings) ;
-- - pas de notification a un chauffeur bloque par la regle des ecarts entre
--   missions (migration 064) ;
-- - un chauffeur « non disponible » ne recoit rien.
--
-- 1. Reglages broadcast_radius_km_<categorie>.
-- 2. Fonctions internes : mission_in_driver_range (rayon) et
--    driver_schedule_conflict (meme regle que la migration 064).
-- 3. Fonction driver_mission_in_range(mission) pour l'accueil du chauffeur :
--    remplace le rayon fixe de 60 km de l'application.
-- 4. Trigger missions_on_created (apres creation d'une mission en attente) :
--    depose la notification « Nouvelle mission » ; la sonnerie est assuree
--    par la migration 057. Une erreur ici n'empeche jamais la creation de la
--    mission.
-- Aucune donnee existante modifiee.

-- 1. Reglages (0 = sans limite)
INSERT INTO public.app_settings (key, value, description) VALUES
  ('broadcast_radius_km_vul', 60, 'Rayon (km) de diffusion des missions VUL autour du point de chargement (0 = sans limite)'),
  ('broadcast_radius_km_n2_medium', 0, 'Rayon (km) de diffusion des missions N2 Moyen autour du point de chargement (0 = sans limite)'),
  ('broadcast_radius_km_n2_large', 0, 'Rayon (km) de diffusion des missions N2 Grand autour du point de chargement (0 = sans limite)')
ON CONFLICT (key) DO NOTHING;

-- 2a. Le chauffeur est-il dans le rayon de diffusion de la mission ?
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

-- 2b. Le chauffeur a-t-il deja une mission trop proche (regle de la 064) ?
CREATE OR REPLACE FUNCTION public.driver_schedule_conflict(p_driver_id uuid, p_mission_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_target timestamptz;
  v_gap numeric;
BEGIN
  SELECT m.scheduled_pickup_time INTO v_target FROM missions m WHERE m.id = p_mission_id;
  IF v_target IS NULL THEN
    RETURN false;
  END IF;

  SELECT s.value INTO v_gap
  FROM app_settings s
  JOIN drivers d ON s.key = 'driver_gap_hours_' || d.vehicle_category::text
  WHERE d.id = p_driver_id;
  v_gap := coalesce(v_gap, 12);

  RETURN EXISTS (
    SELECT 1 FROM missions m
    WHERE m.driver_id = p_driver_id
      AND m.id <> p_mission_id
      AND m.status IN ('accepted', 'in_progress')
      AND m.scheduled_pickup_time IS NOT NULL
      AND abs(extract(epoch FROM (m.scheduled_pickup_time - v_target))) < v_gap * 3600
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.driver_schedule_conflict(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- 3. Pour l'accueil du chauffeur connecte : la mission est-elle dans son rayon ?
CREATE OR REPLACE FUNCTION public.driver_mission_in_range(p_mission_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_driver uuid;
BEGIN
  SELECT d.id INTO v_driver
  FROM drivers d JOIN profiles p ON p.id = d.profile_id
  WHERE p.user_id = auth.uid();
  IF v_driver IS NULL THEN
    RETURN false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM missions m WHERE m.id = p_mission_id AND m.status = 'pending') THEN
    RETURN false;
  END IF;
  RETURN public.mission_in_driver_range(v_driver, p_mission_id);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.driver_mission_in_range(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.driver_mission_in_range(uuid) TO authenticated;

-- 4. Notification « Nouvelle mission »
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

DROP TRIGGER IF EXISTS missions_on_created ON public.missions;
CREATE TRIGGER missions_on_created
  AFTER INSERT ON public.missions
  FOR EACH ROW
  WHEN (NEW.status = 'pending')
  EXECUTE FUNCTION public.on_mission_created();
