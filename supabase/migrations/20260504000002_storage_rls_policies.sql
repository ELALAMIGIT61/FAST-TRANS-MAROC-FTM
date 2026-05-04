-- RLS policies for driver-documents storage bucket
CREATE POLICY "drivers_upload_own_documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'driver-documents');

CREATE POLICY "drivers_read_own_documents"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'driver-documents');

CREATE POLICY "drivers_update_own_documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'driver-documents');

CREATE POLICY "drivers_delete_own_documents"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'driver-documents');
