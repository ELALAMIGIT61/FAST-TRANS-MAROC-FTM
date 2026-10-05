-- Rollback 20260504000030
-- ATTENTION : executer ce fichier REINTRODUIT la possibilite de modifier
-- commission_amount et commission_charged_at (faille financiere).
-- A n'utiliser qu'en cas de regression bloquante, sur decision explicite du porteur.

REVOKE UPDATE ON public.missions FROM anon;
REVOKE UPDATE ON public.missions FROM authenticated;

GRANT UPDATE ON public.missions TO anon;
GRANT UPDATE ON public.missions TO authenticated;
