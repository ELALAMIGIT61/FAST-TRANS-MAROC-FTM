-- Migration 20260504000055 - session 2.24 : deplacement de PostGIS du schema
-- public vers le schema extensions (decision du porteur du 16/10/2026)
--
-- Constat (16/10/2026) :
--  - alerte critique Supabase « rls_disabled_in_public » sur la table
--    public.spatial_ref_sys, creee par l'extension PostGIS installee dans
--    public (premiere migration) ;
--  - cette table appartient a supabase_admin ; anon et authenticated y ont
--    tous les droits, accordes par supabase_admin, que notre compte ne peut
--    ni retirer ni restreindre (RLS impossible a activer) : n'importe qui
--    disposant de la cle publique pouvait la modifier ou la vider par l'API ;
--  - recommandation de Supabase : installer les extensions dans le schema
--    extensions, non expose par l'API ;
--  - PostGIS 3.x ne peut pas changer de schema (ALTER EXTENSION ... SET SCHEMA
--    refuse) : il faut le desinstaller puis le reinstaller ;
--  - inventaire de la vraie base : 3 colonnes geographiques, 3 index, la vue
--    available_drivers, 2 fonctions ; aucune position de chauffeur et aucune
--    mission enregistrees (rien a sauvegarder).
--
-- 1. Suppression des objets qui dependent de PostGIS
-- 2. Desinstallation de PostGIS, reinstallation dans le schema extensions
-- 3. Recreation a l'identique des colonnes, index, vue et fonctions, avec les
--    memes droits ; le chemin de recherche des deux fonctions inclut desormais
--    extensions (sinon ST_Distance et ST_DWithin seraient introuvables).
-- Securite : la vue available_drivers reste illisible directement par anon et
-- authenticated (lue seulement par find_nearby_drivers, executee avec les
-- droits du proprietaire) ; ses droits sont fixes explicitement, car les droits
-- par defaut du schema public accorderaient la lecture a tous.
--
-- Garde-fou : si des missions existent, l'ajout des colonnes NOT NULL echoue
-- et toute la migration est annulee.

-- 1
DROP FUNCTION public.find_nearby_drivers(text, integer, public.vehicle_category);
DROP FUNCTION public.calculate_distance(geography, geography);
DROP VIEW public.available_drivers;
DROP INDEX IF EXISTS public.idx_drivers_location;
DROP INDEX IF EXISTS public.idx_missions_pickup_location;
DROP INDEX IF EXISTS public.idx_missions_dropoff_location;
ALTER TABLE public.drivers DROP COLUMN current_location;
ALTER TABLE public.missions DROP COLUMN pickup_location, DROP COLUMN dropoff_location;

-- 2
DROP EXTENSION postgis;
CREATE EXTENSION postgis WITH SCHEMA extensions;

-- 3. Colonnes et index
ALTER TABLE public.drivers ADD COLUMN current_location extensions.geography(Point, 4326);
ALTER TABLE public.missions
  ADD COLUMN pickup_location extensions.geography(Point, 4326) NOT NULL,
  ADD COLUMN dropoff_location extensions.geography(Point, 4326) NOT NULL;

CREATE INDEX idx_drivers_location ON public.drivers USING gist (current_location);
CREATE INDEX idx_missions_pickup_location ON public.missions USING gist (pickup_location);
CREATE INDEX idx_missions_dropoff_location ON public.missions USING gist (dropoff_location);

-- 3. Vue (definition identique)
CREATE VIEW public.available_drivers AS
 SELECT d.id,
    d.profile_id,
    p.full_name,
    d.vehicle_category,
    d.vehicle_brand,
    d.vehicle_model,
    d.license_plate,
    d.current_location,
    d.rating_average,
    d.total_missions,
    d.last_location_update
   FROM public.drivers d
     JOIN public.profiles p ON p.id = d.profile_id
  WHERE d.is_verified = true AND d.is_available = true AND p.is_active = true;

REVOKE ALL ON public.available_drivers FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.available_drivers TO service_role;

-- 3. Fonctions (corps identiques, chemin de recherche complete)
CREATE OR REPLACE FUNCTION public.calculate_distance(point1 extensions.geography, point2 extensions.geography)
 RETURNS numeric
 LANGUAGE plpgsql
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
    RETURN ROUND((ST_Distance(point1, point2) / 1000)::NUMERIC, 2);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.calculate_distance(extensions.geography, extensions.geography)
  TO PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.find_nearby_drivers(client_point text, radius_meters integer, p_vehicle_category public.vehicle_category)
 RETURNS TABLE(id uuid, full_name text, vehicle_category public.vehicle_category, vehicle_brand character varying, vehicle_model character varying, license_plate character varying, rating_average numeric, total_missions integer, distance_km numeric, last_location_update timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
  SELECT ad.id, ad.full_name::TEXT, ad.vehicle_category,
         ad.vehicle_brand, ad.vehicle_model, ad.license_plate,
         ad.rating_average, ad.total_missions,
         ROUND((ST_Distance(ad.current_location, client_point::geography) / 1000)::NUMERIC, 2) AS distance_km,
         ad.last_location_update
  FROM available_drivers ad
  WHERE ST_DWithin(ad.current_location, client_point::geography, radius_meters)
    AND ad.vehicle_category = p_vehicle_category
    AND ad.last_location_update > NOW() - INTERVAL '5 minutes'
  ORDER BY distance_km ASC;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.find_nearby_drivers(text, integer, public.vehicle_category) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_nearby_drivers(text, integer, public.vehicle_category) TO authenticated, service_role;
