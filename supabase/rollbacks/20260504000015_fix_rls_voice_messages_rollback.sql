-- Rollback pour migration 20260504000015_fix_rls_voice_messages.sql
-- Session 2.14 ter — Correction RLS bucket voice-messages
--
-- ATTENTION : ce rollback SQL seul est insuffisant en cas de déploiement partiel.
-- Il restaure les 4 anciennes policies permissives (authenticated_*_voice_messages),
-- mais si du code applicatif a été modifié ou déployé en dépendance de la nouvelle
-- clause RLS entre-temps, ce rollback SQL doit être accompagné d'un git revert
-- coordonné du code applicatif correspondant. Ne jamais exécuter ce rollback seul
-- sans vérifier l'état du code applicatif en parallèle.

DROP POLICY IF EXISTS "voice_messages_read_own" ON storage.objects;
DROP POLICY IF EXISTS "voice_messages_upload_own" ON storage.objects;
DROP POLICY IF EXISTS "voice_messages_update_own" ON storage.objects;
DROP POLICY IF EXISTS "voice_messages_delete_own" ON storage.objects;

CREATE POLICY "authenticated_read_voice_messages"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'voice-messages'::text);

CREATE POLICY "authenticated_upload_voice_messages"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'voice-messages'::text);

CREATE POLICY "authenticated_update_voice_messages"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'voice-messages'::text);

CREATE POLICY "authenticated_delete_voice_messages"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'voice-messages'::text);
