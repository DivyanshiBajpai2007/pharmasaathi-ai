-- PharmaSaathi — CARE NETWORK FOUNDATION (safe to run more than once)
-- Run in Supabase -> SQL Editor.
--
-- One engine underneath every kind of sharing:
--   grants                 who may see which of a patient's data, for what purpose, until when, and whether it was revoked
--   verification_requests  the WORK to be done (e.g. "please read this unclear medicine"), kept separate from the access grant
--   access_logs            every access is written here, by the server, never by the app
--   professionals          pharmacists / doctors; only status = 'verified' accounts can do anything
--   care_admins            people who may verify or suspend professionals (you)
--
-- Security rule: a professional can NEVER read patient tables directly. They call the functions below, which check
-- "verified? request open? accepted by me? not expired?", write the access log, and only then return data.
-- The shared queue shows language / region / time only — the prescription is released only after a verified pharmacist accepts.

-- ============================================================ people
create table if not exists organisations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null check (kind in ('pharmacy','clinic','hospital')),
  region text,
  status text not null default 'pending' check (status in ('pending','verified','suspended','rejected')),
  created_at timestamptz not null default now()
);

create table if not exists professionals (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('pharmacist','doctor')),
  full_name text not null,
  org_id uuid references organisations(id),
  registration_no text,
  council text,
  region text,
  languages text[] not null default array['en'],
  available boolean not null default true,
  status text not null default 'pending' check (status in ('pending','verified','suspended','rejected')),
  verified_at timestamptz,
  verified_by uuid,
  verified_until date,                       -- re-check date (registrations renew); after it the account stops working
  created_at timestamptz not null default now()
);

create table if not exists care_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists admin_decisions (
  id uuid primary key default gen_random_uuid(),
  subject_type text not null check (subject_type in ('professional','organisation')),
  subject_id uuid not null,
  decision text not null,
  note text,
  decided_by uuid,
  decided_at timestamptz not null default now()
);

-- pharmacists added earlier by hand (pharmacist_reviews.sql) stay trusted
do $$
begin
  if to_regclass('public.pharmacists') is not null then
    insert into professionals (user_id, role, full_name, status, verified_at)
    select p.user_id, 'pharmacist', 'Pharmacist', 'verified', now() from pharmacists p
    on conflict (user_id) do nothing;
  end if;
end $$;

-- ============================================================ grants (the one consent / access record)
create table if not exists grants (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  grantee_id uuid not null references auth.users(id) on delete cascade,
  grantee_type text not null check (grantee_type in ('pharmacist','doctor','family_helper','caregiver')),
  purpose text not null check (purpose in ('prescription_verification','medication_support','patient_care','caregiver_support')),
  scope text[] not null,                     -- e.g. {prescription,current_medications,allergies}
  resource_type text,                        -- what it is tied to, e.g. 'verification_request'
  resource_id uuid,
  status text not null default 'active' check (status in ('pending','active','completed','expired','revoked')),
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  created_by uuid,
  revoked_by uuid
);
create index if not exists grants_patient_idx on grants (patient_id, status);
create index if not exists grants_grantee_idx on grants (grantee_id, status);

