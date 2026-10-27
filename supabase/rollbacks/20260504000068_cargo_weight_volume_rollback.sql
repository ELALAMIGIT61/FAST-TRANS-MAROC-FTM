-- Rollback de la migration 20260504000068 (poids et volume, F6).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Attention : supprime le poids et le volume saisis sur les missions.
-- La notification « Nouvelle mission » revient a sa version de la migration 066.
DROP TRIGGER IF EXISTS require_cargo_weight ON public.missions;
DROP FUNCTION IF EXISTS public.require_cargo_weight();
CREATE OR REPLACE FUNCTION public.on_mission_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_body text;
BEGIN
  v_body := coalesce(NEW.pickup_city, '?') || ' → ' || coalesce(NEW.dropoff_city, '?')
    || CASE WHEN NEW.scheduled_pickup_time IS NULL THEN ''
            ELSE ', le ' || to_char(NEW.scheduled_pickup_time AT TIME ZONE 'UTC', 'DD/MM "à" HH24"h"MI') END
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
ALTER TABLE public.missions
  DROP COLUMN IF EXISTS cargo_volume_m3,
  DROP COLUMN IF EXISTS cargo_weight_kg;
