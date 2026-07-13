-- Migration: fix_storage_transactions_rls_ownership
-- Session 2.12 -- Fast Trans Maroc (FTM)
--
-- OBJECTIF :
-- Corriger absence de clause de propriete sur les policies RLS du bucket
-- Storage driver-documents et sur la policy transactions_insert_own.
--
-- PERIMETRE :
-- - 4 policies sur storage.objects, bucket driver-documents uniquement
-- - transactions_insert_own
-- - Le bucket voice-messages n est pas touche par cette migration.
--   Voir rapport de synthese session 2.12, Etape 1.7.

DROP POLICY IF EXISTS "drivers_read_own_documents" ON storage.objects;
CREATE POLICY "drivers_read_own_documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'driver-documents'
  AND (
    get_my_role() = 'admin'
    OR (storage.foldername(name))[1]::uuid IN (
      SELECT d.id FROM drivers d
      JOIN profiles p ON p.id = d.profile_id
      WHERE p.user_id = auth.uid()
    )
  )
);

DROP POLICY IF EXISTS "drivers_upload_own_documents" ON storage.objects;
CREATE POLICY "drivers_upload_own_documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'driver-documents'
  AND (
    get_my_role() = 'admin'
    OR (storage.foldername(name))[1]::uuid IN (
      SELECT d.id FROM drivers d
      JOIN profiles p ON p.id = d.profile_id
      WHERE p.user_id = auth.uid()
    )
  )
);

DROP POLICY IF EXISTS "drivers_update_own_documents" ON storage.objects;
CREATE POLICY "drivers_update_own_documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'driver-documents'
  AND (
    get_my_role() = 'admin'
    OR (storage.foldername(name))[1]::uuid IN (
      SELECT d.id FROM drivers d
      JOIN profiles p ON p.id = d.profile_id
      WHERE p.user_id = auth.uid()
    )
  )
);

DROP POLICY IF EXISTS "drivers_delete_own_documents" ON storage.objects;
CREATE POLICY "drivers_delete_own_documents"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'driver-documents'
  AND (
    get_my_role() = 'admin'
    OR (storage.foldername(name))[1]::uuid IN (
      SELECT d.id FROM drivers d
      JOIN profiles p ON p.id = d.profile_id
      WHERE p.user_id = auth.uid()
    )
  )
);


DROP POLICY IF EXISTS "transactions_insert_own" ON transactions;
CREATE POLICY "transactions_insert_own"
ON transactions FOR INSERT
TO authenticated
WITH CHECK (
  get_my_role() = 'admin'
  OR wallet_id IN (
    SELECT w.id FROM wallet w
    JOIN drivers dr ON dr.id = w.driver_id
    JOIN profiles p ON p.id = dr.profile_id
    WHERE p.user_id = auth.uid()
  )
);

-- Note : alias "dr" utilise ci-dessus pour la table drivers (au lieu de "d")
-- afin d eviter un artefact de copie recurrent rencontre lors de la
-- redaction de cette migration (fusion de caracteres "drivers d" -> "driversd").
-- Choix sans impact logique ou securitaire sur la clause.
