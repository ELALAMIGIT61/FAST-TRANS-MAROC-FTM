-- Migration 20260504000042 - Volet 4b-4 : protection des champs de validation des documents
-- Faille : anon/authenticated ont UPDATE sur toute la table drivers et aucun WITH CHECK ->
-- un chauffeur pouvait ecrire 'verified' sur ses propres documents et is_verified=true,
-- s'auto-validant sans l'admin. Correctif : un trigger controle les champs de validation.
-- Regles (utilisateurs ordinaires uniquement ; admin et systeme non concernes) :
--   - les 4 statuts ..._verified : un chauffeur peut les passer a 'pending' (remplacement
--     legitime, cf resetDocumentStatus) mais JAMAIS a 'verified' ni 'rejected' (admin seul).
--   - is_verified (drapeau global) : non modifiable par un chauffeur (admin/systeme seuls).
-- Supprime aussi le doublon de policy UPDATE (Drivers can update their own data == drivers_update_own).

CREATE OR REPLACE FUNCTION public.protect_driver_verification_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $function$
BEGIN
  -- Systeme (non-utilisateur) et admin : aucune restriction
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF public.get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  -- is_verified global : non modifiable par un chauffeur
  IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
    RAISE EXCEPTION 'validation_interdite: le statut de verification global ne peut etre modifie que par un administrateur'
      USING ERRCODE = '42501';
  END IF;

  -- Statuts des documents : seul le passage vers 'pending' est autorise au chauffeur
  IF NEW.driver_license_verified IS DISTINCT FROM OLD.driver_license_verified
     AND NEW.driver_license_verified <> 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (permis)'
      USING ERRCODE = '42501';
  END IF;
  IF NEW.insurance_verified IS DISTINCT FROM OLD.insurance_verified
     AND NEW.insurance_verified <> 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (assurance)'
      USING ERRCODE = '42501';
  END IF;
  IF NEW.vehicle_registration_verified IS DISTINCT FROM OLD.vehicle_registration_verified
     AND NEW.vehicle_registration_verified <> 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (carte grise)'
      USING ERRCODE = '42501';
  END IF;
  IF NEW.technical_inspection_verified IS DISTINCT FROM OLD.technical_inspection_verified
     AND NEW.technical_inspection_verified <> 'pending' THEN
    RAISE EXCEPTION 'validation_interdite: seul un administrateur peut valider ou rejeter un document (visite technique)'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS protect_driver_verification_fields ON public.drivers;

CREATE TRIGGER protect_driver_verification_fields
  BEFORE UPDATE ON public.drivers
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_driver_verification_fields();

-- Suppression du doublon de policy UPDATE (identique a drivers_update_own)
DROP POLICY IF EXISTS "Drivers can update their own data" ON public.drivers;
