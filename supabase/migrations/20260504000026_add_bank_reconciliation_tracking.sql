-- Migration 20260504000026 -- Session 2.17, Point 11 (second niveau de validation)
-- Objectif : tracer le rapprochement bancaire differe des transactions creditees
-- via un mode de paiement autre que 'cash_agent' (virement, Wafacash, Cash Plus).
--
-- Conception (arbitrage porteur) : le credit reel sur le wallet a deja lieu des
-- la validation documentaire (deja implemente, session 2.17). Ce champ ne bloque
-- rien -- il trace une verification a posteriori, purement informative, par
-- rapprochement avec le releve bancaire reel du compte FTM (hors application).

ALTER TABLE transactions ADD COLUMN bank_reconciled_at TIMESTAMP WITH TIME ZONE;
