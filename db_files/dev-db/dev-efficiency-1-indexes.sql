-- ============================================================
-- DEV Supabase efficiency improvements — Batch 1: Indexes
-- ============================================================
--
-- Scope: DEV project ONLY (wfytzwvohqaxyeebwhxa).
-- Do NOT run this against the PROD Supabase project.
--
-- Purely additive/subtractive index changes. No tables, columns,
-- RLS policies, or RPC functions are touched. No data is deleted.
--
-- Run each numbered section in order, in the Supabase SQL Editor.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Active work sessions (admin_active_sessions() dashboard query)
-- ------------------------------------------------------------
create index work_sessions_active_started_idx
    on public.work_sessions(started_at)
    where ended_at is null;


-- ------------------------------------------------------------
-- 2. Unverified completed sessions (admin_unverified_sessions())
-- ------------------------------------------------------------
create index work_sessions_unverified_idx
    on public.work_sessions(started_at)
    where ended_at is not null
    and verified_by is null;


-- ------------------------------------------------------------
-- 3. Open issue reports (admin_list_open_issues())
-- ------------------------------------------------------------
create index issue_reports_open_idx
    on public.issue_reports(created_at)
    where status = 'open';


-- ------------------------------------------------------------
-- 4. Open password-reset requests (admin_list_open_password_reset_requests())
-- ------------------------------------------------------------
create index password_reset_requests_open_idx
    on public.password_reset_requests(created_at)
    where status = 'open';


-- ------------------------------------------------------------
-- 5. Redundant index check + drop
-- ------------------------------------------------------------
-- work_sessions_employee_id_idx (plain btree on employee_id) is
-- redundant once work_sessions_employee_started_idx (employee_id,
-- started_at) exists, because a composite index already serves any
-- plain employee_id-only lookup via its leftmost column.
--
-- STEP A — run this SELECT first and read the output:
select indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and tablename = 'work_sessions'
order by indexname;

-- Confirm from the output above BOTH of these before continuing:
--   (a) work_sessions_employee_started_idx exists on (employee_id, started_at)
--   (b) work_sessions_employee_id_idx exists as a plain (employee_id) index
--
-- (Already confirmed separately: no application code or other SQL file
-- in this repo references the name "work_sessions_employee_id_idx".)
--
-- STEP B — only if both are confirmed present, run:
drop index if exists public.work_sessions_employee_id_idx;
