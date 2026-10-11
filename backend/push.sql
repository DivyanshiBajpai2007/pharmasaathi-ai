-- PharmaSaathi — reminders that arrive even when the app is CLOSED (safe to run more than once)
-- Run in Supabase -> SQL Editor.

-- 1) which phones want reminders (one row per phone; the person can only see / change their own)
create table if not exists push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  tz text not null default 'Asia/Kolkata',
  lang text not null default 'en',
  created_at timestamptz not null default now(),
  last_seen timestamptz not null default now()
);
alter table push_subscriptions enable row level security;
drop policy if exists "patient manages own push subscriptions" on push_subscriptions;
create policy "patient manages own push subscriptions" on push_subscriptions for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());

-- 2) how many reminders were already sent for a dose today (only the server reads / writes this: no policies on purpose)
create table if not exists push_sent (
  schedule_id uuid not null references dose_schedule(id) on delete cascade,
  dose_date date not null,
  sent_count int not null default 0,
  last_sent_at timestamptz,
  primary key (schedule_id, dose_date)
);
alter table push_sent enable row level security;
