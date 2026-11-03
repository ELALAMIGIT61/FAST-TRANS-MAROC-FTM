-- Migration 20260504000075 - point A1 : accents dans les messages du serveur
-- (constat du test du 02/11/2026 : « prelevee », « reessayez », « depasser »...)
-- Seuls les textes changent ; les codes en tete des messages
-- (indisponibilite_solde, demarrage_impossible, ...) restent identiques, car
-- l'application s'en sert. Aucune regle ni donnee modifiee.

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
    RAISE EXCEPTION 'indisponibilite_validation: une date de document vient d''être modifiée, attendez la validation de l''administrateur' USING ERRCODE = '42501';
  END IF;

  -- Aucune information du vehicule modifiee dans la meme operation (044)
  IF NEW.vehicle_category IS DISTINCT FROM OLD.vehicle_category
     OR NEW.vehicle_brand IS DISTINCT FROM OLD.vehicle_brand
     OR NEW.vehicle_model IS DISTINCT FROM OLD.vehicle_model
     OR NEW.license_plate IS DISTINCT FROM OLD.license_plate
     OR NEW.vehicle_capacity_kg IS DISTINCT FROM OLD.vehicle_capacity_kg
     OR NEW.vehicle_registration_number IS DISTINCT FROM OLD.vehicle_registration_number THEN
    RAISE EXCEPTION 'indisponibilite_validation: les informations du véhicule viennent d''être modifiées, attendez la validation de l''administrateur' USING ERRCODE = '42501';
  END IF;

  -- Les 4 documents doivent etre valides par l'administrateur
  IF NEW.driver_license_verified IS DISTINCT FROM 'verified'
     OR NEW.insurance_verified IS DISTINCT FROM 'verified'
     OR NEW.vehicle_registration_verified IS DISTINCT FROM 'verified'
     OR NEW.technical_inspection_verified IS DISTINCT FROM 'verified' THEN
    RAISE EXCEPTION 'indisponibilite_validation: un document est en attente de validation ou refusé, attendez la validation de l''administrateur' USING ERRCODE = '42501';
  END IF;

  -- Aucun document expire (dates inchangees : la ligne existante fait foi)
  IF public.driver_has_expired_documents(NEW.id) THEN
    RAISE EXCEPTION 'indisponibilite_documents: un document est expiré, mettez vos documents à jour avant de redevenir disponible' USING ERRCODE = '42501';
  END IF;

  -- Solde disponible suffisant (migration 074 ; absence de wallet toleree)
  v_balance := public.driver_available_balance(NEW.id);
  v_minimum := public.driver_minimum_balance(NEW.id);

  IF v_balance IS NOT NULL AND v_balance < v_minimum THEN
    RAISE EXCEPTION 'indisponibilite_solde: solde disponible insuffisant (% DH, commissions à venir déduites ; minimum % DH), rechargez votre wallet avant de redevenir disponible',
      trim_scale(round(v_balance, 2)), trim_scale(v_minimum) USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.control_driver_availability() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.control_mission_status_transition()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_mission_driver BOOLEAN;
  v_is_mission_client BOOLEAN;
  v_offer_exists BOOLEAN;
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF public.get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM drivers d JOIN profiles p ON p.id = d.profile_id
    WHERE d.id = NEW.driver_id AND p.user_id = auth.uid()
  ) INTO v_is_mission_driver;

  SELECT EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = NEW.client_id AND p.user_id = auth.uid()
  ) INTO v_is_mission_client;

  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    SELECT EXISTS (
      SELECT 1 FROM mission_offers mo
      WHERE mo.mission_id = NEW.id AND mo.driver_id = NEW.driver_id AND mo.status = 'accepted'
    ) INTO v_offer_exists;
    IF NOT v_offer_exists THEN
      RAISE EXCEPTION 'transition_refusee: acceptation sans offre doublement acceptée' USING ERRCODE='42501';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'accepted' AND NEW.status = 'in_progress' THEN
    -- Migration 074 : la commission doit etre prelevee avant le demarrage
    IF v_is_mission_driver AND NEW.commission_charged_at IS NULL THEN
      RAISE EXCEPTION 'demarrage_impossible: la commission de cette mission n''est pas encore prélevée. Si votre solde est insuffisant, rechargez votre wallet ; sinon réessayez dans quelques minutes.' USING ERRCODE = '42501';
    END IF;
    IF v_is_mission_driver THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'transition_refusee: démarrage réservé au chauffeur de la mission' USING ERRCODE='42501';
  END IF;

  IF OLD.status = 'in_progress' AND NEW.status = 'completed' THEN
    IF v_is_mission_driver THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'transition_refusee: clôture réservée au chauffeur de la mission' USING ERRCODE='42501';
  END IF;

  IF OLD.status IN ('pending','accepted') AND NEW.status = 'cancelled_client' THEN
    IF v_is_mission_client THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'transition_refusee: annulation réservée au client de la mission' USING ERRCODE='42501';
  END IF;

  IF OLD.status IN ('pending','accepted') AND NEW.status = 'cancelled_driver' THEN
    IF v_is_mission_driver THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'transition_refusee: annulation réservée au chauffeur de la mission' USING ERRCODE='42501';
  END IF;

  IF OLD.status = 'pending' AND NEW.status = 'expired' THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'transition_refusee: changement de statut non autorisé (% -> %)', OLD.status, NEW.status USING ERRCODE='42501';
END;
$function$;

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
