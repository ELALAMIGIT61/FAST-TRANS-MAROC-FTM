-- Migration 20260504000068 - point A1, F6 : poids et volume du chargement
-- (accord du porteur du 27/10/2026)
--
-- Regles validees :
-- - le client indique le poids (kg) et le volume (m3) de son chargement ;
-- - poids OBLIGATOIRE pour les missions de transport N2 Moyen et N2 Grand,
--   facultatif pour VUL (petits deplacements : le poids est rarement connu) ;
-- - volume facultatif pour toutes les categories ;
-- - le poids et le volume sont affiches au chauffeur (fiche, notification,
--   suivi) ; tous les chauffeurs de la categorie recoivent la mission, c'est
--   au chauffeur de juger (pas de filtre sur sa capacite) ;
-- - l'avertissement « charge utile depassee » (VUL 1,5 t, N2 Moyen 4,5 t,
--   N2 Grand 8 t) est affiche par l'application, sans blocage.
-- Les colis e-commerce (mission_type ecommerce_parcel) ne sont pas concernes
-- par l'obligation : ils ont deja leur propre poids et leurs dimensions.
--
-- 1. Colonnes missions.cargo_weight_kg et missions.cargo_volume_m3 (> 0),
--    renseignees a la creation (non modifiables ensuite par un utilisateur).
-- 2. Trigger require_cargo_weight (avant creation) : refuse une mission de
--    transport N2 sans poids, avec un message lisible.
-- 3. Notification « Nouvelle mission » (fonction de la migration 066) :
--    ajout du poids et du volume quand ils sont connus.
-- Aucune donnee existante modifiee.

-- 1
ALTER TABLE public.missions
  ADD COLUMN IF NOT EXISTS cargo_weight_kg numeric(10,2) CHECK (cargo_weight_kg > 0),
  ADD COLUMN IF NOT EXISTS cargo_volume_m3 numeric(10,2) CHECK (cargo_volume_m3 > 0);

REVOKE UPDATE (cargo_weight_kg, cargo_volume_m3) ON public.missions FROM anon, authenticated;

-- 2
CREATE OR REPLACE FUNCTION public.require_cargo_weight()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.mission_type = 'transport'
     AND NEW.vehicle_category IN ('n2_medium', 'n2_large')
     AND NEW.cargo_weight_kg IS NULL THEN
    RAISE EXCEPTION 'Merci d''indiquer le poids approximatif du chargement (obligatoire pour un camion N2).'
      USING ERRCODE = '23502';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.require_cargo_weight() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS require_cargo_weight ON public.missions;
CREATE TRIGGER require_cargo_weight
  BEFORE INSERT ON public.missions
  FOR EACH ROW
  EXECUTE FUNCTION public.require_cargo_weight();

-- 3
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
