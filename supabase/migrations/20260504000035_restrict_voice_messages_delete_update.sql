-- Migration 20260504000035 - Volet 4a : restriction des messages vocaux
-- Decisions metier :
--   - un message vocal ne se MODIFIE jamais (une modification = falsification) : on retire la policy UPDATE
--   - un participant ne peut SUPPRIMER que SES PROPRES messages (auteur = lui),
--     et seulement si la mission est 'completed' (paiement hors appli, pas de trace a conserver apres)
-- Lecture et depot restent inchanges (les deux participants de la mission).
-- Auteur = profileId en tete du nom de fichier (convention missions/{missionId}/{profileId}_{ts}.ext).

-- 1. Retrait de la policy UPDATE (un message vocal n'est jamais modifie)
DROP POLICY IF EXISTS voice_messages_update_own ON storage.objects;

-- 2. Remplacement de la policy DELETE : ses propres messages uniquement, mission terminee
DROP POLICY IF EXISTS voice_messages_delete_own ON storage.objects;

CREATE POLICY voice_messages_delete_own ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'voice-messages'
    AND split_part(storage.filename(name), '_', 1) IN (
      SELECT p.id::text FROM profiles p WHERE p.user_id = auth.uid()
    )
    AND ((storage.foldername(name))[2])::uuid IN (
      SELECT m.id FROM missions m WHERE m.status = 'completed'
    )
  );
