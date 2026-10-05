-- Migration 20260504000032 - Volet transitions : controle des changements de statut, driver_id, negotiated_price
-- 1. Verrouillage des droits sur driver_id et negotiated_price (comme commission au volet 1)
-- 2. Trigger de controle des transitions de statut sur missions
-- Regles (utilisateurs ordinaires uniquement ; systeme et admin non concernes) :
--   pending   -> accepted            : seulement si une offre 'accepted' existe pour (mission, driver_id) = double acceptation
--   accepted  -> in_progress         : seulement le chauffeur de la mission
--   in_progress -> completed         : seulement le chauffeur de la mission
--   pending/accepted -> cancelled_client : seulement le client de la mission
--   pending/accepted -> cancelled_driver : seulement le chauffeur de la mission
--   pending   -> expired             : autorise (mecanisme d'expiration)
--   toute autre transition de statut : refusee
--   driver_id et negotiated_price    : non modifiables par un utilisateur

-- 1. Verrouillage driver_id + negotiated_price (retrait droit table, re-octroi des autres colonnes)
REVOKE UPDATE ON public.missions FROM anon;
REVOKE UPDATE ON public.missions FROM authenticated;

GRANT UPDATE (
  id, mission_number, client_id, mission_type, vehicle_category,
  pickup_location, pickup_address, pickup_city, dropoff_location, dropoff_address,
  dropoff_city, estimated_distance_km, description, needs_loading_help,
  payment_method, status, scheduled_pickup_time,
  actual_pickup_time, actual_dropoff_time, client_notes, driver_notes,
  client_rating, driver_rating, client_review, created_at, updated_at, completed_at
) ON public.missions TO authenticated;

GRANT UPDATE (
  id, mission_number, client_id, mission_type, vehicle_category,
  pickup_location, pickup_address, pickup_city, dropoff_location, dropoff_address,
  dropoff_city, estimated_distance_km, description, needs_loading_help,
  payment_method, status, scheduled_pickup_time,
  actual_pickup_time, actual_dropoff_time, client_notes, driver_notes,
  client_rating, driver_rating, client_review, created_at, updated_at, completed_at
) ON public.missions TO anon;

-- 2. Trigger de controle des transitions de statut
CREATE OR REPLACE FUNCTION public.control_mission_status_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
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
      RAISE EXCEPTION 'transition_refusee: acceptation sans offre doublement acceptee' USING ERRCODE='42501';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'accepted' AND NEW.status = 'in_progress' THEN
    IF v_is_mission_driver THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'transition_refusee: demarrage reserve au chauffeur de la mission' USING ERRCODE='42501';
  END IF;

  IF OLD.status = 'in_progress' AND NEW.status = 'completed' THEN
    IF v_is_mission_driver THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'transition_refusee: cloture reservee au chauffeur de la mission' USING ERRCODE='42501';
  END IF;

  IF OLD.status IN ('pending','accepted') AND NEW.status = 'cancelled_client' THEN
    IF v_is_mission_client THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'transition_refusee: annulation client reservee au client de la mission' USING ERRCODE='42501';
  END IF;

  IF OLD.status IN ('pending','accepted') AND NEW.status = 'cancelled_driver' THEN
    IF v_is_mission_driver THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'transition_refusee: annulation chauffeur reservee au chauffeur de la mission' USING ERRCODE='42501';
  END IF;

  IF OLD.status = 'pending' AND NEW.status = 'expired' THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'transition_refusee: changement de statut non autorise (% -> %)', OLD.status, NEW.status USING ERRCODE='42501';
END;
$function$;

DROP TRIGGER IF EXISTS control_mission_status_transition ON public.missions;

CREATE TRIGGER control_mission_status_transition
  BEFORE UPDATE ON public.missions
  FOR EACH ROW
  EXECUTE FUNCTION public.control_mission_status_transition();
