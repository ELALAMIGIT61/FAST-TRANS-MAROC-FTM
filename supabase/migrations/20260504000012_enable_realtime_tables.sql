-- Enable Realtime on FTM tables
-- Session 2.10

ALTER PUBLICATION supabase_realtime
ADD TABLE drivers, missions, wallet,
transactions, notifications;
