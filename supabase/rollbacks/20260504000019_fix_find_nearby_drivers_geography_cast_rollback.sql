-- Rollback migration 20260504000019
-- Restaure la version ST_GeographyFromText(client_point)
-- ATTENTION : ne pas executer sans raison documentee -
-- reintroduit l'incompatibilite avec le format HEXEWKB
-- transmis par le payload Realtime.

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
         ROUND((ST_Distance(ad.current_location, ST_GeographyFromText(client_point)) / 1000)::NUMERIC, 2) AS distance_km,
         ad.last_location_update
  FROM available_drivers ad
  WHERE ST_DWithin(ad.current_location, ST_GeographyFromText(client_point), radius_meters)
    AND ad.vehicle_category = p_vehicle_category
    AND ad.last_location_update > NOW() - INTERVAL '5 minutes'
  ORDER BY distance_km ASC;
END;
$function$;
