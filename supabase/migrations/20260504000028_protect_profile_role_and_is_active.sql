-- Migration 20260504000028 - Etape 2 : correction de la faille d'elevation au role admin
-- Regles appliquees aux utilisateurs ordinaires (roles de connexion authenticated / anon) :
--   1. INSERT : role doit etre 'client' ou 'driver'
--   2. UPDATE : role ne peut pas changer
--   3. UPDATE : is_active ne peut pas changer
-- Non concernes : admins (get_my_role() = 'admin') et systeme (postgres, service_role, SQL Editor)

CREATE OR REPLACE FUNCTION public.protect_profile_privileged_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF public.get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.role IS NULL OR NEW.role NOT IN ('client', 'driver') THEN
      RAISE EXCEPTION 'profile_role_forbidden: only client or driver profiles can be created'
        USING ERRCODE = '42501';
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'profile_role_locked: role cannot be changed'
        USING ERRCODE = '42501';
    END IF;
    IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
      RAISE EXCEPTION 'profile_is_active_locked: only an admin can change is_active'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS protect_profile_privileged_fields ON public.profiles;

CREATE TRIGGER protect_profile_privileged_fields
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_privileged_fields();
