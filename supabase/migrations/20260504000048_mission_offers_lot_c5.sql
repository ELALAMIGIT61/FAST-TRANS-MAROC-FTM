-- Migration 20260504000048 - volet 5, lot C5 : offres et attribution des missions
-- (decisions du porteur du 13/10/2026 : C5a, C5b, C5c, C5d)
--
-- Constat (13/10/2026) : sync_mission_on_offer_accepted et
-- process_commission_payment s'executent avec l'identite de l'utilisateur
-- (SECURITY INVOKER) et ecrivent des colonnes verrouillees par les migrations
-- 030 et 032 (driver_id, negotiated_price, commission_charged_at) : la double
-- acceptation d'une offre ne pouvait pas attribuer la mission, et le filet de
-- securite de la commission en fin de mission aurait fait echouer la cloture.
-- Avant de les reparer, les offres sont protegees (aucune regle ne verifiait qui
-- donne quel accord).
--
-- C5a. Nouveau trigger BEFORE INSERT OR UPDATE protect_mission_offer_fields
--      (utilisateurs uniquement ; admin et systeme libres) :
--      - creation : l'offre demarre sans accord, en attente, au tour 1, et
--        seulement sur une mission en attente ;
--      - mission, chauffeur, identifiant et date de creation non modifiables ;
--      - accord client : seulement le client de la mission ; accord chauffeur :
--        seulement le chauffeur de l'offre ; un accord ne se retire qu'en
--        retirant l'offre (statut not_selected), par l'une ou l'autre partie ;
--      - statut accepted seulement si les deux accords sont reunis (calcule par
--        check_mission_offer_transition) ; not_selected seulement depuis pending ;
--      - prix : le client au tour 1 (le tour reste 1) ; le chauffeur une seule
--        contre-proposition (tour 1 -> 2).
-- C5b. sync_mission_on_offer_accepted : SECURITY DEFINER, chemin fixe (contenu
--      inchange).
-- C5c. process_commission_payment : SECURITY DEFINER, chemin fixe (contenu
--      inchange).
-- C5d. Menage des droits sur mission_offers : anon perd INSERT, UPDATE, DELETE,
--      TRUNCATE, TRIGGER, REFERENCES ; authenticated perd DELETE, TRUNCATE,
--      TRIGGER, REFERENCES (aucune policy DELETE, l'application ne supprime pas).

-- C5a
CREATE OR REPLACE FUNCTION public.protect_mission_offer_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_driver boolean;
  v_is_client boolean;
  v_mission_status text;
BEGIN
  -- Systeme (non-utilisateur) et admin : aucune restriction
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF public.get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    SELECT m.status::text INTO v_mission_status FROM missions m WHERE m.id = NEW.mission_id;
    IF v_mission_status IS DISTINCT FROM 'pending' THEN
      RAISE EXCEPTION 'offre_refusee: la mission n''est pas (ou plus) disponible' USING ERRCODE = '42501';
    END IF;
    NEW.client_accepted := false;
    NEW.driver_accepted := false;
    NEW.status := 'pending';
    NEW.round_number := 1;
    RETURN NEW;
  END IF;

  -- UPDATE
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.mission_id IS DISTINCT FROM OLD.mission_id
     OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'offre_refusee: la mission et le chauffeur d''une offre ne sont pas modifiables' USING ERRCODE = '42501';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM drivers d JOIN profiles p ON p.id = d.profile_id
    WHERE d.id = OLD.driver_id AND p.user_id = auth.uid()
  ) INTO v_is_driver;

  SELECT EXISTS (
    SELECT 1 FROM missions m JOIN profiles p ON p.id = m.client_id
    WHERE m.id = OLD.mission_id AND p.user_id = auth.uid()
  ) INTO v_is_client;

  -- Accord du client
  IF NEW.client_accepted IS DISTINCT FROM OLD.client_accepted THEN
    IF NEW.client_accepted THEN
      IF NOT v_is_client THEN
        RAISE EXCEPTION 'offre_refusee: seul le client de la mission peut donner l''accord client' USING ERRCODE = '42501';
      END IF;
    ELSIF NEW.status IS DISTINCT FROM 'not_selected' THEN
      RAISE EXCEPTION 'offre_refusee: un accord ne se retire qu''en retirant l''offre' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Accord du chauffeur
  IF NEW.driver_accepted IS DISTINCT FROM OLD.driver_accepted THEN
    IF NEW.driver_accepted THEN
      IF NOT v_is_driver THEN
        RAISE EXCEPTION 'offre_refusee: seul le chauffeur de l''offre peut donner l''accord chauffeur' USING ERRCODE = '42501';
      END IF;
    ELSIF NEW.status IS DISTINCT FROM 'not_selected' THEN
      RAISE EXCEPTION 'offre_refusee: un accord ne se retire qu''en retirant l''offre' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Statut
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status = 'accepted' THEN
      IF NOT (NEW.client_accepted AND NEW.driver_accepted) THEN
        RAISE EXCEPTION 'offre_refusee: une offre n''est acceptee qu''avec les deux accords' USING ERRCODE = '42501';
      END IF;
    ELSIF NEW.status = 'not_selected' THEN
      IF OLD.status IS DISTINCT FROM 'pending' THEN
        RAISE EXCEPTION 'offre_refusee: seule une offre en attente peut etre retiree' USING ERRCODE = '42501';
      END IF;
    ELSE
      RAISE EXCEPTION 'offre_refusee: changement de statut non autorise (% -> %)', OLD.status, NEW.status USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Prix et tour de negociation
  IF NEW.offered_price IS DISTINCT FROM OLD.offered_price
     OR NEW.round_number IS DISTINCT FROM OLD.round_number THEN
    IF v_is_driver THEN
      IF NOT (OLD.round_number = 1 AND NEW.round_number = 2) THEN
        RAISE EXCEPTION 'offre_refusee: le chauffeur ne peut faire qu''une contre-proposition (tour 1 vers 2)' USING ERRCODE = '42501';
      END IF;
    ELSIF v_is_client THEN
      IF NOT (OLD.round_number = 1 AND NEW.round_number = 1) THEN
        RAISE EXCEPTION 'offre_refusee: le client ne peut modifier le prix qu''au tour 1' USING ERRCODE = '42501';
      END IF;
    ELSE
      RAISE EXCEPTION 'offre_refusee: modification du prix reservee aux participants' USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS protect_mission_offer_fields ON public.mission_offers;
CREATE TRIGGER protect_mission_offer_fields
  BEFORE INSERT OR UPDATE ON public.mission_offers
  FOR EACH ROW EXECUTE FUNCTION public.protect_mission_offer_fields();

-- C5b
ALTER FUNCTION public.sync_mission_on_offer_accepted() SECURITY DEFINER;
ALTER FUNCTION public.sync_mission_on_offer_accepted() SET search_path TO 'public', 'pg_temp';

-- C5c
ALTER FUNCTION public.process_commission_payment() SECURITY DEFINER;
ALTER FUNCTION public.process_commission_payment() SET search_path TO 'public', 'pg_temp';

-- C5d
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.mission_offers FROM anon;
REVOKE DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.mission_offers FROM authenticated;
