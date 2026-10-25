-- Migration 20260504000060 - point A1, correction 28 : le serveur refuse une
-- mission dont l'heure de prise en charge est deja passee (accord du porteur
-- du 25/10/2026, sans delai minimum)
--
-- Constat (25/10/2026, test de la correction 24) : la mission FTM202610259756
-- a ete creee a 15:58 UTC avec une prise en charge a 15:08 UTC. L'horloge du
-- telephone du client etait decalee d'une heure (base de fuseaux horaires non
-- mise a jour apres le retour du Maroc a l'heure GMT le 20/09/2026) ; seule
-- l'application verifiait l'heure, avec cette horloge fausse. La mission a ete
-- expiree au premier passage de la tache 059.
--
-- 1. Trigger reject_past_pickup_time (avant insertion d'une mission) : refuse
--    une heure de prise en charge anterieure a l'heure du serveur, avec un
--    message lisible affiche tel quel par l'application.
-- Seule la creation est controlee : les mises a jour (acceptation, expiration,
-- fin de mission) ne sont pas concernees. Aucune donnee existante modifiee.

CREATE OR REPLACE FUNCTION public.reject_past_pickup_time()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.scheduled_pickup_time IS NOT NULL AND NEW.scheduled_pickup_time < now() THEN
    RAISE EXCEPTION 'L''heure de prise en charge est déjà passée. Vérifiez la date et l''heure de votre téléphone.'
      USING ERRCODE = '22007';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.reject_past_pickup_time() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS reject_past_pickup_time ON public.missions;
CREATE TRIGGER reject_past_pickup_time
  BEFORE INSERT ON public.missions
  FOR EACH ROW
  EXECUTE FUNCTION public.reject_past_pickup_time();
