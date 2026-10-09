-- Rollback 20260504000042
-- ATTENTION : executer ce fichier REINTRODUIT la faille d'auto-validation
-- (un chauffeur pourrait de nouveau ecrire 'verified' sur ses documents et is_verified=true).
-- A n'utiliser qu'en cas de regression bloquante, sur decision explicite du porteur.

DROP TRIGGER IF EXISTS protect_driver_verification_fields ON public.drivers;
DROP FUNCTION IF EXISTS public.protect_driver_verification_fields();

-- Recreation du doublon de policy UPDATE retire (etat d'avant la migration 042)
CREATE POLICY "Drivers can update their own data" ON public.drivers
  FOR UPDATE
  USING (profile_id IN ( SELECT profiles.id FROM profiles WHERE (profiles.user_id = auth.uid())));
