-- Migration 20260504000074 - point A1 : solde disponible et garde-fous
-- (accord du porteur du 02/11/2026)
--
-- Constat : le solde minimum (100 DH, colonne wallet.minimum_balance) n'etait
-- controle qu'au passage « Disponible ». Un chauffeur deja disponible dont le
-- solde baissait continuait a recevoir des missions, a faire des offres et a
-- conclure des accords ; la mise « Hors service » n'etait faite que par
-- l'application, ecran Wallet ouvert.
--
-- Regles validees :
-- 1. Solde disponible = solde - commissions des missions conclues (ou en
--    cours) pas encore prelevees. C'est lui qui est compare au minimum.
-- 2. Minimum reglable par categorie (min_balance_<categorie>, 100 DH au
--    depart) ; jamais inferieur a la commission de la categorie (et la
--    commission jamais superieure au minimum). wallet.minimum_balance est
--    tenu a jour (ecrans existants).
-- 3. Sous le minimum : pas de passage « Disponible », pas de notification ni
--    de fenetre « Nouvelle mission », liste « Missions disponibles » vide, pas
--    d'offre ni d'acceptation de prix par le chauffeur.
-- 4. Conclusion d'un accord (D1) : refusee seulement si le solde disponible
--    ne couvre pas la commission de cette mission ; les accords d'un meme
--    chauffeur sont traites l'un apres l'autre.
-- 5. Mise « Hors service » par le serveur des que le solde disponible passe
--    sous le minimum (accord conclu, solde baisse, minimum releve), avec
--    notification ; les missions deja conclues ne changent pas.
-- 6. Garde-fous : « Demarrer » refuse tant que la commission n'est pas
--    prelevee ; messagerie vocale ouverte au prelevement de la commission (en
--    meme temps que l'adresse exacte) au lieu de 24 h avant sur la seule
--    base de l'heure ; commission prelevee des la conclusion quand le
--    chargement est a moins de 24 h (au lieu d'attendre la tache planifiee).
-- Aucune donnee existante modifiee, sauf wallet.minimum_balance (aligne sur
-- le reglage, 100 DH comme aujourd'hui).

-- 2. Reglages du minimum
INSERT INTO public.app_settings (key, value, description) VALUES
  ('min_balance_vul', 100, 'Solde disponible minimum (DH) pour qu''un chauffeur VUL recoive et prenne des missions'),
  ('min_balance_n2_medium', 100, 'Solde disponible minimum (DH) pour qu''un chauffeur N2 Moyen recoive et prenne des missions'),
  ('min_balance_n2_large', 100, 'Solde disponible minimum (DH) pour qu''un chauffeur N2 Grand recoive et prenne des missions')
ON CONFLICT (key) DO NOTHING;

-- Controle des reglages (complete la migration 073)
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
    RAISE EXCEPTION 'reglage_invalide: la valeur ne peut pas etre negative' USING ERRCODE = '22023';
  END IF;
  IF NEW.key LIKE 'commission\_amount\_%' THEN
    IF NEW.value < 1 THEN
      RAISE EXCEPTION 'reglage_invalide: la commission doit etre d''au moins 1 DH' USING ERRCODE = '22023';
    END IF;
    v_cat := substr(NEW.key, length('commission_amount_') + 1);
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'min_balance_' || v_cat;
    IF v_other IS NOT NULL AND NEW.value > v_other THEN
      RAISE EXCEPTION 'reglage_invalide: la commission (% DH) ne peut pas depasser le solde minimum de la categorie (% DH)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  IF NEW.key LIKE 'min\_balance\_%' THEN
    v_cat := substr(NEW.key, length('min_balance_') + 1);
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'commission_amount_' || v_cat;
    IF v_other IS NOT NULL AND NEW.value < v_other THEN
      RAISE EXCEPTION 'reglage_invalide: le solde minimum (% DH) ne peut pas etre inferieur a la commission de la categorie (% DH)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.validate_app_setting() FROM PUBLIC, anon, authenticated;

-- 1. Calculs
CREATE OR REPLACE FUNCTION public.driver_minimum_balance(p_driver_id uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT s.value FROM drivers d JOIN app_settings s ON s.key = 'min_balance_' || d.vehicle_category::text
     WHERE d.id = p_driver_id),
    (SELECT w.minimum_balance FROM wallet w WHERE w.driver_id = p_driver_id),
    100);
$function$;

CREATE OR REPLACE FUNCTION public.driver_engaged_commissions(p_driver_id uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(sum(m.commission_amount), 0)
  FROM missions m
  WHERE m.driver_id = p_driver_id
    AND m.status IN ('accepted', 'in_progress')
    AND m.commission_charged_at IS NULL
    AND m.commission_amount IS NOT NULL;
$function$;

-- NULL si le chauffeur n'a pas de portefeuille (tolere, comme avant)
CREATE OR REPLACE FUNCTION public.driver_available_balance(p_driver_id uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT w.balance - public.driver_engaged_commissions(p_driver_id)
  FROM wallet w WHERE w.driver_id = p_driver_id;
$function$;

CREATE OR REPLACE FUNCTION public.driver_balance_ok(p_driver_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(public.driver_available_balance(p_driver_id) >= public.driver_minimum_balance(p_driver_id), true);
$function$;

REVOKE EXECUTE ON FUNCTION public.driver_minimum_balance(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.driver_engaged_commissions(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.driver_available_balance(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.driver_balance_ok(uuid) FROM PUBLIC, anon, authenticated;

-- Pour l'accueil du chauffeur connecte
CREATE OR REPLACE FUNCTION public.get_my_wallet_status()
 RETURNS TABLE (balance numeric, engaged numeric, available numeric, minimum numeric,
                commission numeric, vehicle_category text, balance_ok boolean)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT w.balance,
         public.driver_engaged_commissions(d.id),
         w.balance - public.driver_engaged_commissions(d.id),
         public.driver_minimum_balance(d.id),
         public.calculate_commission(d.vehicle_category),
         d.vehicle_category::text,
         public.driver_balance_ok(d.id)
  FROM drivers d
  JOIN profiles p ON p.id = d.profile_id
  JOIN wallet w ON w.driver_id = d.id
  WHERE p.user_id = auth.uid();
$function$;

REVOKE EXECUTE ON FUNCTION public.get_my_wallet_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_wallet_status() TO authenticated;

-- 5. Mise « Hors service » par le serveur
CREATE OR REPLACE FUNCTION public.enforce_driver_balance(p_driver_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_profile uuid;
  v_available numeric;
  v_minimum numeric;
BEGIN
  IF p_driver_id IS NULL OR public.driver_balance_ok(p_driver_id) THEN
    RETURN;
  END IF;
  UPDATE drivers SET is_available = false
  WHERE id = p_driver_id AND is_available = true
  RETURNING profile_id INTO v_profile;
  IF v_profile IS NOT NULL THEN
    v_available := public.driver_available_balance(p_driver_id);
    v_minimum := public.driver_minimum_balance(p_driver_id);
    INSERT INTO notifications (profile_id, type, title, body, data, is_read)
    VALUES (v_profile, 'wallet_low_balance', '⚠️ Wallet insuffisant — Hors service',
            'Votre solde disponible (' || trim_scale(round(v_available, 2))::text || ' DH, commissions à venir déduites) '
              || 'est sous le minimum de ' || trim_scale(v_minimum)::text || ' DH. Vous êtes passé « Hors service » : '
              || 'rechargez votre wallet pour recevoir de nouvelles missions. Vos missions déjà conclues ne changent pas.',
            jsonb_build_object('screen', 'WalletDashboardScreen', 'action', 'topup_wallet'), false);
  END IF;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.enforce_driver_balance(uuid) FROM PUBLIC, anon, authenticated;

-- 2. wallet.minimum_balance aligne sur le reglage (ecrans existants)
UPDATE public.wallet w
SET minimum_balance = s.value
FROM public.drivers d
JOIN public.app_settings s ON s.key = 'min_balance_' || d.vehicle_category::text
WHERE d.id = w.driver_id AND w.minimum_balance IS DISTINCT FROM s.value;

CREATE OR REPLACE FUNCTION public.sync_wallet_minimum()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r record;
BEGIN
  IF TG_TABLE_NAME = 'app_settings' THEN
    FOR r IN
      UPDATE wallet w SET minimum_balance = NEW.value
      FROM drivers d
      WHERE d.id = w.driver_id
        AND 'min_balance_' || d.vehicle_category::text = NEW.key
      RETURNING w.driver_id
    LOOP
      PERFORM public.enforce_driver_balance(r.driver_id);
    END LOOP;
  ELSIF TG_TABLE_NAME = 'drivers' THEN
    UPDATE wallet SET minimum_balance = public.driver_minimum_balance(NEW.id)
    WHERE driver_id = NEW.id;
  ELSIF TG_TABLE_NAME = 'wallet' THEN
    NEW.minimum_balance := public.driver_minimum_balance(NEW.driver_id);
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.sync_wallet_minimum() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS sync_wallet_minimum ON public.app_settings;
CREATE TRIGGER sync_wallet_minimum
  AFTER UPDATE OF value ON public.app_settings
  FOR EACH ROW
  WHEN (NEW.key LIKE 'min\_balance\_%' AND OLD.value IS DISTINCT FROM NEW.value)
  EXECUTE FUNCTION public.sync_wallet_minimum();

DROP TRIGGER IF EXISTS sync_wallet_minimum ON public.drivers;
CREATE TRIGGER sync_wallet_minimum
  AFTER UPDATE OF vehicle_category ON public.drivers
  FOR EACH ROW
  WHEN (OLD.vehicle_category IS DISTINCT FROM NEW.vehicle_category)
  EXECUTE FUNCTION public.sync_wallet_minimum();

DROP TRIGGER IF EXISTS sync_wallet_minimum ON public.wallet;
CREATE TRIGGER sync_wallet_minimum
  BEFORE INSERT ON public.wallet
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_wallet_minimum();

-- 5. Solde en baisse (correction, etc.) : controle
CREATE OR REPLACE FUNCTION public.on_wallet_balance_decrease()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.enforce_driver_balance(NEW.driver_id);
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.on_wallet_balance_decrease() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS wallet_balance_decrease ON public.wallet;
CREATE TRIGGER wallet_balance_decrease
  AFTER UPDATE OF balance ON public.wallet
  FOR EACH ROW
  WHEN (NEW.balance < OLD.balance)
  EXECUTE FUNCTION public.on_wallet_balance_decrease();

-- 4/5/6. Accord conclu : prelevement immediat a moins de 24 h, puis controle
CREATE OR REPLACE FUNCTION public.on_mission_concluded()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.scheduled_pickup_time IS NOT NULL
     AND NEW.scheduled_pickup_time <= now() + interval '24 hours'
     AND NEW.commission_amount IS NOT NULL THEN
    BEGIN
      PERFORM public.charge_commission_anticipated(NEW.id);
    EXCEPTION WHEN OTHERS THEN
      -- la tache planifiee (toutes les 5 minutes) reessaiera
      RAISE WARNING 'on_mission_concluded: prelevement differe pour la mission % (%)', NEW.mission_number, SQLERRM;
    END;
  END IF;
  PERFORM public.enforce_driver_balance(NEW.driver_id);
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.on_mission_concluded() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS missions_on_concluded ON public.missions;
CREATE TRIGGER missions_on_concluded
  AFTER UPDATE OF status ON public.missions
  FOR EACH ROW
  WHEN (OLD.status = 'pending' AND NEW.status = 'accepted' AND NEW.driver_id IS NOT NULL)
  EXECUTE FUNCTION public.on_mission_concluded();

-- 3/4. Offres : controle du solde disponible
CREATE OR REPLACE FUNCTION public.check_driver_balance()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_driver boolean;
  v_final boolean := false;
  v_available numeric;
  v_minimum numeric;
  v_commission numeric;
BEGIN
  -- Systeme (sans utilisateur connecte) : pas de controle
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    v_final := NEW.client_accepted IS TRUE AND NEW.driver_accepted IS TRUE
               AND NOT (OLD.client_accepted IS TRUE AND OLD.driver_accepted IS TRUE);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM drivers d JOIN profiles p ON p.id = d.profile_id
    WHERE d.id = NEW.driver_id AND p.user_id = auth.uid()
  ) INTO v_is_driver;

  -- Les accords d'un meme chauffeur sont traites l'un apres l'autre
  PERFORM 1 FROM wallet w WHERE w.driver_id = NEW.driver_id FOR UPDATE;

  v_available := public.driver_available_balance(NEW.driver_id);
  IF v_available IS NULL THEN
    RETURN NEW;
  END IF;

  IF v_final THEN
    -- D1 : la commission de cette mission doit pouvoir etre payee
    SELECT m.commission_amount INTO v_commission FROM missions m WHERE m.id = NEW.mission_id;
    IF v_commission IS NOT NULL AND v_available < v_commission THEN
      IF v_is_driver THEN
        RAISE EXCEPTION 'solde_insuffisant: votre solde disponible (% DH, commissions à venir déduites) ne couvre pas la commission de cette mission (% DH). Rechargez votre wallet.',
          trim_scale(round(v_available, 2)), trim_scale(v_commission) USING ERRCODE = 'P0001';
      ELSE
        RAISE EXCEPTION 'Ce chauffeur ne peut plus conclure cette mission. Choisissez une autre offre.'
          USING ERRCODE = 'P0001';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  -- Offre ou acceptation de prix par le chauffeur : minimum exige
  IF v_is_driver AND (TG_OP = 'INSERT'
       OR NEW.offered_price IS DISTINCT FROM OLD.offered_price
       OR (NEW.driver_accepted IS TRUE AND OLD.driver_accepted IS NOT TRUE)) THEN
    v_minimum := public.driver_minimum_balance(NEW.driver_id);
    IF v_available < v_minimum THEN
      RAISE EXCEPTION 'solde_insuffisant: votre solde disponible (% DH, commissions à venir déduites) est sous le minimum de % DH. Rechargez votre wallet pour faire des offres.',
        trim_scale(round(v_available, 2)), trim_scale(v_minimum) USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.check_driver_balance() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS check_driver_balance ON public.mission_offers;
CREATE TRIGGER check_driver_balance
  BEFORE INSERT OR UPDATE ON public.mission_offers
  FOR EACH ROW
  EXECUTE FUNCTION public.check_driver_balance();

-- 3. Passage « Disponible » : solde disponible
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

  -- Solde disponible suffisant (migration 074 ; absence de wallet toleree)
  v_balance := public.driver_available_balance(NEW.id);
  v_minimum := public.driver_minimum_balance(NEW.id);

  IF v_balance IS NOT NULL AND v_balance < v_minimum THEN
    RAISE EXCEPTION 'indisponibilite_solde: solde disponible insuffisant (% DH, commissions a venir deduites ; minimum % DH), rechargez votre wallet avant de redevenir disponible',
      trim_scale(round(v_balance, 2)), trim_scale(v_minimum) USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.control_driver_availability() FROM PUBLIC, anon, authenticated;

-- 3. Notification « Nouvelle mission » : solde disponible suffisant
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
      AND NOT public.driver_schedule_conflict(d.id, NEW.id)
      AND public.driver_balance_ok(d.id);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'on_mission_created: notifications non envoyees pour la mission % (%)',
      NEW.mission_number, SQLERRM;
  END;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.on_mission_created() FROM PUBLIC, anon, authenticated;

-- 3. Liste « Missions disponibles » : solde disponible suffisant
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
    AND public.driver_balance_ok(d.id)
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

REVOKE EXECUTE ON FUNCTION public.driver_open_missions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.driver_open_missions() TO authenticated;

-- 3. Fenetre « Nouvelle mission » : solde disponible suffisant
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
  IF NOT public.driver_balance_ok(v_driver) THEN
    RETURN false;
  END IF;
  RETURN public.mission_in_driver_range(v_driver, p_mission_id);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.driver_mission_in_range(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.driver_mission_in_range(uuid) TO authenticated;

-- 6. Demarrage refuse tant que la commission n'est pas prelevee
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
    -- Migration 074 : la commission doit etre prelevee avant le demarrage
    IF v_is_mission_driver AND NEW.commission_charged_at IS NULL THEN
      RAISE EXCEPTION 'demarrage_impossible: la commission de cette mission n''est pas encore prelevee. Si votre solde est insuffisant, rechargez votre wallet ; sinon reessayez dans quelques minutes.' USING ERRCODE = '42501';
    END IF;
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

-- 6. Messagerie vocale annoncee au prelevement de la commission
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
  v_paid boolean;
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
    v_paid := r.commission_charged_at IS NOT NULL;

    -- a. Commission
    IF r.commission_charged_at IS NULL AND r.commission_amount IS NOT NULL THEN
      BEGIN
        v_result := public.charge_commission_anticipated(r.id);
        IF COALESCE((v_result->>'success')::boolean, false) THEN
          v_charged := v_charged + 1;
          v_paid := true;
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
    -- Migration 074 : seulement une fois la commission prelevee
    IF r.voice_channel_notified_at IS NULL AND v_paid THEN
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

REVOKE EXECUTE ON FUNCTION public.process_missions_24h_window() FROM PUBLIC, anon, authenticated;

-- 6. Messages vocaux (fichiers) : seulement apres le prelevement de la commission
DROP POLICY IF EXISTS "voice_messages_read_own" ON storage.objects;
CREATE POLICY "voice_messages_read_own"
ON storage.objects FOR SELECT
TO authenticated
USING (
  (bucket_id = 'voice-messages'::text) AND (
    ((storage.foldername(name))[2])::uuid IN (
      SELECT m.id FROM missions m
      JOIN profiles p_client ON p_client.id = m.client_id
      WHERE p_client.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL
      UNION
      SELECT m.id FROM missions m
      JOIN drivers d ON d.id = m.driver_id
      JOIN profiles p_driver ON p_driver.id = d.profile_id
      WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL
    )
  )
);

DROP POLICY IF EXISTS "voice_messages_upload_own" ON storage.objects;
CREATE POLICY "voice_messages_upload_own"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  (bucket_id = 'voice-messages'::text) AND (
    ((storage.foldername(name))[2])::uuid IN (
      SELECT m.id FROM missions m
      JOIN profiles p_client ON p_client.id = m.client_id
      WHERE p_client.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL
      UNION
      SELECT m.id FROM missions m
      JOIN drivers d ON d.id = m.driver_id
      JOIN profiles p_driver ON p_driver.id = d.profile_id
      WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL
    )
  )
);
