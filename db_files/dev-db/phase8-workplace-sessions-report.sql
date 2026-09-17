-- ============================================================
-- PHASE 8 (slice) — WORKPLACE MONTHLY SESSIONS REPORT
-- ============================================================
--
-- Backs the Edit Workplace screen's "Download All Sessions" button:
-- every completed work session at one workplace within an admin-chosen
-- month, across every role (employee, admin, super_admin) - not scoped
-- to employees only, unlike admin_monthly_active_employees()
-- (phase8-monthly-active-employees.sql).
--
-- profiles is joined here inside the function (rather than a plain
-- PostgREST embed from the client) because work_sessions has two FKs
-- into profiles (employee_id, verified_by) - an embed would be
-- ambiguous without a relationship hint, so this follows the same
-- RPC-with-explicit-join pattern already used by admin_active_sessions()
-- / admin_unverified_sessions() (phase6-admin-dashboard.sql) and
-- list_my_sessions_for_month().
--
-- [p_month_start, p_month_end_exclusive) bounds are supplied by the
-- client, same convention as fetchEmployeeSessionsForMonth() - not a
-- security boundary, since an admin can already see every month's data
-- for every workplace.
-- ============================================================

create or replace function public.admin_workplace_sessions_for_month(
    p_workplace_id uuid,
    p_month_start timestamptz,
    p_month_end_exclusive timestamptz
)
returns table (
    session_id uuid,
    employee_id text,
    employee_name text,
    started_at timestamptz,
    ended_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
    if not public.is_admin() then
        raise exception 'Only an administrator can view this.';
    end if;

    return query
    select
        ws.id,
        ws.employee_id,
        p.full_name,
        ws.started_at,
        ws.ended_at
    from public.work_sessions ws
    join public.profiles p on p.employee_id = ws.employee_id
    where ws.workplace_id = p_workplace_id
      and ws.ended_at is not null
      and ws.started_at >= p_month_start
      and ws.started_at < p_month_end_exclusive
    order by ws.started_at asc;
end;
$$;

grant execute on function public.admin_workplace_sessions_for_month(uuid, timestamptz, timestamptz)
    to authenticated;
