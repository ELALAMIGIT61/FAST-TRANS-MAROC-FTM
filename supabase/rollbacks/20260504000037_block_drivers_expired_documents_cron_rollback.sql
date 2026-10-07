-- Rollback 20260504000037
-- Retire le CRON de blocage et la fonction associee.
-- Effet : les chauffeurs aux documents expires ne seront plus bloques automatiquement.
-- Ne retire PAS is_available=false deja positionne (les chauffeurs deja bloques le restent).
-- A n'utiliser qu'en cas de regression bloquante, sur decision explicite du porteur.

SELECT cron.unschedule('block-expired-documents')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'block-expired-documents');

DROP FUNCTION IF EXISTS public.block_drivers_with_expired_documents();
