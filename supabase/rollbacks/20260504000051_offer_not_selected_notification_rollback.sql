-- Rollback de la migration 20260504000051 (volet 5, lot E)
-- Retablit la fonction telle que laissee par la migration 048 (sans notification).

CREATE OR REPLACE FUNCTION public.sync_mission_on_offer_accepted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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
