-- Rollback 20260504000040
-- Re-accorde l'execution a anon et authenticated (etat d'avant cette migration).

GRANT EXECUTE ON FUNCTION public.driver_has_expired_documents(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.driver_has_expired_documents(uuid) TO authenticated;
