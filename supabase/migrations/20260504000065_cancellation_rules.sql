-- Migration 20260504000065 - point A1, F4 : regles d'annulation (accord du
-- porteur du 26/10/2026)
--
-- Regles validees :
-- - le client peut annuler a tout moment ; si la commission a deja ete
--   prelevee, le chauffeur garde son droit au remboursement (demande puis
--   validation par l'admin, procedure existante) ;
-- - si le chauffeur annule une mission acceptee a moins de X heures de la
--   prise en charge alors que la commission est deja prelevee, celle-ci n'est
--   pas remboursee ; X depend de la categorie : VUL 2 h, N2 Moyen 12 h,
--   N2 Grand 24 h, reglable par l'admin (table app_settings, migration 064) ;
-- - l'application previent le chauffeur avant l'annulation (avertissement et
--   confirmation) ; apres une annulation tardive, il recoit une notification
--   qui confirme l'annulation et le non-remboursement ;
-- - quand le client annule une mission encore en attente, les offres en
--   attente sont fermees et leurs chauffeurs prevenus.
--
-- 1. Reglages cancel_refund_hours_<categorie>.
-- 2. Colonnes missions.cancelled_at et missions.refund_forfeited, remplies
--    uniquement par le serveur, au moment de l'annulation (heure du serveur,
--    pas celle du telephone), et non modifiables par les utilisateurs.
-- 3. Fonction get_driver_cancel_terms(mission) : ce que l'application affiche
--    dans l'avertissement (delai, commission, perte du remboursement ou non).
-- 4. Notification au chauffeur apres une annulation tardive.
-- 5. Refus serveur d'une demande de remboursement pour une mission dont le
--    remboursement est perdu (l'admin garde la main).
-- 6. Annulation par le client d'une mission en attente : offres fermees,
--    chauffeurs prevenus.
-- Aucune donnee existante modifiee (les nouvelles colonnes valent NULL/false).

-- 1. Reglages
INSERT INTO public.app_settings (key, value, description) VALUES
  ('cancel_refund_hours_vul', 2, 'Delai (heures) avant la mission sous lequel un chauffeur VUL qui annule perd le remboursement de la commission'),
  ('cancel_refund_hours_n2_medium', 12, 'Delai (heures) avant la mission sous lequel un chauffeur N2 Moyen qui annule perd le remboursement de la commission'),
  ('cancel_refund_hours_n2_large', 24, 'Delai (heures) avant la mission sous lequel un chauffeur N2 Grand qui annule perd le remboursement de la commission')
ON CONFLICT (key) DO NOTHING;

-- 2. Colonnes d'annulation
ALTER TABLE public.missions ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;
ALTER TABLE public.missions ADD COLUMN IF NOT EXISTS refund_forfeited boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.cancel_refund_hours(p_category text)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT s.value FROM app_settings s WHERE s.key = 'cancel_refund_hours_' || p_category),
    24);
$function$;

