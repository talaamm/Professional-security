-- ============================================================
-- CREATE FIRST SUPER ADMIN — run once, in the Supabase SQL Editor,
-- against the PROD project.
-- ============================================================
--
-- Why you can't do this from the Table Editor: profiles.auth_user_id
-- is a NOT NULL FK into auth.users(id) (db_files/prod-bootstrap/
-- 003_tables.sql), and there's no UI field to hand it an id for a
-- row that doesn't exist yet. This script creates the auth.users row
-- itself (same bcrypt-via-pgcrypto technique as admin_create_employee()
-- in db_files/dev-db/phase7-admin-create-employee.sql), lets the
-- existing on_auth_user_created trigger create the matching profiles
-- row (which always comes out role = 'employee' -
-- handle_new_user() in db_files/prod-bootstrap/005_helper_functions.sql
-- hardcodes that), then promotes it to super_admin.
--
-- EDIT the three values in the "declare" block right below before
-- running: v_employee_id (9 digits, must be unique), v_full_name
-- (shown in the app UI), v_password (change it after first login).
-- ============================================================

do $$
declare
    v_employee_id text := '000000001';
    v_full_name   text := 'Super Admin';
    v_password    text := '123456';
    v_instance_id uuid;
    v_new_auth_id uuid;
begin
    if exists (select 1 from public.profiles where employee_id = v_employee_id) then
        raise exception 'Employee ID % is already registered.', v_employee_id;
    end if;

    -- Reuse whatever instance_id this project's auth.users rows already
    -- carry (mirrors admin_create_employee()); falls back to the
    -- conventional all-zero UUID when auth.users is still empty.
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
        crypt(v_password, gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('employee_id', v_employee_id, 'full_name', v_full_name),
        now(), now(),
        '', '', '', ''
    );

    -- on_auth_user_created has just inserted a profiles row with
    -- role = 'employee' (handle_new_user() always hardcodes that).
    -- Promote it.
    update public.profiles
    set role = 'super_admin'
    where employee_id = v_employee_id;
end $$;

-- Verify:
select employee_id, full_name, role, status
from public.profiles
where employee_id = '000000001';
