-- ============================================================
-- DEV Supabase efficiency improvements — Batch 2: Length audit
-- ============================================================
--
-- Scope: DEV project ONLY (wfytzwvohqaxyeebwhxa). Read-only —
-- this makes no changes, just reports current data sizes.
--
-- Run this in the Supabase SQL Editor, then send the result rows
-- back so the proposed CHECK constraints can be confirmed safe
-- before anything is added.
-- ============================================================

select
    'profiles.full_name'                        as column_name,
    max(length(full_name))                      as max_length,
    150                                          as proposed_limit
from public.profiles

union all
select
    'profiles.employee_id',
    max(length(employee_id)),
    32
from public.profiles

union all
select
    'workplaces.name',
    max(length(name)),
    120
from public.workplaces

union all
select
    'work_sessions.manual_location_name',
    max(length(manual_location_name)),
    120
from public.work_sessions

union all
select
    'work_sessions.end_manual_location_name',
    max(length(end_manual_location_name)),
    120
from public.work_sessions

union all
select
    'work_sessions.notes',
    max(length(notes)),
    500
from public.work_sessions

union all
select
    'audit_logs.reason',
    max(length(reason)),
    500
from public.audit_logs

order by column_name;