REVOKE EXECUTE ON FUNCTION public.cancel_refund_hours(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.set_mission_cancellation_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.cancelled_at := NULL;
    NEW.refund_forfeited := false;
    RETURN NEW;
  END IF;

  -- Valeurs gelees : seul le passage a l'annulation les remplit.
  NEW.cancelled_at := OLD.cancelled_at;
  NEW.refund_forfeited := OLD.refund_forfeited;

  IF NEW.status IN ('cancelled_client', 'cancelled_driver')
     AND OLD.status NOT IN ('cancelled_client', 'cancelled_driver') THEN
    NEW.cancelled_at := now();
    IF NEW.status = 'cancelled_driver'
       AND OLD.status = 'accepted'
       AND OLD.commission_charged_at IS NOT NULL
       AND OLD.scheduled_pickup_time IS NOT NULL
       AND OLD.scheduled_pickup_time - now()
           < make_interval(secs => public.cancel_refund_hours(OLD.vehicle_category::text) * 3600) THEN
      NEW.refund_forfeited := true;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.set_mission_cancellation_fields() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS set_mission_cancellation_fields ON public.missions;
CREATE TRIGGER set_mission_cancellation_fields
  BEFORE INSERT OR UPDATE ON public.missions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_mission_cancellation_fields();

-- 3. Conditions d'annulation pour le chauffeur de la mission
CREATE OR REPLACE FUNCTION public.get_driver_cancel_terms(p_mission_id uuid)
RETURNS TABLE (
  delay_hours numeric,
  hours_left numeric,
  commission_charged boolean,
  commission_amount numeric,
  refund_lost_if_cancelled boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  m record;
  v_delay numeric;
  v_left numeric;
BEGIN
  SELECT mi.* INTO m
  FROM missions mi
  JOIN drivers d ON d.id = mi.driver_id
  JOIN profiles p ON p.id = d.profile_id
  WHERE mi.id = p_mission_id AND p.user_id = auth.uid();
  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_delay := public.cancel_refund_hours(m.vehicle_category::text);
  v_left := CASE WHEN m.scheduled_pickup_time IS NULL THEN NULL
                 ELSE round(extract(epoch FROM (m.scheduled_pickup_time - now())) / 3600, 1) END;

  RETURN QUERY SELECT
    trim_scale(v_delay),
    v_left,
    m.commission_charged_at IS NOT NULL,
    m.commission_amount::numeric,
    (m.status = 'accepted'
     AND m.commission_charged_at IS NOT NULL
     AND m.scheduled_pickup_time IS NOT NULL
     AND m.scheduled_pickup_time - now() < make_interval(secs => v_delay * 3600));
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_driver_cancel_terms(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_driver_cancel_terms(uuid) TO authenticated;

-- 4 et 6. Notifications apres une annulation
CREATE OR REPLACE FUNCTION public.on_mission_cancelled()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_number text := coalesce(NEW.mission_number, '');
  v_profile uuid;
BEGIN
  -- 4. Annulation tardive par le chauffeur : confirmation et non-remboursement
  IF NEW.status = 'cancelled_driver' AND NEW.refund_forfeited THEN
    SELECT d.profile_id INTO v_profile FROM drivers d WHERE d.id = NEW.driver_id;
    IF v_profile IS NOT NULL THEN
      INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
      VALUES (
        v_profile,
        'mission_cancelled',
        '❌ Mission annulée',
        'Vous avez annulé la mission ' || v_number || ' à moins de '
          || trim_scale(public.cancel_refund_hours(NEW.vehicle_category::text))
          || ' h de la prise en charge : la commission de '
          || trim_scale(coalesce(NEW.commission_amount, 0)::numeric) || ' DH ne sera pas remboursée.',
        jsonb_build_object('mission_id', NEW.id, 'screen', 'WalletDashboardScreen'),
        false
      );
    END IF;
  END IF;

  -- 6. Mission en attente annulee par le client : offres fermees, chauffeurs prevenus
  IF OLD.status = 'pending' AND NEW.status = 'cancelled_client' THEN
    WITH closed AS (
      UPDATE public.mission_offers
      SET status = 'not_selected'
      WHERE mission_id = NEW.id
        AND status = 'pending'
      RETURNING driver_id
    )
    INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
    SELECT DISTINCT d.profile_id,
           'offer_update',
           '❌ Mission annulée',
           'La mission ' || v_number || ' a été annulée par le client.',
           jsonb_build_object('mission_id', NEW.id, 'screen', 'DriverHomeScreen'),
           false
    FROM closed c
    JOIN public.drivers d ON d.id = c.driver_id
    WHERE d.profile_id IS NOT NULL;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.on_mission_cancelled() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS missions_on_cancelled ON public.missions;
CREATE TRIGGER missions_on_cancelled
  AFTER UPDATE OF status ON public.missions
  FOR EACH ROW
  WHEN (OLD.status IN ('pending', 'accepted')
        AND NEW.status IN ('cancelled_client', 'cancelled_driver'))
  EXECUTE FUNCTION public.on_mission_cancelled();

-- 5. Demande de remboursement refusee si le remboursement est perdu
CREATE OR REPLACE FUNCTION public.reject_forfeited_refund()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.transaction_type = 'refund'
     AND NEW.mission_id IS NOT NULL
     AND auth.uid() IS NOT NULL
     AND coalesce(public.get_my_role(), '') <> 'admin'
     AND EXISTS (SELECT 1 FROM missions m WHERE m.id = NEW.mission_id AND m.refund_forfeited) THEN
    RAISE EXCEPTION 'Remboursement impossible : la mission a été annulée par vous à moins du délai prévu avant la prise en charge.'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.reject_forfeited_refund() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS reject_forfeited_refund ON public.transactions;
CREATE TRIGGER reject_forfeited_refund
  BEFORE INSERT ON public.transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.reject_forfeited_refund();
