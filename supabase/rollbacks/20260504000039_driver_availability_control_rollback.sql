-- Rollback 20260504000039
-- Retire le trigger de controle de disponibilite et la fonction partagee,
-- et restaure block_drivers_with_expired_documents dans sa version autonome (migration 037).
-- Effet : le passage a is_available=true redevient libre (blocage contournable d'un clic).
-- A n'utiliser qu'en cas de regression bloquante, sur decision explicite du porteur.

DROP TRIGGER IF EXISTS control_driver_availability ON public.drivers;
DROP FUNCTION IF EXISTS public.control_driver_availability();

-- Restauration de la version autonome du CRON (sans la fonction partagee)
CREATE OR REPLACE FUNCTION public.block_drivers_with_expired_documents()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_today date := CURRENT_DATE;
  v_count integer;
BEGIN
  WITH to_block AS (
    SELECT d.id
    FROM drivers d
    WHERE d.is_available = true
      AND (
        (d.driver_license_expiry IS NOT NULL AND d.driver_license_expiry < v_today)
        OR (d.insurance_expiry IS NOT NULL AND d.insurance_expiry < v_today)
        OR (d.vehicle_registration_expiry IS NOT NULL AND d.vehicle_registration_expiry < v_today)
        OR (
          d.vehicle_first_service_date IS NOT NULL
          AND d.vehicle_first_service_date < (v_today - INTERVAL '5 years')
          AND (
            d.technical_inspection_expiry IS NULL
            OR d.technical_inspection_expiry < v_today
          )
        )
      )
  )
  UPDATE drivers
  SET is_available = false
  WHERE id IN (SELECT id FROM to_block);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RAISE LOG 'block_drivers_with_expired_documents: % chauffeur(s) bloque(s)', v_count;
  RETURN v_count;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.block_drivers_with_expired_documents() FROM anon;
REVOKE EXECUTE ON FUNCTION public.block_drivers_with_expired_documents() FROM authenticated;

DROP FUNCTION IF EXISTS public.driver_has_expired_documents(uuid);
