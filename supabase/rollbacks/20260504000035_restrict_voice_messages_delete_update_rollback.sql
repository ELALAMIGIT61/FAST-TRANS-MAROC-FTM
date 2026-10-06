-- Rollback 20260504000035
-- ATTENTION : executer ce fichier REINTRODUIT la possibilite pour un participant
-- d'effacer ou de modifier les messages vocaux de l'AUTRE partie, a tout moment.
-- A n'utiliser qu'en cas de regression bloquante, sur decision explicite du porteur.
-- Recree les policies UPDATE et DELETE telles qu'avant la migration 035.

CREATE POLICY voice_messages_update_own ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    (bucket_id = 'voice-messages'::text) AND (((storage.foldername(name))[2])::uuid IN (
      SELECT m.id FROM (missions m JOIN profiles p_client ON ((p_client.id = m.client_id))) WHERE (p_client.user_id = auth.uid())
      UNION
      SELECT m.id FROM ((missions m JOIN drivers d ON ((d.id = m.driver_id))) JOIN profiles p_driver ON ((p_driver.id = d.profile_id))) WHERE ((m.driver_id IS NOT NULL) AND (p_driver.user_id = auth.uid()))
    ))
  );

DROP POLICY IF EXISTS voice_messages_delete_own ON storage.objects;

CREATE POLICY voice_messages_delete_own ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    (bucket_id = 'voice-messages'::text) AND (((storage.foldername(name))[2])::uuid IN (
      SELECT m.id FROM (missions m JOIN profiles p_client ON ((p_client.id = m.client_id))) WHERE (p_client.user_id = auth.uid())
      UNION
      SELECT m.id FROM ((missions m JOIN drivers d ON ((d.id = m.driver_id))) JOIN profiles p_driver ON ((p_driver.id = d.profile_id))) WHERE ((m.driver_id IS NOT NULL) AND (p_driver.user_id = auth.uid()))
    ))
  );
