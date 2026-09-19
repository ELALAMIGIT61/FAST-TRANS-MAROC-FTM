-- Migration 20260504000027 -- Session 2.17
-- Objectif : ajouter la policy UPDATE manquante sur transactions.
--
-- Decouverte via tests de non-regression : validatePendingTransaction(),
-- rejectPendingTransaction() et markBankReconciled() echouaient toutes
-- silencieusement (aucune erreur SDK, mais aucune ligne modifiee), faute
-- de policy UPDATE sur cette table -- seules SELECT et INSERT existaient.
--
-- Seul l'admin peut modifier une transaction (validation, rejet, rapprochement
-- bancaire) -- aucun droit UPDATE accorde au chauffeur/client sur cette table.

CREATE POLICY "transactions_update_admin"
ON transactions FOR UPDATE
TO authenticated
USING (get_my_role() = 'admin')
WITH CHECK (get_my_role() = 'admin');
