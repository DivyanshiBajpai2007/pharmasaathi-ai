-- PharmaSaathi — full record of every dose (safe to run more than once)
-- Run in Supabase -> SQL Editor. Without it the app still works; only the extra detail is not kept.

-- 1) the dose row now also remembers WHEN it was confirmed (empty = only marked early, not yet confirmed) and a note
alter table dose_logs add column if not exists confirmed_at timestamptz;
alter table dose_logs add column if not exists confirm_note text;

-- 2) append-only history: every mark / confirm / undo / correction is a new row, nothing is overwritten
create table if not exists dose_events (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  schedule_id uuid not null references dose_schedule(id) on delete cascade,
  dose_date date not null default current_date,
  event text not null check (event in ('marked_taken_early','confirmed_taken','reopened','undone','corrected_not_taken','missed','cancelled')),
  note text,
  event_at timestamptz not null default now()
);
create index if not exists dose_events_patient_idx on dose_events (patient_id, dose_date);
alter table dose_events enable row level security;
drop policy if exists "patient reads own dose events" on dose_events;
create policy "patient reads own dose events" on dose_events for select using (patient_id = auth.uid());
drop policy if exists "patient adds own dose events" on dose_events;
create policy "patient adds own dose events" on dose_events for insert with check (patient_id = auth.uid());
-- (no update / delete policy on purpose: the history cannot be edited from the app)
