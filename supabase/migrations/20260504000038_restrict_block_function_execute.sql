-- Migration 20260504000038 - Volet 4b-2 (correctif) : restriction d'execution de block_drivers_with_expired_documents
-- La migration 037 utilisait REVOKE FROM PUBLIC, inefficace ici car anon/authenticated
-- ont un GRANT EXECUTE direct (pose automatiquement par Supabase sur les fonctions du schema public),
-- pas un droit herite de PUBLIC. Methode correcte : retirer nommement a anon et authenticated.
-- La fonction ne doit etre executee que par le systeme (CRON via service_role) ou postgres.

REVOKE EXECUTE ON FUNCTION public.block_drivers_with_expired_documents() FROM anon;
REVOKE EXECUTE ON FUNCTION public.block_drivers_with_expired_documents() FROM authenticated;
