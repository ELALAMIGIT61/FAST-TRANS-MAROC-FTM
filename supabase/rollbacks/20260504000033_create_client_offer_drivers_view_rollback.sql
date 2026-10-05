-- Rollback 20260504000033
-- Supprime la vue client des chauffeurs ayant fait une offre.
-- Sans danger : la vue ne fait qu'exposer des donnees non sensibles de maniere filtree ;
-- la supprimer retire une fonctionnalite, ne reouvre aucune faille.
-- A n'utiliser que si l'ecran client qui la consomme est aussi retire.

DROP VIEW IF EXISTS public.client_offer_drivers;
