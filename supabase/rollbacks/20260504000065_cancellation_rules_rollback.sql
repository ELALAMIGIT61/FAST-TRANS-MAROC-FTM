-- Rollback de la migration 20260504000065 (regles d'annulation, F4).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Attention : supprime les colonnes cancelled_at et refund_forfeited (et leurs valeurs).
DROP TRIGGER IF EXISTS reject_forfeited_refund ON public.transactions;
DROP FUNCTION IF EXISTS public.reject_forfeited_refund();
DROP TRIGGER IF EXISTS missions_on_cancelled ON public.missions;
DROP FUNCTION IF EXISTS public.on_mission_cancelled();
DROP FUNCTION IF EXISTS public.get_driver_cancel_terms(uuid);
DROP TRIGGER IF EXISTS set_mission_cancellation_fields ON public.missions;
DROP FUNCTION IF EXISTS public.set_mission_cancellation_fields();
DROP FUNCTION IF EXISTS public.cancel_refund_hours(text);
ALTER TABLE public.missions DROP COLUMN IF EXISTS refund_forfeited;
ALTER TABLE public.missions DROP COLUMN IF EXISTS cancelled_at;
DELETE FROM public.app_settings WHERE key LIKE 'cancel_refund_hours_%';