-- ============================================================ verification requests (the work)
create table if not exists verification_requests (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'waiting' check (status in ('waiting','accepted','answered','expired','cancelled')),
  language text not null default 'en' check (language in ('en','hi')),
  region text,
  target_pro uuid references professionals(user_id),          -- a connected pharmacist chosen by the patient; null = shared queue
  image_path text,                                            -- private storage object: <patient id>/<file>
  ai_reading jsonb not null,                                  -- what the AI read (kept as the original, never overwritten)
  question jsonb,                                             -- which items are unclear
  context jsonb not null default '{}'::jsonb,                 -- snapshot for safety: {"current_medicines":[...],"allergies":[...]}
  age_group text check (age_group in ('child','adult','older')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  accepted_by uuid references professionals(user_id),
  accepted_at timestamptz,
  answer jsonb,                                               -- {"type":"read_as|unable|clearer_photo","items":[{"index":2,"read_as":"..."}],"note":""}
  answered_at timestamptz,
  patient_decision text check (patient_decision in ('added','declined')),
  patient_decided_at timestamptz,
  check (octet_length(ai_reading::text) <= 30000),
  check (octet_length(context::text) <= 30000)
);
create index if not exists vr_patient_idx on verification_requests (patient_id, status);
create index if not exists vr_queue_idx on verification_requests (status, expires_at);

create table if not exists access_logs (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null,
  actor_id uuid,
  actor_role text,
  request_id uuid,
  grant_id uuid,
  action text not null,                                       -- create / accept / view / answer / release / cancel / revoke / expire ...
  resource_type text,
  at timestamptz not null default now()
);
create index if not exists access_logs_patient_idx on access_logs (patient_id, at desc);

-- ============================================================ row level security
alter table organisations enable row level security;
alter table professionals enable row level security;
alter table care_admins enable row level security;
alter table admin_decisions enable row level security;
alter table grants enable row level security;
alter table verification_requests enable row level security;
alter table access_logs enable row level security;

create or replace function is_care_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from care_admins a where a.user_id = auth.uid())
$$;
create or replace function is_verified_pro(_role text default null) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from professionals p
    where p.user_id = auth.uid() and p.status = 'verified'
      and (p.verified_until is null or p.verified_until >= current_date)
      and (_role is null or p.role = _role))
$$;
-- for later features (permanent connections, doctors, family helpers): does the caller hold an active grant for this patient?
create or replace function has_grant(_patient uuid, _scope text, _type text default null) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from grants g
    where g.patient_id = _patient and g.grantee_id = auth.uid() and g.status = 'active'
      and (g.expires_at is null or g.expires_at > now()) and _scope = any(g.scope)
      and (_type is null or g.grantee_type = _type))
$$;

drop policy if exists "own professional row" on professionals;
create policy "own professional row" on professionals for select using (user_id = auth.uid() or is_care_admin());
drop policy if exists "admin reads organisations" on organisations;
create policy "admin reads organisations" on organisations for select using (is_care_admin());
drop policy if exists "admin reads admin rows" on care_admins;
create policy "admin reads admin rows" on care_admins for select using (is_care_admin());
drop policy if exists "admin reads decisions" on admin_decisions;
create policy "admin reads decisions" on admin_decisions for select using (is_care_admin());

drop policy if exists "patient or grantee reads grant" on grants;
create policy "patient or grantee reads grant" on grants for select using (patient_id = auth.uid() or grantee_id = auth.uid());
drop policy if exists "patient reads own requests" on verification_requests;
create policy "patient reads own requests" on verification_requests for select using (patient_id = auth.uid());
drop policy if exists "patient reads own access log" on access_logs;
create policy "patient reads own access log" on access_logs for select using (patient_id = auth.uid());
-- (no insert / update / delete policies on purpose: everything is written by the functions below)

grant select on organisations, professionals, care_admins, admin_decisions, grants, verification_requests, access_logs to authenticated;

-- ============================================================ patient functions
create or replace function create_verification_request(
  _ai_reading jsonb, _question jsonb, _context jsonb, _image_path text,
  _language text, _region text, _age_group text, _target uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); rid uuid; open_count int;
begin
  if me is null then raise exception 'sign_in_required' using errcode = '28000'; end if;
  if _language not in ('en','hi') then raise exception 'bad_language' using errcode = '22023'; end if;
  if _ai_reading is null or jsonb_typeof(_ai_reading) <> 'array' or jsonb_array_length(_ai_reading) = 0 or jsonb_array_length(_ai_reading) > 25 then
    raise exception 'bad_reading' using errcode = '22023';
  end if;
  if _image_path is not null and split_part(_image_path, '/', 1) <> me::text then raise exception 'bad_image_path' using errcode = '22023'; end if;
  select count(*) into open_count from verification_requests where patient_id = me and status in ('waiting','accepted');
  if open_count >= 5 then raise exception 'too_many_open_requests' using errcode = '54000'; end if;
  if _target is not null then
    -- a direct request needs a real connection: an active care-team grant with a verified pharmacist
    if not exists (select 1 from professionals p where p.user_id = _target and p.role = 'pharmacist' and p.status = 'verified')
       or not exists (select 1 from grants g where g.patient_id = me and g.grantee_id = _target and g.purpose = 'medication_support' and g.status = 'active' and (g.expires_at is null or g.expires_at > now())) then
      raise exception 'not_connected' using errcode = '42501';
    end if;
  end if;
  insert into verification_requests (patient_id, language, region, target_pro, image_path, ai_reading, question, context, age_group)
  values (me, _language, nullif(trim(_region), ''), _target, _image_path, _ai_reading, _question, coalesce(_context, '{}'::jsonb), _age_group)
  returning id into rid;
  insert into access_logs (patient_id, actor_id, actor_role, request_id, action, resource_type) values (me, me, 'patient', rid, 'create', 'verification_request');
  return rid;
