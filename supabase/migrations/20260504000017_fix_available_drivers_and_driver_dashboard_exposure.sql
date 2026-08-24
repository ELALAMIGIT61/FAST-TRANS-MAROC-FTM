-- Migration 20260504000017
-- Correction de sécurité : exposition non filtrée de available_drivers et driver_dashboard
-- Découverte fortuite en cours d'investigation session 2.14 quinquies (Partie 1)
-- Périmètre initial de la session élargi sur décision explicite du porteur — voir rapport de synthèse

-- ============================================================
-- 0. Suppression préalable de la fonction dépendante et de la vue
--    (CREATE OR REPLACE VIEW ne permet pas de retirer une colonne
--    existante — SQLSTATE 42P16 — nécessite DROP puis CREATE)
-- ============================================================
DROP FUNCTION IF EXISTS public.find_nearby_drivers(text, integer, vehicle_category);
DROP VIEW IF EXISTS available_drivers;

-- ============================================================
-- 1. Recréation de la vue available_drivers sans phone_number
-- ============================================================
CREATE VIEW available_drivers AS
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
FROM drivers d
  JOIN profiles p ON p.id = d.profile_id
WHERE d.is_verified = true AND d.is_available = true AND p.is_active = true;

-- ============================================================
-- 2. Recréation de la RPC find_nearby_drivers sans phone_number
-- ============================================================
CREATE FUNCTION public.find_nearby_drivers(
  client_point text,
  radius_meters integer,
  p_vehicle_category vehicle_category
)
RETURNS TABLE(
  id uuid,
  full_name text,
  vehicle_category vehicle_category,
  vehicle_brand character varying,
  vehicle_model character varying,
  license_plate character varying,
  rating_average numeric,
  total_missions integer,
  distance_km numeric,
  last_location_update timestamp with time zone
)
LANGUAGE plpgsql SECURITY DEFINER AS $function$
BEGIN
  RETURN QUERY
  SELECT ad.id, ad.full_name::TEXT, ad.vehicle_category,
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
-- 3. Révocation des accès larges sur available_drivers
--    Seule la RPC (SECURITY DEFINER) doit pouvoir la consulter
-- ============================================================
REVOKE SELECT ON available_drivers FROM anon;
REVOKE SELECT ON available_drivers FROM authenticated;

-- ============================================================
-- 4. Révocation de l'accès anonyme sur driver_dashboard
--    + activation de security_invoker pour faire respecter
--    le RLS déjà strict de wallet/transactions/drivers
-- ============================================================
REVOKE SELECT ON driver_dashboard FROM anon;
ALTER VIEW driver_dashboard SET (security_invoker = true);

-- ============================================================
-- 5. Restriction des permissions d'exécution sur la RPC elle-même
--    Retrait de anon et PUBLIC, ne laisser que authenticated
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.find_nearby_drivers(text, integer, vehicle_category) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.find_nearby_drivers(text, integer, vehicle_category) FROM anon;
GRANT EXECUTE ON FUNCTION public.find_nearby_drivers(text, integer, vehicle_category) TO authenticated;
