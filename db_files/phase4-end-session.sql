-- ============================================================
-- PHASE 4 — END-OF-SESSION WORKPLACE VERIFICATION
-- ============================================================
--
-- Replaces end_work_session() (from phase3-session-functions.sql)
-- so that finishing work checks the employee's current GPS
-- position against the workplace recorded when THAT session
-- started (work_sessions.workplace_id) - the same
-- re-derive-it-yourself principle start_work_session() already
-- uses, applied to the end side.
--
-- Outcome:
--   - Start workplace known AND current position is within its
--     radius_meters -> end_verification = 'verified', session ends
--     immediately.
--   - Start workplace was never recognized (manual start), no
--     longer exists, or the current position is outside its
--     radius -> raises 'LOCATION_MISMATCH'. The app must then ask
--     the employee to confirm their location and resubmit with
--     p_manual_location_name -> end_verification = 'manual'.
--
-- A session is only fully verified when BOTH start_verification
-- and end_verification are 'verified'. There is no separate
-- unverified flag/column - "unverified" is simply any session
-- where either side is 'manual' (or 'unknown'), same as the
-- pending-admin-review treatment already used for a manual start.
-- ============================================================


-- manual_location_name already exists and is used for a manual
-- START location. A manual END location needs its own column so
-- the two are never conflated on the same session.

alter table public.work_sessions
    add column if not exists end_manual_location_name text;

alter table public.work_sessions
    drop constraint if exists work_sessions_end_manual_location_valid;

alter table public.work_sessions
    add constraint work_sessions_end_manual_location_valid
        check (
            end_manual_location_name is null
            or length(trim(end_manual_location_name)) > 0
        );


drop function if exists public.end_work_session();

create or replace function public.end_work_session(
    p_latitude double precision,
    p_longitude double precision,
    p_accuracy double precision,
    p_manual_location_name text default null
)
returns public.work_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
    v_employee_id text;
    v_status public.user_status;
    v_active public.work_sessions;
    v_workplace public.workplaces;
    v_distance double precision;
    v_verification public.verification_method;
    v_manual_name text;
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

    select * into v_active
    from public.work_sessions
    where employee_id = v_employee_id
      and ended_at is null;

    if v_active.id is null then
        raise exception 'No active work session was found.';
    end if;

    -- Try to auto-verify against the workplace recorded at start.
    if v_active.workplace_id is not null then
        select * into v_workplace
        from public.workplaces
        where id = v_active.workplace_id;

        if v_workplace.id is not null then
            v_distance := public._distance_meters(
                p_latitude, p_longitude,
                v_workplace.latitude, v_workplace.longitude
            );

            if v_distance <= v_workplace.radius_meters then
                v_verification := 'verified';
            end if;
        end if;
    end if;

    -- No recognized start workplace, workplace no longer exists, or the
    -- employee is no longer within its radius: require manual confirmation.
    if v_verification is null then
        v_manual_name := nullif(trim(p_manual_location_name), '');

        if v_manual_name is null then
            raise exception 'LOCATION_MISMATCH';
        end if;

        v_verification := 'manual';
    end if;

    update public.work_sessions
    set
        ended_at = now(),
        end_latitude = p_latitude,
        end_longitude = p_longitude,
        end_accuracy = p_accuracy,
        end_verification = v_verification,
        end_manual_location_name = v_manual_name
    where id = v_active.id
    returning * into v_session;

    return v_session;
end;
$$;

grant execute on function public.end_work_session(
    double precision, double precision, double precision, text
) to authenticated;

-- ============================================================
-- END PHASE 4 END-SESSION VERIFICATION
-- ============================================================
