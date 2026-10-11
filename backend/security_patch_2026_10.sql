-- PharmaSaathi security patch (Oct 2026). Run ONCE in Supabase -> SQL Editor on a database set up before this date.
--
-- Problem: Supabase grants EXECUTE on new functions to the anon and authenticated roles by default.
-- care_network.sql only revoked from PUBLIC, so the two maintenance jobs below (which have no permission
-- check inside) could be called by anyone through /rest/v1/rpc using the public app key, for example
-- care_purge_old(0) would delete every verification photo immediately.
-- Fix: only the service role / scheduler may run them; anon may not run any care-network function.

revoke all on function care_expire_stale() from public, anon, authenticated;
revoke all on function care_purge_old(int) from public, anon, authenticated;

revoke all on function create_verification_request(jsonb, jsonb, jsonb, text, text, text, text, uuid) from anon;
revoke all on function cancel_verification(uuid) from anon;
revoke all on function decide_verification(uuid, text) from anon;
revoke all on function revoke_grant(uuid) from anon;
revoke all on function patient_pro_card(uuid) from anon;
revoke all on function pharmacist_queue() from anon;
revoke all on function pharmacist_accept(uuid) from anon;
revoke all on function pharmacist_answer(uuid, jsonb) from anon;
revoke all on function pharmacist_release(uuid) from anon;
revoke all on function pharmacist_can_read_image(text) from anon;
revoke all on function admin_set_professional_status(uuid, text, text, date) from anon;
revoke all on function has_grant(uuid, text, text) from anon;
revoke all on function is_verified_pro(text) from anon;
revoke all on function is_care_admin() from anon;

-- Check: both columns must be false for both rows.
select p.proname,
       has_function_privilege('anon', p.oid, 'execute')          as anon_can_run,
       has_function_privilege('authenticated', p.oid, 'execute') as signed_in_can_run
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('care_purge_old', 'care_expire_stale');
