-- ============================================================
-- PHASE 7 (slice) — SUPER ADMIN: PROMOTE/DEMOTE ROLE
-- ============================================================
--
-- Two pieces:
--
--   1. super_admin_set_account_role(employee_id, new_role, reason?)
--      Lets a super admin turn an employee into an admin, or an
--      admin back into a plain employee, from that account's detail
--      screen. Restricted to super_admin callers; the target must
--      currently be 'employee' or 'admin' (never another super_admin,
--      never the caller themself) and new_role must be 'admin' or
--      'employee' - promoting/demoting to super_admin isn't offered
--      here, same one-tier-down-only rule as every other super-admin
--      action added in phase7-admin-self-sessions-and-super-admin.sql.
--
--      Demoting an admin whose employee_id doesn't happen to be a
--      9-digit number would otherwise violate
--      profiles_employee_id_format (that check only applies to
--      role = 'employee') with a raw constraint-violation error - this
--      function checks it up front instead, with a message that
--      actually explains what to fix.
--
--   2. profiles_update_admin RLS policy, tightened. As originally
--      written it let ANY admin UPDATE ANY column on ANY profile
--      (including role) via a raw client call, since is_admin() was
--      its only check - the schema's own comment flagged this as
--      deferred ("Role-management restrictions will be handled by
--      secure functions later"). Nothing in the app actually relies
--      on this policy today (every profile write already goes through
--      a SECURITY DEFINER function, confirmed by grep - no raw
--      .update() on profiles anywhere in lib/), so narrowing it here
--      costs nothing and closes a real self-promotion path: without
--      this, any admin could call supabase.from('profiles').update({
--      role: 'admin'}) directly and grant themselves (or anyone)
--      admin access, completely bypassing the function above. The
--      policy now only ever allows touching a row that is - and
--      stays - role = 'employee', so it can never be used to create
--      or touch an admin/super_admin row. SECURITY DEFINER functions
--      are unaffected by this (they run as the function owner, not
--      subject to the caller's RLS).
-- ============================================================


-- ------------------------------------------------------------
-- 1. super_admin_set_account_role(...)
-- ------------------------------------------------------------

create or replace function public.super_admin_set_account_role(
    p_employee_id text,
    p_new_role public.user_role,
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
        raise exception 'Only a super administrator can change an account''s role.';
    end if;

    if p_employee_id = v_super_admin_employee_id then
        raise exception 'You cannot change your own role.';
    end if;

    if p_new_role not in ('admin', 'employee') then
        raise exception 'Role can only be changed to admin or employee here.';
    end if;

    select * into v_before
    from public.profiles
    where employee_id = p_employee_id;

    if v_before.employee_id is null then
        raise exception 'Account not found.';
    end if;

    if v_before.role = 'super_admin' then
        raise exception 'Super admin accounts cannot be managed here.';
    end if;

    if v_before.role = p_new_role then
        raise exception 'This account already has that role.';
    end if;

    if p_new_role = 'employee' and p_employee_id !~ '^[0-9]{9}$' then
        raise exception
            'This admin''s employee ID isn''t a 9-digit employee ID, so it can''t become an employee account. Contact your developer to fix the ID first.';
    end if;

    update public.profiles
    set role = p_new_role
    where employee_id = p_employee_id
    returning * into v_target;

    insert into public.audit_logs (
        actor_employee_id, action, entity_type, entity_id, old_data, new_data, reason
    ) values (
        v_super_admin_employee_id,
        case when p_new_role = 'admin' then 'PROMOTE_TO_ADMIN' else 'DEMOTE_TO_EMPLOYEE' end,
        'profiles',
        null,
        to_jsonb(v_before),
        to_jsonb(v_target),
        p_reason
    );

    return v_target;
end;
$$;

grant execute on function public.super_admin_set_account_role(text, public.user_role, text)
    to authenticated;


-- ------------------------------------------------------------
-- 2. profiles_update_admin - narrowed so a raw client update can
--    never create or touch an admin/super_admin row.
-- ------------------------------------------------------------

drop policy if exists profiles_update_admin on public.profiles;

create policy profiles_update_admin
on public.profiles
for update
to authenticated
using (
    public.is_admin()
    and role = 'employee'
)
with check (
    public.is_admin()
    and role = 'employee'
);

-- ============================================================
-- END PHASE 7 ROLE MANAGEMENT (SLICE)
-- ============================================================
