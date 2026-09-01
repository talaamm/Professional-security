-- ============================================================
-- PHASE 7 (slice) — ADMIN SELF WORK SESSIONS + SUPER ADMIN
-- ============================================================
--
-- Three pieces:
--
--   1. work_sessions.ended_by - who actually performed the end
--      action (the employee themself, or the admin who force-ended
--      it from the dashboard). Mirrors the existing verified_by
--      column. Needed so the review screen can show "Ended by: X"
--      for an admin-ended session, distinct from who it belongs to.
--      Existing rows are left NULL - there's no reliable way to
--      backfill who ended a session before this column existed
--      (admin_end_work_session did record it in audit_logs, but a
--      normal self-ended session never wrote an audit row at all),
--      so old sessions just show no "ended by" note, which is the
--      correct default (nothing unusual to call out).
--
--   2. start_work_session() / end_work_session() /
--      end_work_session_for_logout() - now role-aware. An admin or
--      super_admin's own session is always recorded as 'verified' on
--      both sides, regardless of GPS/workplace matching - per your
--      instruction that admin work sessions never need review. The
--      re-derive-it-yourself distance check still runs and still
--      matters for plain employees; it's simply not a gate for
--      admin/super_admin. source is set from the caller's actual
--      role (session_source shares the same 'employee'/'admin'/
--      'super_admin' labels as user_role, so no lookup table is
--      needed).
--
--   3. super_admin_set_admin_status(...) /
--      super_admin_reset_admin_password(...) - the same two actions
--      admin_set_employee_status()/admin_reset_employee_password()
--      already provide for employee accounts, mirrored for admin
--      accounts and restricted to super_admin callers. A super admin
--      cannot target another super_admin or themself here, same
--      one-tier-down-only rule already used for admin-over-employee.
-- ============================================================


-- ------------------------------------------------------------
-- 1. ended_by column
-- ------------------------------------------------------------

alter table public.work_sessions
    add column if not exists ended_by text;

alter table public.work_sessions
    drop constraint if exists work_sessions_ended_by_fkey;

alter table public.work_sessions
    add constraint work_sessions_ended_by_fkey
        foreign key (ended_by)
        references public.profiles(employee_id)
        on delete restrict;


-- ------------------------------------------------------------
-- 2a. start_work_session() - role-aware verification.
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
-- 2b. end_work_session() - role-aware verification + ended_by.
--     The existing verified_by logic ("both sides verified -> vouch
--     for yourself") already produces the right result for an admin
--     once both sides are forced 'verified', so it's left untouched.
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
-- 2c. end_work_session_for_logout() - same role-aware verification,
--     plus ended_by. verified_by is now set for the admin/super_admin
--     case too, since both sides land on 'verified' here just like a
--     normal Finish Work - without it, the employee's own History
--     would misleadingly show "Pending review" for a session that
--     was never actually queued for review.
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
-- 2d. admin_end_work_session() - now also records ended_by, so the
--     review screen can show which admin force-ended it (the
--     reason, already stored in notes, was there from the start).
--     Also now blocks targeting the caller's own session - without
--     this, an admin could force-end their own active session through
--     the dashboard's "End Session" button and get end_verification =
--     'manual' instead of the always-verified outcome Finish Work
--     gives them, quietly defeating the "admin sessions are always
--     verified" guarantee.
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
-- 2e. admin_unverified_sessions() - now also returns ended_by/
--     ended_by_name/notes, so the review screen can show who ended
--     an admin-force-ended session and their reason. Return shape
--     changed, so the function must be dropped first.
-- ------------------------------------------------------------

drop function if exists public.admin_unverified_sessions();

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
-- 3a. super_admin_set_admin_status(...) - mirrors
--     admin_set_employee_status(), restricted to super_admin callers
--     and to role = 'admin' targets (never another super_admin, never
--     themself).
-- ------------------------------------------------------------

create or replace function public.super_admin_set_admin_status(
    p_employee_id text,
    p_status public.user_status,
    p_reason text default null
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
    v_super_admin_employee_id text;
    v_before public.profiles;
    v_target public.profiles;
begin
    select employee_id into v_super_admin_employee_id
    from public.profiles
    where auth_user_id = auth.uid()
      and status = 'active'
      and role = 'super_admin';

    if v_super_admin_employee_id is null then
        raise exception 'Only a super administrator can change an admin''s status.';
    end if;

    if p_employee_id = v_super_admin_employee_id then
        raise exception 'You cannot change your own account status.';
    end if;

    select * into v_before
    from public.profiles
    where employee_id = p_employee_id;

    if v_before.employee_id is null then
        raise exception 'Administrator not found.';
    end if;

    if v_before.role <> 'admin' then
        raise exception 'Only admin accounts can be managed here.';
    end if;

    update public.profiles
    set
        status = p_status,
        deactivated_at = case when p_status = 'inactive' then now() else null end
    where employee_id = p_employee_id
    returning * into v_target;

    insert into public.audit_logs (
        actor_employee_id, action, entity_type, entity_id, old_data, new_data, reason
    ) values (
        v_super_admin_employee_id,
        case when p_status = 'active' then 'ACTIVATE_ADMIN' else 'DEACTIVATE_ADMIN' end,
        'profiles',
        null,
        to_jsonb(v_before),
        to_jsonb(v_target),
        p_reason
    );

    return v_target;
end;
$$;

grant execute on function public.super_admin_set_admin_status(text, public.user_status, text)
    to authenticated;


-- ------------------------------------------------------------
-- 3b. super_admin_reset_admin_password(...) - mirrors
--     admin_reset_employee_password(), restricted to super_admin
--     callers and role = 'admin' targets.
-- ------------------------------------------------------------

create or replace function public.super_admin_reset_admin_password(p_employee_id text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    v_super_admin_employee_id text;
    v_target_auth_user_id uuid;
    v_target_role public.user_role;
begin
    select employee_id into v_super_admin_employee_id
    from public.profiles
    where auth_user_id = auth.uid()
      and status = 'active'
      and role = 'super_admin';

    if v_super_admin_employee_id is null then
        raise exception 'Only a super administrator can reset an admin''s password.';
    end if;

    if p_employee_id = v_super_admin_employee_id then
        raise exception 'You cannot reset your own password here. Use Change Password instead.';
    end if;

    select auth_user_id, role into v_target_auth_user_id, v_target_role
    from public.profiles
    where employee_id = p_employee_id;

    if v_target_auth_user_id is null then
        raise exception 'Administrator not found.';
    end if;

    if v_target_role <> 'admin' then
        raise exception 'Only admin accounts can be reset here.';
    end if;

    update auth.users
    set encrypted_password = crypt('123456', gen_salt('bf')),
        updated_at = now()
    where id = v_target_auth_user_id;

    insert into public.audit_logs (
        actor_employee_id, action, entity_type, entity_id, old_data, new_data, reason
    ) values (
        v_super_admin_employee_id, 'RESET_PASSWORD', 'profiles', null,
        null, jsonb_build_object('employee_id', p_employee_id), null
    );
end;
$$;

grant execute on function public.super_admin_reset_admin_password(text) to authenticated;

-- ============================================================
-- END PHASE 7 ADMIN SELF SESSIONS + SUPER ADMIN (SLICE)
-- ============================================================
