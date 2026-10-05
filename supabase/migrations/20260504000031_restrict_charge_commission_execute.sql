-- Migration 20260504000031 - Volet 1 securite (correctif) : restriction d'execution de charge_commission_anticipated
-- La migration 029 utilisait REVOKE EXECUTE FROM anon, inefficace car le droit
-- etait detenu via PUBLIC (tout le monde), pas directement par anon.
-- Methode correcte : retirer a PUBLIC, re-accorder a authenticated et service_role.
-- La securite reelle repose sur le controle interne de la fonction (appelant = chauffeur
-- de la mission), ajoute en migration 029. Ce retrait ferme en plus la porte aux
-- visiteurs non connectes (anon).

REVOKE EXECUTE ON FUNCTION public.charge_commission_anticipated(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.charge_commission_anticipated(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.charge_commission_anticipated(uuid) TO service_role;
