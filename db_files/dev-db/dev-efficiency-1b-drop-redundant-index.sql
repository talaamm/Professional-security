-- ============================================================
-- DEV Supabase efficiency improvements — Batch 1b: Drop redundant index
-- ============================================================
--
-- Scope: DEV project ONLY (wfytzwvohqaxyeebwhxa).
--
-- All three conditions verified before this file was written:
--   (a) work_sessions_employee_started_idx exists on (employee_id, started_at)
--       -- confirmed via dev-efficiency-1-indexes.sql STEP A output
--   (b) work_sessions_employee_id_idx exists as a plain (employee_id) index
--       -- confirmed via the same output
--   (c) no application code or SQL file in this repo references the name
--       "work_sessions_employee_id_idx" -- confirmed by repo-wide search
--
-- A composite index already serves any plain employee_id-only lookup via
-- its leftmost column, so the plain index is pure dead weight (storage +
-- write overhead on every insert/update) with no query benefit.
-- ============================================================

drop index if exists public.work_sessions_employee_id_idx;

-- Verify afterward: this should now return one fewer row than before
-- (work_sessions_employee_id_idx should be gone; work_sessions_employee_started_idx
-- must still be present).
select indexname
from pg_indexes
where schemaname = 'public'
  and tablename = 'work_sessions'
order by indexname;
