-- Rollback de la migration 20260504000067 (notation par criteres, F5).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Attention : supprime les notes par critere et le statut de moderation des avis.
DROP FUNCTION IF EXISTS public.moderate_review(uuid, boolean);
DROP FUNCTION IF EXISTS public.get_reviews_to_moderate();
DROP FUNCTION IF EXISTS public.get_my_driver_reputation();
DROP FUNCTION IF EXISTS public.get_offer_driver_reviews(uuid);
DROP FUNCTION IF EXISTS public.get_offer_driver_reputation(uuid);
DROP FUNCTION IF EXISTS public.driver_reputation(uuid);
DELETE FROM public.app_settings WHERE key = 'cancel_count_window_months';
DROP TRIGGER IF EXISTS check_criteria_ratings ON public.missions;
DROP FUNCTION IF EXISTS public.check_criteria_ratings();
ALTER TABLE public.missions
  DROP COLUMN IF EXISTS review_moderated_at,
  DROP COLUMN IF EXISTS review_status,
  DROP COLUMN IF EXISTS rating_service,
  DROP COLUMN IF EXISTS rating_care,
  DROP COLUMN IF EXISTS rating_punctuality;
