-- Migration 20260504000019
-- Session 2.14 quinquies bis
-- Correction : accepter directement le cast ::geography pour client_point
-- (compatible WKT et HEXEWKB, ce dernier etant le format transmis par
-- le payload Realtime pour les colonnes geography - voir investigation
-- Partie 1 / Volet A)

CREATE OR REPLACE FUNCTION public.find_nearby_drivers(
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
         ROUND((ST_Distance(ad.current_location, client_point::geography) / 1000)::NUMERIC, 2) AS distance_km,
         ad.last_location_update
  FROM available_drivers ad
  WHERE ST_DWithin(ad.current_location, client_point::geography, radius_meters)
    AND ad.vehicle_category = p_vehicle_category
    AND ad.last_location_update > NOW() - INTERVAL '5 minutes'
  ORDER BY distance_km ASC;
END;
$function$;
