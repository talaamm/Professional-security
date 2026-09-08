-- ============================================================
-- PROD BOOTSTRAP 012 — PASSWORD RESET REQUEST FUNCTIONS
-- ============================================================
--
-- Source: phase7-password-reset.sql (table/RLS/grants already in
-- 003_tables.sql / 007_rls_policies.sql). admin_reset_employee_password
-- is in 010_admin_functions.sql, grouped with the other admin/
-- super-admin password-reset function rather than here.
-- ============================================================


-- request_password_reset(employee_id, message?) - submitted from the
-- unauthenticated Forgot Password screen. The ONLY function in this
-- app granted to anon.
create or replace function public.request_password_reset(
    p_employee_id text,
    p_message text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_employee_id text;
    v_message text;
begin
    v_employee_id := trim(p_employee_id);

    if v_employee_id !~ '^[0-9]{9}$' then
        raise exception 'Enter your 9-digit Employee ID.';
    end if;

    if not exists (
        select 1 from public.profiles
        where employee_id = v_employee_id
          and role = 'employee'
    ) then
        raise exception 'Employee ID not found.';
    end if;

    v_message := nullif(trim(p_message), '');
    if v_message is not null and length(v_message) > 200 then
        raise exception 'Please keep your message to 200 characters or fewer.';
    end if;

    insert into public.password_reset_requests (employee_id, message)
    values (v_employee_id, v_message);
end;
$$;

grant execute on function public.request_password_reset(text, text) to anon, authenticated;


-- admin_list_open_password_reset_requests() - open requests, oldest
-- first. Same shape/convention as admin_list_open_issues().
create or replace function public.admin_list_open_password_reset_requests()
returns table (
    request_id uuid,
    employee_id text,
    employee_name text,
    message text,
    created_at timestamptz
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
        prr.id,
        prr.employee_id,
        p.full_name,
        prr.message,
        prr.created_at
    from public.password_reset_requests prr
    join public.profiles p on p.employee_id = prr.employee_id
    where prr.status = 'open'
    order by prr.created_at asc;
end;
$$;

grant execute on function public.admin_list_open_password_reset_requests() to authenticated;


-- admin_resolve_password_reset_request(request_id) - dismisses one
-- request without necessarily resetting a password.
create or replace function public.admin_resolve_password_reset_request(p_request_id uuid)
returns public.password_reset_requests
language plpgsql
security definer
set search_path = public
as $$
declare
    v_admin_employee_id text;
    v_before public.password_reset_requests;
    v_request public.password_reset_requests;
begin
    select employee_id into v_admin_employee_id
    from public.profiles
    where auth_user_id = auth.uid()
      and status = 'active'
      and role in ('admin', 'super_admin');

    if v_admin_employee_id is null then
        raise exception 'Only an administrator can resolve a password reset request.';
    end if;

    select * into v_before
    from public.password_reset_requests
    where id = p_request_id;

    if v_before.id is null then
        raise exception 'Request not found.';
    end if;

    if v_before.status = 'resolved' then
        raise exception 'This request has already been resolved.';
    end if;

    update public.password_reset_requests
    set
        status = 'resolved',
        resolved_at = now(),
        resolved_by = v_admin_employee_id
    where id = p_request_id
    returning * into v_request;

    insert into public.audit_logs (
        actor_employee_id, action, entity_type, entity_id, old_data, new_data, reason
    ) values (
        v_admin_employee_id, 'RESOLVE_PASSWORD_RESET_REQUEST', 'password_reset_requests',
        v_request.id, to_jsonb(v_before), to_jsonb(v_request), null
    );

    return v_request;
end;
$$;

grant execute on function public.admin_resolve_password_reset_request(uuid) to authenticated;
