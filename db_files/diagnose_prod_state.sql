-- Read-only diagnostic. Run in the Supabase SQL editor against PROD.
-- Tells you exactly which post-2026-09-08 changes are missing.

-- 1) Are the two functions added on 2026-09-17 present?
select
    'admin_workplace_sessions_for_month' as check_name,
    exists (
        select 1 from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'admin_workplace_sessions_for_month'
    ) as exists_in_prod
union all
select
    'admin_monthly_active_employees',
    exists (
        select 1 from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'admin_monthly_active_employees'
    );

-- 2) Current length limit on password_reset_requests.message
--    Should read "<= 50" if the 2026-09-12 change is applied, "<= 200" if not.
select
    conname,
    pg_get_constraintdef(oid) as definition
from pg_constraint
where conname = 'password_reset_requests_message_length';

-- 3) Sanity check: confirm the table/columns this all depends on actually exist
--    (should return true; if false, something more basic is off and stop here)
select exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'password_reset_requests'
) as password_reset_requests_table_exists;
