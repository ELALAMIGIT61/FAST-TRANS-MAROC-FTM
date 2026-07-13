-- ROLLBACK pour 20260504000013_fix_storage_transactions_rls_ownership.sql
-- Session 2.12 -- Fast Trans Maroc (FTM)
--
-- ATTENTION : NE JAMAIS placer ce fichier dans supabase/migrations/
-- A appliquer MANUELLEMENT uniquement, en cas d echec confirme d un test
-- post-deploiement (Etape 2.4/2.5). Jamais via le pipeline automatique.
--
-- Restaure l etat exact lu aux Etapes 1.1 et 1.4 de la session 2.12.

DROP POLICY IF EXISTS "drivers_read_own_documents" ON storage.objects;
CREATE POLICY "drivers_read_own_documents"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'driver-documents');

DROP POLICY IF EXISTS "drivers_upload_own_documents" ON storage.objects;
CREATE POLICY "drivers_upload_own_documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'driver-documents');

DROP POLICY IF EXISTS "drivers_update_own_documents" ON storage.objects;
CREATE POLICY "drivers_update_own_documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'driver-documents');

DROP POLICY IF EXISTS "drivers_delete_own_documents" ON storage.objects;
CREATE POLICY "drivers_delete_own_documents"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'driver-documents');

DROP POLICY IF EXISTS "transactions_insert_own" ON transactions;
CREATE POLICY "transactions_insert_own"
ON transactions FOR INSERT
TO authenticated
WITH CHECK (true);
