-- Migration 20260504000051 - volet 5, lot E : notification "Offre non retenue" par la base
-- (decision du porteur du 14/10/2026)
--
-- Constat : la notification aux chauffeurs non retenus etait envoyee par
-- l'application, avec un mauvais identifiant (fiche chauffeur au lieu du
-- profil) ; quand le chauffeur retenu confirmait en dernier, il ne voyait pas
-- les autres offres ; et la regle de la migration 049 interdit, a juste titre,
-- qu'un chauffeur notifie un autre chauffeur. Aucun chauffeur evince n'etait
-- donc jamais prevenu.
--
-- Correction : au moment ou une offre est acceptee, le trigger
-- sync_mission_on_offer_accepted (deja execute avec les droits du proprietaire
-- depuis la migration 048) depose lui-meme la notification "Offre non retenue"
-- chez chaque chauffeur dont l'offre passe a not_selected.
-- Notification visible dans la cloche ; pas d'envoi push (fait par l'application).
-- Le reste de la fonction est inchange.

CREATE OR REPLACE FUNCTION public.sync_mission_on_offer_accepted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_mission_number text;
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    UPDATE public.missions
    SET driver_id = NEW.driver_id,
        status = 'accepted',
        negotiated_price = NEW.offered_price
    WHERE id = NEW.mission_id
      AND status = 'pending'
    RETURNING mission_number INTO v_mission_number;

    -- Si la mission n'etait plus pending (ex. expiree entre-temps),
    -- l'UPDATE ci-dessus n'affecte aucune ligne : on bloque alors
    -- toute la transaction plutot que de laisser mission_offers
    -- dans un etat incoherent avec missions.
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Cette mission n''est plus disponible (statut modifie entre-temps), acceptation impossible.';
    END IF;

    -- Les autres offres passent a not_selected et leurs chauffeurs sont prevenus
    WITH losers AS (
      UPDATE public.mission_offers
      SET status = 'not_selected'
      WHERE mission_id = NEW.mission_id
        AND id != NEW.id
        AND status = 'pending'
      RETURNING driver_id
    )
    INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
    SELECT DISTINCT d.profile_id,
           'offer_update',
           'ℹ️ Offre non retenue',
           'Un autre chauffeur a été retenu pour la mission ' || coalesce(v_mission_number, '') || '.',
           jsonb_build_object('mission_id', NEW.mission_id, 'screen', 'DriverHomeScreen'),
           false
    FROM losers l
    JOIN public.drivers d ON d.id = l.driver_id
    WHERE d.profile_id IS NOT NULL;
  END IF;

  RETURN NEW;
END;
$function$;
