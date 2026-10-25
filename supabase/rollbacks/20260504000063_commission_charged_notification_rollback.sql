-- Rollback de la migration 20260504000063 (point A1, correction 22)
-- Retire la notification envoyee au moment du prelevement. A utiliser avec la
-- version precedente de l'application (annonce de la commission en fin de mission).
-- NE JAMAIS placer ce fichier dans supabase/migrations/.

DROP TRIGGER IF EXISTS missions_commission_charged ON public.missions;
DROP FUNCTION IF EXISTS public.notify_commission_charged();
