-- Rollback 20260504000034
-- ATTENTION : executer ce fichier REINTRODUIT la faille de lecture large des chauffeurs
-- (tout utilisateur connecte pourrait de nouveau lire tous les chauffeurs disponibles).
-- A n'utiliser qu'en cas de regression bloquante, sur decision explicite du porteur.
-- Recree les deux policies retirees, a l'identique de leur definition d'avant la migration 034.

CREATE POLICY drivers_select_available ON public.drivers
  FOR SELECT
  USING ((is_verified = true) AND (is_available = true));

CREATE POLICY "Drivers can view their own data" ON public.drivers
  FOR SELECT
  USING (profile_id IN ( SELECT profiles.id FROM profiles WHERE (profiles.user_id = auth.uid())));
