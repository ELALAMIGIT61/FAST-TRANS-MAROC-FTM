-- Migration 20260504000039 - Volet 4b-3 : controle du passage a is_available = true
-- 1. Fonction partagee driver_has_expired_documents(driver_id) : unique source de verite
--    pour "ce chauffeur a-t-il un document expire ?" (memes regles que le CRON 4b-2).
-- 2. Reecriture de block_drivers_with_expired_documents pour utiliser cette fonction (plus de duplication).
-- 3. Trigger de controle : un utilisateur ordinaire ne peut passer is_available de false a true
--    que si solde >= minimum ET aucun document expire. Rend le blocage reellement contraignant
--    (il etait contournable d'un clic). Admin et systeme non concernes.

-- 1. Fonction partagee de detection d'expiration
CREATE OR REPLACE FUNCTION public.driver_has_expired_documents(p_driver_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM drivers d
    WHERE d.id = p_driver_id
      AND (
        (d.driver_license_expiry IS NOT NULL AND d.driver_license_expiry < CURRENT_DATE)
        OR (d.insurance_expiry IS NOT NULL AND d.insurance_expiry < CURRENT_DATE)
        OR (d.vehicle_registration_expiry IS NOT NULL AND d.vehicle_registration_expiry < CURRENT_DATE)
        OR (
          d.vehicle_first_service_date IS NOT NULL
          AND d.vehicle_first_service_date < (CURRENT_DATE - INTERVAL '5 years')
          AND (d.technical_inspection_expiry IS NULL OR d.technical_inspection_expiry < CURRENT_DATE)
        )
      )
  );
$function$;

REVOKE EXECUTE ON FUNCTION public.driver_has_expired_documents(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.driver_has_expired_documents(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.driver_has_expired_documents(uuid) TO service_role;

-- 2. Reecriture du CRON de blocage pour utiliser la fonction partagee
CREATE OR REPLACE FUNCTION public.block_drivers_with_expired_documents()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_count integer;
BEGIN
  UPDATE drivers
  SET is_available = false
  WHERE is_available = true
    AND public.driver_has_expired_documents(id);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RAISE LOG 'block_drivers_with_expired_documents: % chauffeur(s) bloque(s)', v_count;
  RETURN v_count;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.block_drivers_with_expired_documents() FROM anon;
REVOKE EXECUTE ON FUNCTION public.block_drivers_with_expired_documents() FROM authenticated;

-- 3. Trigger de controle du passage a is_available = true
CREATE OR REPLACE FUNCTION public.control_driver_availability()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_balance numeric;
  v_minimum numeric;
BEGIN
  IF NOT (OLD.is_available = false AND NEW.is_available = true) THEN
    RETURN NEW;
  END IF;
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF public.get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  IF public.driver_has_expired_documents(NEW.id) THEN
    RAISE EXCEPTION 'indisponibilite_documents: un document est expire, mettez vos documents a jour avant de redevenir disponible'
      USING ERRCODE = '42501';
  END IF;

  SELECT w.balance, w.minimum_balance INTO v_balance, v_minimum
  FROM wallet w WHERE w.driver_id = NEW.id;

  IF v_balance IS NOT NULL AND v_balance < v_minimum THEN
    RAISE EXCEPTION 'indisponibilite_solde: solde insuffisant (minimum requis), rechargez votre wallet avant de redevenir disponible'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS control_driver_availability ON public.drivers;

CREATE TRIGGER control_driver_availability
  BEFORE UPDATE ON public.drivers
  FOR EACH ROW
  EXECUTE FUNCTION public.control_driver_availability();
