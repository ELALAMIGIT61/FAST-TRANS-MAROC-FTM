-- Migration 20260504000046 - volet 5, lot B : droits sur les fonctions
-- (decisions du porteur du 13/10/2026 : B1, B2, B3, B4 option b)
--
-- Inventaire du 13/10/2026 : 25 fonctions dans public (hors extensions),
-- 9 appelables et 16 fonctions de trigger (non appelables directement).
--
-- B1. Chemin de recherche fixe sur les deux fonctions SECURITY DEFINER
--     anciennes qui n'en avaient pas : find_nearby_drivers et get_my_role.
--     PostGIS est installe dans public (verifie) : 'public', 'pg_temp' suffit.
--     Contenu des fonctions et droits d'execution inchanges (ALTER, pas de
--     CREATE OR REPLACE).
-- B2. driver_has_expired_documents : retrait du droit EXECUTE a PUBLIC (point
--     ouvert du volet 4b-3). Seuls l'utilisent des fonctions SECURITY DEFINER
--     (control_driver_availability, block_drivers_with_expired_documents),
--     executees avec les droits du proprietaire. Migration distincte de toute
--     (re)creation de la fonction (lecon B.8 : droits par defaut du schema).
-- B3. Aucun changement sur les fonctions de trigger ni sur les fonctions de
--     calcul/generation utilisees par les triggers de creation.
-- B4. Droits par defaut du schema conserves ; regle de travail : apres toute
--     migration qui cree une fonction, relancer l'inventaire des droits et
--     fermer explicitement ce qui doit l'etre.

-- B1
ALTER FUNCTION public.find_nearby_drivers(text, integer, vehicle_category) SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.get_my_role() SET search_path TO 'public', 'pg_temp';

-- B2
REVOKE EXECUTE ON FUNCTION public.driver_has_expired_documents(uuid) FROM PUBLIC, anon, authenticated;
