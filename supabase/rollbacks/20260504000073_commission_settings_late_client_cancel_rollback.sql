-- Rollback de la migration 20260504000073 (commission reglable, annulation
-- tardive par le client). A executer seulement sur decision du porteur.
-- Ne pas placer dans migrations/. Les missions gardent leur commission.
DROP TRIGGER IF EXISTS notify_commission_amount_changed ON public.app_settings;
DROP FUNCTION IF EXISTS public.notify_commission_amount_changed();
DROP TRIGGER IF EXISTS validate_app_setting ON public.app_settings;
DROP FUNCTION IF EXISTS public.validate_app_setting();
DROP FUNCTION IF EXISTS public.get_commission_amounts();
DROP FUNCTION IF EXISTS public.get_client_cancel_terms(uuid);

-- Versions precedentes
CREATE OR REPLACE FUNCTION public.calculate_commission(category vehicle_category)
 RETURNS numeric
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RETURN CASE category
        WHEN 'vul' THEN 25.00
        WHEN 'n2_medium' THEN 40.00
        WHEN 'n2_large' THEN 50.00
        ELSE 25.00
    END;
END;
$function$;

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
                || CASE WHEN NEW.commission_charged_at IS NOT NULL
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

DROP FUNCTION IF EXISTS public.client_cancel_no_refund_hours(text);
DELETE FROM public.app_settings WHERE key LIKE 'commission\_amount\_%' OR key LIKE 'client\_cancel\_no\_refund\_hours\_%';
