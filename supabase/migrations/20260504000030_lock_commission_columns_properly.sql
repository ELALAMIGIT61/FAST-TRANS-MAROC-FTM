-- Migration 20260504000030 - Volet 1 securite (correctif) : verrouillage effectif des colonnes financieres
-- La migration 029 utilisait REVOKE UPDATE (colonnes) FROM anon/authenticated, inefficace
-- car un droit UPDATE existait aussi sur la table entiere. Methode correcte :
--   1. retirer UPDATE sur la table entiere
--   2. re-accorder UPDATE colonne par colonne sur toutes les colonnes SAUF
--      commission_amount et commission_charged_at
-- Resultat : commission_amount et commission_charged_at ne sont plus modifiables
-- par anon ni authenticated. negotiated_price, status, driver_id restent modifiables
-- (verrouillage reporte au volet transitions).

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
