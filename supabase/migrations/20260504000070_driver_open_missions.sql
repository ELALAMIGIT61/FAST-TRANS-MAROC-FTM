-- Migration 20260504000070 - point A1, F2 : ecran « Missions disponibles »
-- du chauffeur (accord du porteur du 28/10/2026 : option B, avec fonction
-- serveur)
--
-- Constat : une nouvelle mission n'apparait au chauffeur que dans la fenetre
-- de 60 secondes (application ouverte) ou par la notification « Nouvelle
-- mission ». S'il la manque, il ne peut plus la retrouver.
--
-- Regles validees :
-- - partie 1 « Missions ouvertes » : les missions en attente auxquelles le
--   chauffeur peut encore faire une offre, avec EXACTEMENT les regles de la
--   notification « Nouvelle mission » (migrations 066 et 068) : meme
--   categorie, documents verifies, compte actif, « disponible », dans le
--   rayon de diffusion, non bloque par la regle des ecarts (migration 064) ;
--   en plus : heure de prise en charge pas encore passee, et pas deja une
--   offre en attente de ce chauffeur sur la mission (elle est en partie 2) ;
-- - partie 2 « Mes offres en cours » : les offres en attente du chauffeur
--   connecte, visibles meme quand il est « hors service » (decision 2) ;
-- - aucune information sur le client n'est renvoyee.
--
-- 1. Fonction driver_open_missions() : partie 1 (son nombre sert aussi au
--    bouton « Missions disponibles (N) », decision 3).
-- 2. Fonction driver_pending_offers() : partie 2.
-- Le chauffeur est toujours celui de la session (auth.uid()) : aucun
-- parametre, un chauffeur ne peut pas lire la liste d'un autre.
-- Lecture seule : aucune table creee, aucune donnee modifiee.

-- 1. Missions ouvertes pour le chauffeur connecte
CREATE OR REPLACE FUNCTION public.driver_open_missions()
RETURNS TABLE (
  id uuid,
  mission_number varchar,
  mission_type public.mission_type,
  vehicle_category public.vehicle_category,
  pickup_address text,
  pickup_city varchar,
  dropoff_address text,
  dropoff_city varchar,
  scheduled_pickup_time timestamptz,
  estimated_distance_km numeric,
  needs_loading_help boolean,
  commission_amount numeric,
  cargo_weight_kg numeric,
  cargo_volume_m3 numeric,
  description text,
  status public.mission_status,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT m.id, m.mission_number, m.mission_type, m.vehicle_category,
         m.pickup_address, m.pickup_city, m.dropoff_address, m.dropoff_city,
         m.scheduled_pickup_time, m.estimated_distance_km, m.needs_loading_help,
         m.commission_amount, m.cargo_weight_kg, m.cargo_volume_m3,
         m.description, m.status, m.created_at
  FROM drivers d
  JOIN profiles p ON p.id = d.profile_id
  JOIN missions m ON m.vehicle_category = d.vehicle_category
  WHERE p.user_id = auth.uid()
    AND d.is_verified = true
    AND d.is_available = true
    AND p.is_active = true
    AND m.status = 'pending'
    AND m.scheduled_pickup_time > now()
    AND m.client_id IS DISTINCT FROM d.profile_id
    AND public.mission_in_driver_range(d.id, m.id)
    AND NOT public.driver_schedule_conflict(d.id, m.id)
    AND NOT EXISTS (
      SELECT 1 FROM mission_offers o
      WHERE o.mission_id = m.id AND o.driver_id = d.id AND o.status = 'pending'
    )
  ORDER BY m.scheduled_pickup_time ASC;
$function$;

REVOKE EXECUTE ON FUNCTION public.driver_open_missions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.driver_open_missions() TO authenticated;

-- 2. Offres en attente du chauffeur connecte
CREATE OR REPLACE FUNCTION public.driver_pending_offers()
RETURNS TABLE (
  offer_id uuid,
  mission_id uuid,
  offered_price numeric,
  round_number integer,
  client_accepted boolean,
  driver_accepted boolean,
  offer_updated_at timestamptz,
  mission_number varchar,
  vehicle_category public.vehicle_category,
  pickup_address text,
  pickup_city varchar,
  dropoff_address text,
  dropoff_city varchar,
  scheduled_pickup_time timestamptz,
  cargo_weight_kg numeric,
  cargo_volume_m3 numeric,
  commission_amount numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT o.id, o.mission_id, o.offered_price, o.round_number,
         o.client_accepted, o.driver_accepted, o.updated_at,
         m.mission_number, m.vehicle_category,
         m.pickup_address, m.pickup_city, m.dropoff_address, m.dropoff_city,
         m.scheduled_pickup_time, m.cargo_weight_kg, m.cargo_volume_m3,
         m.commission_amount
  FROM drivers d
  JOIN profiles p ON p.id = d.profile_id
  JOIN mission_offers o ON o.driver_id = d.id
  JOIN missions m ON m.id = o.mission_id
  WHERE p.user_id = auth.uid()
    AND o.status = 'pending'
    AND m.status = 'pending'
  ORDER BY m.scheduled_pickup_time ASC;
$function$;

REVOKE EXECUTE ON FUNCTION public.driver_pending_offers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.driver_pending_offers() TO authenticated;
