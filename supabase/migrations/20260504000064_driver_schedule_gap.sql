-- Migration 20260504000064 - point A1, section D : ecart minimum entre deux
-- missions d'un meme chauffeur (accord du porteur du 26/10/2026)
--
-- Regles validees :
-- - le chauffeur continue de recevoir les missions, mais le serveur refuse
--   son offre si elle tombe trop pres d'une mission qu'il a deja ;
-- - seules les missions acceptees ou en cours comptent : des que la mission
--   precedente est terminee (ou annulee, expiree), le blocage est leve ;
-- - l'ecart depend de la categorie du vehicule : VUL 1 h, N2 Moyen 6 h,
--   N2 Grand 12 h ;
-- - ces ecarts sont ranges dans un tableau de reglages (app_settings),
--   modifiable par l'admin sans nouvelle migration.
--
-- 1. Table app_settings (cle, valeur, description), lecture et modification
--    reservees a l'admin. Elle accueillera aussi le delai d'annulation (F4).
-- 2. Trigger check_driver_schedule_conflict (avant insertion ou mise a jour
--    d'une offre) : controle a la creation de l'offre, puis au moment ou la
--    seconde partie donne son accord (le planning a pu changer entre-temps).
-- Aucune donnee existante modifiee. Les messages sont affiches tels quels
-- par l'application.

-- 1. Tableau de reglages
CREATE TABLE IF NOT EXISTS public.app_settings (
  key text PRIMARY KEY,
  value numeric NOT NULL,
  description text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_settings FROM anon;
REVOKE INSERT, DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.app_settings FROM authenticated;
GRANT SELECT, UPDATE ON public.app_settings TO authenticated;

DROP POLICY IF EXISTS app_settings_select_admin ON public.app_settings;
CREATE POLICY app_settings_select_admin ON public.app_settings
  FOR SELECT TO authenticated
  USING (public.get_my_role() = 'admin');

DROP POLICY IF EXISTS app_settings_update_admin ON public.app_settings;
CREATE POLICY app_settings_update_admin ON public.app_settings
  FOR UPDATE TO authenticated
  USING (public.get_my_role() = 'admin')
  WITH CHECK (public.get_my_role() = 'admin' AND value >= 0);

INSERT INTO public.app_settings (key, value, description) VALUES
  ('driver_gap_hours_vul', 1, 'Ecart minimum (heures) entre deux missions d''un chauffeur VUL'),
  ('driver_gap_hours_n2_medium', 6, 'Ecart minimum (heures) entre deux missions d''un chauffeur N2 Moyen'),
  ('driver_gap_hours_n2_large', 12, 'Ecart minimum (heures) entre deux missions d''un chauffeur N2 Grand')
ON CONFLICT (key) DO NOTHING;

-- 2. Controle du planning du chauffeur
CREATE OR REPLACE FUNCTION public.check_driver_schedule_conflict()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_target timestamptz;
  v_category text;
  v_gap numeric;
  v_conflict timestamptz;
  v_is_driver boolean;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    -- Seul l'accord final (les deux parties d'accord) est controle.
    IF NOT (NEW.client_accepted IS TRUE AND NEW.driver_accepted IS TRUE)
       OR (OLD.client_accepted IS TRUE AND OLD.driver_accepted IS TRUE) THEN
      RETURN NEW;
    END IF;
  END IF;

  SELECT m.scheduled_pickup_time INTO v_target
  FROM missions m WHERE m.id = NEW.mission_id;
  IF v_target IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT d.vehicle_category::text INTO v_category
  FROM drivers d WHERE d.id = NEW.driver_id;

  SELECT s.value INTO v_gap
  FROM app_settings s WHERE s.key = 'driver_gap_hours_' || v_category;
  v_gap := coalesce(v_gap, 12);

  SELECT m.scheduled_pickup_time INTO v_conflict
  FROM missions m
  WHERE m.driver_id = NEW.driver_id
    AND m.id <> NEW.mission_id
    AND m.status IN ('accepted', 'in_progress')
    AND m.scheduled_pickup_time IS NOT NULL
    AND abs(extract(epoch FROM (m.scheduled_pickup_time - v_target))) < v_gap * 3600
  ORDER BY abs(extract(epoch FROM (m.scheduled_pickup_time - v_target)))
  LIMIT 1;

  IF v_conflict IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    v_is_driver := true;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM drivers d JOIN profiles p ON p.id = d.profile_id
      WHERE d.id = NEW.driver_id AND p.user_id = auth.uid()
    ) INTO v_is_driver;
  END IF;

  IF v_is_driver THEN
    RAISE EXCEPTION 'Vous avez déjà une mission le % à %. Une nouvelle mission doit avoir au moins % h d''écart.',
      to_char(v_conflict AT TIME ZONE 'UTC', 'DD/MM'),
      to_char(v_conflict AT TIME ZONE 'UTC', 'HH24"h"MI'),
      trim_scale(v_gap)
      USING ERRCODE = 'P0001';
  ELSE
    RAISE EXCEPTION 'Ce chauffeur n''est plus disponible à cette heure. Choisissez une autre offre.'
      USING ERRCODE = 'P0001';
  END IF;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.check_driver_schedule_conflict() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS check_driver_schedule_conflict ON public.mission_offers;
CREATE TRIGGER check_driver_schedule_conflict
  BEFORE INSERT OR UPDATE ON public.mission_offers
  FOR EACH ROW
  EXECUTE FUNCTION public.check_driver_schedule_conflict();
