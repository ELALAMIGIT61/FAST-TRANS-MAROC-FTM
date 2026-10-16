-- Rollback de la migration 20260504000056 (session 2.25)
-- Retablit l'etat anterieur (chemins de recherche non fixes, fonctions
-- trigger executables par anon et authenticated).

ALTER FUNCTION public.set_commission_amount()              RESET search_path;
ALTER FUNCTION public.set_mission_number()                 RESET search_path;
ALTER FUNCTION public.set_tracking_number()                RESET search_path;
ALTER FUNCTION public.calculate_commission(public.vehicle_category) RESET search_path;
ALTER FUNCTION public.generate_mission_number()            RESET search_path;
ALTER FUNCTION public.set_estimated_distance()             RESET search_path;
ALTER FUNCTION public.generate_tracking_number()           RESET search_path;
ALTER FUNCTION public.update_updated_at_column()           RESET search_path;
ALTER FUNCTION public.check_mission_offer_transition()     RESET search_path;

GRANT EXECUTE ON FUNCTION public.control_driver_availability()    TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_commission_payment()     TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sync_mission_on_offer_accepted() TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_driver_rating()           TO PUBLIC, anon, authenticated;
