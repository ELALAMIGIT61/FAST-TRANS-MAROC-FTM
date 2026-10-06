-- Migration 20260504000034 - Bloc choix du chauffeur : fermeture de la faille de lecture des chauffeurs
-- Retire la policy drivers_select_available qui laissait TOUT utilisateur connecte lire
-- TOUS les chauffeurs verifies et disponibles (nom, telephone via profil, documents, position, etc.).
-- Le client passe desormais par la vue securisee client_offer_drivers (migration 033),
-- qui ne montre que 4 infos non sensibles des chauffeurs ayant fait une offre sur SES missions.
-- Supprime aussi le doublon "Drivers can view their own data" (identique a drivers_select_own).
-- Conservees : drivers_select_admin (admin voit tout), drivers_select_own (chauffeur voit sa ligne).
-- find_nearby_drivers n'est pas affectee (SECURITY DEFINER, ne depend pas de ces policies).

DROP POLICY IF EXISTS drivers_select_available ON public.drivers;
DROP POLICY IF EXISTS "Drivers can view their own data" ON public.drivers;
