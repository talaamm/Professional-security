-- ============================================================
-- PHASE 3 — EMPLOYEE START / END WORK SESSION
-- Secure database functions
-- ============================================================
--
-- work_sessions intentionally has NO insert/update policy for
-- normal authenticated clients (see db-schema-V2.sql section 20).
-- Starting/ending a session goes through these SECURITY DEFINER
-- functions instead, so the client can never set employee_id,
-- started_at, ended_at, or workplace_id directly.
--
-- No GPS/workplace detection yet (that's Phase 4) — sessions are
-- created with workplace_id = NULL and verification = 'unknown'.
-- ============================================================


create or replace function public.start_work_session()
returns public.work_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
    v_employee_id text;
    v_status public.user_status;
    v_session public.work_sessions;
begin
    select employee_id, status
    into v_employee_id, v_status
    from public.profiles
    where auth_user_id = auth.uid();

    if v_employee_id is null then
        raise exception 'Profile not found for the current user.';
    end if;

    if v_status <> 'active' then
        raise exception 'Your account is inactive. Please contact an administrator.';
    end if;

    if exists (
        select 1
        from public.work_sessions
        where employee_id = v_employee_id
          and ended_at is null
    ) then
        raise exception 'You already have an active work session.';
    end if;

    insert into public.work_sessions (
        employee_id,
        started_at,
        start_verification,
        source
    )
    values (
        v_employee_id,
        now(),
        'unknown',
        'employee'
    )
    on conflict (employee_id) where ended_at is null do nothing
    returning * into v_session;

    if v_session.id is null then
        raise exception 'You already have an active work session.';
    end if;

    return v_session;
end;
$$;


create or replace function public.end_work_session()
returns public.work_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
    v_employee_id text;
    v_status public.user_status;
    v_session public.work_sessions;
begin
    select employee_id, status
    into v_employee_id, v_status
    from public.profiles
    where auth_user_id = auth.uid();

    if v_employee_id is null then
        raise exception 'Profile not found for the current user.';
    end if;

    if v_status <> 'active' then
        raise exception 'Your account is inactive. Please contact an administrator.';
    end if;

    update public.work_sessions
    set
        ended_at = now(),
        end_verification = 'unknown'
    where employee_id = v_employee_id
      and ended_at is null
    returning * into v_session;

    if v_session.id is null then
        raise exception 'No active work session was found.';
    end if;

    return v_session;
end;
$$;


grant execute on function public.start_work_session() to authenticated;
grant execute on function public.end_work_session() to authenticated;


-- ============================================================
-- END PHASE 3 SESSION FUNCTIONS
-- ============================================================
