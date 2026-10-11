-- Migration 20260504000043 - volet 4b-5 (partie base)
-- Correction des deux gardiens de la table drivers + protection des dates.
--
-- 1. protect_driver_verification_fields (SECURITY INVOKER) :
--    - retrait du controle sur is_verified : colonne GENERATED ALWAYS
--      (4 statuts = verified), non modifiable directement et non calculee
--      dans un trigger BEFORE ; ce controle bloquait TOUTE mise a jour
--      chauffeur (constat par test du 10/10/2026).
--    - statuts : seul le passage vers 'pending' est autorise, NULL interdit.
--    - toute modification d'une date remet le document concerne en
--      'pending' (date de 1re mise en circulation -> carte grise).
--    - tout document non valide => chauffeur rendu indisponible (C.2).
-- 2. control_driver_availability (SECURITY DEFINER) :
--    - identification de l'appelant par auth.uid() : current_user vaut le
--      proprietaire dans une fonction SECURITY DEFINER, l'ancien controle
--      laissait donc tout passer (constat par test du 10/10/2026).
--    - redevenir disponible exige : aucune date modifiee dans la meme
--      operation, les 4 documents valides, aucun document expire,
--      solde suffisant (absence de wallet toleree, inchange).
-- Admin et systeme (CRON, service, SQL Editor) restent libres.

CREATE OR REPLACE FUNCTION public.protect_driver_verification_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Systeme (non-utilisateur) et admin : aucune restriction
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF public.get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  -- 1. Statuts : seul le passage vers 'pending' est autorise (NULL interdit)
  IF NEW.driver_license_verified IS DISTINCT FROM OLD.driver_license_verified
     AND NEW.driver_license_verified IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (permis)' USING ERRCODE = '42501';
  END IF;
  IF NEW.insurance_verified IS DISTINCT FROM OLD.insurance_verified
     AND NEW.insurance_verified IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (assurance)' USING ERRCODE = '42501';
  END IF;
  IF NEW.vehicle_registration_verified IS DISTINCT FROM OLD.vehicle_registration_verified
     AND NEW.vehicle_registration_verified IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (carte grise)' USING ERRCODE = '42501';
  END IF;
  IF NEW.technical_inspection_verified IS DISTINCT FROM OLD.technical_inspection_verified
     AND NEW.technical_inspection_verified IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (visite technique)' USING ERRCODE = '42501';
  END IF;

  -- 2. Dates : toute modification remet le document concerne en attente
  IF NEW.driver_license_expiry IS DISTINCT FROM OLD.driver_license_expiry THEN
    NEW.driver_license_verified := 'pending';
  END IF;
  IF NEW.insurance_expiry IS DISTINCT FROM OLD.insurance_expiry THEN
    NEW.insurance_verified := 'pending';
  END IF;
  IF NEW.vehicle_registration_expiry IS DISTINCT FROM OLD.vehicle_registration_expiry
     OR NEW.vehicle_first_service_date IS DISTINCT FROM OLD.vehicle_first_service_date THEN
    NEW.vehicle_registration_verified := 'pending';
  END IF;
  IF NEW.technical_inspection_expiry IS DISTINCT FROM OLD.technical_inspection_expiry THEN
    NEW.technical_inspection_verified := 'pending';
  END IF;

  -- 3. Document non valide : chauffeur rendu indisponible (C.2)
  IF NEW.driver_license_verified IS DISTINCT FROM 'verified'
     OR NEW.insurance_verified IS DISTINCT FROM 'verified'
     OR NEW.vehicle_registration_verified IS DISTINCT FROM 'verified'
     OR NEW.technical_inspection_verified IS DISTINCT FROM 'verified' THEN
    NEW.is_available := false;
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

  -- Systeme (CRON, service, SQL Editor) : aucun utilisateur connecte.
  -- current_user est inutilisable ici (SECURITY DEFINER => proprietaire).
  -- Un appel anon n'a pas d'identite mais ne passe pas la RLS UPDATE.
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF public.get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  -- Aucune date modifiee dans la meme operation (ce trigger passe avant
  -- protect_driver_verification_fields, qui remet le document en attente)
  IF NEW.driver_license_expiry IS DISTINCT FROM OLD.driver_license_expiry
     OR NEW.insurance_expiry IS DISTINCT FROM OLD.insurance_expiry
     OR NEW.vehicle_registration_expiry IS DISTINCT FROM OLD.vehicle_registration_expiry
     OR NEW.vehicle_first_service_date IS DISTINCT FROM OLD.vehicle_first_service_date
     OR NEW.technical_inspection_expiry IS DISTINCT FROM OLD.technical_inspection_expiry THEN
    RAISE EXCEPTION 'indisponibilite_validation: une date de document vient d''etre modifiee, attendez la validation de l''administrateur' USING ERRCODE = '42501';
  END IF;

  -- Les 4 documents doivent etre valides par l'administrateur
  IF NEW.driver_license_verified IS DISTINCT FROM 'verified'
     OR NEW.insurance_verified IS DISTINCT FROM 'verified'
     OR NEW.vehicle_registration_verified IS DISTINCT FROM 'verified'
     OR NEW.technical_inspection_verified IS DISTINCT FROM 'verified' THEN
    RAISE EXCEPTION 'indisponibilite_validation: un document est en attente de validation ou refuse, attendez la validation de l''administrateur' USING ERRCODE = '42501';
  END IF;

  -- Aucun document expire (dates inchangees : la ligne existante fait foi)
  IF public.driver_has_expired_documents(NEW.id) THEN
    RAISE EXCEPTION 'indisponibilite_documents: un document est expire, mettez vos documents a jour avant de redevenir disponible' USING ERRCODE = '42501';
  END IF;

  -- Solde suffisant (absence de wallet toleree)
  SELECT w.balance, w.minimum_balance INTO v_balance, v_minimum
  FROM wallet w
  WHERE w.driver_id = NEW.id;

  IF v_balance IS NOT NULL AND v_balance < v_minimum THEN
    RAISE EXCEPTION 'indisponibilite_solde: solde insuffisant (minimum requis), rechargez votre wallet avant de redevenir disponible' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;
