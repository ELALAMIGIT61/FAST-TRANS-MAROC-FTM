-- Rollback 20260504000029
-- ATTENTION : executer ce fichier REINTRODUIT les failles financieres du volet 1
-- (colonnes modifiables, pas de controle d'appelant, montants negatifs possibles).
-- A n'utiliser qu'en cas de regression bloquante, sur decision explicite du porteur.
-- NOTE : la version restauree de charge_commission_anticipated est la version
-- VULNERABLE d'avant ce volet (sans controle d'appelant ni de statut).

GRANT UPDATE (commission_amount, commission_charged_at) ON public.missions TO anon;
GRANT UPDATE (commission_amount, commission_charged_at) ON public.missions TO authenticated;

ALTER TABLE public.missions DROP CONSTRAINT IF EXISTS missions_commission_amount_non_negative;
ALTER TABLE public.missions DROP CONSTRAINT IF EXISTS missions_negotiated_price_non_negative;

GRANT EXECUTE ON FUNCTION public.charge_commission_anticipated(uuid) TO anon;

CREATE POLICY "Users can update their own missions" ON public.missions
  FOR UPDATE
  USING (
    (client_id IN ( SELECT profiles.id FROM profiles WHERE (profiles.user_id = auth.uid())))
    OR (driver_id IN ( SELECT drivers.id FROM drivers WHERE (drivers.profile_id IN ( SELECT profiles.id FROM profiles WHERE (profiles.user_id = auth.uid())))))
  );

-- NOTE : ce rollback ne restaure PAS l'ancienne definition de la fonction.
-- Si necessaire, la readapter manuellement depuis l'historique git (commit f370da5 et anterieurs).
