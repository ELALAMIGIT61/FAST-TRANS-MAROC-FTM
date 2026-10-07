-- Migration 20260504000036 - Volet 4b-1 : champs manquants pour le controle des documents
-- 1. vehicle_registration_expiry : date d'expiration de la carte grise (omission confirmee).
--    Les 3 autres documents (permis, assurance, visite technique) ont deja leur date d'expiration.
-- 2. vehicle_first_service_date : date de 1ere mise en service du vehicule.
--    Necessaire pour la regle metier : visite technique exigee seulement si vehicule > 5 ans.
-- Les deux colonnes sont nullable (les chauffeurs existants n'ont pas ces valeurs ;
-- elles seront renseignees lors du prochain depot/remplacement de document, validees par l'admin).

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS vehicle_registration_expiry date,
  ADD COLUMN IF NOT EXISTS vehicle_first_service_date date;
