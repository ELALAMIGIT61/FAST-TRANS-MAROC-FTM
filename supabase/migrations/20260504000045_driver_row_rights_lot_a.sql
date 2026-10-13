-- Migration 20260504000045 - volet 5, lot A : droits du chauffeur sur sa fiche
-- (decisions du porteur du 13/10/2026 : A1, A2 option a, A3, A4)
--
-- A1. protect_driver_verification_fields (reprise de la 044) : la note
--     (rating_average), le nombre d'avis (total_reviews) et le nombre de
--     missions (total_missions) ne sont plus modifiables directement par un
--     utilisateur ; seuls les automatismes (triggers sur missions), l'admin et
--     le systeme le peuvent. Le reste de la fonction est identique a la 044.
-- A2. Nouveau trigger BEFORE INSERT protect_driver_insert_fields : une fiche
--     creee par un utilisateur (non admin) demarre toujours avec les 4 documents
--     en 'pending', indisponible, 0 mission, 0 avis, note 0 (valeurs corrigees
--     silencieusement ; l'inscription normale n'envoie pas ces champs).
-- A3. Menage des droits sur la table drivers : anon perd tout droit d'ecriture ;
--     authenticated perd DELETE (aucune policy DELETE), TRUNCATE, TRIGGER,
--     REFERENCES. Inchanges : SELECT/INSERT/UPDATE d'authenticated (encadres par
--     les policies et les triggers).
-- A4. update_driver_rating passe en SECURITY DEFINER : le recalcul de la note,
--     declenche par la notation d'un client, etait bloque par la RLS de drivers
--     (le client n'est pas proprietaire de la fiche) et echouait en silence.

-- A1
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

  -- 2ter. Statistiques (045) : note, nombre d'avis et nombre de missions ne
  -- sont modifiables que par les automatismes de la base (triggers sur
  -- missions : fin de mission, notation), jamais directement par l'utilisateur.
  -- pg_trigger_depth() = 1 : modification directe (pas issue d'un autre trigger).
  IF pg_trigger_depth() = 1 AND (
       NEW.rating_average IS DISTINCT FROM OLD.rating_average
       OR NEW.total_reviews IS DISTINCT FROM OLD.total_reviews
       OR NEW.total_missions IS DISTINCT FROM OLD.total_missions) THEN
    RAISE EXCEPTION 'statistiques_protegees: la note, le nombre d''avis et le nombre de missions sont calcules automatiquement' USING ERRCODE = '42501';
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

-- A2
CREATE OR REPLACE FUNCTION public.protect_driver_insert_fields()
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

  NEW.driver_license_verified       := 'pending';
  NEW.vehicle_registration_verified := 'pending';
  NEW.insurance_verified            := 'pending';
  NEW.technical_inspection_verified := 'pending';
  NEW.is_available   := false;
  NEW.total_missions := 0;
  NEW.total_reviews  := 0;
  NEW.rating_average := 0;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS protect_driver_insert_fields ON public.drivers;
CREATE TRIGGER protect_driver_insert_fields
  BEFORE INSERT ON public.drivers
  FOR EACH ROW EXECUTE FUNCTION public.protect_driver_insert_fields();

-- A3
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.drivers FROM anon;
REVOKE DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.drivers FROM authenticated;

-- A4 (meme calcul qu'a l'origine, execute avec les droits du proprietaire)
CREATE OR REPLACE FUNCTION public.update_driver_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$;
