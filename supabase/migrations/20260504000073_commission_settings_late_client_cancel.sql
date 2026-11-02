-- Migration 20260504000073 - point A1 : commission reglable par l'admin et
-- annulation tardive par le client (accord du porteur du 02/11/2026)
--
-- 1. Commission reglable par categorie (reglages commission_amount_<categorie>,
--    25 / 40 / 50 DH au depart, 1 DH au minimum). Le montant est fixe a la
--    creation de la mission : une mission deja creee garde le sien.
--    Fonction get_commission_amounts() pour l'affichage dans l'application
--    (client et chauffeur). Quand l'admin change un montant, les chauffeurs de
--    la categorie sont prevenus.
-- 2. Annulation tardive par le client : si le client annule une mission
--    conclue, commission deja prelevee, a moins de X heures de l'heure prevue
--    (ou apres), la commission n'est pas remboursee (meme mecanisme que
--    l'annulation tardive par le chauffeur, migration 065). X par categorie,
--    reglable (client_cancel_no_refund_hours_<categorie> : VUL 1 h, N2 Moyen
--    2 h, N2 Grand 2 h). Le chauffeur et l'admin sont prevenus ; le client est
--    averti avant de confirmer (fonction get_client_cancel_terms). Objectif :
--    contrer l'annulation demandee par le chauffeur au client pour recuperer
--    la commission alors que le transport a lieu.
-- 3. Controle serveur des valeurs de reglages (valeurs negatives refusees,
--    commission d'au moins 1 DH).
-- Aucune donnee existante modifiee (les missions gardent leur commission).

-- 1. Reglages
INSERT INTO public.app_settings (key, value, description) VALUES
  ('commission_amount_vul', 25, 'Commission prelevee au chauffeur VUL pour une mission (DH, au moins 1)'),
  ('commission_amount_n2_medium', 40, 'Commission prelevee au chauffeur N2 Moyen pour une mission (DH, au moins 1)'),
  ('commission_amount_n2_large', 50, 'Commission prelevee au chauffeur N2 Grand pour une mission (DH, au moins 1)'),
  ('client_cancel_no_refund_hours_vul', 1, 'Annulation par le client a moins de ce delai (heures) avant une mission VUL : commission du chauffeur non remboursee'),
  ('client_cancel_no_refund_hours_n2_medium', 2, 'Annulation par le client a moins de ce delai (heures) avant une mission N2 Moyen : commission du chauffeur non remboursee'),
  ('client_cancel_no_refund_hours_n2_large', 2, 'Annulation par le client a moins de ce delai (heures) avant une mission N2 Grand : commission du chauffeur non remboursee')
ON CONFLICT (key) DO NOTHING;

-- 1a. Montant de la commission a la creation d'une mission (lu dans les
--     reglages ; anciennes valeurs si le reglage manque)
CREATE OR REPLACE FUNCTION public.calculate_commission(category vehicle_category)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT s.value FROM app_settings s WHERE s.key = 'commission_amount_' || category::text),
    CASE category WHEN 'vul' THEN 25.00 WHEN 'n2_medium' THEN 40.00 WHEN 'n2_large' THEN 50.00 ELSE 25.00 END);
$function$;

REVOKE EXECUTE ON FUNCTION public.calculate_commission(vehicle_category) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_commission(vehicle_category) TO authenticated;

-- 1b. Montants en vigueur, pour l'affichage dans l'application
CREATE OR REPLACE FUNCTION public.get_commission_amounts()
 RETURNS TABLE (vehicle_category text, amount numeric)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT c.cat, public.calculate_commission(c.cat::vehicle_category)
  FROM (VALUES ('vul'), ('n2_medium'), ('n2_large')) AS c(cat);
$function$;

REVOKE EXECUTE ON FUNCTION public.get_commission_amounts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_commission_amounts() TO authenticated;

-- 3. Controle des valeurs de reglages (serveur)
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

REVOKE EXECUTE ON FUNCTION public.validate_app_setting() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS validate_app_setting ON public.app_settings;
CREATE TRIGGER validate_app_setting
  BEFORE INSERT OR UPDATE ON public.app_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_app_setting();

