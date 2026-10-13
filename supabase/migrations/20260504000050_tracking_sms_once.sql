-- Migration 20260504000050 - volet 5, lot D-bis etape 2 : un seul SMS de suivi par colis
-- (decision du porteur du 13/10/2026 : option (a))
--
-- La fonction serveur send-tracking-sms reserve l'envoi en renseignant
-- tracking_sms_sent_at (uniquement si la colonne est vide) ; toute nouvelle
-- demande pour le meme colis est refusee. Si l'envoi echoue ou si aucun
-- fournisseur SMS n'est configure, la colonne est remise a vide.
-- Seule la fonction serveur (cle de service) ecrit cette colonne : aucune regle
-- n'autorise la modification d'un colis par un utilisateur.

ALTER TABLE public.ecommerce_parcels
  ADD COLUMN IF NOT EXISTS tracking_sms_sent_at TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN public.ecommerce_parcels.tracking_sms_sent_at IS
  'Date d''envoi du SMS de suivi au destinataire (un seul SMS par colis) - volet 5 lot D-bis';
