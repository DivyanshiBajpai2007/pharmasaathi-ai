-- PharmaSaathi — pharmacist verification queue (safe to run more than once)
-- Run this in Supabase -> SQL Editor. It ONLY adds two new tables; it does not touch your existing data.
--
-- How it is used:
--  * When the AI review finds something to verify, the patient can "Send to pharmacist".
--    That inserts a row here with status 'pending'.
--  * A pharmacist (a user listed in the `pharmacists` table) reads pending rows and updates them
--    to 'verified' / 'changed' / 'rejected' with a note. Until a pharmacist portal exists, you can do
--    this by hand in Table Editor -> pharmacist_reviews.
--  * The patient sees the status and note in the app.
--
-- To make someone a pharmacist reviewer, insert their auth user id into `pharmacists`:
--   insert into pharmacists (user_id) values ('<the user''s uuid from Authentication -> Users>');

create table if not exists pharmacists (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists pharmacist_reviews (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  age_group text not null check (age_group in ('child','adult','older')),
  medicines jsonb not null,            -- what the scan read: name, strength, amount, times per day, duration
  findings jsonb not null,             -- PharmaSaathi's own checks + the AI draft's concerns (unverified)
  status text not null default 'pending' check (status in ('pending','verified','changed','rejected')),
  pharmacist_id uuid references auth.users(id),
  pharmacist_note text,
  reviewed_at timestamptz
);
create index if not exists pharmacist_reviews_status_idx on pharmacist_reviews (status, created_at);
create index if not exists pharmacist_reviews_patient_idx on pharmacist_reviews (patient_id, created_at desc);

alter table pharmacists enable row level security;
alter table pharmacist_reviews enable row level security;

drop policy if exists "pharmacist sees own row" on pharmacists;
create policy "pharmacist sees own row" on pharmacists for select using (user_id = auth.uid());

-- a patient can add a review for themselves (always starting as pending) and read their own
drop policy if exists "patient adds own review" on pharmacist_reviews;
create policy "patient adds own review" on pharmacist_reviews for insert
  with check (patient_id = auth.uid() and status = 'pending' and pharmacist_id is null and pharmacist_note is null);
drop policy if exists "patient reads own review" on pharmacist_reviews;
create policy "patient reads own review" on pharmacist_reviews for select using (patient_id = auth.uid());

-- pharmacists can read every review and answer it
drop policy if exists "pharmacist reads all reviews" on pharmacist_reviews;
create policy "pharmacist reads all reviews" on pharmacist_reviews for select
  using (exists (select 1 from pharmacists p where p.user_id = auth.uid()));
drop policy if exists "pharmacist answers reviews" on pharmacist_reviews;
create policy "pharmacist answers reviews" on pharmacist_reviews for update
  using (exists (select 1 from pharmacists p where p.user_id = auth.uid()))
  with check (exists (select 1 from pharmacists p where p.user_id = auth.uid()));
