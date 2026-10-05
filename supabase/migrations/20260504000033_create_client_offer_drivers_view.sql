-- Migration 20260504000033 - Bloc choix du chauffeur : vue client securisee
-- Vue montrant au client, pour chaque chauffeur AYANT UNE OFFRE sur une de SES missions,
-- uniquement 4 informations non sensibles : categorie, capacite, note, nombre de missions.
-- Aucune donnee identifiante ou sensible (ni nom, ni telephone, ni plaque, ni position, ni documents).
-- security_invoker = true : la vue s'execute avec les droits du client qui la consulte,
-- donc le filtrage "mes offres uniquement" s'appuie sur auth.uid().

CREATE OR REPLACE VIEW public.client_offer_drivers
WITH (security_invoker = true)
AS
SELECT
  mo.id          AS offer_id,
  mo.mission_id  AS mission_id,
  d.id           AS driver_id,
  d.vehicle_category,
  d.vehicle_capacity_kg,
  d.rating_average,
  d.total_missions
FROM mission_offers mo
JOIN missions m  ON m.id = mo.mission_id
JOIN drivers d   ON d.id = mo.driver_id
JOIN profiles p  ON p.id = m.client_id
WHERE p.user_id = auth.uid();

-- La vue est lisible par les utilisateurs connectes ; le filtre auth.uid() garantit
-- que chacun ne voit que les chauffeurs ayant fait une offre sur SES propres missions.
GRANT SELECT ON public.client_offer_drivers TO authenticated;