end $$;

create or replace function cancel_verification(_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare r verification_requests%rowtype;
begin
  update verification_requests set status = 'cancelled' where id = _id and patient_id = auth.uid() and status in ('waiting','accepted') returning * into r;
  if not found then raise exception 'not_available' using errcode = 'P0002'; end if;
  update grants set status = 'revoked', revoked_at = now(), revoked_by = auth.uid() where resource_type = 'verification_request' and resource_id = _id and status = 'active';
  insert into access_logs (patient_id, actor_id, actor_role, request_id, action, resource_type) values (r.patient_id, auth.uid(), 'patient', _id, 'cancel', 'verification_request');
end $$;

-- the patient hears the answer and says yes / no to adding the medicine
create or replace function decide_verification(_id uuid, _decision text) returns void language plpgsql security definer set search_path = public as $$
begin
  if _decision not in ('added','declined') then raise exception 'bad_decision' using errcode = '22023'; end if;
  update verification_requests set patient_decision = _decision, patient_decided_at = now()
  where id = _id and patient_id = auth.uid() and status = 'answered' and patient_decision is null;
  if not found then raise exception 'not_available' using errcode = 'P0002'; end if;
end $$;

create or replace function revoke_grant(_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare g grants%rowtype;
begin
  update grants set status = 'revoked', revoked_at = now(), revoked_by = auth.uid()
  where id = _id and patient_id = auth.uid() and status in ('pending','active') returning * into g;
  if not found then raise exception 'not_available' using errcode = 'P0002'; end if;
  insert into access_logs (patient_id, actor_id, actor_role, grant_id, action, resource_type) values (g.patient_id, auth.uid(), 'patient', _id, 'revoke', 'grant');
end $$;

-- who answered my request (name, place, role) — only for the patient who owns it
create or replace function patient_pro_card(_request uuid) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c jsonb;
begin
  select jsonb_build_object('full_name', p.full_name, 'role', p.role, 'organisation', o.name, 'verified', (p.status = 'verified'))
    into c
  from verification_requests r join professionals p on p.user_id = r.accepted_by left join organisations o on o.id = p.org_id
  where r.id = _request and r.patient_id = auth.uid();
  return c;
end $$;

-- ============================================================ pharmacist functions
-- the waiting list: language, region and time only. No patient data.
create or replace function pharmacist_queue()
returns table (id uuid, language text, region text, created_at timestamptz, expires_at timestamptz, direct boolean, mine boolean, item_count int)
language plpgsql stable security definer set search_path = public as $$
declare p professionals%rowtype;
begin
  if not is_verified_pro('pharmacist') then raise exception 'not_allowed' using errcode = '42501'; end if;
  select * into p from professionals where user_id = auth.uid();
  return query
    select r.id, r.language, r.region, r.created_at, r.expires_at, (r.target_pro is not null), (r.accepted_by = auth.uid()),
           case when jsonb_typeof(r.ai_reading) = 'array' then jsonb_array_length(r.ai_reading) else 0 end
    from verification_requests r
    where r.expires_at > now()
      and ( (r.status = 'waiting' and p.available
              and (r.target_pro = auth.uid()
                   or (r.target_pro is null and r.language = any(p.languages)
                       and (p.region is null or r.region is null or lower(p.region) = lower(r.region)))))
         or (r.status = 'accepted' and r.accepted_by = auth.uid()) )
    order by (r.accepted_by = auth.uid()) desc nulls last, r.created_at;
end $$;

create or replace function pharmacist_accept(_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare p professionals%rowtype; r verification_requests%rowtype; fresh boolean := true;
begin
  if not is_verified_pro('pharmacist') then raise exception 'not_allowed' using errcode = '42501'; end if;
  select * into p from professionals where user_id = auth.uid();
  update verification_requests set status = 'accepted', accepted_by = auth.uid(), accepted_at = now()
  where id = _id and status = 'waiting' and expires_at > now() and p.available
    and (target_pro = auth.uid()
         or (target_pro is null and language = any(p.languages) and (p.region is null or region is null or lower(p.region) = lower(region))))
  returning * into r;
  if not found then                                          -- opening my own already-accepted request again is fine
    fresh := false;
    select * into r from verification_requests where id = _id and accepted_by = auth.uid() and status = 'accepted' and expires_at > now();
    if not found then raise exception 'not_available' using errcode = 'P0002'; end if;
  end if;
  if fresh then
    insert into grants (patient_id, grantee_id, grantee_type, purpose, scope, resource_type, resource_id, status, expires_at, created_by)
    values (r.patient_id, auth.uid(), 'pharmacist', 'prescription_verification', array['prescription','current_medications','allergies'],
            'verification_request', r.id, 'active', r.expires_at, r.patient_id);
  end if;
  insert into access_logs (patient_id, actor_id, actor_role, request_id, action, resource_type)
  values (r.patient_id, auth.uid(), 'pharmacist', r.id, case when fresh then 'accept' else 'view' end, 'verification_request');
  return jsonb_build_object('id', r.id, 'ai_reading', r.ai_reading, 'question', r.question, 'context', r.context, 'image_path', r.image_path,
                            'language', r.language, 'age_group', r.age_group, 'expires_at', r.expires_at);
end $$;

-- "read as X" / "unable to read" / "needs a clearer photo". The prescription itself is never edited; access ends at once.
create or replace function pharmacist_answer(_id uuid, _answer jsonb) returns void language plpgsql security definer set search_path = public as $$
declare r verification_requests%rowtype; t text; cleaned jsonb := '[]'::jsonb; it jsonb; nm text; idx int; note text;
begin
  if not is_verified_pro('pharmacist') then raise exception 'not_allowed' using errcode = '42501'; end if;
  select * into r from verification_requests where id = _id and accepted_by = auth.uid() and status = 'accepted' and expires_at > now();
  if not found then raise exception 'not_available' using errcode = 'P0002'; end if;
  t := _answer ->> 'type';
  if t not in ('read_as','unable','clearer_photo') then raise exception 'bad_answer' using errcode = '22023'; end if;
  if t = 'read_as' then
    if jsonb_typeof(_answer -> 'items') <> 'array' or jsonb_array_length(_answer -> 'items') not between 1 and 10 then raise exception 'bad_answer' using errcode = '22023'; end if;
    for it in select * from jsonb_array_elements(_answer -> 'items') loop
      if jsonb_typeof(it) <> 'object' or jsonb_typeof(it -> 'index') <> 'number' then raise exception 'bad_answer' using errcode = '22023'; end if;
      idx := (it ->> 'index')::int;
      nm := btrim(regexp_replace(coalesce(it ->> 'read_as', ''), '[<>]', '', 'g'));
      if idx < 0 or idx > 99 or char_length(nm) not between 2 and 80 then raise exception 'bad_answer' using errcode = '22023'; end if;
      cleaned := cleaned || jsonb_build_array(jsonb_build_object('index', idx, 'read_as', nm));
    end loop;
  end if;
  note := left(btrim(regexp_replace(coalesce(_answer ->> 'note', ''), '[<>]', '', 'g')), 200);
  update verification_requests
     set status = 'answered', answered_at = now(), answer = jsonb_build_object('type', t, 'items', cleaned, 'note', note)
   where id = _id;
  update grants set status = 'completed' where resource_type = 'verification_request' and resource_id = _id and status = 'active';
  insert into access_logs (patient_id, actor_id, actor_role, request_id, action, resource_type) values (r.patient_id, auth.uid(), 'pharmacist', _id, 'answer', 'verification_request');
end $$;

-- can't do it: hand the request back to the queue (access ends)
create or replace function pharmacist_release(_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare r verification_requests%rowtype;
begin
  if not is_verified_pro('pharmacist') then raise exception 'not_allowed' using errcode = '42501'; end if;
  update verification_requests set status = 'waiting', accepted_by = null, accepted_at = null
   where id = _id and accepted_by = auth.uid() and status = 'accepted' returning * into r;
  if not found then raise exception 'not_available' using errcode = 'P0002'; end if;
  update grants set status = 'completed' where resource_type = 'verification_request' and resource_id = _id and status = 'active';
  insert into access_logs (patient_id, actor_id, actor_role, request_id, action, resource_type) values (r.patient_id, auth.uid(), 'pharmacist', _id, 'release', 'verification_request');
end $$;

-- may the caller download the prescription photo? (used by the storage rule below)
create or replace function pharmacist_can_read_image(_path text) returns boolean language sql stable security definer set search_path = public as $$
  select is_verified_pro('pharmacist') and exists (select 1 from verification_requests r
    where r.image_path = _path and r.accepted_by = auth.uid() and r.status = 'accepted' and r.expires_at > now())
$$;

-- ============================================================ admin functions (you)
create or replace function admin_set_professional_status(_user uuid, _status text, _note text default null, _verified_until date default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_care_admin() then raise exception 'not_allowed' using errcode = '42501'; end if;
  if _status not in ('pending','verified','suspended','rejected') then raise exception 'bad_status' using errcode = '22023'; end if;
  update professionals set status = _status,
         verified_at = case when _status = 'verified' then now() else verified_at end,
         verified_by = case when _status = 'verified' then auth.uid() else verified_by end,
         verified_until = case when _status = 'verified' then _verified_until else verified_until end
   where user_id = _user;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  insert into admin_decisions (subject_type, subject_id, decision, note, decided_by) values ('professional', _user, _status, _note, auth.uid());
  if _status <> 'verified' then                              -- a suspended / rejected professional loses open work immediately
    update grants set status = 'revoked', revoked_at = now(), revoked_by = auth.uid()
     where grantee_id = _user and status = 'active' and purpose = 'prescription_verification';
    update verification_requests set status = 'waiting', accepted_by = null, accepted_at = null where accepted_by = _user and status = 'accepted';
  end if;
end $$;

-- ============================================================ expiry and retention (run by the server, not the app)
create or replace function care_expire_stale() returns jsonb language plpgsql security definer set search_path = public as $$
declare n_req int; n_grants int;
begin
  with e as (update verification_requests set status = 'expired' where status in ('waiting','accepted') and expires_at <= now() returning id, patient_id)
  insert into access_logs (patient_id, request_id, actor_role, action, resource_type) select patient_id, id, 'system', 'expire', 'verification_request' from e;
  get diagnostics n_req = row_count;
  update grants set status = 'expired' where status = 'active' and expires_at is not null and expires_at <= now();
  get diagnostics n_grants = row_count;
  return jsonb_build_object('requests', n_req, 'grants', n_grants);
end $$;

-- photos and the safety snapshot are deleted after _photo_days; the small record (AI reading + answer + who + when) is kept for the audit trail
create or replace function care_purge_old(_photo_days int default 30) returns jsonb language plpgsql security definer set search_path = public as $$
declare n int := 0; r record;
begin
  for r in select id, image_path from verification_requests
           where status in ('answered','expired','cancelled') and coalesce(answered_at, created_at) < now() - make_interval(days => _photo_days)
             and (image_path is not null or context <> '{}'::jsonb) loop
    if r.image_path is not null and to_regclass('storage.objects') is not null then
      execute 'delete from storage.objects where bucket_id = $1 and name = $2' using 'rx-verification', r.image_path;
    end if;
    update verification_requests set image_path = null, context = '{}'::jsonb where id = r.id;
    n := n + 1;
  end loop;
  return jsonb_build_object('purged', n);
end $$;

-- ============================================================ who may call what
-- Supabase grants EXECUTE on new functions to anon and authenticated by default, so revoking from
-- public alone is not enough. Revoke from all three, then grant back only what the app needs below.
-- care_expire_stale / care_purge_old are maintenance jobs: only the service role / scheduler may run them.
revoke all on function create_verification_request(jsonb, jsonb, jsonb, text, text, text, text, uuid) from public, anon, authenticated;
revoke all on function cancel_verification(uuid) from public, anon, authenticated;
revoke all on function decide_verification(uuid, text) from public, anon, authenticated;
revoke all on function revoke_grant(uuid) from public, anon, authenticated;
revoke all on function patient_pro_card(uuid) from public, anon, authenticated;
revoke all on function pharmacist_queue() from public, anon, authenticated;
revoke all on function pharmacist_accept(uuid) from public, anon, authenticated;
revoke all on function pharmacist_answer(uuid, jsonb) from public, anon, authenticated;
revoke all on function pharmacist_release(uuid) from public, anon, authenticated;
revoke all on function pharmacist_can_read_image(text) from public, anon, authenticated;
revoke all on function admin_set_professional_status(uuid, text, text, date) from public, anon, authenticated;
revoke all on function care_expire_stale() from public, anon, authenticated;
revoke all on function care_purge_old(int) from public, anon, authenticated;
revoke all on function has_grant(uuid, text, text) from public, anon, authenticated;
revoke all on function is_verified_pro(text) from public, anon, authenticated;
revoke all on function is_care_admin() from public, anon, authenticated;

grant execute on function create_verification_request(jsonb, jsonb, jsonb, text, text, text, text, uuid) to authenticated;
grant execute on function cancel_verification(uuid) to authenticated;
grant execute on function decide_verification(uuid, text) to authenticated;
grant execute on function revoke_grant(uuid) to authenticated;
grant execute on function patient_pro_card(uuid) to authenticated;
grant execute on function pharmacist_queue() to authenticated;
grant execute on function pharmacist_accept(uuid) to authenticated;
grant execute on function pharmacist_answer(uuid, jsonb) to authenticated;
grant execute on function pharmacist_release(uuid) to authenticated;
grant execute on function pharmacist_can_read_image(text) to authenticated;
grant execute on function admin_set_professional_status(uuid, text, text, date) to authenticated;
grant execute on function has_grant(uuid, text, text) to authenticated;
grant execute on function is_verified_pro(text) to authenticated;
grant execute on function is_care_admin() to authenticated;
-- care_expire_stale / care_purge_old are for the server (cron) only

-- ============================================================ private photo storage
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('rx-verification', 'rx-verification', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "patient uploads own verification photo" on storage.objects;
create policy "patient uploads own verification photo" on storage.objects for insert to authenticated
  with check (bucket_id = 'rx-verification' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "patient reads own verification photo" on storage.objects;
create policy "patient reads own verification photo" on storage.objects for select to authenticated
  using (bucket_id = 'rx-verification' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "patient deletes own verification photo" on storage.objects;
create policy "patient deletes own verification photo" on storage.objects for delete to authenticated
  using (bucket_id = 'rx-verification' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "accepting pharmacist reads the photo" on storage.objects;
create policy "accepting pharmacist reads the photo" on storage.objects for select to authenticated
  using (bucket_id = 'rx-verification' and pharmacist_can_read_image(name));

-- ============================================================ automatic expiry / retention (needs pg_cron, already enabled for reminders)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('care-expire-stale', '*/5 * * * *', 'select care_expire_stale()');
    perform cron.schedule('care-purge-old', '17 3 * * *', 'select care_purge_old(30)');
  end if;
end $$;

-- To make yourself an admin (replace with YOUR user id from Authentication -> Users):
--   insert into care_admins (user_id) values ('00000000-0000-0000-0000-000000000000');
-- To add a pharmacist you have checked (their user id from Authentication -> Users):
--   insert into professionals (user_id, role, full_name, registration_no, council, region, languages, status, verified_at, verified_until)
--   values ('<user id>', 'pharmacist', 'Full Name', 'REG-NO', 'State Pharmacy Council', 'Kanpur', array['hi','en'], 'verified', now(), current_date + 365);
