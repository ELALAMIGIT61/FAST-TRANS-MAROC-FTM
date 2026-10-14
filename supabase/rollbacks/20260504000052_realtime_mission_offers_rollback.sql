-- Rollback de la migration 20260504000052 (volet 5, lot E-bis)

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'mission_offers'
  ) THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.mission_offers;
  END IF;
END $$;
