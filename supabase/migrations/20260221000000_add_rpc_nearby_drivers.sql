-- Migration: add_rpc_nearby_drivers
-- Adds the find_nearby_drivers() RPC function used by missionService.ts

CREATE OR REPLACE FUNCTION find_nearby_drivers(
    client_point       TEXT,
    radius_meters      INTEGER,
    p_vehicle_category vehicle_category
)
RETURNS TABLE (
    id                   UUID,
    full_name            TEXT,
    phone_number         VARCHAR,
    vehicle_category     vehicle_category,
    vehicle_brand        VARCHAR,
    vehicle_model        VARCHAR,
    license_plate        VARCHAR,
    rating_average       DECIMAL,
    total_missions       INTEGER,
    distance_km          DECIMAL,
    last_location_update TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ad.id,
        ad.full_name::TEXT,
        ad.phone_number,
        ad.vehicle_category,
        ad.vehicle_brand,
        ad.vehicle_model,
        ad.license_plate,
        ad.rating_average,
        ad.total_missions,
        ROUND((ST_Distance(
            ad.current_location,
            ST_GeographyFromText(client_point)
        ) / 1000)::NUMERIC, 2) AS distance_km,
        ad.last_location_update
    FROM available_drivers ad
    WHERE ST_DWithin(
        ad.current_location,
        ST_GeographyFromText(client_point),
        radius_meters
    )
    AND ad.vehicle_category = p_vehicle_category
    AND ad.last_location_update > NOW() - INTERVAL '5 minutes'
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
