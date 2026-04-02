-- Migration : 20260226000000_fix_profiles_rls_recursion.sql
-- Objectif : Corriger la récursion infinie dans la politique
--            profiles_select_admin sur la table profiles
-- Cause    : La politique faisait un SELECT FROM profiles
--            pour vérifier le rôle → boucle infinie au login OTP
-- Solution : Créer une fonction SECURITY DEFINER qui lit le rôle
--            sans déclencher les politiques RLS

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT role FROM profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

DROP POLICY IF EXISTS "profiles_select_admin" ON profiles;

CREATE POLICY "profiles_select_admin" ON profiles
FOR SELECT
USING (
  get_my_role() = 'admin'
  OR auth.uid() = user_id
);
