-- Rollback 20260504000032
-- ATTENTION : executer ce fichier REINTRODUIT les failles de transitions
-- (statut librement modifiable, driver_id et negotiated_price a nouveau modifiables).
-- Il PRESERVE le verrouillage des colonnes financieres du volet 1
-- (commission_amount, commission_charged_at restent verrouillees).
-- A n'utiliser qu'en cas de regression bloquante, sur decision explicite du porteur.

DROP TRIGGER IF EXISTS control_mission_status_transition ON public.missions;
DROP FUNCTION IF EXISTS public.control_mission_status_transition();

REVOKE UPDATE ON public.missions FROM anon;
REVOKE UPDATE ON public.missions FROM authenticated;

GRANT UPDATE (
  id, mission_number, client_id, driver_id, mission_type, vehicle_category,
  pickup_location, pickup_address, pickup_city, dropoff_location, dropoff_address,
  dropoff_city, estimated_distance_km, description, needs_loading_help,
  negotiated_price, payment_method, status, scheduled_pickup_time,
  actual_pickup_time, actual_dropoff_time, client_notes, driver_notes,
  client_rating, driver_rating, client_review, created_at, updated_at, completed_at
) ON public.missions TO authenticated;

GRANT UPDATE (
  id, mission_number, client_id, driver_id, mission_type, vehicle_category,
  pickup_location, pickup_address, pickup_city, dropoff_location, dropoff_address,
  dropoff_city, estimated_distance_km, description, needs_loading_help,
  negotiated_price, payment_method, status, scheduled_pickup_time,
  actual_pickup_time, actual_dropoff_time, client_notes, driver_notes,
  client_rating, driver_rating, client_review, created_at, updated_at, completed_at
) ON public.missions TO anon;
