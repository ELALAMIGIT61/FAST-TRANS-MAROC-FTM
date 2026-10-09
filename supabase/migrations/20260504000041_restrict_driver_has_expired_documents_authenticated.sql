-- Migration 20260504000041 - Volet 4b-3 (correctif 2) : retrait du droit EXECUTE residuel a authenticated
-- sur driver_has_expired_documents. La migration 040 n'avait pas suffi (authenticated encore present
-- en lecture directe : {postgres=X, authenticated=X, service_role=X}) ; anon avait bien ete retire.
-- Cause racine identifiee : droits par defaut du schema public (ALTER DEFAULT PRIVILEGES) qui
-- re-accordent EXECUTE a anon/authenticated a chaque CREATE OR REPLACE d'une fonction. Correction
-- durable renvoyee au volet 5 (audit global des droits). Ici, retrait cible qui tiendra tant que
-- la fonction n'est pas recreee.

REVOKE EXECUTE ON FUNCTION public.driver_has_expired_documents(uuid) FROM authenticated;
