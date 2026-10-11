-- PharmaSaathi — start the reminder job (run ONCE, after deploying the send-reminders function)
-- Run in Supabase -> SQL Editor. Before you press Run:
--   replace  PUT-YOUR-CRON-SECRET-HERE  with the same secret text you saved as CRON_SECRET in Edge Functions -> Secrets.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- every minute the job asks the function to send any reminders that are due
select cron.schedule(
  'pharmasaathi-dose-reminders',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://snhnxfxlhcyculwqquzm.supabase.co/functions/v1/send-reminders',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', 'PUT-YOUR-CRON-SECRET-HERE'),
    body := '{}'::jsonb
  );
  $$
);

-- To stop it later:   select cron.unschedule('pharmasaathi-dose-reminders');
-- To see if it runs:  select * from cron.job_run_details order by start_time desc limit 5;
