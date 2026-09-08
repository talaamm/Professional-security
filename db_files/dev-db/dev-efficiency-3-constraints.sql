-- ============================================================
-- DEV Supabase efficiency improvements — Batch 3: Length constraints
-- ============================================================
--
-- Scope: DEV project ONLY (wfytzwvohqaxyeebwhxa).
-- Do NOT run this against the PROD Supabase project.
--
-- Every column below was checked against dev-efficiency-2-length-audit.sql
-- results before this file was written. All 7 columns fit comfortably
-- under their proposed limit (largest actual value was 22 characters,
-- against limits of 32-500) -- none were skipped.
--
-- column                                    max_length  proposed_limit
-- profiles.full_name                        16          150
-- profiles.employee_id                      9           32
-- workplaces.name                           14          120
-- work_sessions.manual_location_name        10          120
-- work_sessions.end_manual_location_name    10          120
-- work_sessions.notes                       22          500
-- audit_logs.reason                         22          500
--
-- issue_reports.message and password_reset_requests.message are
-- deliberately NOT touched here -- already constrained (<=50, <=200)
-- and explicitly excluded from this change.
--
-- NULL values are unaffected: length(NULL) is NULL, and a CHECK
-- constraint only rejects rows where the expression evaluates to
-- FALSE, so nullable columns (manual_location_name, end_manual_location_name,
-- notes, reason) still accept NULL exactly as before.
-- ============================================================

alter table public.profiles
    add constraint profiles_full_name_length
    check (length(full_name) <= 150);

alter table public.profiles
    add constraint profiles_employee_id_length
    check (length(employee_id) <= 32);

alter table public.workplaces
    add constraint workplaces_name_length
    check (length(name) <= 120);

alter table public.work_sessions
    add constraint work_sessions_manual_location_name_length
    check (length(manual_location_name) <= 120);

alter table public.work_sessions
    add constraint work_sessions_end_manual_location_name_length
    check (length(end_manual_location_name) <= 120);

alter table public.work_sessions
    add constraint work_sessions_notes_length
    check (length(notes) <= 500);

alter table public.audit_logs
    add constraint audit_logs_reason_length
    check (length(reason) <= 500);

-- Verify afterward: should list all 7 new constraints.
select conname, conrelid::regclass as table_name, pg_get_constraintdef(oid) as definition
from pg_constraint
where conname in (
    'profiles_full_name_length',
    'profiles_employee_id_length',
    'workplaces_name_length',
    'work_sessions_manual_location_name_length',
    'work_sessions_end_manual_location_name_length',
    'work_sessions_notes_length',
    'audit_logs_reason_length'
)
order by conname;
