-- Rollback 20260504000036
-- Retire les deux colonnes ajoutees (carte grise expiry + date de 1ere mise en service).
-- Sans danger tant qu'aucune logique (CRON de blocage, regle visite technique) ne s'en sert encore.
-- A n'executer que si les sous-volets suivants (4b-2 et au-dela) ne sont pas deployes.

ALTER TABLE public.drivers
  DROP COLUMN IF EXISTS vehicle_registration_expiry,
  DROP COLUMN IF EXISTS vehicle_first_service_date;
