-- ============================================================
-- PROD BOOTSTRAP 008 — SESSION FUNCTIONS (FINAL VERSIONS)
-- ============================================================
--
-- Every function below is the LAST redefinition across the phase
-- files, verbatim - no rewriting. Superseded intermediate versions
-- (phase3's no-arg start/end_work_session, phase4's non-role-aware
-- versions, phase6's pre-ended_by admin_unverified_sessions, etc.)
-- are not created at all; going straight to final state.
--
-- Final-version source file for each:
--   start_work_session            phase7-admin-self-sessions-and-super-admin.sql
--   end_work_session               phase7-admin-self-sessions-and-super-admin.sql
--   end_work_session_for_logout    phase7-admin-self-sessions-and-super-admin.sql
--   admin_end_work_session         phase7-admin-self-sessions-and-super-admin.sql
--   admin_unverified_sessions      phase7-admin-self-sessions-and-super-admin.sql
--   admin_active_sessions          phase6-admin-dashboard.sql (never redefined again)
--   admin_verify_session           phase6-admin-dashboard.sql (never redefined again)
--   admin_edit_work_session        phase7-session-management.sql (never redefined again)
--   admin_delete_work_session      phase7-session-management.sql (never redefined again)
--   list_my_sessions_for_month     fix-list-my-sessions-ambiguous-column.sql
--                                  (supersedes phase6-fix-history-verified-by.sql -
--                                   that earlier version had an ambiguous-column bug)
-- ============================================================


-- ------------------------------------------------------------
-- start_work_session(...) - role-aware: an admin/super_admin's own
-- session is always 'verified' on the start side (no distance gate);
-- a plain employee still has GPS/workplace distance re-derived and
-- checked server-side, never trusting a client-asserted match.
-- ------------------------------------------------------------

create or replace function public.start_work_session(
    p_latitude double precision,
    p_longitude double precision,
    p_accuracy double precision,
    p_workplace_id uuid default null,
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
    v_role public.user_role;
    v_is_admin boolean;
    v_workplace public.workplaces;
    v_distance double precision;
    v_verification public.verification_method;
    v_manual_name text;
    v_session public.work_sessions;
begin
    select employee_id, status, role
    into v_employee_id, v_status, v_role
    from public.profiles
    where auth_user_id = auth.uid();

    if v_employee_id is null then
        raise exception 'Profile not found for the current user.';
    end if;

    if v_status <> 'active' then
        raise exception 'Your account is inactive. Please contact an administrator.';
    end if;

    v_is_admin := v_role in ('admin', 'super_admin');

    if exists (
        select 1
        from public.work_sessions
        where employee_id = v_employee_id
          and ended_at is null
    ) then
        raise exception 'You already have an active work session.';
    end if;

    if p_workplace_id is not null then
        select * into v_workplace
        from public.workplaces
        where id = p_workplace_id
          and status = 'active';

        if v_workplace.id is null then
            raise exception 'The selected workplace is no longer available.';
        end if;

        -- Admins/super admins are trusted staff - their own sessions are
        -- always verified, so the distance re-check that gates a plain
        -- employee doesn't apply to them.
        if not v_is_admin then
            v_distance := public._distance_meters(
                p_latitude, p_longitude,
                v_workplace.latitude, v_workplace.longitude
            );

            if v_distance > v_workplace.radius_meters then
                raise exception 'You are not currently within range of the selected workplace.';
            end if;
        end if;

        v_verification := 'verified';
    else
        v_manual_name := nullif(trim(p_manual_location_name), '');

        if v_manual_name is null then
            raise exception 'Enter a workplace name or select a detected workplace.';
        end if;

        v_verification := case when v_is_admin then 'verified' else 'manual' end;
    end if;

    insert into public.work_sessions (
        employee_id,
        workplace_id,
        started_at,
        start_latitude,
        start_longitude,
        start_accuracy,
        start_verification,
        manual_location_name,
        source
    )
    values (
        v_employee_id,
        p_workplace_id,
        now(),
        p_latitude,
        p_longitude,
        p_accuracy,
        v_verification,
        v_manual_name,
        v_role::text::public.session_source
    )
    on conflict (employee_id) where ended_at is null do nothing
    returning * into v_session;

    if v_session.id is null then
        raise exception 'You already have an active work session.';
    end if;

    return v_session;
end;
$$;

grant execute on function public.start_work_session(
    double precision, double precision, double precision, uuid, text
) to authenticated;


-- ------------------------------------------------------------
-- end_work_session(...) - role-aware verification + ended_by.
-- ------------------------------------------------------------

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
    v_role public.user_role;
    v_is_admin boolean;
    v_active public.work_sessions;
    v_workplace public.workplaces;
    v_distance double precision;
    v_verification public.verification_method;
    v_manual_name text;
    v_session public.work_sessions;
begin
    select employee_id, status, role
    into v_employee_id, v_status, v_role
    from public.profiles
    where auth_user_id = auth.uid();

    if v_employee_id is null then
        raise exception 'Profile not found for the current user.';
    end if;

    if v_status <> 'active' then
        raise exception 'Your account is inactive. Please contact an administrator.';
    end if;

    v_is_admin := v_role in ('admin', 'super_admin');

    select * into v_active
    from public.work_sessions
    where employee_id = v_employee_id
      and ended_at is null;

    if v_active.id is null then
        raise exception 'No active work session was found.';
    end if;

    if v_is_admin then
        -- Admin/super admin sessions are always verified - no distance
        -- gate, no manual-confirmation fallback needed.
        v_verification := 'verified';
        v_manual_name := nullif(trim(p_manual_location_name), '');
    else
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
    end if;

    update public.work_sessions
    set
        ended_at = now(),
        end_latitude = p_latitude,
        end_longitude = p_longitude,
        end_accuracy = p_accuracy,
        end_verification = v_verification,
        end_manual_location_name = v_manual_name,
        ended_by = v_employee_id,
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
-- end_work_session_for_logout() - force-ends the caller's own
-- active session with no GPS, e.g. when logging out while working.
-- ------------------------------------------------------------

create or replace function public.end_work_session_for_logout()
returns public.work_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
    v_employee_id text;
    v_role public.user_role;
    v_is_admin boolean;
    v_active public.work_sessions;
    v_session public.work_sessions;
begin
    select employee_id, role into v_employee_id, v_role
    from public.profiles
    where auth_user_id = auth.uid();

    if v_employee_id is null then
        raise exception 'Profile not found for the current user.';
    end if;

    v_is_admin := v_role in ('admin', 'super_admin');

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
        end_verification = case when v_is_admin then 'verified' else 'manual' end,
        ended_by = v_employee_id,
        verified_by = case when v_is_admin then v_employee_id else verified_by end,
        notes = 'Session ended automatically: logged out while working.',
        updated_at = now()
    where id = v_active.id
    returning * into v_session;

    return v_session;
end;
$$;

grant execute on function public.end_work_session_for_logout() to authenticated;


-- ------------------------------------------------------------
-- admin_active_sessions() - employees currently working, for the
-- dashboard's "Currently Working" card.
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
-- admin_unverified_sessions() - completed sessions still needing
-- review (oldest first). Final shape includes ended_by/ended_by_name/
-- notes so the review screen can show who force-ended a session.
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
    end_verification public.verification_method,
    ended_by text,
    ended_by_name text,
    notes text
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
        ws.end_verification,
        ws.ended_by,
        eb.full_name,
        ws.notes
    from public.work_sessions ws
    join public.profiles p on p.employee_id = ws.employee_id
    left join public.workplaces w on w.id = ws.workplace_id
    left join public.profiles eb on eb.employee_id = ws.ended_by
    where ws.ended_at is not null
      and ws.verified_by is null
      and (ws.start_verification <> 'verified' or ws.end_verification <> 'verified')
    order by ws.started_at asc;
end;
$$;

grant execute on function public.admin_unverified_sessions() to authenticated;


-- ------------------------------------------------------------
-- admin_verify_session(...) - an admin resolves one unverified
-- session, both sides marked verified, recorded in audit_logs.
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


-- ------------------------------------------------------------
-- admin_end_work_session(...) - force-ends another employee's active
-- session from the dashboard. Blocks targeting the caller's own
-- session (must use Finish Work for that, which keeps the
-- always-verified admin-session guarantee intact).
-- ------------------------------------------------------------

create or replace function public.admin_end_work_session(
    p_session_id uuid,
    p_reason text default null
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
        raise exception 'Only an administrator can end a session.';
    end if;

    select * into v_before
    from public.work_sessions
    where id = p_session_id;

    if v_before.id is null then
        raise exception 'Session not found.';
    end if;

    if v_before.ended_at is not null then
        raise exception 'This session has already ended.';
    end if;

    if v_before.employee_id = v_admin_employee_id then
        raise exception 'Use Finish Work to end your own session.';
    end if;

    update public.work_sessions
    set
        ended_at = now(),
        end_verification = 'manual',
        source = 'admin',
        ended_by = v_admin_employee_id,
        notes = coalesce(nullif(trim(p_reason), ''), notes),
        updated_at = now()
    where id = p_session_id
    returning * into v_session;

    insert into public.audit_logs (
        actor_employee_id, action, entity_type, entity_id, old_data, new_data, reason
    ) values (
        v_admin_employee_id, 'ADMIN_END_SESSION', 'work_sessions', v_session.id,
        to_jsonb(v_before), to_jsonb(v_session), p_reason
    );

    return v_session;
end;
$$;

grant execute on function public.admin_end_work_session(uuid, text) to authenticated;


-- ------------------------------------------------------------
-- admin_edit_work_session(...) - corrects a completed session's
-- start/end time and workplace/location; marks it verified under
-- the editing admin's name.
-- ------------------------------------------------------------

create or replace function public.admin_edit_work_session(
    p_session_id uuid,
    p_started_at timestamptz,
    p_ended_at timestamptz,
    p_workplace_id uuid default null,
    p_manual_location_name text default null,
    p_reason text default null
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
    v_manual_name text;
begin
    select employee_id into v_admin_employee_id
    from public.profiles
    where auth_user_id = auth.uid()
      and status = 'active'
      and role in ('admin', 'super_admin');

    if v_admin_employee_id is null then
        raise exception 'Only an administrator can edit a session.';
    end if;

    if p_ended_at <= p_started_at then
        raise exception 'End time must be after the start time.';
    end if;

    select * into v_before
    from public.work_sessions
    where id = p_session_id;

    if v_before.id is null then
        raise exception 'Session not found.';
    end if;

    if v_before.ended_at is null then
        raise exception 'Only a completed session can be edited here.';
    end if;

    if p_workplace_id is null then
        v_manual_name := nullif(trim(p_manual_location_name), '');
        if v_manual_name is null then
            raise exception 'Choose a workplace or enter a location name.';
        end if;
    end if;

    update public.work_sessions
    set
        started_at = p_started_at,
        ended_at = p_ended_at,
        workplace_id = p_workplace_id,
        manual_location_name = v_manual_name,
        start_verification = 'verified',
        end_verification = 'verified',
        verified_by = v_admin_employee_id,
        notes = coalesce(nullif(trim(p_reason), ''), notes),
        updated_at = now()
    where id = p_session_id
    returning * into v_session;

    insert into public.audit_logs (
        actor_employee_id, action, entity_type, entity_id, old_data, new_data, reason
    ) values (
        v_admin_employee_id, 'EDIT_SESSION', 'work_sessions', v_session.id,
        to_jsonb(v_before), to_jsonb(v_session), p_reason
    );

    return v_session;
end;
$$;

grant execute on function public.admin_edit_work_session(
    uuid, timestamptz, timestamptz, uuid, text, text
) to authenticated;


-- ------------------------------------------------------------
-- admin_delete_work_session(...) - permanently removes a completed
-- session; a reason is required (this is irreversible). The full row
-- is preserved in audit_logs.old_data.
-- ------------------------------------------------------------

create or replace function public.admin_delete_work_session(
    p_session_id uuid,
    p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_admin_employee_id text;
    v_before public.work_sessions;
begin
    select employee_id into v_admin_employee_id
    from public.profiles
    where auth_user_id = auth.uid()
      and status = 'active'
      and role in ('admin', 'super_admin');

    if v_admin_employee_id is null then
        raise exception 'Only an administrator can delete a session.';
    end if;

    if nullif(trim(p_reason), '') is null then
        raise exception 'A reason is required to delete a session.';
    end if;

    select * into v_before
    from public.work_sessions
    where id = p_session_id;

    if v_before.id is null then
        raise exception 'Session not found.';
    end if;

    if v_before.ended_at is null then
        raise exception 'Only a completed session can be deleted here. End it first.';
    end if;

    delete from public.work_sessions where id = p_session_id;

    insert into public.audit_logs (
        actor_employee_id, action, entity_type, entity_id, old_data, new_data, reason
    ) values (
        v_admin_employee_id, 'DELETE_SESSION', 'work_sessions', v_before.id,
        to_jsonb(v_before), null, p_reason
    );
end;
$$;

grant execute on function public.admin_delete_work_session(uuid, text) to authenticated;


-- ------------------------------------------------------------
-- list_my_sessions_for_month(...) - the caller's own sessions for a
-- given month, with the verifier's name safely joined server-side
-- (avoids a client-side embed that RLS on profiles would silently
-- null out). Final version: qualifies profiles.employee_id explicitly
-- to avoid the ambiguous-column bug the first version had.
-- ------------------------------------------------------------

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
