-- Migration 20260504000052 - volet 5, lot E-bis : diffusion en direct des offres
-- (decision du porteur du 14/10/2026)
--
-- Constat : la table mission_offers ne faisait pas partie de la publication
-- supabase_realtime (migration 012 : drivers, missions, wallet, transactions,
-- notifications). L'ecran des offres, qui ecoute les offres en direct, ne
-- recevait donc jamais rien : aucune negociation ne pouvait aboutir dans
-- l'application. La diffusion respecte les regles d'acces (RLS) : chacun ne
-- recoit que les offres qu'il a le droit de voir.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'mission_offers'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.mission_offers;
  END IF;
END $$;
