-- Rollback de la migration 20260504000045 (volet 5, lot A)
-- Restaure : protect_driver_verification_fields de la 044, suppression du
-- trigger d'INSERT, droits d'origine sur drivers, update_driver_rating en
-- SECURITY INVOKER (definition d'origine du schema initial).
-- A executer uniquement sur decision du porteur.

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

DROP TRIGGER IF EXISTS protect_driver_insert_fields ON public.drivers;
DROP FUNCTION IF EXISTS public.protect_driver_insert_fields();

GRANT INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.drivers TO anon;
GRANT DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.drivers TO authenticated;

CREATE OR REPLACE FUNCTION public.update_driver_rating()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.client_rating IS NOT NULL AND (OLD.client_rating IS NULL OR OLD.client_rating != NEW.client_rating) THEN
        UPDATE drivers
        SET 
            rating_average = (
                SELECT ROUND(AVG(client_rating)::NUMERIC, 2)
                FROM missions
                WHERE driver_id = NEW.driver_id AND client_rating IS NOT NULL
            ),
            total_reviews = (
                SELECT COUNT(*)
                FROM missions
                WHERE driver_id = NEW.driver_id AND client_rating IS NOT NULL
            )
        WHERE id = NEW.driver_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
