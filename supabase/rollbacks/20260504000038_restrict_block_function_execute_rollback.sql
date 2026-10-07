-- Rollback 20260504000038
-- Re-accorde l'execution a anon et authenticated (etat d'avant cette migration).

GRANT EXECUTE ON FUNCTION public.block_drivers_with_expired_documents() TO anon;
GRANT EXECUTE ON FUNCTION public.block_drivers_with_expired_documents() TO authenticated;
