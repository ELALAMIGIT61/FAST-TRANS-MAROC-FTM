-- Migration 20260504000067 - point A1, F5 : notation par criteres, nombre
-- d'annulations et commentaires moderes (accord du porteur du 26/10/2026)
--
-- Regles validees :
-- - en fin de mission, le client note le chauffeur sur 3 criteres (1 a 5) :
--   ponctualite, soin de la marchandise, services ; les 3 sont obligatoires,
--   la note est definitive ; le commentaire reste facultatif ;
-- - une moyenne PAR CRITERE est affichee (pas de moyenne globale au client) ;
--   la moyenne globale (drivers.rating_average) reste calculee en interne ;
-- - le client voit aussi, pour chaque chauffeur ayant fait une offre, le
--   nombre de missions realisees et le nombre de missions annulees par le
--   chauffeur sur une periode reglable par l'admin (6 mois au depart) ;
-- - les commentaires ne sont visibles par les autres clients qu'apres
--   validation par l'admin ; les 3 derniers publies sont affiches, sans le
--   nom du client ;
-- - le chauffeur voit ses 3 moyennes et ses annulations sur son tableau de bord ;
-- - les anciennes notes uniques (donnees de test) ne sont pas reprises dans
--   les moyennes par critere (choix b).
--
-- 1. Colonnes missions : rating_punctuality, rating_care, rating_service,
--    review_status (pending / published / rejected), review_moderated_at.
--    Seules les 3 notes sont modifiables par les utilisateurs (droits par
--    colonne) ; le statut de l'avis est gere par le serveur (et protege par
--    le trigger ci-dessous).
-- 2. Trigger check_criteria_ratings (avant mise a jour) : 3 notes ensemble,
--    une seule fois ; la note globale client_rating devient leur moyenne
--    arrondie (les controles existants de la migration 047 s'appliquent :
--    client de la mission, mission terminee) ; un commentaire accompagne
--    des 3 notes passe « a moderer ».
-- 3. Reglage cancel_count_window_months = 6.
-- 4. Fonctions de lecture : get_offer_driver_reputation(mission) et
--    get_offer_driver_reviews(mission) pour le client de la mission ;
--    get_my_driver_reputation() pour le chauffeur connecte.
-- 5. Moderation (admin seulement) : get_reviews_to_moderate() et
--    moderate_review(mission, publier).
-- Aucune donnee existante modifiee (nouvelles colonnes a NULL).

