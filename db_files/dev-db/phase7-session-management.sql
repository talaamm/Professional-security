-- ============================================================
-- PHASE 7 (slice) — ADMIN SESSION MANAGEMENT: END / EDIT / DELETE
-- ============================================================
--
-- Adds three admin actions on work_sessions, each SECURITY DEFINER
-- with its own explicit role check (work_sessions has no
-- INSERT/UPDATE/DELETE policy for anyone - see db-schema-V2.sql
-- section 20), and each writes an audit_logs row - including when
-- the session being touched was already verified, per your
-- instruction that every admin edit/delete must be tracked
-- regardless of prior verification state.
--
--   1. admin_end_work_session(session_id, reason?)
--      Terminates an employee's still-ACTIVE session from the
--      dashboard's "Currently Working" card. Per
--      requirements-and-architecture_V1.md section 4.3, this must
--      not look like the employee ended it themself: source is set
--      to 'admin', and end_verification is 'manual' (there is no
--      GPS reading from an admin acting remotely) - so a
--      force-ended session lands in admin_unverified_sessions() for
--      proper follow-up review, same as any other unverified end.
--
--   2. admin_edit_work_session(session_id, started_at, ended_at,
--      workplace_id?, manual_location_name?, reason?)
--      Corrects a completed session's start/end time and
--      workplace/location. Marks both sides 'verified' and
--      verified_by = the editing admin, since an admin manually
--      setting this data is now vouching for it.
--
--   3. admin_delete_work_session(session_id, reason)
--      Permanently removes a completed session. reason is required
--      (unlike the other two, where it's optional) because this is
--      irreversible - the full row is preserved in audit_logs
--      (old_data) even though the live row is gone, so the record
--      isn't actually lost, just no longer part of the employee's
--      active history/reports.
-- ============================================================


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

    update public.work_sessions
    set
        ended_at = now(),
        end_verification = 'manual',
        source = 'admin',
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

-- ============================================================
-- END PHASE 7 SESSION MANAGEMENT (SLICE)
-- ============================================================
