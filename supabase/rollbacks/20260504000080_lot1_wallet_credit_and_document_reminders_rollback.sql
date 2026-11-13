-- Rollback de la migration 20260504000080 (lot 1 : credit du portefeuille et rappels de documents).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- A n'executer qu'APRES avoir remis l'application dans sa version d'avant le lot 1
-- (l'application du lot 1 appelle admin_credit_wallet et admin_validate_pending_transaction).
-- Les transactions et les rappels deja enregistres sont conserves : seules les
-- fonctions et le declencheur sont retires. Les rappels redeviennent figes, comme avant.

DROP TRIGGER IF EXISTS sync_document_reminders ON public.drivers;
DROP FUNCTION IF EXISTS public.sync_document_reminders();
DROP FUNCTION IF EXISTS public.upsert_document_reminder(uuid, text, date);
DROP FUNCTION IF EXISTS public.admin_validate_pending_transaction(uuid);
DROP FUNCTION IF EXISTS public.admin_credit_wallet(uuid, numeric, public.transaction_type, uuid, text, jsonb);
