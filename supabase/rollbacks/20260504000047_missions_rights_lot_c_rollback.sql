-- Rollback de la migration 20260504000047 (volet 5, lot C)
-- Restaure : droits UPDATE colonnes d'origine (etat migration 032) pour anon et
-- authenticated, droits table d'origine, les deux policies d'origine, et
-- supprime le trigger protect_mission_participant_fields.
-- A executer uniquement sur decision du porteur.

DROP TRIGGER IF EXISTS protect_mission_participant_fields ON public.missions;
DROP FUNCTION IF EXISTS public.protect_mission_participant_fields();

CREATE POLICY "Users can view their own missions"
    ON missions FOR SELECT
    USING (
        client_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
        OR driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Clients can create missions"
    ON missions FOR INSERT
    WITH CHECK (
        client_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
    );

GRANT INSERT, DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.missions TO anon;
GRANT DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.missions TO authenticated;

GRANT UPDATE (
  id, mission_number, client_id, mission_type, vehicle_category,
  pickup_location, pickup_address, pickup_city, dropoff_location, dropoff_address,
  dropoff_city, estimated_distance_km, description, needs_loading_help,
  payment_method, status, scheduled_pickup_time,
  actual_pickup_time, actual_dropoff_time, client_notes, driver_notes,
  client_rating, driver_rating, client_review, created_at, updated_at, completed_at
) ON public.missions TO authenticated;

GRANT UPDATE (
  id, mission_number, client_id, mission_type, vehicle_category,
  pickup_location, pickup_address, pickup_city, dropoff_location, dropoff_address,
  dropoff_city, estimated_distance_km, description, needs_loading_help,
  payment_method, status, scheduled_pickup_time,
  actual_pickup_time, actual_dropoff_time, client_notes, driver_notes,
  client_rating, driver_rating, client_review, created_at, updated_at, completed_at
) ON public.missions TO anon;
