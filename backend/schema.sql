-- PharmaSaathi AI — Supabase schema (v2)
-- Run in: Supabase Dashboard -> SQL Editor -> New query -> paste all -> Run.
-- Safe to re-run: tables use "if not exists", policies are dropped and recreated.

create extension if not exists "pgcrypto";

-- ============= PROFILES =============
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null default 'patient' check (role in ('patient','caregiver')),
  phone text,
  lang text not null default 'en' check (lang in ('en','hi')),
  caregiver_name text,
  caregiver_phone text,
  created_at timestamptz not null default now()
);
alter table profiles add column if not exists caregiver_name text;
alter table profiles add column if not exists caregiver_phone text;

-- caregiver <-> patient links (for the future caregiver-dashboard feature)
create table if not exists caregiver_links (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  caregiver_id uuid not null references profiles(id) on delete cascade,
  can_view_schedule boolean not null default true,
  can_view_reports boolean not null default false,
  can_view_prescriptions boolean not null default true,
  created_at timestamptz not null default now(),
  unique (patient_id, caregiver_id)
);

-- ============= SHARED REFERENCE DATA =============
create table if not exists medicine_catalog (
  id text primary key,
  icon text not null default '💊',
  aliases text[] not null default '{}',       -- brand names / spellings used to match OCR text
  name_en text not null, name_hi text not null,
  use_en text not null,  use_hi text not null,
  dose_line_en text not null, dose_line_hi text not null,
  adult_dose_en text, adult_dose_hi text,
  child_dose_en text,  child_dose_hi text,
  liquid_en text, liquid_hi text,
  moa_en text, moa_hi text,
  antidote_en text, antidote_hi text,
  contraindications_en jsonb not null default '[]',
  contraindications_hi jsonb not null default '[]',
  interaction_text_en text, interaction_text_hi text
);
alter table medicine_catalog add column if not exists aliases text[] not null default '{}';

create table if not exists drug_interactions (
  id uuid primary key default gen_random_uuid(),
  drug_a text not null references medicine_catalog(id),
  drug_b text not null references medicine_catalog(id),
  severity text not null check (severity in ('warn','risk')),
  explanation_en text not null,
  explanation_hi text not null,
  check (drug_a < drug_b)
);

-- ============= PRESCRIPTIONS (separate per doctor/visit) =============
create table if not exists prescriptions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  doctor_name text,
  source text not null default 'manual' check (source in ('manual','scanned','self_reported')),
  prescribed_date date not null default current_date,
  created_at timestamptz not null default now()
);

-- one row per medicine in a prescription. medicine_id is NULL for medicines that
-- are not in the safety catalog — those are tracked (schedule/reminders) but
-- flagged in the app as "not safety-checked".
create table if not exists prescription_items (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references prescriptions(id) on delete cascade,
  patient_id uuid not null references profiles(id) on delete cascade,
  medicine_id text references medicine_catalog(id),
  custom_name text,
  custom_dose text,
  status text not null default 'active' check (status in ('active','paused','stopped','completed')),
  stopped_reason text,
  stopped_at timestamptz,
  created_at timestamptz not null default now(),
  check (medicine_id is not null or custom_name is not null)
);
alter table prescription_items alter column medicine_id drop not null;
alter table prescription_items add column if not exists custom_name text;
alter table prescription_items add column if not exists custom_dose text;

-- ============= SCHEDULE & ADHERENCE =============
create table if not exists dose_schedule (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  prescription_item_id uuid not null references prescription_items(id) on delete cascade,
  time_of_day time not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table dose_schedule add column if not exists created_at timestamptz not null default now();

create table if not exists dose_logs (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references dose_schedule(id) on delete cascade,
  patient_id uuid not null references profiles(id) on delete cascade,
  dose_date date not null default current_date,
  taken_at timestamptz,
  status text not null default 'pending' check (status in ('pending','taken','missed','skipped')),
  unique (schedule_id, dose_date)
);

-- ============= SAFETY / ADR =============
create table if not exists adr_reports (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  medicine_id text references medicine_catalog(id),
  medicine_name text,
  reaction text not null,
  severity text not null check (severity in ('mild','moderate','severe')),
  onset_note text,
  reported_via text not null default 'app',
  status text not null default 'under_review' check (status in ('under_review','reviewed')),
  created_at timestamptz not null default now()
);
alter table adr_reports alter column medicine_id drop not null;
alter table adr_reports add column if not exists medicine_name text;

create table if not exists diagnostic_reports (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  lab_name text,
  report_date date not null default current_date,
  values jsonb not null default '[]',
  note text,
  created_at timestamptz not null default now()
);

create table if not exists appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  doctor_name text not null,
  specialty text,
  place text,
  slot_at timestamptz not null,
  status text not null default 'booked' check (status in ('booked','cancelled','completed')),
  created_at timestamptz not null default now()
);

