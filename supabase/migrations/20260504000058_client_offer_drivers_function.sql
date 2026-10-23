-- Migration 20260504000058 - point A1, correction 19 : informations du chauffeur
-- visibles par le client sur l'ecran des offres (accord du porteur du 23/10/2026)
--
-- Constat (23/10/2026, test sur deux telephones) : la vue client_offer_drivers
-- (migration 033) renvoie toujours une liste vide. Elle s'execute avec les
-- droits du client (security_invoker = true), or la migration 034 a retire
-- aux clients la lecture de la table drivers. Le client ne voit donc ni la
-- categorie, ni la capacite, ni la note, ni le nombre de missions du chauffeur.
--
-- 1. Fonction get_client_offer_drivers(p_mission_id) : lit drivers avec les
--    droits du proprietaire (SECURITY DEFINER), mais ne renvoie que les
--    4 informations non sensibles prevues en 033, et uniquement pour les
--    chauffeurs ayant une offre sur une mission DU CLIENT CONNECTE
--    (filtre auth.uid()). Jamais : nom, telephone, plaque, position, documents.
-- 2. Droits : executable par les utilisateurs connectes uniquement.
-- 3. Suppression de la vue client_offer_drivers, devenue inutile.
-- Aucune table modifiee, aucune donnee ecrite, aucune policy changee.

-- 1
CREATE OR REPLACE FUNCTION public.get_client_offer_drivers(p_mission_id uuid)
RETURNS TABLE (
  offer_id            uuid,
  mission_id          uuid,
  driver_id           uuid,
  vehicle_category    public.vehicle_category,
  vehicle_capacity_kg integer,
  rating_average      numeric,
  total_missions      integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT
    mo.id,
    mo.mission_id,
    d.id,
    d.vehicle_category,
    d.vehicle_capacity_kg,
    d.rating_average,
    d.total_missions
  FROM public.mission_offers mo
  JOIN public.missions m ON m.id = mo.mission_id
  JOIN public.drivers  d ON d.id = mo.driver_id
  JOIN public.profiles p ON p.id = m.client_id
  WHERE mo.mission_id = p_mission_id
    AND p.user_id = auth.uid();
$function$;

-- 2
REVOKE EXECUTE ON FUNCTION public.get_client_offer_drivers(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_client_offer_drivers(uuid) TO authenticated;

-- 3
DROP VIEW IF EXISTS public.client_offer_drivers;
