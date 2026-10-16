-- Migration 20260504000056 - session 2.25 : avertissements du Security Advisor
-- (decision du porteur du 16/10/2026 : corriger 17 avertissements, documenter
-- les 8 autres comme acceptes)
--
-- A. function_search_path_mutable (9 avertissements) : chemin de recherche
--    fixe pour neuf fonctions qui n'en avaient pas (meme regle que le lot B du
--    volet 5). Contenu des fonctions inchange. set_estimated_distance appelle
--    calculate_distance (PostGIS) : son chemin inclut aussi extensions.
-- B. anon/authenticated_security_definer_function_executable (8 avertissements) :
--    quatre fonctions de declenchement (trigger) executees avec les droits du
--    proprietaire etaient appelables par l'API. Une fonction trigger ne peut
--    de toute facon pas etre appelee directement ; le droit d'execution est
--    retire (le declenchement automatique ne depend pas de ce droit).
--
-- Avertissements acceptes (non traites, fonctionnement voulu ou contrainte
-- de la plateforme) : get_my_role (regles d'acces), get_public_parcel_tracking
-- (suivi public d'un colis), can_notify_profile (regle des notifications),
-- find_nearby_drivers (recherche de chauffeurs), pg_net dans public
-- (contrainte Supabase), protection des mots de passe divulgues (connexion
-- par code SMS, sans mot de passe).

-- A
ALTER FUNCTION public.set_commission_amount()              SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.set_mission_number()                 SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.set_tracking_number()                SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.calculate_commission(public.vehicle_category) SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.generate_mission_number()            SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.set_estimated_distance()             SET search_path TO 'public', 'extensions', 'pg_temp';
ALTER FUNCTION public.generate_tracking_number()           SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.update_updated_at_column()           SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.check_mission_offer_transition()     SET search_path TO 'public', 'pg_temp';

-- B
REVOKE EXECUTE ON FUNCTION public.control_driver_availability()    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.process_commission_payment()     FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.sync_mission_on_offer_accepted() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_driver_rating()           FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.control_driver_availability()    TO service_role;
GRANT EXECUTE ON FUNCTION public.process_commission_payment()     TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_mission_on_offer_accepted() TO service_role;
GRANT EXECUTE ON FUNCTION public.update_driver_rating()           TO service_role;
