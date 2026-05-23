-- Migration: add_transactions_insert_policy
-- Allows authenticated users to insert transactions

CREATE POLICY "transactions_insert_own"
ON transactions
FOR INSERT
TO authenticated
WITH CHECK (true);
