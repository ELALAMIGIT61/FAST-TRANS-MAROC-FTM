-- Migration : 20260504000006_fix_wallet_update_admin_rls.sql
-- Objectif : Corriger la recursion RLS infinie sur wallet_update_admin
-- Cause    : EXISTS (SELECT FROM profiles) -> recursion infinie
-- Solution : get_my_role() SECURITY DEFINER - meme correctif que 20260226000000
DROP POLICY IF EXISTS "wallet_update_admin" ON wallet;
CREATE POLICY "wallet_update_admin" ON wallet
FOR UPDATE
USING (get_my_role() = 'admin');
