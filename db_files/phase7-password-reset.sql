-- ============================================================
-- PHASE 7 (slice) — ADMIN-MANAGED PASSWORD RESET
-- ============================================================
--
-- Two pieces:
--
--   1. admin_reset_employee_password(employee_id) - lets an admin
--      reset an employee's password to the fixed default "123456"
--      from that employee's detail screen. Employees authenticate
--      with an internal @internal.app address (see auth_service.dart)
--      that can't receive a real reset-link email, so this direct
--      reset is the whole password-recovery story for this app.
--      Updates auth.users.encrypted_password directly with
--      pgcrypto's crypt()/gen_salt('bf') - the same bcrypt hashing
--      Supabase Auth itself uses - rather than needing an Edge
--      Function with the service-role key. This bypasses Supabase
--      Auth's own hooks/webhooks, which is fine here since this app
--      doesn't use any.
--
--   2. password_reset_requests - lets a locked-out employee (who
--      can't sign in to use report_issue(), which requires
--      auth.uid()) submit a "please reset my password" request from
--      the login screen's Forgot Password form. request_password_reset()
--      is the only function granted to the `anon` role in this whole
--      app for exactly that reason. Admins see open requests on the
--      Employees tab (same DashboardSection pattern as Reported
--      Issues) and process them via admin_reset_employee_password(),
--      which auto-resolves any open request for that employee -
--      admin_resolve_password_reset_request() is there too, for
--      dismissing a request without a reset (e.g. a duplicate).
--
-- Reuses the existing public.issue_status enum ('open'/'resolved')
-- rather than declaring a duplicate one.
-- ============================================================


create table public.password_reset_requests (

    id uuid primary key default gen_random_uuid(),

    employee_id text not null
        references public.profiles(employee_id)
        on delete restrict,

    message text,

    status public.issue_status not null default 'open',

    created_at timestamptz not null default now(),

    resolved_at timestamptz,

    resolved_by text
        references public.profiles(employee_id)
        on delete restrict,

    constraint password_reset_requests_message_length
        check (message is null or length(message) <= 200),

    constraint password_reset_requests_resolved_dates
        check (
            (status = 'open' and resolved_at is null and resolved_by is null)
            or
            (status = 'resolved' and resolved_at is not null and resolved_by is not null)
        )
);

alter table public.password_reset_requests enable row level security;

-- Only admins can read requests - not even the requesting employee,
-- since they aren't authenticated when they submit one.
create policy password_reset_requests_select_admin
on public.password_reset_requests
for select
to authenticated
using (
    public.is_admin()
);

revoke all on public.password_reset_requests from anon;
grant select on public.password_reset_requests to authenticated;


-- ------------------------------------------------------------
-- request_password_reset(employee_id, message?) - submitted from
-- the (unauthenticated) Forgot Password screen. Granted to `anon`,
-- unlike every other write function in this app. employee_id is
-- validated against the same 9-digit format + must belong to a real
-- profile - message is capped at 200 chars server-side too, same
-- never-trust-the-client rule as report_issue().
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- admin_list_open_password_reset_requests() - for the Employees tab,
-- oldest first. Same shape/convention as admin_list_open_issues().
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- admin_resolve_password_reset_request(request_id) - dismisses one
-- request without necessarily resetting a password (e.g. a
-- duplicate, or it was already handled another way).
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- admin_reset_employee_password(employee_id) - resets the target
-- employee's password to "123456" (bcrypt-hashed, same as any other
-- Supabase Auth password). Also auto-resolves any open password
-- reset request(s) for that employee, since this action is exactly
-- what processing one means. Restricted to employee accounts, same
-- as admin_set_employee_status() - admin-over-admin password resets
-- are a later phase.
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

-- ============================================================
-- END PHASE 7 PASSWORD RESET (SLICE)
-- ============================================================
