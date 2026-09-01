-- Rollback migration 20260504000021
-- Session 2.14 sexies
--
-- Supprime entierement la table mission_offers, ses policies RLS,
-- son trigger de controle de transition et la fonction associee.
-- Sans impact sur missions ou drivers (relation ON DELETE CASCADE
-- uniquement dans le sens mission_offers -> missions/drivers, pas
-- l'inverse).
--
-- ATTENTION : toute donnee de negociation en cours sera perdue de
-- facon irreversible si cette table contient deja des lignes au
-- moment de l'execution de ce rollback.

DROP TRIGGER IF EXISTS check_mission_offer_transition_trigger ON public.mission_offers;
DROP FUNCTION IF EXISTS public.check_mission_offer_transition();
DROP TABLE IF EXISTS public.mission_offers;
