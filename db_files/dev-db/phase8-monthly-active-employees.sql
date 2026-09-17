-- ============================================================
-- PHASE 8 (slice) — EMPLOYEES ACTIVE THIS MONTH
-- ============================================================
--
-- Backs the Employees tab's "Employees of This Month" expandable list
-- and its "Download List" PDF export. Only employees (role = 'employee')
-- who completed at least one work session in the current calendar month
-- are returned, alphabetical by name.
--
-- p_limit/p_offset support both callers with one function (no duplicate
-- endpoint for the same read):
--   - the paged list on screen: p_limit = 5, p_offset = 0/5/10/...
--   - the full download: p_limit left null, which Postgres treats as
--     "no limit" - every matching employee, still ordered the same way.
--
-- "This month" is computed server-side from now(), not passed in by the
-- client, so it can't be spoofed and always matches the server's clock.
-- Same is_admin()-gated SECURITY DEFINER pattern as admin_active_sessions()
-- / admin_unverified_sessions() (phase6-admin-dashboard.sql).
-- ============================================================

create or replace function public.admin_monthly_active_employees(
    p_limit integer default null,
    p_offset integer default 0
)
returns table (
    employee_id text,
    full_name text,
    session_count bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_month_start timestamptz := date_trunc('month', now());
    v_month_end timestamptz := v_month_start + interval '1 month';
begin
    if not public.is_admin() then
        raise exception 'Only an administrator can view this.';
    end if;

    return query
    select
        p.employee_id,
        p.full_name,
        count(ws.id) as session_count
    from public.work_sessions ws
    join public.profiles p on p.employee_id = ws.employee_id
    where p.role = 'employee'
      and ws.ended_at is not null
      and ws.started_at >= v_month_start
      and ws.started_at < v_month_end
    group by p.employee_id, p.full_name
    order by p.full_name
    limit p_limit offset p_offset;
end;
$$;

grant execute on function public.admin_monthly_active_employees(integer, integer)
    to authenticated;
