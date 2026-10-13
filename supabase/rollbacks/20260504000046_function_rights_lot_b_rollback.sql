-- Rollback de la migration 20260504000046 (volet 5, lot B)
-- Restaure : find_nearby_drivers et get_my_role sans chemin de recherche fixe,
-- droit EXECUTE a PUBLIC sur driver_has_expired_documents.
-- A executer uniquement sur decision du porteur.

ALTER FUNCTION public.find_nearby_drivers(text, integer, vehicle_category) RESET search_path;
ALTER FUNCTION public.get_my_role() RESET search_path;

GRANT EXECUTE ON FUNCTION public.driver_has_expired_documents(uuid) TO PUBLIC;
