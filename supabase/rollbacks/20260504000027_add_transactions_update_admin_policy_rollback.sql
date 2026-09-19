-- Rollback de la migration 20260504000027
DROP POLICY IF EXISTS "transactions_update_admin" ON transactions;
