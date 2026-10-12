-- Migration 20260504000044 - volet 4b-5 (C.1.2 changement de vehicule)
-- Extension des deux gardiens de la table drivers (migration 043) aux
-- informations du vehicule : categorie, marque, modele, plaque, capacite,
-- numero de carte grise.
--
-- Regle (decision du porteur, 12/10/2026) : tout changement des informations
-- du vehicule par le chauffeur doit etre valide par l'administrateur.
-- 1. protect_driver_verification_fields : toute modification d'une de ces
--    colonnes remet la carte grise en 'pending' (=> chauffeur indisponible).
-- 2. control_driver_availability : refus de redevenir disponible dans la
--    meme operation qu'une modification de ces colonnes.
-- Admin et systeme (CRON, service, SQL Editor) restent libres (inchange).
-- Le reste des deux fonctions est strictement identique a la migration 043.

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

  -- 2bis. Vehicule (044) : tout changement remet la carte grise en attente
  IF NEW.vehicle_category IS DISTINCT FROM OLD.vehicle_category
     OR NEW.vehicle_brand IS DISTINCT FROM OLD.vehicle_brand
     OR NEW.vehicle_model IS DISTINCT FROM OLD.vehicle_model
     OR NEW.license_plate IS DISTINCT FROM OLD.license_plate
     OR NEW.vehicle_capacity_kg IS DISTINCT FROM OLD.vehicle_capacity_kg
     OR NEW.vehicle_registration_number IS DISTINCT FROM OLD.vehicle_registration_number THEN
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

  -- Aucune information du vehicule modifiee dans la meme operation (044)
  IF NEW.vehicle_category IS DISTINCT FROM OLD.vehicle_category
     OR NEW.vehicle_brand IS DISTINCT FROM OLD.vehicle_brand
     OR NEW.vehicle_model IS DISTINCT FROM OLD.vehicle_model
     OR NEW.license_plate IS DISTINCT FROM OLD.license_plate
     OR NEW.vehicle_capacity_kg IS DISTINCT FROM OLD.vehicle_capacity_kg
     OR NEW.vehicle_registration_number IS DISTINCT FROM OLD.vehicle_registration_number THEN
    RAISE EXCEPTION 'indisponibilite_validation: les informations du vehicule viennent d''etre modifiees, attendez la validation de l''administrateur' USING ERRCODE = '42501';
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
