-- ============================================================
-- PHASE 7 (slice) — EMPLOYEE ISSUE REPORTS
-- ============================================================
--
-- Lets an employee send a short (<=50 char) note to admins via a
-- "Having an issue? Tell the admin" button on Home, and lets admins
-- see/resolve those reports from the Employees tab.
--
-- Same conventions as the rest of this app:
--   - No INSERT/UPDATE policy for normal clients - writes go
--     through report_issue() / admin_resolve_issue(), which resolve
--     the caller's own identity server-side rather than trusting
--     anything the client sends.
--   - admin_list_open_issues() is SECURITY DEFINER with its own
--     explicit is_admin() check, same as the other admin_* reads.
--   - Resolving an issue writes an audit_logs row, same as every
--     other admin action in this app.
-- ============================================================


create type public.issue_status as enum (
    'open',
    'resolved'
);


create table public.issue_reports (

    id uuid primary key default gen_random_uuid(),

    employee_id text not null
        references public.profiles(employee_id)
        on delete restrict,

    message text not null,

    status public.issue_status not null default 'open',

    created_at timestamptz not null default now(),

    resolved_at timestamptz,

    resolved_by text
        references public.profiles(employee_id)
        on delete restrict,

    constraint issue_reports_message_length
        check (
            length(trim(message)) > 0
            and length(message) <= 50
        ),

    constraint issue_reports_resolved_dates
        check (
            (status = 'open' and resolved_at is null and resolved_by is null)
            or
            (status = 'resolved' and resolved_at is not null and resolved_by is not null)
        )
);

alter table public.issue_reports enable row level security;


-- Employees can see their own reports.
create policy issue_reports_select_own
on public.issue_reports
for select
to authenticated
using (
    employee_id = (
        select employee_id
        from public.profiles
        where auth_user_id = auth.uid()
    )
);


-- Admins can see all reports.
create policy issue_reports_select_admin
on public.issue_reports
for select
to authenticated
using (
    public.is_admin()
);


revoke all on public.issue_reports from anon;
grant select on public.issue_reports to authenticated;


-- ------------------------------------------------------------
-- report_issue(message) - an employee raises an issue. The
-- employee_id is resolved from auth.uid(), never taken from the
-- client. Length is enforced here too (never trust frontend
-- validation alone).
-- ------------------------------------------------------------

create or replace function public.report_issue(p_message text)
returns public.issue_reports
language plpgsql
security definer
set search_path = public
as $$
declare
    v_employee_id text;
    v_message text;
    v_report public.issue_reports;
begin
    select employee_id into v_employee_id
    from public.profiles
    where auth_user_id = auth.uid();

    if v_employee_id is null then
        raise exception 'Profile not found for the current user.';
    end if;

    v_message := trim(p_message);

    if v_message = '' then
        raise exception 'Please describe the issue.';
    end if;

    if length(v_message) > 50 then
        raise exception 'Please keep the description to 50 characters or fewer.';
    end if;

    insert into public.issue_reports (employee_id, message)
    values (v_employee_id, v_message)
    returning * into v_report;

    return v_report;
end;
$$;

grant execute on function public.report_issue(text) to authenticated;


-- ------------------------------------------------------------
-- admin_list_open_issues() - open reports for the Employees tab,
-- oldest first (a review queue, same convention as
-- admin_unverified_sessions()).
-- ------------------------------------------------------------

create or replace function public.admin_list_open_issues()
returns table (
    issue_id uuid,
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
        ir.id,
        ir.employee_id,
        p.full_name,
        ir.message,
        ir.created_at
    from public.issue_reports ir
    join public.profiles p on p.employee_id = ir.employee_id
    where ir.status = 'open'
    order by ir.created_at asc;
end;
$$;

grant execute on function public.admin_list_open_issues() to authenticated;


-- ------------------------------------------------------------
-- admin_resolve_issue(issue_id) - marks one report done.
-- ------------------------------------------------------------

create or replace function public.admin_resolve_issue(p_issue_id uuid)
returns public.issue_reports
language plpgsql
security definer
set search_path = public
as $$
declare
    v_admin_employee_id text;
    v_before public.issue_reports;
    v_report public.issue_reports;
begin
    select employee_id into v_admin_employee_id
    from public.profiles
    where auth_user_id = auth.uid()
      and status = 'active'
      and role in ('admin', 'super_admin');

    if v_admin_employee_id is null then
        raise exception 'Only an administrator can resolve an issue report.';
    end if;

    select * into v_before
    from public.issue_reports
    where id = p_issue_id;

    if v_before.id is null then
        raise exception 'Issue report not found.';
    end if;

    if v_before.status = 'resolved' then
        raise exception 'This issue has already been resolved.';
    end if;

    update public.issue_reports
    set
        status = 'resolved',
        resolved_at = now(),
        resolved_by = v_admin_employee_id
    where id = p_issue_id
    returning * into v_report;

    insert into public.audit_logs (
        actor_employee_id, action, entity_type, entity_id, old_data, new_data, reason
    ) values (
        v_admin_employee_id, 'RESOLVE_ISSUE', 'issue_reports', v_report.id,
        to_jsonb(v_before), to_jsonb(v_report), null
    );

    return v_report;
end;
$$;

grant execute on function public.admin_resolve_issue(uuid) to authenticated;

-- ============================================================
-- END PHASE 7 ISSUE REPORTS (SLICE)
-- ============================================================
