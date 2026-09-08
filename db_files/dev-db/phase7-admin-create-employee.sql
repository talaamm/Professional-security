-- ============================================================
-- PHASE 7 (slice) — ADMIN-CREATED EMPLOYEE REGISTRATION
-- ============================================================
--
-- admin_create_employee(employee_id, full_name) - lets an admin/
-- super_admin register a new employee from the Employees tab's
-- "Register New Employee" button, replacing employee
-- self-registration. The account gets the same fixed default
-- password "123456" as admin_reset_employee_password()
-- (db_files/phase7-password-reset.sql) - the employee changes it
-- after first login via Change Password.
--
-- Inserts directly into auth.users (bcrypt-hashed via pgcrypto,
-- same technique as admin_reset_employee_password()) rather than
-- calling Supabase Auth's signUp() from the client, because signUp()
-- would replace the *admin's own* active session on their device
-- with the newly created employee's session. The existing
-- on_auth_user_created trigger (db-schema-V2.sql section 13) then
-- creates the matching profiles row automatically, exactly as it
-- does for self-registration - role always comes out 'employee'
-- regardless of caller.
-- ============================================================

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

-- ============================================================
-- END PHASE 7 ADMIN-CREATED EMPLOYEE REGISTRATION (SLICE)
-- ============================================================