-- 1c. Chauffeurs prevenus d'un changement de commission
CREATE OR REPLACE FUNCTION public.notify_commission_amount_changed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cat text := substr(NEW.key, length('commission_amount_') + 1);
  v_label text;
BEGIN
  v_label := CASE v_cat WHEN 'vul' THEN 'VUL' WHEN 'n2_medium' THEN 'N2 Moyen' WHEN 'n2_large' THEN 'N2 Grand' ELSE v_cat END;
  BEGIN
    INSERT INTO notifications (profile_id, type, title, body, data, is_read)
    SELECT d.profile_id, 'commission_rate_changed', '💰 Nouvelle commission',
           'La commission ' || v_label || ' passe de ' || trim_scale(OLD.value)::text || ' à '
             || trim_scale(NEW.value)::text || ' DH pour les nouvelles missions. '
             || 'Les missions déjà créées gardent leur commission.',
           jsonb_build_object('screen', 'DriverHomeScreen'), false
    FROM drivers d
    WHERE d.vehicle_category::text = v_cat AND d.profile_id IS NOT NULL;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'notify_commission_amount_changed: notifications non envoyees (%)', SQLERRM;
  END;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.notify_commission_amount_changed() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS notify_commission_amount_changed ON public.app_settings;
CREATE TRIGGER notify_commission_amount_changed
  AFTER UPDATE OF value ON public.app_settings
  FOR EACH ROW
  WHEN (NEW.key LIKE 'commission\_amount\_%' AND OLD.value IS DISTINCT FROM NEW.value)
  EXECUTE FUNCTION public.notify_commission_amount_changed();

-- 2. Annulation tardive par le client
CREATE OR REPLACE FUNCTION public.client_cancel_no_refund_hours(p_category text)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT s.value FROM app_settings s WHERE s.key = 'client_cancel_no_refund_hours_' || p_category),
    2);
$function$;

REVOKE EXECUTE ON FUNCTION public.client_cancel_no_refund_hours(text) FROM PUBLIC, anon, authenticated;

