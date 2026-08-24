-- Rollback de la migration 20260504000017
-- AVERTISSEMENT CRITIQUE : l'exécution de ce rollback reintroduit sciemment
-- la faille de securite corrigee par la migration 20260504000017 - exposition
-- publique (anon) du numero de telephone des chauffeurs (available_drivers) et
-- des donnees financieres individuelles des chauffeurs (driver_dashboard).
-- A n'executer qu'en cas d'incident de deploiement bloquant, jamais par confort
-- ou par simple retour en arriere de routine.

-- ============================================================
-- 1. Restauration des permissions d'execution larges sur la RPC
-- ============================================================
GRANT EXECUTE ON FUNCTION public.find_nearby_drivers(text, integer, vehicle_category) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.find_nearby_drivers(text, integer, vehicle_category) TO anon;

-- ============================================================
-- 2. Restauration de la vue driver_dashboard sans security_invoker
--    + acces anon
-- ============================================================
ALTER VIEW driver_dashboard RESET (security_invoker);
GRANT SELECT ON driver_dashboard TO anon;

-- ============================================================
-- 3. Restauration des acces larges sur available_drivers
-- ============================================================
GRANT SELECT ON available_drivers TO anon;
GRANT SELECT ON available_drivers TO authenticated;

-- ============================================================
-- 4. Restauration de la RPC find_nearby_drivers avec phone_number
-- ============================================================
CREATE OR REPLACE FUNCTION public.find_nearby_drivers(
  client_point text,
  radius_meters integer,
  p_vehicle_category vehicle_category
)
RETURNS TABLE(
  id uuid, full_name text, phone_number character varying,
  vehicle_category vehicle_category, vehicle_brand character varying,
  vehicle_model character varying, license_plate character varying,
  rating_average numeric, total_missions integer,
  distance_km numeric, last_location_update timestamp with time zone
)
LANGUAGE plpgsql SECURITY DEFINER AS $function$
BEGIN
  RETURN QUERY
  SELECT ad.id, ad.full_name::TEXT, ad.phone_number, ad.vehicle_category,
         ad.vehicle_brand, ad.vehicle_model, ad.license_plate,
         ad.rating_average, ad.total_missions,
         ROUND((ST_Distance(ad.current_location, ST_GeographyFromText(client_point)) / 1000)::NUMERIC, 2) AS distance_km,
         ad.last_location_update
  FROM available_drivers ad
  WHERE ST_DWithin(ad.current_location, ST_GeographyFromText(client_point), radius_meters)
    AND ad.vehicle_category = p_vehicle_category
    AND ad.last_location_update > NOW() - INTERVAL '5 minutes'
  ORDER BY distance_km ASC;
END;
$function$;

-- ============================================================
-- 5. Restauration de la vue available_drivers avec phone_number
-- ============================================================
CREATE OR REPLACE VIEW available_drivers AS
SELECT d.id,
  d.profile_id,
  p.full_name,
  p.phone_number,
  d.vehicle_category,
  d.vehicle_brand,
  d.vehicle_model,
  d.license_plate,
  d.current_location,
  d.rating_average,
  d.total_missions,
  d.last_location_update
FROM drivers d
  JOIN profiles p ON p.id = d.profile_id
WHERE d.is_verified = true AND d.is_available = true AND p.is_active = true;
