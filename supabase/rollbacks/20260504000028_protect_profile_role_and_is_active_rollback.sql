-- Rollback 20260504000028
-- ATTENTION : executer ce fichier REINTRODUIT la faille d'elevation au role admin.
-- A n'utiliser qu'en cas de regression bloquante, sur decision explicite du porteur.

DROP TRIGGER IF EXISTS protect_profile_privileged_fields ON public.profiles;
DROP FUNCTION IF EXISTS public.protect_profile_privileged_fields();
