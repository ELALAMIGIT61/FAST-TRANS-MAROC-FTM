-- Rollback de la migration 20260504000055 (session 2.24)
-- Reinstalle PostGIS dans le schema public, faille comprise (table
-- spatial_ref_sys modifiable par anon et authenticated) : a n'utiliser
-- qu'en cas de blocage. Echoue si des missions existent (colonnes NOT NULL).

DROP FUNCTION public.find_nearby_drivers(text, integer, public.vehicle_category);
DROP FUNCTION public.calculate_distance(extensions.geography, extensions.geography);
DROP VIEW public.available_drivers;
DROP INDEX IF EXISTS public.idx_drivers_location;
DROP INDEX IF EXISTS public.idx_missions_pickup_location;
DROP INDEX IF EXISTS public.idx_missions_dropoff_location;
ALTER TABLE public.drivers DROP COLUMN current_location;
ALTER TABLE public.missions DROP COLUMN pickup_location, DROP COLUMN dropoff_location;

DROP EXTENSION postgis;
CREATE EXTENSION postgis WITH SCHEMA public;

ALTER TABLE public.drivers ADD COLUMN current_location public.geography(Point, 4326);
ALTER TABLE public.missions
  ADD COLUMN pickup_location public.geography(Point, 4326) NOT NULL,
  ADD COLUMN dropoff_location public.geography(Point, 4326) NOT NULL;

CREATE INDEX idx_drivers_location ON public.drivers USING gist (current_location);
CREATE INDEX idx_missions_pickup_location ON public.missions USING gist (pickup_location);
CREATE INDEX idx_missions_dropoff_location ON public.missions USING gist (dropoff_location);

CREATE VIEW public.available_drivers AS
 SELECT d.id, d.profile_id, p.full_name, d.vehicle_category, d.vehicle_brand,
    d.vehicle_model, d.license_plate, d.current_location, d.rating_average,
    d.total_missions, d.last_location_update
   FROM public.drivers d
     JOIN public.profiles p ON p.id = d.profile_id
  WHERE d.is_verified = true AND d.is_available = true AND p.is_active = true;

REVOKE ALL ON public.available_drivers FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.available_drivers TO service_role;

CREATE OR REPLACE FUNCTION public.calculate_distance(point1 public.geography, point2 public.geography)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN ROUND((ST_Distance(point1, point2) / 1000)::NUMERIC, 2);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.calculate_distance(public.geography, public.geography)
  TO PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.find_nearby_drivers(client_point text, radius_meters integer, p_vehicle_category public.vehicle_category)
 RETURNS TABLE(id uuid, full_name text, vehicle_category public.vehicle_category, vehicle_brand character varying, vehicle_model character varying, license_plate character varying, rating_average numeric, total_missions integer, distance_km numeric, last_location_update timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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
