-- ============================================================
-- PROD BOOTSTRAP 011 — ISSUE REPORT FUNCTIONS
-- ============================================================
--
-- Source: phase7-issue-reports.sql. Only the 3 functions are taken
-- from that file - its CREATE TYPE issue_status / CREATE TABLE
-- issue_reports / RLS policies / grants are identical duplicates of
-- what db-schema-V2.sql's addendum already declares (002_types.sql,
-- 003_tables.sql, 007_rls_policies.sql), so they are not repeated
-- here. See the prod-bootstrap report, section F, for detail.
-- ============================================================


-- report_issue(message) - employee_id resolved from auth.uid(),
-- never taken from the client. Length enforced here too.
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


-- admin_list_open_issues() - open reports, oldest first.
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


-- admin_resolve_issue(issue_id) - marks one report done.
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
