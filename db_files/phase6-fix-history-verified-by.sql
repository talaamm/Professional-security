-- ============================================================
-- PHASE 6 FIX — EMPLOYEE HISTORY SHOWED THE VERIFIER'S ID, NOT NAME
-- ============================================================
--
-- Bug: the Flutter History screen fetched the caller's own sessions
-- with a direct client-side select, embedding
-- profiles!work_sessions_verified_by_fkey(full_name) to show who
-- verified a session. That embed is still subject to RLS on
-- profiles - and profiles has no policy letting a plain employee
-- read an admin's profile row (only their own, via
-- profiles_select_own). So the embed silently came back NULL and
-- the UI fell back to printing the raw verified_by employee_id.
--
-- Fix: move this read into a SECURITY DEFINER function, scoped to
-- the caller's own sessions only (employee_id is resolved from
-- auth.uid() server-side, never taken from the client), so it can
-- safely join the verifier's name without needing a broader RLS
-- grant on profiles.
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
    select employee_id into v_employee_id
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
-- END PHASE 6 FIX
-- ============================================================
