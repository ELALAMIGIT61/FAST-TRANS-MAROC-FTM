-- Migration 20260504000015 — Correction RLS bucket voice-messages
-- Bloc 1/4 : SELECT — accès en lecture restreint au client + chauffeur de la mission

-- Rattrapage traçabilité : ce DROP a été exécuté manuellement hors circuit GitHub
-- via le SQL Editor Supabase (incident documenté au compte-rendu de session 2.14 ter).
-- IF EXISTS évite toute erreur puisque la policy n'existe déjà plus en base.
DROP POLICY IF EXISTS "authenticated_read_voice_messages" ON storage.objects;

CREATE POLICY "voice_messages_read_own"
ON storage.objects FOR SELECT
TO authenticated
USING (
  (bucket_id = 'voice-messages'::text) AND (
    ((storage.foldername(name))[2])::uuid IN (
      SELECT m.id FROM missions m
      JOIN profiles p_client ON p_client.id = m.client_id
      WHERE p_client.user_id = auth.uid()
      UNION
      SELECT m.id FROM missions m
      JOIN drivers d ON d.id = m.driver_id
      JOIN profiles p_driver ON p_driver.id = d.profile_id
      WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid()
    )
  )
);

-- Bloc 2/4 : INSERT — upload restreint au client + chauffeur de la mission

DROP POLICY IF EXISTS "authenticated_upload_voice_messages" ON storage.objects;

CREATE POLICY "voice_messages_upload_own"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  (bucket_id = 'voice-messages'::text) AND (
    ((storage.foldername(name))[2])::uuid IN (
      SELECT m.id FROM missions m
      JOIN profiles p_client ON p_client.id = m.client_id
      WHERE p_client.user_id = auth.uid()
      UNION
      SELECT m.id FROM missions m
      JOIN drivers d ON d.id = m.driver_id
      JOIN profiles p_driver ON p_driver.id = d.profile_id
      WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid()
    )
  )
);

-- Bloc 3/4 : UPDATE — modification restreinte au client + chauffeur de la mission

DROP POLICY IF EXISTS "authenticated_update_voice_messages" ON storage.objects;

CREATE POLICY "voice_messages_update_own"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  (bucket_id = 'voice-messages'::text) AND (
    ((storage.foldername(name))[2])::uuid IN (
      SELECT m.id FROM missions m
      JOIN profiles p_client ON p_client.id = m.client_id
      WHERE p_client.user_id = auth.uid()
      UNION
      SELECT m.id FROM missions m
      JOIN drivers d ON d.id = m.driver_id
      JOIN profiles p_driver ON p_driver.id = d.profile_id
      WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid()
    )
  )
);

-- Bloc 4/4 : DELETE — suppression restreinte au client + chauffeur de la mission

DROP POLICY IF EXISTS "authenticated_delete_voice_messages" ON storage.objects;

CREATE POLICY "voice_messages_delete_own"
ON storage.objects FOR DELETE
TO authenticated
USING (
  (bucket_id = 'voice-messages'::text) AND (
    ((storage.foldername(name))[2])::uuid IN (
      SELECT m.id FROM missions m
      JOIN profiles p_client ON p_client.id = m.client_id
      WHERE p_client.user_id = auth.uid()
      UNION
      SELECT m.id FROM missions m
      JOIN drivers d ON d.id = m.driver_id
      JOIN profiles p_driver ON p_driver.id = d.profile_id
      WHERE m.driver_id IS NOT NULL AND p_driver.user_id = auth.uid()
    )
  )
);