-- 2a. Remboursement perdu en cas d'annulation tardive par le client
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
    -- Migration 073 : annulation tardive par le client (ou apres l'heure prevue)
    IF NEW.status = 'cancelled_client'
       AND OLD.status = 'accepted'
       AND OLD.commission_charged_at IS NOT NULL
       AND OLD.scheduled_pickup_time IS NOT NULL
       AND OLD.scheduled_pickup_time - now()
           < make_interval(secs => public.client_cancel_no_refund_hours(OLD.vehicle_category::text) * 3600) THEN
      NEW.refund_forfeited := true;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.set_mission_cancellation_fields() FROM PUBLIC, anon, authenticated;

-- 2b. Chauffeur prevenu (texte de la migration 069 complete)
CREATE OR REPLACE FUNCTION public.on_mission_status_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_number text := coalesce(NEW.mission_number, '');
  v_driver_profile uuid;
BEGIN
  SELECT d.profile_id INTO v_driver_profile FROM drivers d WHERE d.id = NEW.driver_id;

  BEGIN
    IF OLD.status = 'accepted' AND NEW.status = 'in_progress' AND NEW.client_id IS NOT NULL THEN
      INSERT INTO notifications (profile_id, type, title, body, data, is_read)
      VALUES (NEW.client_id, 'mission_started', '🚛 Chargement en cours',
              'Votre mission ' || v_number || ' a démarré. Trajet en cours vers '
                || coalesce(NEW.dropoff_city, 'la destination') || '.',
              jsonb_build_object('mission_id', NEW.id, 'screen', 'MissionTrackingScreen'), false);

    ELSIF OLD.status = 'in_progress' AND NEW.status = 'completed' THEN
      IF NEW.client_id IS NOT NULL THEN
        INSERT INTO notifications (profile_id, type, title, body, data, is_read)
        VALUES (NEW.client_id, 'mission_completed', '🏁 Mission terminée !',
                'Mission ' || v_number || ' livrée à ' || coalesce(NEW.dropoff_city, 'destination')
                  || '. Évaluez votre chauffeur.',
                jsonb_build_object('mission_id', NEW.id, 'screen', 'RatingScreen'), false);
      END IF;
      IF v_driver_profile IS NOT NULL THEN
        INSERT INTO notifications (profile_id, type, title, body, data, is_read)
        VALUES (v_driver_profile, 'mission_completed', '✅ Mission clôturée',
                'Mission ' || v_number || ' clôturée. Merci !',
                jsonb_build_object('mission_id', NEW.id, 'screen', 'DriverHomeScreen'), false);
      END IF;

    ELSIF OLD.status = 'accepted' AND NEW.status = 'cancelled_client' AND v_driver_profile IS NOT NULL THEN
      INSERT INTO notifications (profile_id, type, title, body, data, is_read)
      VALUES (v_driver_profile, 'mission_cancelled', '❌ Mission annulée',
              'La mission ' || v_number || ' a été annulée par le client.'
                || CASE WHEN NEW.commission_charged_at IS NOT NULL AND NEW.refund_forfeited
                        THEN ' Annulation tardive (moins de '
                          || trim_scale(public.client_cancel_no_refund_hours(NEW.vehicle_category::text))::text
                          || ' h avant l''heure prévue, ou après) : la commission ne sera pas remboursée.'
                        WHEN NEW.commission_charged_at IS NOT NULL
                        THEN ' Vous pouvez demander le remboursement de la commission depuis la mission.'
                        ELSE '' END,
              jsonb_build_object('mission_id', NEW.id, 'screen', 'MissionActiveScreen'), false);

    ELSIF OLD.status = 'accepted' AND NEW.status = 'cancelled_driver' AND NEW.client_id IS NOT NULL THEN
      INSERT INTO notifications (profile_id, type, title, body, data, is_read)
      VALUES (NEW.client_id, 'mission_cancelled', '❌ Mission annulée',
              'La mission ' || v_number || ' a été annulée par le chauffeur. Vous pouvez créer une nouvelle mission.',
              jsonb_build_object('mission_id', NEW.id, 'screen', 'MissionTrackingScreen'), false);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'on_mission_status_notify: notification non envoyee pour la mission % (%)', v_number, SQLERRM;
  END;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.on_mission_status_notify() FROM PUBLIC, anon, authenticated;

-- 2c. Admin prevenu d'une annulation tardive par le client
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

  -- Migration 073 : annulation tardive par le client, admin prevenu
  IF NEW.status = 'cancelled_client' AND NEW.refund_forfeited THEN
    INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
    SELECT p.id, 'mission_cancelled', '⚠️ Annulation tardive par le client',
           'La mission ' || v_number || ' a été annulée par le client moins de '
             || trim_scale(public.client_cancel_no_refund_hours(NEW.vehicle_category::text))::text
             || ' h avant l''heure prévue (ou après) : commission du chauffeur non remboursée.',
           jsonb_build_object('mission_id', NEW.id), false
    FROM profiles p WHERE p.role = 'admin';
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

-- 2d. Refus de remboursement : message valable pour les deux cas
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
    RAISE EXCEPTION 'Remboursement impossible : la mission a été annulée trop près de l''heure prévue (annulation tardive).'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.reject_forfeited_refund() FROM PUBLIC, anon, authenticated;

-- 2e. Ce que l'application affiche au client avant une annulation
CREATE OR REPLACE FUNCTION public.get_client_cancel_terms(p_mission_id uuid)
 RETURNS TABLE (late boolean, hours numeric, commission_charged boolean)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (m.status = 'accepted'
          AND m.commission_charged_at IS NOT NULL
          AND m.scheduled_pickup_time IS NOT NULL
          AND m.scheduled_pickup_time - now()
              < make_interval(secs => public.client_cancel_no_refund_hours(m.vehicle_category::text) * 3600)),
         public.client_cancel_no_refund_hours(m.vehicle_category::text),
         m.commission_charged_at IS NOT NULL
  FROM missions m
  JOIN profiles p ON p.id = m.client_id
  WHERE m.id = p_mission_id AND p.user_id = auth.uid();
$function$;

REVOKE EXECUTE ON FUNCTION public.get_client_cancel_terms(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_client_cancel_terms(uuid) TO authenticated;
