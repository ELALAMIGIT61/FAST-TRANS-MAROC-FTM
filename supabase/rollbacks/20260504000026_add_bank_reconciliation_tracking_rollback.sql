-- Rollback de la migration 20260504000026
ALTER TABLE transactions DROP COLUMN IF EXISTS bank_reconciled_at;
