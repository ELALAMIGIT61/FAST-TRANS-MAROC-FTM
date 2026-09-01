-- Migration 20260504000021
-- Session 2.14 sexies
-- Creation de la table mission_offers pour la negociation de prix structuree
-- (offres tour 1, contre-offre client diffusee, reponses tour 2, plafond 2 tours)

CREATE TABLE public.mission_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id uuid NOT NULL REFERENCES public.missions(id) ON DELETE CASCADE,
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  round_number integer NOT NULL DEFAULT 1 CHECK (round_number IN (1, 2)),
  offered_price numeric NOT NULL,
  -- Double validation obligatoire : l'accord n'est definitif que
  -- lorsque client_accepted ET driver_accepted valent true,
  -- quel que soit l'ordre dans lequel chaque partie a accepte.
  client_accepted boolean NOT NULL DEFAULT false,
  driver_accepted boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'not_selected')),
  message text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.mission_offers ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER update_mission_offers_updated_at
  BEFORE UPDATE ON public.mission_offers
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- RLS : SELECT/INSERT/UPDATE sur le modele voice-messages
-- (chaine de propriete client+chauffeur via auth.uid())
-- ============================================================

CREATE POLICY mission_offers_select_participants ON public.mission_offers
FOR SELECT TO authenticated
USING (
  driver_id IN (
    SELECT d.id FROM drivers d
    JOIN profiles p ON p.id = d.profile_id
    WHERE p.user_id = auth.uid()
  )
  OR mission_id IN (
    SELECT m.id FROM missions m
    JOIN profiles p ON p.id = m.client_id
    WHERE p.user_id = auth.uid()
  )
);

CREATE POLICY mission_offers_insert_driver ON public.mission_offers
FOR INSERT TO authenticated
WITH CHECK (
  driver_id IN (
    SELECT d.id FROM drivers d
    JOIN profiles p ON p.id = d.profile_id
    WHERE p.user_id = auth.uid()
  )
);

CREATE POLICY mission_offers_update_participants ON public.mission_offers
FOR UPDATE TO authenticated
USING (
  driver_id IN (
    SELECT d.id FROM drivers d
    JOIN profiles p ON p.id = d.profile_id
    WHERE p.user_id = auth.uid()
  )
  OR mission_id IN (
    SELECT m.id FROM missions m
    JOIN profiles p ON p.id = m.client_id
    WHERE p.user_id = auth.uid()
  )
)
WITH CHECK (
  driver_id IN (
    SELECT d.id FROM drivers d
    JOIN profiles p ON p.id = d.profile_id
    WHERE p.user_id = auth.uid()
  )
  OR mission_id IN (
    SELECT m.id FROM missions m
    JOIN profiles p ON p.id = m.client_id
    WHERE p.user_id = auth.uid()
  )
);

-- ============================================================
-- Trigger de controle de transition : bloque toute modification
-- de status/offered_price une fois l'offre acceptee
-- ============================================================

CREATE OR REPLACE FUNCTION public.check_mission_offer_transition()
RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
  -- Une fois l'offre definitivement conclue (statut accepted),
  -- plus aucune modification n'est permise.
  IF OLD.status = 'accepted' AND NEW.status != OLD.status THEN
    RAISE EXCEPTION 'Cette offre a deja ete acceptee, elle ne peut plus etre modifiee.';
  END IF;

  IF OLD.status = 'accepted' AND NEW.offered_price != OLD.offered_price THEN
    RAISE EXCEPTION 'Le prix d''une offre acceptee ne peut plus etre modifie.';
  END IF;

  -- Des qu'une partie a deja donne son accord (client_accepted ou
  -- driver_accepted = true), le prix ne peut plus etre modifie :
  -- seule une acceptation de l'autre partie est encore possible,
  -- pas une nouvelle contre-proposition.
  IF (OLD.client_accepted = true OR OLD.driver_accepted = true)
     AND NEW.offered_price != OLD.offered_price THEN
    RAISE EXCEPTION 'Un accord est deja en attente de confirmation, le prix ne peut plus etre modifie.';
  END IF;

  -- On ne peut pas changer le prix ET accepter dans la meme operation :
  -- accepter porte necessairement sur le prix tel qu'il etait avant
  -- cette requete, jamais sur un nouveau prix propose simultanement.
  IF NEW.offered_price != OLD.offered_price
     AND ((NEW.client_accepted = true AND NEW.client_accepted != OLD.client_accepted)
       OR (NEW.driver_accepted = true AND NEW.driver_accepted != OLD.driver_accepted)) THEN
    RAISE EXCEPTION 'Impossible de modifier le prix et accepter dans la meme operation.';
  END IF;

  -- Passage automatique au statut final des que les deux parties
  -- ont accepte.
  IF NEW.client_accepted = true AND NEW.driver_accepted = true THEN
    NEW.status := 'accepted';
  END IF;

  RETURN NEW;
END;
$function$;

CREATE TRIGGER check_mission_offer_transition_trigger
  BEFORE UPDATE ON public.mission_offers
  FOR EACH ROW
  EXECUTE FUNCTION public.check_mission_offer_transition();
