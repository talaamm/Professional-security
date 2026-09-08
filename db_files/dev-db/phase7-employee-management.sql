-- ============================================================
-- PHASE 7 (slice) — ADMIN EMPLOYEE MANAGEMENT: ACTIVATE/DEACTIVATE
-- ============================================================
--
-- Adds admin_set_employee_status(...), used by the new Employees
-- tab's employee detail screen. Searching and viewing employees
-- already work through the existing profiles_select_admin /
-- work_sessions_select_admin RLS policies (admins can already
-- SELECT any profile/session) - only the status change itself
-- needs a function, because:
--   - profiles has no client-facing "toggle my status" concept;
--     writes should be audited like every other admin action.
--   - status/deactivated_at must change together
--     (profiles_status_dates check constraint), which a raw
--     `update ... set status = ...` from the client would violate
--     half the time.
-- ============================================================

create or replace function public.admin_set_employee_status(
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
    v_admin_employee_id text;
    v_before public.profiles;
    v_target public.profiles;
begin
    select employee_id into v_admin_employee_id
    from public.profiles
    where auth_user_id = auth.uid()
      and status = 'active'
      and role in ('admin', 'super_admin');

    if v_admin_employee_id is null then
        raise exception 'Only an administrator can change an employee''s status.';
    end if;

    if p_employee_id = v_admin_employee_id then
        raise exception 'You cannot change your own account status.';
    end if;

    select * into v_before
    from public.profiles
    where employee_id = p_employee_id;

    if v_before.employee_id is null then
        raise exception 'Employee not found.';
    end if;

    if v_before.role <> 'employee' then
        raise exception 'Only employee accounts can be managed here.';
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
        v_admin_employee_id,
        case when p_status = 'active' then 'ACTIVATE_EMPLOYEE' else 'DEACTIVATE_EMPLOYEE' end,
        'profiles',
        null,
        to_jsonb(v_before),
        to_jsonb(v_target),
        p_reason
    );

    return v_target;
end;
$$;

grant execute on function public.admin_set_employee_status(text, public.user_status, text)
    to authenticated;

-- ============================================================
-- END PHASE 7 EMPLOYEE MANAGEMENT (SLICE)
-- ============================================================