create table if not exists rewards (
  patient_id uuid primary key references profiles(id) on delete cascade,
  coins integer not null default 0,
  streak integer not null default 0,
  last_full_day date
);

-- ============= AUTO-CREATE PROFILE + REWARDS ON SIGN-UP =============
-- Runs server-side the moment an auth user is created, so it works even when
-- email confirmation is on (no session exists yet at sign-up time).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, role, lang)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'full_name',''), split_part(new.email,'@',1)),
    'patient',
    case when new.raw_user_meta_data->>'lang' in ('en','hi') then new.raw_user_meta_data->>'lang' else 'en' end
  ) on conflict (id) do nothing;
  insert into public.rewards (patient_id) values (new.id) on conflict (patient_id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============= ROW LEVEL SECURITY =============
alter table profiles enable row level security;
alter table caregiver_links enable row level security;
alter table prescriptions enable row level security;
alter table prescription_items enable row level security;
alter table dose_schedule enable row level security;
alter table dose_logs enable row level security;
alter table adr_reports enable row level security;
alter table diagnostic_reports enable row level security;
alter table appointments enable row level security;
alter table rewards enable row level security;
alter table medicine_catalog enable row level security;
alter table drug_interactions enable row level security;

drop policy if exists "catalog readable by authenticated" on medicine_catalog;
create policy "catalog readable by authenticated" on medicine_catalog for select using (auth.role() = 'authenticated');
drop policy if exists "interactions readable by authenticated" on drug_interactions;
create policy "interactions readable by authenticated" on drug_interactions for select using (auth.role() = 'authenticated');

drop policy if exists "own profile" on profiles;
create policy "own profile" on profiles for select using (id = auth.uid());
drop policy if exists "update own profile" on profiles;
create policy "update own profile" on profiles for update using (id = auth.uid());
drop policy if exists "insert own profile" on profiles;
create policy "insert own profile" on profiles for insert with check (id = auth.uid());

create or replace function is_linked_caregiver(target_patient uuid, perm text)
returns boolean language sql stable as $$
  select exists (
    select 1 from caregiver_links cl
    where cl.patient_id = target_patient and cl.caregiver_id = auth.uid()
      and ( perm = 'schedule' and cl.can_view_schedule
         or perm = 'reports' and cl.can_view_reports
         or perm = 'prescriptions' and cl.can_view_prescriptions )
  );
$$;

-- patient-owned tables: full access for the patient; read-only for a linked caregiver
drop policy if exists "patient full access" on prescriptions;
create policy "patient full access" on prescriptions for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());
drop policy if exists "caregiver read prescriptions" on prescriptions;
create policy "caregiver read prescriptions" on prescriptions for select using (is_linked_caregiver(patient_id, 'prescriptions'));

drop policy if exists "patient full access" on prescription_items;
create policy "patient full access" on prescription_items for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());
drop policy if exists "caregiver read prescription_items" on prescription_items;
create policy "caregiver read prescription_items" on prescription_items for select using (is_linked_caregiver(patient_id, 'prescriptions'));

drop policy if exists "patient full access" on dose_schedule;
create policy "patient full access" on dose_schedule for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());
drop policy if exists "caregiver read schedule" on dose_schedule;
create policy "caregiver read schedule" on dose_schedule for select using (is_linked_caregiver(patient_id, 'schedule'));

drop policy if exists "patient full access" on dose_logs;
create policy "patient full access" on dose_logs for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());
drop policy if exists "caregiver read dose_logs" on dose_logs;
create policy "caregiver read dose_logs" on dose_logs for select using (is_linked_caregiver(patient_id, 'schedule'));

drop policy if exists "patient full access" on adr_reports;
create policy "patient full access" on adr_reports for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());
drop policy if exists "caregiver read adr" on adr_reports;
create policy "caregiver read adr" on adr_reports for select using (is_linked_caregiver(patient_id, 'reports'));

drop policy if exists "patient full access" on diagnostic_reports;
create policy "patient full access" on diagnostic_reports for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());
drop policy if exists "caregiver read diagnostics" on diagnostic_reports;
create policy "caregiver read diagnostics" on diagnostic_reports for select using (is_linked_caregiver(patient_id, 'reports'));

drop policy if exists "patient full access" on appointments;
create policy "patient full access" on appointments for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());

drop policy if exists "patient full access" on rewards;
create policy "patient full access" on rewards for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());

drop policy if exists "patient manages own links" on caregiver_links;
create policy "patient manages own links" on caregiver_links for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());
drop policy if exists "caregiver sees own links" on caregiver_links;
create policy "caregiver sees own links" on caregiver_links for select using (caregiver_id = auth.uid());

-- illness / reason written on the prescription (optional)
alter table prescriptions add column if not exists diagnosis text;

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
