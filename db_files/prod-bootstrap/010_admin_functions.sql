-- ============================================================
-- PROD BOOTSTRAP 010 — ADMIN / SUPER-ADMIN FUNCTIONS
-- ============================================================
--
-- Source files: phase7-employee-management.sql,
-- phase7-admin-create-employee.sql, phase7-password-reset.sql
-- (admin_reset_employee_password only - the rest of that file is in
-- 012_password_reset_functions.sql), phase7-role-management.sql,
-- phase7-admin-self-sessions-and-super-admin.sql (super_admin_*).
-- None of these were redefined again in a later file.
-- ============================================================


-- ------------------------------------------------------------
-- admin_set_employee_status(...) - activate/deactivate an employee.
-- status/deactivated_at must change together
-- (profiles_status_dates), which is why this can't be a raw client
-- update even under the (already narrowed) profiles_update_admin RLS
-- policy - every such write is audited here too.
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- admin_create_employee(...) - registers a new employee with the
-- fixed default password "123456" (changed after first login).
-- Inserts directly into auth.users rather than calling client-side
-- signUp(), which would replace the admin's own active session.
-- on_auth_user_created then creates the matching profiles row.
-- ------------------------------------------------------------

create or replace function public.admin_create_employee(
    p_employee_id text,
    p_full_name text
)
returns public.profiles
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    v_admin_employee_id text;
    v_employee_id text;
    v_full_name text;
    v_instance_id uuid;
    v_new_auth_id uuid;
    v_profile public.profiles;
begin
    select employee_id into v_admin_employee_id
    from public.profiles
    where auth_user_id = auth.uid()
      and status = 'active'
      and role in ('admin', 'super_admin');

    if v_admin_employee_id is null then
        raise exception 'Only an administrator can register an employee.';
    end if;

    v_employee_id := trim(p_employee_id);
    if v_employee_id !~ '^[0-9]{9}$' then
        raise exception 'Enter a valid 9-digit Employee ID.';
    end if;

    v_full_name := trim(p_full_name);
    if length(v_full_name) = 0 then
        raise exception 'Enter the employee''s name.';
    end if;

    if exists (select 1 from public.profiles where employee_id = v_employee_id) then
        raise exception 'This Employee ID is already registered.';
    end if;

    -- Reuse whatever instance_id this project's existing auth.users rows
    -- already carry, rather than assuming the conventional all-zero UUID.
    select instance_id into v_instance_id from auth.users limit 1;
    if v_instance_id is null then
        v_instance_id := '00000000-0000-0000-0000-000000000000';
    end if;

    v_new_auth_id := gen_random_uuid();

    insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at,
        confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
        v_instance_id, v_new_auth_id, 'authenticated', 'authenticated',
        lower(v_employee_id) || '@internal.app',
        crypt('123456', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('employee_id', v_employee_id, 'full_name', v_full_name),
        now(), now(),
        '', '', '', ''
    );

    -- on_auth_user_created trigger has just created the profiles row.
    select * into v_profile
    from public.profiles
    where auth_user_id = v_new_auth_id;

    insert into public.audit_logs (
        actor_employee_id, action, entity_type, entity_id, old_data, new_data, reason
    ) values (
        v_admin_employee_id, 'CREATE_EMPLOYEE', 'profiles', null,
        null, to_jsonb(v_profile), null
    );

    return v_profile;
end;
$$;

grant execute on function public.admin_create_employee(text, text) to authenticated;


-- ------------------------------------------------------------
-- admin_reset_employee_password(...) - resets to the fixed default
-- "123456" (bcrypt-hashed via pgcrypto), and auto-resolves any open
-- password reset request for that employee.
-- ------------------------------------------------------------

create or replace function public.admin_reset_employee_password(p_employee_id text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    v_admin_employee_id text;
    v_target_auth_user_id uuid;
    v_target_role public.user_role;
begin
    select employee_id into v_admin_employee_id
    from public.profiles
    where auth_user_id = auth.uid()
      and status = 'active'
      and role in ('admin', 'super_admin');

    if v_admin_employee_id is null then
        raise exception 'Only an administrator can reset a password.';
    end if;

    if p_employee_id = v_admin_employee_id then
        raise exception 'You cannot reset your own password here. Use Change Password instead.';
    end if;

    select auth_user_id, role into v_target_auth_user_id, v_target_role
    from public.profiles
    where employee_id = p_employee_id;

    if v_target_auth_user_id is null then
        raise exception 'Employee not found.';
    end if;

    if v_target_role <> 'employee' then
        raise exception 'Only employee accounts can be reset here.';
    end if;

    update auth.users
    set encrypted_password = crypt('123456', gen_salt('bf')),
        updated_at = now()
    where id = v_target_auth_user_id;

    update public.password_reset_requests
    set
        status = 'resolved',
        resolved_at = now(),
        resolved_by = v_admin_employee_id
    where employee_id = p_employee_id
      and status = 'open';

    insert into public.audit_logs (
        actor_employee_id, action, entity_type, entity_id, old_data, new_data, reason
    ) values (
        v_admin_employee_id, 'RESET_PASSWORD', 'profiles', null,
        null, jsonb_build_object('employee_id', p_employee_id), null
    );
end;
$$;

grant execute on function public.admin_reset_employee_password(text) to authenticated;


-- ------------------------------------------------------------
-- super_admin_set_account_role(...) - promote employee<->admin.
-- Never targets/creates a super_admin, never the caller themself.
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
-- super_admin_set_admin_status(...) - mirrors admin_set_employee_status()
-- for admin accounts. Restricted to super_admin callers, role = 'admin'
-- targets only (never another super_admin, never themself).
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
-- super_admin_reset_admin_password(...) - mirrors
-- admin_reset_employee_password() for admin accounts.
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


-- ------------------------------------------------------------
-- profiles_update_admin RLS policy is already created in its FINAL
-- (narrowed, role = 'employee' only) form in 007_rls_policies.sql -
-- no further action needed here.
-- ------------------------------------------------------------
