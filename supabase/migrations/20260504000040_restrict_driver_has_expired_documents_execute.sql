-- Migration 20260504000040 - Volet 4b-3 (correctif) : restriction d'execution de driver_has_expired_documents
-- Meme cause que le correctif 038 (2e occurrence confirmee) : Supabase repose automatiquement
-- un GRANT EXECUTE direct a anon/authenticated sur les fonctions du schema public, APRES les
-- instructions de la migration qui cree la fonction. Le REVOKE place dans la migration 039
-- a donc ete ecrase. Correction dans une migration separee, appliquee apres le deploiement.
-- Fonction de lecture seule (true/false), reservee au systeme par coherence.

REVOKE EXECUTE ON FUNCTION public.driver_has_expired_documents(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.driver_has_expired_documents(uuid) FROM authenticated;
