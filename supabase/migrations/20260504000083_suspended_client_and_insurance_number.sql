-- Migration 20260504000083 - controle de la suspension des clients et du numero d'assurance
-- (validee par le porteur le 23/11/2026 ; aucun fichier protege modifie)
--
-- 1. Client suspendu encore connecte (constat de la campagne de tests du
--    20/11/2026 : un client suspendu a cree une mission). Le serveur refuse
--    desormais, pour un client dont le compte est suspendu (profiles.is_active
--    faux) : creer une mission, creer un colis, accepter une offre ou proposer
--    un prix, noter un chauffeur. Restent autorises (decision du porteur du
--    23/11/2026) : annuler une mission en cours, refuser une offre, les messages
--    vocaux et la gestion de ses adresses enregistrees.
--    Seules les actions faites directement par le client sont controlees
--    (current_user = authenticated) ; les automatismes de la base et les
--    fonctions du serveur ne sont pas touches.
-- 2. Numero de police d'assurance : un changement de ce numero par le chauffeur
--    remet l'assurance en attente, comme un changement de sa date, et rend donc
--    le chauffeur indisponible jusqu'a la validation de l'administrateur.
--    Le trigger porte un nom qui le fait passer avant
--    protect_driver_verification_fields, qui rend le chauffeur indisponible
--    quand un document est en attente.
-- Retour arriere : supabase/rollbacks/20260504000083_suspended_client_and_insurance_number_rollback.sql

-- 1. Client suspendu
CREATE OR REPLACE FUNCTION public.current_client_is_suspended()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE user_id = auth.uid() AND role = 'client' AND is_active IS FALSE
  );
$function$;

REVOKE ALL ON FUNCTION public.current_client_is_suspended() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_client_is_suspended() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.block_suspended_client()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Automatismes et fonctions du serveur : aucun controle
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF NOT public.current_client_is_suspended() THEN
    RETURN NEW;
  END IF;

  -- Un bloc par table : les champs de NEW ne sont lus que pour la bonne table
  IF TG_TABLE_NAME = 'missions' THEN
    IF TG_OP = 'INSERT' THEN
      RAISE EXCEPTION 'compte_suspendu: votre compte est suspendu, vous ne pouvez pas créer de mission. Contactez le service Fast Trans Maroc.' USING ERRCODE = '42501';
    END IF;
    IF NEW.rating_punctuality IS DISTINCT FROM OLD.rating_punctuality
       OR NEW.rating_care IS DISTINCT FROM OLD.rating_care
       OR NEW.rating_service IS DISTINCT FROM OLD.rating_service
       OR NEW.client_rating IS DISTINCT FROM OLD.client_rating
       OR NEW.client_review IS DISTINCT FROM OLD.client_review THEN
      RAISE EXCEPTION 'compte_suspendu: votre compte est suspendu, vous ne pouvez pas noter de chauffeur. Contactez le service Fast Trans Maroc.' USING ERRCODE = '42501';
    END IF;
  ELSIF TG_TABLE_NAME = 'mission_offers' THEN
    IF NEW.offered_price IS DISTINCT FROM OLD.offered_price
       OR (NEW.client_accepted IS TRUE AND OLD.client_accepted IS NOT TRUE) THEN
      RAISE EXCEPTION 'compte_suspendu: votre compte est suspendu, vous ne pouvez pas accepter d''offre ni proposer de prix. Contactez le service Fast Trans Maroc.' USING ERRCODE = '42501';
    END IF;
  ELSIF TG_TABLE_NAME = 'ecommerce_parcels' THEN
    RAISE EXCEPTION 'compte_suspendu: votre compte est suspendu, vous ne pouvez pas créer de colis. Contactez le service Fast Trans Maroc.' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS a_block_suspended_client ON public.missions;
CREATE TRIGGER a_block_suspended_client
  BEFORE INSERT OR UPDATE ON public.missions
  FOR EACH ROW EXECUTE FUNCTION public.block_suspended_client();

DROP TRIGGER IF EXISTS a_block_suspended_client ON public.mission_offers;
CREATE TRIGGER a_block_suspended_client
  BEFORE UPDATE ON public.mission_offers
  FOR EACH ROW EXECUTE FUNCTION public.block_suspended_client();

DROP TRIGGER IF EXISTS a_block_suspended_client ON public.ecommerce_parcels;
CREATE TRIGGER a_block_suspended_client
  BEFORE INSERT ON public.ecommerce_parcels
  FOR EACH ROW EXECUTE FUNCTION public.block_suspended_client();

-- 2. Numero de police d'assurance
CREATE OR REPLACE FUNCTION public.insurance_number_requires_validation()
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
  IF NEW.insurance_number IS DISTINCT FROM OLD.insurance_number THEN
    NEW.insurance_verified := 'pending';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS protect_driver_insurance_number ON public.drivers;
CREATE TRIGGER protect_driver_insurance_number
  BEFORE UPDATE ON public.drivers
  FOR EACH ROW EXECUTE FUNCTION public.insurance_number_requires_validation();
