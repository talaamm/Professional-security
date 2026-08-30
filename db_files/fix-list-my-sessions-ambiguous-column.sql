-- ============================================================
-- FIX — "column reference employee_id is ambiguous"
-- ============================================================
--
-- list_my_sessions_for_month() declares `employee_id text` as one
-- of its RETURNS TABLE columns. In PL/pgSQL, every RETURNS TABLE
-- column becomes an implicit variable in the function's own scope -
-- so the unqualified `select employee_id into v_employee_id from
-- public.profiles ...` line couldn't tell whether `employee_id`
-- meant that implicit OUT variable or profiles.employee_id, and
-- Postgres correctly refused to guess.
--
-- Fix: qualify it as profiles.employee_id. Everywhere else in the
-- function already uses table aliases (ws., w., vp.), which is why
-- only this one line broke.
-- ============================================================

create or replace function public.list_my_sessions_for_month(
    p_month_start timestamptz,
    p_month_end_exclusive timestamptz
)
returns table (
    id uuid,
    employee_id text,
    workplace_id uuid,
    workplace_name text,
    manual_location_name text,
    end_manual_location_name text,
    started_at timestamptz,
    ended_at timestamptz,
    start_verification public.verification_method,
    end_verification public.verification_method,
    verified_by text,
    verified_by_name text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_employee_id text;
begin
    select profiles.employee_id into v_employee_id
    from public.profiles
    where auth_user_id = auth.uid();

    if v_employee_id is null then
        raise exception 'Profile not found for the current user.';
    end if;

    return query
    select
        ws.id,
        ws.employee_id,
        ws.workplace_id,
        w.name,
        ws.manual_location_name,
        ws.end_manual_location_name,
        ws.started_at,
        ws.ended_at,
        ws.start_verification,
        ws.end_verification,
        ws.verified_by,
        vp.full_name
    from public.work_sessions ws
    left join public.workplaces w on w.id = ws.workplace_id
    left join public.profiles vp on vp.employee_id = ws.verified_by
    where ws.employee_id = v_employee_id
      and ws.started_at >= p_month_start
      and ws.started_at < p_month_end_exclusive
    order by ws.started_at desc;
end;
$$;

grant execute on function public.list_my_sessions_for_month(timestamptz, timestamptz)
    to authenticated;

-- ============================================================
-- END FIX
-- ============================================================