-- 1. Colonnes
ALTER TABLE public.missions
  ADD COLUMN IF NOT EXISTS rating_punctuality smallint CHECK (rating_punctuality BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS rating_care smallint CHECK (rating_care BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS rating_service smallint CHECK (rating_service BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS review_status text CHECK (review_status IN ('pending', 'published', 'rejected')),
  ADD COLUMN IF NOT EXISTS review_moderated_at timestamptz;

GRANT UPDATE (rating_punctuality, rating_care, rating_service) ON public.missions TO authenticated;
REVOKE UPDATE (review_status, review_moderated_at) ON public.missions FROM anon, authenticated;

-- 2. Controle de la notation par criteres
CREATE OR REPLACE FUNCTION public.check_criteria_ratings()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Le statut de l'avis n'est jamais modifiable directement par un utilisateur
  -- (l'admin passe par moderate_review).
  IF current_user IN ('authenticated', 'anon') THEN
    NEW.review_status := OLD.review_status;
    NEW.review_moderated_at := OLD.review_moderated_at;
  END IF;

  IF NEW.rating_punctuality IS DISTINCT FROM OLD.rating_punctuality
     OR NEW.rating_care IS DISTINCT FROM OLD.rating_care
     OR NEW.rating_service IS DISTINCT FROM OLD.rating_service THEN
    IF OLD.rating_punctuality IS NOT NULL OR OLD.rating_care IS NOT NULL OR OLD.rating_service IS NOT NULL THEN
      RAISE EXCEPTION 'La note de cette mission a déjà été donnée : elle est définitive.'
        USING ERRCODE = '42501';
    END IF;
    IF NEW.rating_punctuality IS NULL OR NEW.rating_care IS NULL OR NEW.rating_service IS NULL THEN
      RAISE EXCEPTION 'Merci de noter les 3 critères : ponctualité, soin de la marchandise et services.'
        USING ERRCODE = '22023';
    END IF;
    -- Note globale interne = moyenne arrondie des 3 criteres
    NEW.client_rating := round((NEW.rating_punctuality + NEW.rating_care + NEW.rating_service) / 3.0)::integer;
  END IF;

  -- Un commentaire donne avec la notation par criteres passe a moderer
  IF NEW.client_review IS DISTINCT FROM OLD.client_review
     AND NEW.rating_punctuality IS NOT NULL
     AND nullif(btrim(coalesce(NEW.client_review, '')), '') IS NOT NULL THEN
    NEW.review_status := 'pending';
    NEW.review_moderated_at := NULL;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.check_criteria_ratings() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS check_criteria_ratings ON public.missions;
CREATE TRIGGER check_criteria_ratings
  BEFORE UPDATE ON public.missions
  FOR EACH ROW
  EXECUTE FUNCTION public.check_criteria_ratings();

-- 3. Reglage
INSERT INTO public.app_settings (key, value, description) VALUES
  ('cancel_count_window_months', 6, 'Periode (mois) de comptage des annulations du chauffeur affichees aux clients')
ON CONFLICT (key) DO NOTHING;

-- 4a. Reputation d'un chauffeur (fonction interne)
CREATE OR REPLACE FUNCTION public.driver_reputation(p_driver_id uuid)
RETURNS TABLE (
  avg_punctuality numeric,
  avg_care numeric,
  avg_service numeric,
  rated_missions integer,
  completed_missions integer,
  cancelled_missions integer,
  cancel_window_months numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_window numeric;
BEGIN
  SELECT s.value INTO v_window FROM app_settings s WHERE s.key = 'cancel_count_window_months';
  v_window := coalesce(v_window, 6);

  RETURN QUERY
  SELECT
    round(avg(m.rating_punctuality) FILTER (WHERE m.rating_punctuality IS NOT NULL), 1),
    round(avg(m.rating_care) FILTER (WHERE m.rating_care IS NOT NULL), 1),
    round(avg(m.rating_service) FILTER (WHERE m.rating_service IS NOT NULL), 1),
    (count(*) FILTER (WHERE m.rating_punctuality IS NOT NULL))::integer,
    (count(*) FILTER (WHERE m.status = 'completed'))::integer,
    (count(*) FILTER (WHERE m.status = 'cancelled_driver'
                        AND coalesce(m.cancelled_at, m.updated_at)
                            >= now() - make_interval(days => (v_window * 30)::integer)))::integer,
    trim_scale(v_window)
  FROM missions m
  WHERE m.driver_id = p_driver_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.driver_reputation(uuid) FROM PUBLIC, anon, authenticated;

-- 4b. Pour le client : reputation des chauffeurs ayant une offre sur SA mission
CREATE OR REPLACE FUNCTION public.get_offer_driver_reputation(p_mission_id uuid)
RETURNS TABLE (
  driver_id uuid,
  avg_punctuality numeric,
  avg_care numeric,
  avg_service numeric,
  rated_missions integer,
  completed_missions integer,
  cancelled_missions integer,
  cancel_window_months numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT o.driver_id, r.*
  FROM (
    SELECT DISTINCT mo.driver_id
    FROM mission_offers mo
    JOIN missions m ON m.id = mo.mission_id
    JOIN profiles p ON p.id = m.client_id
    WHERE mo.mission_id = p_mission_id AND p.user_id = auth.uid()
  ) o
  CROSS JOIN LATERAL public.driver_reputation(o.driver_id) r;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_offer_driver_reputation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_offer_driver_reputation(uuid) TO authenticated;

-- 4c. Pour le client : 3 derniers commentaires publies de chaque chauffeur
--     (sans le nom du client)
CREATE OR REPLACE FUNCTION public.get_offer_driver_reviews(p_mission_id uuid)
RETURNS TABLE (
  driver_id uuid,
  review_date timestamptz,
  review text,
  rating_punctuality smallint,
  rating_care smallint,
  rating_service smallint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT x.driver_id, x.review_date, x.client_review, x.rating_punctuality, x.rating_care, x.rating_service
  FROM (
    SELECT rm.driver_id,
           coalesce(rm.completed_at, rm.updated_at) AS review_date,
           rm.client_review, rm.rating_punctuality, rm.rating_care, rm.rating_service,
           row_number() OVER (PARTITION BY rm.driver_id
                              ORDER BY coalesce(rm.completed_at, rm.updated_at) DESC) AS rn
    FROM missions rm
    WHERE rm.review_status = 'published'
      AND rm.driver_id IN (
        SELECT mo.driver_id
        FROM mission_offers mo
        JOIN missions m ON m.id = mo.mission_id
        JOIN profiles p ON p.id = m.client_id
        WHERE mo.mission_id = p_mission_id AND p.user_id = auth.uid()
      )
  ) x
  WHERE x.rn <= 3
  ORDER BY x.driver_id, x.review_date DESC;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_offer_driver_reviews(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_offer_driver_reviews(uuid) TO authenticated;

-- 4d. Pour le chauffeur connecte : sa propre reputation
CREATE OR REPLACE FUNCTION public.get_my_driver_reputation()
RETURNS TABLE (
  avg_punctuality numeric,
  avg_care numeric,
  avg_service numeric,
  rated_missions integer,
  completed_missions integer,
  cancelled_missions integer,
  cancel_window_months numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT r.*
  FROM drivers d
  JOIN profiles p ON p.id = d.profile_id
  CROSS JOIN LATERAL public.driver_reputation(d.id) r
  WHERE p.user_id = auth.uid();
$function$;

REVOKE EXECUTE ON FUNCTION public.get_my_driver_reputation() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_driver_reputation() TO authenticated;

-- 5a. Admin : commentaires a moderer
CREATE OR REPLACE FUNCTION public.get_reviews_to_moderate()
RETURNS TABLE (
  mission_id uuid,
  mission_number text,
  review_date timestamptz,
  review text,
  rating_punctuality smallint,
  rating_care smallint,
  rating_service smallint,
  driver_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF coalesce(public.get_my_role(), '') <> 'admin' THEN
    RAISE EXCEPTION 'Réservé à l''administrateur.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT m.id, m.mission_number::text, coalesce(m.completed_at, m.updated_at),
         m.client_review, m.rating_punctuality, m.rating_care, m.rating_service,
         p.full_name::text
  FROM missions m
  LEFT JOIN drivers d ON d.id = m.driver_id
  LEFT JOIN profiles p ON p.id = d.profile_id
  WHERE m.review_status = 'pending'
  ORDER BY coalesce(m.completed_at, m.updated_at);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_reviews_to_moderate() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_reviews_to_moderate() TO authenticated;

-- 5b. Admin : publier ou refuser un commentaire
CREATE OR REPLACE FUNCTION public.moderate_review(p_mission_id uuid, p_publish boolean)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF coalesce(public.get_my_role(), '') <> 'admin' THEN
    RAISE EXCEPTION 'Réservé à l''administrateur.' USING ERRCODE = '42501';
  END IF;
  UPDATE missions
  SET review_status = CASE WHEN p_publish THEN 'published' ELSE 'rejected' END,
      review_moderated_at = now()
  WHERE id = p_mission_id AND review_status = 'pending';
  RETURN FOUND;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.moderate_review(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.moderate_review(uuid, boolean) TO authenticated;
