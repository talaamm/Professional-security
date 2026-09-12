-- ============================================================
-- FIX — admins could force-end another admin's/super admin's
-- active work session from the dashboard
-- ============================================================
--
-- Corrected rule:
--   - admin: sees everyone currently working (employees AND other
--     admins - admin_active_sessions() is unchanged, this was never
--     the problem) but may only END an employee's session. Ending an
--     admin/super_admin session is blocked server-side.
--   - super_admin: sees everyone and may end anyone's session, no
--     restriction.
--
-- admin_end_work_session() (phase7-admin-self-sessions-and-super-
-- admin.sql) now looks up the caller's own role and only checks the
-- target's role when the caller is a plain 'admin'.
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
    v_caller_role public.user_role;
    v_target_role public.user_role;
    v_before public.work_sessions;
    v_session public.work_sessions;
begin
    select employee_id, role into v_admin_employee_id, v_caller_role
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

    if v_caller_role = 'admin' then
        select role into v_target_role
        from public.profiles
        where employee_id = v_before.employee_id;

        if v_target_role <> 'employee' then
            raise exception 'You cannot end another administrator''s session.';
        end if;
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

-- ============================================================
-- END FIX
-- ============================================================
