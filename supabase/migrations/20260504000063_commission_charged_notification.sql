-- Migration 20260504000063 - point A1, correction 22 : notification « Commission
-- prelevee » envoyee au moment du prelevement (accord du porteur du 25/10/2026)
--
-- Constat : la notification « Commission prelevee » etait envoyee par
-- l'application a la fin de la mission, alors que la commission est prelevee
-- bien avant par la tache serveur (24 h avant la prise en charge, migration
-- 054), qui n'envoyait rien en cas de succes.
--
-- 1. Trigger missions_commission_charged : des que commission_charged_at passe
--    de vide a rempli (prelevement anticipe par la tache 054, ou prelevement de
--    secours a la fin de la mission), le chauffeur recoit « Commission prelevee »,
--    une seule fois par mission. La sonnerie est assuree par la migration 057.
-- Les fonctions de prelevement ne sont pas modifiees.
-- L'application, de son cote, n'annonce plus la commission a la fin de la
-- mission (« Mission cloturee »).

CREATE OR REPLACE FUNCTION public.notify_commission_charged()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_profile uuid;
BEGIN
  SELECT d.profile_id INTO v_profile FROM public.drivers d WHERE d.id = NEW.driver_id;
  IF v_profile IS NOT NULL THEN
    INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
    VALUES (
      v_profile,
      'commission_charged',
      '💰 Commission prélevée',
      'Commission de ' || coalesce(trim_scale(NEW.commission_amount)::text, '?')
        || ' DH prélevée pour la mission ' || coalesce(NEW.mission_number, '') || '.',
      jsonb_build_object('mission_id', NEW.id, 'screen', 'WalletDashboardScreen'),
      false
    );
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.notify_commission_charged() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS missions_commission_charged ON public.missions;
CREATE TRIGGER missions_commission_charged
  AFTER UPDATE OF commission_charged_at ON public.missions
  FOR EACH ROW
  WHEN (OLD.commission_charged_at IS NULL AND NEW.commission_charged_at IS NOT NULL)
  EXECUTE FUNCTION public.notify_commission_charged();
