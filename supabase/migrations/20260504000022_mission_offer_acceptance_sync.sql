-- Migration 20260504000022
-- Session 2.14 sexies
-- Synchronisation automatique missions <- mission_offers lors de
-- l'acceptation finale d'une offre (les deux parties ont accepte).
-- Sur le modele du trigger update_driver_rating (mise a jour croisee
-- entre tables suite a une transition de statut).

CREATE OR REPLACE FUNCTION public.sync_mission_on_offer_accepted()
RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    UPDATE public.missions
    SET driver_id = NEW.driver_id,
        status = 'accepted',
        negotiated_price = NEW.offered_price
    WHERE id = NEW.mission_id
      AND status = 'pending';

    -- Si la mission n'etait plus pending (ex. expiree entre-temps),
    -- l'UPDATE ci-dessus n'affecte aucune ligne : on bloque alors
    -- toute la transaction plutot que de laisser mission_offers
    -- dans un etat incoherent avec missions.
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Cette mission n''est plus disponible (statut modifie entre-temps), acceptation impossible.';
    END IF;

    UPDATE public.mission_offers
    SET status = 'not_selected'
    WHERE mission_id = NEW.mission_id
      AND id != NEW.id
      AND status = 'pending';
  END IF;

  RETURN NEW;
END;
$function$;

CREATE TRIGGER sync_mission_on_offer_accepted_trigger
  AFTER UPDATE ON public.mission_offers
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_mission_on_offer_accepted();
