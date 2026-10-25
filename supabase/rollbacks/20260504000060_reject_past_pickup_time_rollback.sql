-- Rollback de la migration 20260504000060 (point A1, correction 28)
-- Retire le controle serveur de l'heure de prise en charge a la creation.
-- NE JAMAIS placer ce fichier dans supabase/migrations/.

DROP TRIGGER IF EXISTS reject_past_pickup_time ON public.missions;
DROP FUNCTION IF EXISTS public.reject_past_pickup_time();
