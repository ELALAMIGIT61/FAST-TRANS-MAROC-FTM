-- Rollback migration 20260504000020
-- Session 2.14 quinquies bis
--
-- ATTENTION : ne pas executer sans raison documentee et validee par
-- le porteur - reintroduit la faille de securite corrigee (lecture
-- non authentifiee possible sur la table drivers via la policy RLS
-- drivers_select_available, combinee a l'acces anon restaure).
--
-- Restaure l'acces SELECT du role anon sur la table drivers, tel
-- qu'il existait avant la migration 20260504000020.

GRANT SELECT ON drivers TO anon;
