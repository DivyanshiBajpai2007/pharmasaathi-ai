-- PharmaSaathi — keep the illness / reason written on a prescription (safe to run more than once)
-- Run in Supabase -> SQL Editor. Without it the app still works; the doctor name is saved,
-- and the illness is shown in the current session only.
alter table prescriptions add column if not exists diagnosis text;
