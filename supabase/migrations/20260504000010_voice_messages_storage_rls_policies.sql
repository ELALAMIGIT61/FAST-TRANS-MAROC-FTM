-- RLS policies for voice-messages storage bucket
CREATE POLICY "authenticated_upload_voice_messages"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'voice-messages');
CREATE POLICY "authenticated_read_voice_messages"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'voice-messages');
CREATE POLICY "authenticated_update_voice_messages"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'voice-messages');
CREATE POLICY "authenticated_delete_voice_messages"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'voice-messages');
