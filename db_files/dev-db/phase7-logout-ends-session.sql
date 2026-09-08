-- ============================================================
-- PHASE 7 (slice) — LOGOUT ENDS ACTIVE SESSION
-- ============================================================
--
-- Employees are warned client-side before logging out while a work
-- session is active (see lib/widgets/logout_helper.dart), so this
-- function is only reached after they've confirmed. It force-ends
-- their own active session with no GPS involved, so:
--   - end_verification = 'manual' -> lands in
--     admin_unverified_sessions() for review, same convention as
--     every other non-GPS-matched end.
--   - source stays 'employee' (its default from start_work_session)
--     since the employee is the one who ended it, unlike
--     admin_end_work_session() which sets source = 'admin' -
--     notes just records *why* it wasn't the normal Finish Work
--     flow.
--
-- SECURITY DEFINER, scoped to auth.uid() like every other
-- self-service function here (start_work_session, end_work_session)
-- - never trusts a client-passed employee id.
-- ============================================================

create or replace function public.end_work_session_for_logout()
returns public.work_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
    v_employee_id text;
    v_active public.work_sessions;
    v_session public.work_sessions;
begin
    select employee_id into v_employee_id
    from public.profiles
    where auth_user_id = auth.uid();

    if v_employee_id is null then
        raise exception 'Profile not found for the current user.';
    end if;

    select * into v_active
    from public.work_sessions
    where employee_id = v_employee_id
      and ended_at is null;

    if v_active.id is null then
        raise exception 'No active work session was found.';
    end if;

    update public.work_sessions
    set
        ended_at = now(),
        end_verification = 'manual',
        notes = 'Session ended automatically: employee logged out while working.',
        updated_at = now()
    where id = v_active.id
    returning * into v_session;

    return v_session;
end;
$$;

grant execute on function public.end_work_session_for_logout() to authenticated;

-- ============================================================
-- END PHASE 7 LOGOUT-ENDS-SESSION (SLICE)
-- ============================================================
