-- Rollback de la migration 20260504000076 (raison d'annulation du client,
-- historique du client montre aux chauffeurs, point C).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Remet les versions des migrations 072, 074 et 075. Les raisons enregistrees
-- sont supprimees avec leur table.

DROP TRIGGER IF EXISTS require_client_cancel_reason ON public.missions;
DROP FUNCTION IF EXISTS public.require_client_cancel_reason();
DROP FUNCTION IF EXISTS public.cancel_mission_by_client(uuid, text, text);
DROP FUNCTION IF EXISTS public.get_mission_client_record(uuid);
DROP TABLE IF EXISTS public.mission_cancel_reasons;
DELETE FROM public.app_settings WHERE key = 'client_cancel_window_months';

DROP FUNCTION IF EXISTS public.driver_open_missions();
CREATE FUNCTION public.driver_open_missions()
 RETURNS TABLE(id uuid, mission_number character varying, mission_type mission_type, vehicle_category vehicle_category, pickup_address text, pickup_city character varying, dropoff_address text, dropoff_city character varying, scheduled_pickup_time timestamp with time zone, estimated_distance_km numeric, needs_loading_help boolean, commission_amount numeric, cargo_weight_kg numeric, cargo_volume_m3 numeric, description text, status mission_status, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT m.id, m.mission_number, m.mission_type, m.vehicle_category,
         m.pickup_address, m.pickup_city, m.dropoff_address, m.dropoff_city,
         m.scheduled_pickup_time, m.estimated_distance_km, m.needs_loading_help,
         m.commission_amount, m.cargo_weight_kg, m.cargo_volume_m3,
         m.description, m.status, m.created_at
  FROM drivers d
  JOIN profiles p ON p.id = d.profile_id
  JOIN missions m ON m.vehicle_category = d.vehicle_category
  WHERE p.user_id = auth.uid()
    AND d.is_verified = true
    AND d.is_available = true
    AND p.is_active = true
    AND public.driver_balance_ok(d.id)
    AND m.status = 'pending'
    AND m.scheduled_pickup_time > now()
    AND m.client_id IS DISTINCT FROM d.profile_id
    AND public.mission_in_driver_range(d.id, m.id)
    AND NOT public.driver_schedule_conflict(d.id, m.id)
    AND NOT EXISTS (
      SELECT 1 FROM mission_offers o
      WHERE o.mission_id = m.id AND o.driver_id = d.id AND o.status = 'pending'
    )
  ORDER BY m.scheduled_pickup_time ASC;
$function$;
REVOKE EXECUTE ON FUNCTION public.driver_open_missions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.driver_open_missions() TO authenticated, service_role;
DROP FUNCTION IF EXISTS public.client_cancel_record(uuid);

CREATE OR REPLACE FUNCTION public.can_read_mission_exact_location(p_mission_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM missions m
    LEFT JOIN profiles pc ON pc.id = m.client_id
    LEFT JOIN drivers d ON d.id = m.driver_id
    LEFT JOIN profiles pd ON pd.id = d.profile_id
    WHERE m.id = p_mission_id
      AND (pc.user_id = auth.uid()
           OR (pd.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL))
  )
  OR EXISTS (SELECT 1 FROM profiles pa WHERE pa.user_id = auth.uid() AND pa.role = 'admin');
$function$;

DROP POLICY IF EXISTS "voice_messages_read_own" ON storage.objects;
CREATE POLICY "voice_messages_read_own"
ON storage.objects FOR SELECT
TO authenticated
USING (
  (bucket_id = 'voice-messages'::text) AND (
    ((storage.foldername(name))[2])::uuid IN (
      SELECT m.id FROM missions m
      JOIN profiles p_client ON p_client.id = m.client_id
      WHERE p_client.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL
      UNION
      SELECT m.id FROM missions m
      JOIN drivers d ON d.id = m.driver_id
      JOIN profiles p_driver ON p_driver.id = d.profile_id
      WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL
    )
  )
);

DROP POLICY IF EXISTS "voice_messages_upload_own" ON storage.objects;
CREATE POLICY "voice_messages_upload_own"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  (bucket_id = 'voice-messages'::text) AND (
    ((storage.foldername(name))[2])::uuid IN (
      SELECT m.id FROM missions m
      JOIN profiles p_client ON p_client.id = m.client_id
      WHERE p_client.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL
      UNION
      SELECT m.id FROM missions m
      JOIN drivers d ON d.id = m.driver_id
      JOIN profiles p_driver ON p_driver.id = d.profile_id
      WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL
    )
  )
);

-- Version 075 de validate_app_setting
CREATE OR REPLACE FUNCTION public.validate_app_setting()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cat text;
  v_other numeric;
BEGIN
  IF NEW.value < 0 THEN
    RAISE EXCEPTION 'reglage_invalide: la valeur ne peut pas être négative' USING ERRCODE = '22023';
  END IF;
  IF NEW.key LIKE 'commission\_amount\_%' THEN
    IF NEW.value < 1 THEN
      RAISE EXCEPTION 'reglage_invalide: la commission doit être d''au moins 1 DH' USING ERRCODE = '22023';
    END IF;
    v_cat := substr(NEW.key, length('commission_amount_') + 1);
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'min_balance_' || v_cat;
    IF v_other IS NOT NULL AND NEW.value > v_other THEN
      RAISE EXCEPTION 'reglage_invalide: la commission (% DH) ne peut pas dépasser le solde minimum de la catégorie (% DH)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  IF NEW.key LIKE 'min\_balance\_%' THEN
    v_cat := substr(NEW.key, length('min_balance_') + 1);
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'commission_amount_' || v_cat;
    IF v_other IS NOT NULL AND NEW.value < v_other THEN
      RAISE EXCEPTION 'reglage_invalide: le solde minimum (% DH) ne peut pas être inférieur à la commission de la catégorie (% DH)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.validate_app_setting() FROM PUBLIC, anon, authenticated;
