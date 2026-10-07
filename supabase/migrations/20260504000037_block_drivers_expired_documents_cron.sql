-- Migration 20260504000037 - Volet 4b-2 : blocage automatique des chauffeurs aux documents expires
-- Fonction SQL (pas d'Edge Function : pure operation base, plus robuste, testable manuellement).
-- Un CRON quotidien la declenche. Elle passe is_available = false pour tout chauffeur
-- disponible ayant AU MOINS un document expire ou manquant selon les regles ci-dessous.
-- Regles :
--   - permis, assurance, carte grise : bloque si date d'expiration renseignee ET depassee
--   - visite technique : bloque si le vehicule a PLUS de 5 ans
--     (vehicle_first_service_date renseignee ET anterieure a aujourd'hui - 5 ans)
--     ET visite technique absente (NULL) OU expiree. Capture le cas du vehicule
--     qui franchit les 5 ans en cours d'usage sans visite technique fournie.
--   - la fonction ne fait QUE bloquer (jamais debloquer) : pas de conflit avec le blocage
--     par solde ni avec le volet transitions. Le deblocage est gere en 4b-3.
-- TOLERANCE TRANSITOIRE (donnees de test) : une date d'expiration vide (permis/assurance/
--   carte grise) ou une date de mise en service vide ne bloque pas. En PRODUCTION, tous ces
--   champs doivent etre obligatoires a l'inscription (a inscrire dans l'onboarding / 4b-5) ;
--   ce cas disparaitra alors. La tolerance evite de bloquer a tort les profils de test actuels.

CREATE OR REPLACE FUNCTION public.block_drivers_with_expired_documents()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_today date := CURRENT_DATE;
  v_count integer;
BEGIN
  WITH to_block AS (
    SELECT d.id
    FROM drivers d
    WHERE d.is_available = true
      AND (
        (d.driver_license_expiry IS NOT NULL AND d.driver_license_expiry < v_today)
        OR (d.insurance_expiry IS NOT NULL AND d.insurance_expiry < v_today)
        OR (d.vehicle_registration_expiry IS NOT NULL AND d.vehicle_registration_expiry < v_today)
        OR (
          d.vehicle_first_service_date IS NOT NULL
          AND d.vehicle_first_service_date < (v_today - INTERVAL '5 years')
          AND (
            d.technical_inspection_expiry IS NULL
            OR d.technical_inspection_expiry < v_today
          )
        )
      )
  )
  UPDATE drivers
  SET is_available = false
  WHERE id IN (SELECT id FROM to_block);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RAISE LOG 'block_drivers_with_expired_documents: % chauffeur(s) bloque(s)', v_count;
  RETURN v_count;
END;
$function$;

-- Droits d'execution : seulement le systeme (service_role). Jamais anon/authenticated.
REVOKE EXECUTE ON FUNCTION public.block_drivers_with_expired_documents() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.block_drivers_with_expired_documents() TO service_role;

-- CRON quotidien a 7h (avant le CRON de rappels de 8h : on bloque puis on notifie).
SELECT cron.unschedule('block-expired-documents')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'block-expired-documents');

SELECT cron.schedule(
  'block-expired-documents',
  '0 7 * * *',
  $$ SELECT public.block_drivers_with_expired_documents(); $$
);
