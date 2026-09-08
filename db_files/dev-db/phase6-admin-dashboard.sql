-- ============================================================
-- PHASE 6 — ADMIN DASHBOARD & WORKFORCE MONITORING
-- ============================================================
--
-- Adds:
--   1. work_sessions.verified_by - who is vouching for a completed
--      session's accuracy. NULL = still needs admin review.
--   2. end_work_session() - replaced to set verified_by to the
--      employee themself when a session ends with BOTH sides
--      auto-verified by GPS (the "no issues" default case).
--   3. admin_active_sessions() - employees currently working, for
--      the dashboard's "Currently Working" card.
--   4. admin_unverified_sessions() - completed sessions still
--      needing review, for the "Unverified Sessions" card.
--   5. admin_verify_session(...) - an admin reviews one unverified
--      session, optionally correcting the claimed location text,
--      and marks it verified under their own name.
--
-- Only sessions that have ENDED are ever "unverified" and
-- reviewable. An active session with a manual start already shows
-- the employee a "pending admin review" note (Phase 4), but there
-- is nothing final to review/correct until it ends - the same
-- distance check that runs at start could still succeed at end.
-- ============================================================


-- ------------------------------------------------------------
-- 1. verified_by column
-- ------------------------------------------------------------

alter table public.work_sessions
    add column if not exists verified_by text;

alter table public.work_sessions
    drop constraint if exists work_sessions_verified_by_fkey;

alter table public.work_sessions
    add constraint work_sessions_verified_by_fkey
        foreign key (verified_by)
        references public.profiles(employee_id)
        on delete restrict;


-- ------------------------------------------------------------
-- 2. end_work_session() - now sets verified_by = self when both
--    sides end up GPS-verified with no admin ever needing to step
--    in. Otherwise verified_by is left as-is (NULL) so the session
--    surfaces in admin_unverified_sessions() once it ends.
-- ------------------------------------------------------------

drop function if exists public.end_work_session(
    double precision, double precision, double precision, text
);

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
        end_manual_location_name = v_manual_name,
        verified_by = case
            when v_active.start_verification = 'verified' and v_verification = 'verified'
            then v_employee_id
            else verified_by
        end
    where id = v_active.id
    returning * into v_session;

    return v_session;
end;
$$;

grant execute on function public.end_work_session(
    double precision, double precision, double precision, text
) to authenticated;


-- ------------------------------------------------------------
-- 3. admin_active_sessions() - employees currently working.
-- ------------------------------------------------------------

create or replace function public.admin_active_sessions()
returns table (
    session_id uuid,
    employee_id text,
    employee_name text,
    workplace_name text,
    manual_location_name text,
    started_at timestamptz,
    start_verification public.verification_method
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
        w.name,
        ws.manual_location_name,
        ws.started_at,
        ws.start_verification
    from public.work_sessions ws
    join public.profiles p on p.employee_id = ws.employee_id
    left join public.workplaces w on w.id = ws.workplace_id
    where ws.ended_at is null
    order by ws.started_at desc;
end;
$$;

grant execute on function public.admin_active_sessions() to authenticated;


-- ------------------------------------------------------------
-- 4. admin_unverified_sessions() - completed sessions still
--    needing review (oldest first, like a review queue).
-- ------------------------------------------------------------

create or replace function public.admin_unverified_sessions()
returns table (
    session_id uuid,
    employee_id text,
    employee_name text,
    workplace_name text,
    manual_location_name text,
    end_manual_location_name text,
    started_at timestamptz,
    ended_at timestamptz,
    start_verification public.verification_method,
    end_verification public.verification_method
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
        w.name,
        ws.manual_location_name,
        ws.end_manual_location_name,
        ws.started_at,
        ws.ended_at,
        ws.start_verification,
        ws.end_verification
    from public.work_sessions ws
    join public.profiles p on p.employee_id = ws.employee_id
    left join public.workplaces w on w.id = ws.workplace_id
    where ws.ended_at is not null
      and ws.verified_by is null
      and (ws.start_verification <> 'verified' or ws.end_verification <> 'verified')
    order by ws.started_at asc;
end;
$$;

grant execute on function public.admin_unverified_sessions() to authenticated;


-- ------------------------------------------------------------
-- 5. admin_verify_session(...) - an admin resolves one unverified
--    session. Both sides are marked verified (a side that was
--    already fine is simply re-set to the same value); the claimed
--    location text is only overwritten when the admin actually
--    edited it. Recorded in audit_logs like any other admin action.
-- ------------------------------------------------------------

create or replace function public.admin_verify_session(
    p_session_id uuid,
    p_start_location_name text default null,
    p_end_location_name text default null,
    p_note text default null
)
returns public.work_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
    v_admin_employee_id text;
    v_before public.work_sessions;
    v_session public.work_sessions;
begin
    select employee_id into v_admin_employee_id
    from public.profiles
    where auth_user_id = auth.uid()
      and status = 'active'
      and role in ('admin', 'super_admin');

    if v_admin_employee_id is null then
        raise exception 'Only an administrator can verify a session.';
    end if;

    select * into v_before
    from public.work_sessions
    where id = p_session_id;

    if v_before.id is null then
        raise exception 'Session not found.';
    end if;

    if v_before.ended_at is null then
        raise exception 'This session has not ended yet.';
    end if;

    update public.work_sessions
    set
        start_verification = 'verified',
        end_verification = 'verified',
        manual_location_name =
            coalesce(nullif(trim(p_start_location_name), ''), manual_location_name),
        end_manual_location_name =
            coalesce(nullif(trim(p_end_location_name), ''), end_manual_location_name),
        verified_by = v_admin_employee_id,
        notes = coalesce(nullif(trim(p_note), ''), notes),
        updated_at = now()
    where id = p_session_id
    returning * into v_session;

    insert into public.audit_logs (
        actor_employee_id, action, entity_type, entity_id, old_data, new_data, reason
    ) values (
        v_admin_employee_id,
        'VERIFY_SESSION',
        'work_sessions',
        v_session.id,
        to_jsonb(v_before),
        to_jsonb(v_session),
        p_note
    );

    return v_session;
end;
$$;

grant execute on function public.admin_verify_session(uuid, text, text, text) to authenticated;

-- ============================================================
-- END PHASE 6 ADMIN DASHBOARD
-- ============================================================
