-- Rollback de la migration 20260504000058 (point A1, correction 19)
-- Recree la vue client_offer_drivers a l'identique de la migration 033 et
-- supprime la fonction get_client_offer_drivers. A utiliser avec la version
-- precedente de l'application (getClientOfferDrivers lisant la vue).
-- NE JAMAIS placer ce fichier dans supabase/migrations/.

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

GRANT SELECT ON public.client_offer_drivers TO authenticated;

DROP FUNCTION IF EXISTS public.get_client_offer_drivers(uuid);
