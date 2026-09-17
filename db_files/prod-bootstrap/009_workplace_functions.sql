-- ============================================================
-- PROD BOOTSTRAP 009 — WORKPLACE FUNCTIONS
-- ============================================================
--
-- Direct workplace CRUD (create/update/deactivate) goes through the
-- RLS policies in 007, not a function - only the read-only proximity
-- lookup and the monthly sessions report need one.
-- ============================================================

-- Find active workplaces within their own allowed radius of the
-- given coordinates. NOT security definer - runs with the caller's
-- own privileges, so workplaces_select_active RLS applies exactly as
-- it does everywhere else.
create or replace function public.find_nearby_workplaces(
    p_latitude double precision,
    p_longitude double precision
)
returns table (
    workplace_id uuid,
    name text,
    distance_meters double precision
)
language sql
stable
set search_path = public
as $$
    select
        w.id,
        w.name,
        public._distance_meters(p_latitude, p_longitude, w.latitude, w.longitude)
    from public.workplaces w
    where w.status = 'active'
      and public._distance_meters(p_latitude, p_longitude, w.latitude, w.longitude)
            <= w.radius_meters
    order by 3 asc;
$$;

grant execute on function public.find_nearby_workplaces(double precision, double precision)
    to authenticated;


-- ------------------------------------------------------------
-- admin_workplace_sessions_for_month(...) - every completed work
-- session at one workplace within an admin-chosen month, across every
-- role (employee, admin, super_admin). Source: phase8-workplace-
-- sessions-report.sql. Backs the Edit Workplace screen's "Download All
-- Sessions" button.
-- ------------------------------------------------------------

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
