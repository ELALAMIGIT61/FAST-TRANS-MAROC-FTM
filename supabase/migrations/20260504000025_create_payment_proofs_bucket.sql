-- Migration 20260504000025 -- Session 2.17, Point 11
-- Nouveau bucket dedie aux justificatifs de paiement (recharge par virement,
-- Wafacash, Cash Plus, etc.) -- distinct de driver-documents (identite/legal)
-- et voice-messages (audio), conformement a la decision de conception
-- actee en Partie 1 (aucun bucket existant n'est reutilise tel quel).
--
-- Convention de chemin : {driver_id}/{timestamp}.{ext} -- meme structure
-- que driver-documents, indice [1] du chemin utilise pour la chaine de
-- propriete dans les policies.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'payment-proofs',
  'payment-proofs',
  false,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'application/pdf']
);

-- RLS -- patron repris de driver-documents (get_my_role(), plus robuste
-- que l'ancien EXISTS utilise pour voice-messages)

CREATE POLICY "drivers_read_own_payment_proofs"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'payment-proofs'
  AND (
    get_my_role() = 'admin'
    OR (storage.foldername(name))[1]::uuid IN (
      SELECT d.id FROM drivers d
      JOIN profiles p ON p.id = d.profile_id
      WHERE p.user_id = auth.uid()
    )
  )
);

CREATE POLICY "drivers_upload_own_payment_proofs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'payment-proofs'
  AND (
    get_my_role() = 'admin'
    OR (storage.foldername(name))[1]::uuid IN (
      SELECT d.id FROM drivers d
      JOIN profiles p ON p.id = d.profile_id
      WHERE p.user_id = auth.uid()
    )
  )
);

-- Pas de policy UPDATE/DELETE cote chauffeur : un justificatif de paiement
-- deja soumis ne doit pas pouvoir etre modifie ou retire par le chauffeur
-- une fois envoye (integrite de la preuve pour l'admin). Seul l'admin
-- (get_my_role() = 'admin') peut supprimer, si necessaire en maintenance.

CREATE POLICY "admin_delete_payment_proofs"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'payment-proofs'
  AND get_my_role() = 'admin'
);
