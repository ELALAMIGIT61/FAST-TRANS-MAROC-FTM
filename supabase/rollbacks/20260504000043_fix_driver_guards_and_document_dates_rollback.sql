-- Rollback de la migration 20260504000043 - volet 4b-5 (partie base)
-- Restaure la logique des deux fonctions telle que lue en base le 10/10/2026
-- (etat apres migrations 039 et 042). Commentaires d'origine non repris.
-- ATTENTION : restaure aussi les deux defauts corriges par 043
-- (blocage de toute mise a jour chauffeur ; gardien de disponibilite inoperant).

CREATE OR REPLACE FUNCTION public.protect_driver_verification_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF public.get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
    RAISE EXCEPTION 'validation_interdite: le statut de verification global ne peut etre modifie que par un administrateur' USING ERRCODE = '42501';
  END IF;

  IF NEW.driver_license_verified IS DISTINCT FROM OLD.driver_license_verified AND NEW.driver_license_verified <> 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (permis)' USING ERRCODE = '42501';
  END IF;
  IF NEW.insurance_verified IS DISTINCT FROM OLD.insurance_verified AND NEW.insurance_verified <> 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (assurance)' USING ERRCODE = '42501';
  END IF;
  IF NEW.vehicle_registration_verified IS DISTINCT FROM OLD.vehicle_registration_verified AND NEW.vehicle_registration_verified <> 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (carte grise)' USING ERRCODE = '42501';
  END IF;
  IF NEW.technical_inspection_verified IS DISTINCT FROM OLD.technical_inspection_verified AND NEW.technical_inspection_verified <> 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (visite technique)' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.control_driver_availability()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
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
    RAISE EXCEPTION 'indisponibilite_documents: un document est expire, mettez vos documents a jour avant de redevenir disponible' USING ERRCODE = '42501';
  END IF;

  SELECT w.balance, w.minimum_balance INTO v_balance, v_minimum
  FROM wallet w
  WHERE w.driver_id = NEW.id;

  IF v_balance IS NOT NULL AND v_balance < v_minimum THEN
    RAISE EXCEPTION 'indisponibilite_solde: solde insuffisant (minimum requis), rechargez votre wallet avant de redevenir disponible' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;
