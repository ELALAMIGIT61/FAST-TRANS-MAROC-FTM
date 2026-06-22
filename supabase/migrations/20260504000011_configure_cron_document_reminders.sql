-- Migration 20260504000011
-- Configure CRON job for document expiry reminders
-- pg_cron + pg_net activated session 2.9
-- service_role key stored in Vault (never in code)
-- timeout_milliseconds := 30000 validated session 2.9

select cron.unschedule('check-document-reminders')
  where exists (
    select 1 from cron.job
    where jobname = 'check-document-reminders'
  );

select cron.schedule(
  'check-document-reminders',
  '0 8 * * *',
  $$
    select net.http_post(
      url := 'https://ustckqnecsilxqlyjute.supabase.co/functions/v1/check-document-reminders',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'supabase_service_role_key' limit 1)
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    );
  $$
);
