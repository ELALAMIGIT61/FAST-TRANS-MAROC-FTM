-- Rollback de la migration 20260504000050 (volet 5, lot D-bis etape 2)
-- A appliquer apres avoir remis l'ancienne version de send-tracking-sms.

ALTER TABLE public.ecommerce_parcels
  DROP COLUMN IF EXISTS tracking_sms_sent_at;
