-- Rollback de la migration 20260504000074 (solde disponible et garde-fous).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
DROP TRIGGER IF EXISTS check_driver_balance ON public.mission_offers;
DROP FUNCTION IF EXISTS public.check_driver_balance();
DROP TRIGGER IF EXISTS missions_on_concluded ON public.missions;
DROP FUNCTION IF EXISTS public.on_mission_concluded();
DROP TRIGGER IF EXISTS wallet_balance_decrease ON public.wallet;
DROP FUNCTION IF EXISTS public.on_wallet_balance_decrease();
DROP TRIGGER IF EXISTS sync_wallet_minimum ON public.app_settings;
DROP TRIGGER IF EXISTS sync_wallet_minimum ON public.drivers;
DROP TRIGGER IF EXISTS sync_wallet_minimum ON public.wallet;
DROP FUNCTION IF EXISTS public.sync_wallet_minimum();
DROP FUNCTION IF EXISTS public.get_my_wallet_status();

-- Versions precedentes
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

CREATE OR REPLACE FUNCTION public.on_mission_created()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_body text;
BEGIN
  v_body := public.approx_place_label(NEW.pickup_district, NEW.pickup_city)
    || ' → ' || public.approx_place_label(NEW.dropoff_district, NEW.dropoff_city)
    || CASE WHEN NEW.scheduled_pickup_time IS NULL THEN ''
            ELSE ', le ' || to_char(NEW.scheduled_pickup_time AT TIME ZONE 'UTC', 'DD/MM "à" HH24"h"MI') END
    || CASE WHEN NEW.cargo_weight_kg IS NULL AND NEW.cargo_volume_m3 IS NULL THEN ''
            ELSE ' — ' || concat_ws(', ',
                   CASE WHEN NEW.cargo_weight_kg IS NOT NULL
                        THEN trim_scale(NEW.cargo_weight_kg)::text || ' kg' END,
                   CASE WHEN NEW.cargo_volume_m3 IS NOT NULL
                        THEN replace(trim_scale(NEW.cargo_volume_m3)::text, '.', ',') || ' m³' END) END
    || '. Touchez pour voir la mission et faire une offre.';

  BEGIN
    INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
    SELECT d.profile_id,
           'new_mission',
           '🚚 Nouvelle mission',
           v_body,
           jsonb_build_object('mission_id', NEW.id, 'mission_number', NEW.mission_number,
                              'screen', 'NewMissionModal'),
           false
    FROM drivers d
    JOIN profiles p ON p.id = d.profile_id
    WHERE d.vehicle_category = NEW.vehicle_category
      AND d.is_verified = true
      AND d.is_available = true
      AND p.is_active = true
      AND d.profile_id IS DISTINCT FROM NEW.client_id
      AND public.mission_in_driver_range(d.id, NEW.id)
      AND NOT public.driver_schedule_conflict(d.id, NEW.id);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'on_mission_created: notifications non envoyees pour la mission % (%)',
      NEW.mission_number, SQLERRM;
  END;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.driver_open_missions()
 RETURNS TABLE(id uuid, mission_number character varying, mission_type mission_type, vehicle_category vehicle_category, pickup_address text, pickup_city character varying, dropoff_address text, dropoff_city character varying, scheduled_pickup_time timestamp with time zone, estimated_distance_km numeric, needs_loading_help boolean, commission_amount numeric, cargo_weight_kg numeric, cargo_volume_m3 numeric, description text, status mission_status, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT m.id, m.mission_number, m.mission_type, m.vehicle_category,
         m.pickup_address, m.pickup_city, m.dropoff_address, m.dropoff_city,
         m.scheduled_pickup_time, m.estimated_distance_km, m.needs_loading_help,
         m.commission_amount, m.cargo_weight_kg, m.cargo_volume_m3,
         m.description, m.status, m.created_at
  FROM drivers d
  JOIN profiles p ON p.id = d.profile_id
  JOIN missions m ON m.vehicle_category = d.vehicle_category
  WHERE p.user_id = auth.uid()
    AND d.is_verified = true
    AND d.is_available = true
    AND p.is_active = true
    AND m.status = 'pending'
    AND m.scheduled_pickup_time > now()
    AND m.client_id IS DISTINCT FROM d.profile_id
    AND public.mission_in_driver_range(d.id, m.id)
    AND NOT public.driver_schedule_conflict(d.id, m.id)
    AND NOT EXISTS (
      SELECT 1 FROM mission_offers o
      WHERE o.mission_id = m.id AND o.driver_id = d.id AND o.status = 'pending'
    )
  ORDER BY m.scheduled_pickup_time ASC;
$function$;

CREATE OR REPLACE FUNCTION public.driver_mission_in_range(p_mission_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_driver uuid;
BEGIN
  SELECT d.id INTO v_driver
  FROM drivers d JOIN profiles p ON p.id = d.profile_id
  WHERE p.user_id = auth.uid();
  IF v_driver IS NULL THEN
    RETURN false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM missions m WHERE m.id = p_mission_id AND m.status = 'pending') THEN
    RETURN false;
  END IF;
  RETURN public.mission_in_driver_range(v_driver, p_mission_id);
END;
$function$;

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

CREATE OR REPLACE FUNCTION public.process_missions_24h_window()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r RECORD;
  v_result jsonb;
  v_driver_profile uuid;
  v_balance numeric;
  v_charged integer := 0;
  v_insufficient integer := 0;
  v_voice integer := 0;
  v_marked uuid;
BEGIN
  FOR r IN
    SELECT m.id, m.mission_number, m.client_id, m.driver_id, m.commission_amount,
           m.commission_charged_at, m.voice_channel_notified_at, m.commission_alert_sent_at
    FROM missions m
    WHERE m.status IN ('accepted', 'in_progress')
      AND m.driver_id IS NOT NULL
      AND m.scheduled_pickup_time IS NOT NULL
      AND m.scheduled_pickup_time <= NOW() + INTERVAL '24 hours'
      AND (m.commission_charged_at IS NULL OR m.voice_channel_notified_at IS NULL)
    ORDER BY m.scheduled_pickup_time
  LOOP
    SELECT d.profile_id INTO v_driver_profile FROM drivers d WHERE d.id = r.driver_id;

    -- a. Commission
    IF r.commission_charged_at IS NULL AND r.commission_amount IS NOT NULL THEN
      BEGIN
        v_result := public.charge_commission_anticipated(r.id);
        IF COALESCE((v_result->>'success')::boolean, false) THEN
          v_charged := v_charged + 1;
        ELSIF COALESCE(v_result->>'error', '') <> 'already_charged' THEN
          RAISE WARNING 'process_missions_24h_window: mission % non prelevee (%)',
            r.mission_number, v_result->>'error';
        END IF;
      EXCEPTION WHEN check_violation THEN
        -- Solde insuffisant (wallet.balance >= 0) : rien n'est preleve,
        -- nouvel essai au passage suivant, alerte envoyee une seule fois.
        v_insufficient := v_insufficient + 1;
        IF r.commission_alert_sent_at IS NULL THEN
          SELECT w.balance INTO v_balance FROM wallet w WHERE w.driver_id = r.driver_id;
          IF v_driver_profile IS NOT NULL THEN
            INSERT INTO notifications (profile_id, type, title, body, data, is_read)
            VALUES (
              v_driver_profile, 'commission_insufficient_balance',
              '⚠️ Solde insuffisant',
              'Votre solde (' || to_char(COALESCE(v_balance, 0), 'FM999999990.00')
                || ' DH) ne couvre pas la commission de la mission ' || r.mission_number
                || ' (' || to_char(r.commission_amount, 'FM999999990.00')
                || ' DH). Rechargez votre portefeuille.',
              jsonb_build_object('mission_id', r.id, 'screen', 'WalletDashboard'),
              false);
          END IF;
          INSERT INTO notifications (profile_id, type, title, body, data, is_read)
          SELECT p.id, 'commission_insufficient_balance',
                 '⚠️ Commission non prélevée',
                 'La commission de la mission ' || r.mission_number
                   || ' n''a pas pu être prélevée : solde du chauffeur insuffisant.',
                 jsonb_build_object('mission_id', r.id),
                 false
          FROM profiles p WHERE p.role = 'admin';
          UPDATE missions SET commission_alert_sent_at = NOW() WHERE id = r.id;
        END IF;
      END;
    END IF;

    -- b. Annonce de la messagerie vocale (une seule fois)
    IF r.voice_channel_notified_at IS NULL THEN
      v_marked := NULL;
      UPDATE missions SET voice_channel_notified_at = NOW()
      WHERE id = r.id AND voice_channel_notified_at IS NULL
      RETURNING id INTO v_marked;
      IF v_marked IS NOT NULL THEN
        INSERT INTO notifications (profile_id, type, title, body, data, is_read)
        SELECT t.pid, 'voice_channel_opened',
               '🎤 Messagerie vocale disponible',
               'Votre mission ' || r.mission_number
                 || ' approche. Vous pouvez désormais échanger des messages vocaux.',
               jsonb_build_object('mission_id', r.id, 'screen', 'VoiceChat'),
               false
        FROM (VALUES (r.client_id), (v_driver_profile)) AS t(pid)
        WHERE t.pid IS NOT NULL;
        v_voice := v_voice + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'charged', v_charged,
    'insufficient_balance', v_insufficient,
    'voice_announced', v_voice
  );
