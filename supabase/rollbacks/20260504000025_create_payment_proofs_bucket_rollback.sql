-- Rollback de la migration 20260504000025
DROP POLICY IF EXISTS "admin_delete_payment_proofs" ON storage.objects;
DROP POLICY IF EXISTS "drivers_upload_own_payment_proofs" ON storage.objects;
DROP POLICY IF EXISTS "drivers_read_own_payment_proofs" ON storage.objects;
DELETE FROM storage.buckets WHERE id = 'payment-proofs';
