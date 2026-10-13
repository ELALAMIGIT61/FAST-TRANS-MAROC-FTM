-- Migration 20260504000047 - volet 5, lot C : missions
-- (decisions du porteur du 13/10/2026 : C1, C2, C3, C4 ; note definitive)
--
-- C1. Le "contrat" d'une mission n'est plus modifiable par un utilisateur
--     apres la creation : retrait du droit UPDATE sur id, mission_number,
--     client_id, created_at, mission_type, vehicle_category, adresses et
--     localisations, distance, date prevue, mode de paiement, description,
--     aide au chargement. Restent modifiables (et encadres par C2 et par le
--     controle des transitions de la migration 032) : status, actual_pickup_time,
--     actual_dropoff_time, completed_at, client_notes, driver_notes,
--     client_rating, client_review, driver_rating, updated_at.
--     (driver_id, negotiated_price, commission_* deja verrouilles : 030, 032.)
-- C2. Nouveau trigger BEFORE UPDATE protect_mission_participant_fields :
--     - note et avis du client : seulement le client de la mission, mission
--       terminee, une seule fois (note definitive) ;
--     - note du chauffeur sur le client : seulement le chauffeur, mission
--       terminee, une seule fois ;
--     - notes du client : seulement le client ; notes du chauffeur et heures
--       (prise en charge, livraison, fin) : seulement le chauffeur.
--     Admin et systeme libres.
-- C3. Suppression de deux policies d'origine (schema initial) :
--     "Clients can create missions" (permettait a tout utilisateur, y compris
--     un chauffeur, de creer une mission ; reste missions_insert_client, reservee
--     au role client) et "Users can view their own missions" (doublon exact de
--     missions_select_participants).
-- C4. Menage des droits : anon perd INSERT, UPDATE (toutes colonnes), DELETE,
--     TRUNCATE, TRIGGER, REFERENCES ; authenticated perd DELETE (aucune policy
--     DELETE), TRUNCATE, TRIGGER, REFERENCES.

-- C1
REVOKE UPDATE (
  id, mission_number, client_id, created_at, mission_type, vehicle_category,
  pickup_location, pickup_address, pickup_city,
  dropoff_location, dropoff_address, dropoff_city,
  estimated_distance_km, scheduled_pickup_time, payment_method,
  description, needs_loading_help
) ON public.missions FROM authenticated;

-- C2
CREATE OR REPLACE FUNCTION public.protect_mission_participant_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_driver boolean;
  v_is_client boolean;
BEGIN
  -- Systeme (non-utilisateur) et admin : aucune restriction
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF public.get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM drivers d JOIN profiles p ON p.id = d.profile_id
    WHERE d.id = OLD.driver_id AND p.user_id = auth.uid()
  ) INTO v_is_driver;

  SELECT EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = OLD.client_id AND p.user_id = auth.uid()
  ) INTO v_is_client;

  -- Note et avis du client sur le chauffeur
  IF NEW.client_rating IS DISTINCT FROM OLD.client_rating
     OR NEW.client_review IS DISTINCT FROM OLD.client_review THEN
    IF NOT v_is_client THEN
      RAISE EXCEPTION 'champ_reserve: seul le client de la mission peut noter le chauffeur' USING ERRCODE = '42501';
    END IF;
    IF NEW.status IS DISTINCT FROM 'completed' THEN
      RAISE EXCEPTION 'champ_reserve: la note ne peut etre donnee qu''une fois la mission terminee' USING ERRCODE = '42501';
    END IF;
    IF OLD.client_rating IS NOT NULL OR OLD.client_review IS NOT NULL THEN
      RAISE EXCEPTION 'champ_reserve: la note et l''avis sont definitifs une fois donnes' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Note du chauffeur sur le client
  IF NEW.driver_rating IS DISTINCT FROM OLD.driver_rating THEN
    IF NOT v_is_driver THEN
      RAISE EXCEPTION 'champ_reserve: seul le chauffeur de la mission peut noter le client' USING ERRCODE = '42501';
    END IF;
    IF NEW.status IS DISTINCT FROM 'completed' THEN
      RAISE EXCEPTION 'champ_reserve: la note ne peut etre donnee qu''une fois la mission terminee' USING ERRCODE = '42501';
    END IF;
    IF OLD.driver_rating IS NOT NULL THEN
      RAISE EXCEPTION 'champ_reserve: la note est definitive une fois donnee' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Notes du client
  IF NEW.client_notes IS DISTINCT FROM OLD.client_notes AND NOT v_is_client THEN
    RAISE EXCEPTION 'champ_reserve: seules les notes du client sont modifiables par le client' USING ERRCODE = '42501';
  END IF;

  -- Notes du chauffeur et heures d'execution
  IF (NEW.driver_notes IS DISTINCT FROM OLD.driver_notes
      OR NEW.actual_pickup_time IS DISTINCT FROM OLD.actual_pickup_time
      OR NEW.actual_dropoff_time IS DISTINCT FROM OLD.actual_dropoff_time
      OR NEW.completed_at IS DISTINCT FROM OLD.completed_at)
     AND NOT v_is_driver THEN
    RAISE EXCEPTION 'champ_reserve: notes du chauffeur et heures d''execution reservees au chauffeur de la mission' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS protect_mission_participant_fields ON public.missions;
CREATE TRIGGER protect_mission_participant_fields
  BEFORE UPDATE ON public.missions
  FOR EACH ROW EXECUTE FUNCTION public.protect_mission_participant_fields();

-- C3
DROP POLICY IF EXISTS "Clients can create missions" ON public.missions;
DROP POLICY IF EXISTS "Users can view their own missions" ON public.missions;

-- C4
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.missions FROM anon;
REVOKE DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.missions FROM authenticated;