END;
$function$;

-- Controle des reglages : version de la migration 073
CREATE OR REPLACE FUNCTION public.validate_app_setting()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.value < 0 THEN
    RAISE EXCEPTION 'reglage_invalide: la valeur ne peut pas etre negative' USING ERRCODE = '22023';
  END IF;
  IF NEW.key LIKE 'commission\_amount\_%' AND NEW.value < 1 THEN
    RAISE EXCEPTION 'reglage_invalide: la commission doit etre d''au moins 1 DH' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$function$;

DROP POLICY IF EXISTS "voice_messages_read_own" ON storage.objects;
CREATE POLICY "voice_messages_read_own" ON storage.objects FOR SELECT TO authenticated
USING ((bucket_id = 'voice-messages'::text) AND (((storage.foldername(name))[2])::uuid IN (
  SELECT m.id FROM missions m JOIN profiles p_client ON p_client.id = m.client_id WHERE p_client.user_id = auth.uid()
  UNION
  SELECT m.id FROM missions m JOIN drivers d ON d.id = m.driver_id JOIN profiles p_driver ON p_driver.id = d.profile_id
  WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid())));
DROP POLICY IF EXISTS "voice_messages_upload_own" ON storage.objects;
CREATE POLICY "voice_messages_upload_own" ON storage.objects FOR INSERT TO authenticated
WITH CHECK ((bucket_id = 'voice-messages'::text) AND (((storage.foldername(name))[2])::uuid IN (
  SELECT m.id FROM missions m JOIN profiles p_client ON p_client.id = m.client_id WHERE p_client.user_id = auth.uid()
  UNION
  SELECT m.id FROM missions m JOIN drivers d ON d.id = m.driver_id JOIN profiles p_driver ON p_driver.id = d.profile_id
  WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid())));

DROP FUNCTION IF EXISTS public.enforce_driver_balance(uuid);
DROP FUNCTION IF EXISTS public.driver_balance_ok(uuid);
DROP FUNCTION IF EXISTS public.driver_available_balance(uuid);
DROP FUNCTION IF EXISTS public.driver_engaged_commissions(uuid);
DROP FUNCTION IF EXISTS public.driver_minimum_balance(uuid);
DELETE FROM public.app_settings WHERE key LIKE 'min\_balance\_%';
