-- Migration 20260504000076 - point A1 : annulation par le client apres accord
-- (decisions du porteur du 03/11/2026)
-- 1. Raison obligatoire quand le client annule une mission conclue (report de
--    la mission, malentendu avec le chauffeur, autre raison), avec quelques
--    mots facultatifs (200 caracteres au plus). Raison visible de l'admin
--    seulement (table separee, jamais lisible par le chauffeur).
-- 2. Historique du client montre aux chauffeurs : missions realisees,
--    annulations apres accord et annulations tardives, sur une periode
--    reglable (6 mois par defaut) ; « Nouveau client » sans historique.
-- 3. Point C : plus d'acces du chauffeur a l'adresse exacte, ni d'acces aux
--    messages vocaux, quand la mission est annulee ou non realisee.

-- 1a. Reglage de la periode (une seule valeur, toutes categories)
INSERT INTO public.app_settings (key, value, description) VALUES
  ('client_cancel_window_months', 6, 'Periode (mois) de comptage des missions et annulations du client affichees aux chauffeurs')
ON CONFLICT (key) DO NOTHING;

-- 1b. Raisons d'annulation : lecture par l'admin seulement, ecriture par la
--     fonction cancel_mission_by_client uniquement
CREATE TABLE IF NOT EXISTS public.mission_cancel_reasons (
  mission_id uuid PRIMARY KEY REFERENCES public.missions(id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (reason IN ('report', 'malentendu_chauffeur', 'autre')),
  reason_text varchar(200),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.mission_cancel_reasons ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.mission_cancel_reasons FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.mission_cancel_reasons TO authenticated;
DROP POLICY IF EXISTS mission_cancel_reasons_select_admin ON public.mission_cancel_reasons;
CREATE POLICY mission_cancel_reasons_select_admin ON public.mission_cancel_reasons
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin'));

-- 1c. Annulation d'une mission conclue par le client, avec sa raison
CREATE OR REPLACE FUNCTION public.cancel_mission_by_client(
  p_mission_id uuid, p_reason text, p_reason_text text DEFAULT NULL)
 RETURNS public.missions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_mission public.missions;
BEGIN
  SELECT m.* INTO v_mission
  FROM missions m JOIN profiles p ON p.id = m.client_id
  WHERE m.id = p_mission_id AND p.user_id = auth.uid()
  FOR UPDATE OF m;
  IF v_mission.id IS NULL THEN
    RAISE EXCEPTION 'transition_refusee: annulation réservée au client de la mission' USING ERRCODE = '42501';
  END IF;
  IF v_mission.status <> 'accepted' THEN
    RAISE EXCEPTION 'annulation_impossible: cette mission ne peut plus être annulée.' USING ERRCODE = '42501';
  END IF;
  IF p_reason IS NULL OR p_reason NOT IN ('report', 'malentendu_chauffeur', 'autre') THEN
    RAISE EXCEPTION 'raison_requise: choisissez la raison de l''annulation.' USING ERRCODE = '22023';
  END IF;

  INSERT INTO mission_cancel_reasons (mission_id, reason, reason_text)
  VALUES (p_mission_id, p_reason, left(nullif(btrim(coalesce(p_reason_text, '')), ''), 200))
  ON CONFLICT (mission_id) DO UPDATE
    SET reason = EXCLUDED.reason, reason_text = EXCLUDED.reason_text, created_at = now();

  UPDATE missions SET status = 'cancelled_client'
  WHERE id = p_mission_id
  RETURNING * INTO v_mission;
  RETURN v_mission;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.cancel_mission_by_client(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_mission_by_client(uuid, text, text) TO authenticated;

-- 1d. Une mission conclue ne peut plus etre annulee par le client sans raison
--     (ancienne version de l'application : modification directe refusee)
CREATE OR REPLACE FUNCTION public.require_client_cancel_reason()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user IN ('authenticated', 'anon')
     AND OLD.status = 'accepted' AND NEW.status = 'cancelled_client'
     AND public.get_my_role() IS DISTINCT FROM 'admin'
     AND NOT EXISTS (SELECT 1 FROM mission_cancel_reasons r WHERE r.mission_id = NEW.id) THEN
    RAISE EXCEPTION 'raison_requise: mettez à jour l''application pour annuler cette mission (raison de l''annulation demandée).' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.require_client_cancel_reason() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS require_client_cancel_reason ON public.missions;
CREATE TRIGGER require_client_cancel_reason
  BEFORE UPDATE OF status ON public.missions
  FOR EACH ROW EXECUTE FUNCTION public.require_client_cancel_reason();

-- 1e. Reglage de la periode : au moins 1 mois
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
  IF NEW.key = 'client_cancel_window_months' AND NEW.value < 1 THEN
    RAISE EXCEPTION 'reglage_invalide: la période doit être d''au moins 1 mois' USING ERRCODE = '22023';
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

-- 2a. Historique d'un client (usage interne)
CREATE OR REPLACE FUNCTION public.client_cancel_record(p_client uuid)
 RETURNS TABLE(completed_missions integer, cancelled_missions integer,
               late_cancelled_missions integer, window_months integer, is_new boolean)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH w AS (
    SELECT greatest(1, coalesce(
      (SELECT s.value FROM app_settings s WHERE s.key = 'client_cancel_window_months'), 6))::integer AS months
  ), c AS (
    SELECT
      count(*) FILTER (WHERE m.status = 'completed'
                         AND coalesce(m.completed_at, m.updated_at) >= now() - make_interval(months => w.months)) AS done,
      count(*) FILTER (WHERE m.status = 'completed') AS done_ever,
      count(*) FILTER (WHERE m.status = 'cancelled_client' AND m.driver_id IS NOT NULL
                         AND coalesce(m.cancelled_at, m.updated_at) >= now() - make_interval(months => w.months)) AS cancelled,
      count(*) FILTER (WHERE m.status = 'cancelled_client' AND m.driver_id IS NOT NULL
                         AND coalesce(m.cancelled_at, m.updated_at) >= now() - make_interval(months => w.months)
                         AND (m.refund_forfeited
                              OR (m.scheduled_pickup_time IS NOT NULL
                                  AND m.scheduled_pickup_time - coalesce(m.cancelled_at, m.updated_at)
                                      < make_interval(secs => public.client_cancel_no_refund_hours(m.vehicle_category::text) * 3600)))) AS late
    FROM w LEFT JOIN missions m ON m.client_id = p_client
    GROUP BY w.months
  )
  SELECT c.done::integer, c.cancelled::integer, c.late::integer, w.months,
         (c.done_ever = 0 AND c.cancelled = 0)
  FROM c, w;
$function$;
REVOKE EXECUTE ON FUNCTION public.client_cancel_record(uuid) FROM PUBLIC, anon, authenticated;

-- 2b. Historique du client d'une mission, pour un chauffeur qui peut la voir
--     (ou l'admin). Des nombres seulement : jamais les raisons.
CREATE OR REPLACE FUNCTION public.get_mission_client_record(p_mission_id uuid)
 RETURNS TABLE(completed_missions integer, cancelled_missions integer,
               late_cancelled_missions integer, window_months integer, is_new boolean)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_client uuid;
BEGIN
  SELECT m.client_id INTO v_client
  FROM missions m
  WHERE m.id = p_mission_id
    AND (
      EXISTS (SELECT 1 FROM profiles pa WHERE pa.user_id = auth.uid() AND pa.role = 'admin')
      OR EXISTS (
        SELECT 1 FROM drivers d JOIN profiles p ON p.id = d.profile_id
        WHERE p.user_id = auth.uid()
          AND (m.driver_id = d.id
               OR EXISTS (SELECT 1 FROM mission_offers o WHERE o.mission_id = m.id AND o.driver_id = d.id)
               OR (m.status = 'pending' AND d.is_verified AND d.vehicle_category = m.vehicle_category))
      )
    );
  IF v_client IS NULL THEN
    RETURN;
  END IF;
  RETURN QUERY SELECT * FROM public.client_cancel_record(v_client);
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.get_mission_client_record(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_mission_client_record(uuid) TO authenticated;

-- 2c. Liste « Missions disponibles » : historique du client sur chaque fiche
DROP FUNCTION IF EXISTS public.driver_open_missions();
CREATE FUNCTION public.driver_open_missions()
 RETURNS TABLE(id uuid, mission_number character varying, mission_type mission_type, vehicle_category vehicle_category, pickup_address text, pickup_city character varying, dropoff_address text, dropoff_city character varying, scheduled_pickup_time timestamp with time zone, estimated_distance_km numeric, needs_loading_help boolean, commission_amount numeric, cargo_weight_kg numeric, cargo_volume_m3 numeric, description text, status mission_status, created_at timestamp with time zone,
               client_completed_missions integer, client_cancelled_missions integer, client_late_cancelled_missions integer, client_window_months integer, client_is_new boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT m.id, m.mission_number, m.mission_type, m.vehicle_category,
         m.pickup_address, m.pickup_city, m.dropoff_address, m.dropoff_city,
         m.scheduled_pickup_time, m.estimated_distance_km, m.needs_loading_help,
         m.commission_amount, m.cargo_weight_kg, m.cargo_volume_m3,
         m.description, m.status, m.created_at,
         r.completed_missions, r.cancelled_missions, r.late_cancelled_missions, r.window_months, r.is_new
  FROM drivers d
  JOIN profiles p ON p.id = d.profile_id
  JOIN missions m ON m.vehicle_category = d.vehicle_category
  LEFT JOIN LATERAL public.client_cancel_record(m.client_id) r ON true
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
GRANT EXECUTE ON FUNCTION public.driver_open_missions() TO authenticated, service_role;

-- 3a. Point C : adresse exacte fermee au chauffeur si la mission est annulee
--     ou non realisee (le client et l'admin gardent l'acces)
CREATE OR REPLACE FUNCTION public.can_read_mission_exact_location(p_mission_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM missions m
    LEFT JOIN profiles pc ON pc.id = m.client_id
    LEFT JOIN drivers d ON d.id = m.driver_id
    LEFT JOIN profiles pd ON pd.id = d.profile_id
    WHERE m.id = p_mission_id
      AND (pc.user_id = auth.uid()
           OR (pd.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL
               AND m.status NOT IN ('cancelled_client', 'cancelled_driver', 'expired')))
  )
  OR EXISTS (SELECT 1 FROM profiles pa WHERE pa.user_id = auth.uid() AND pa.role = 'admin');
$function$;

-- 3b. Point C : messages vocaux fermes si la mission est annulee ou non realisee
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
        AND m.status NOT IN ('cancelled_client', 'cancelled_driver', 'expired')
      UNION
      SELECT m.id FROM missions m
      JOIN drivers d ON d.id = m.driver_id
      JOIN profiles p_driver ON p_driver.id = d.profile_id
      WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL
        AND m.status NOT IN ('cancelled_client', 'cancelled_driver', 'expired')
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
        AND m.status NOT IN ('cancelled_client', 'cancelled_driver', 'expired')
      UNION
      SELECT m.id FROM missions m
      JOIN drivers d ON d.id = m.driver_id
      JOIN profiles p_driver ON p_driver.id = d.profile_id
      WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid() AND m.commission_charged_at IS NOT NULL
        AND m.status NOT IN ('cancelled_client', 'cancelled_driver', 'expired')
    )
  )
);
