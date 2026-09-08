-- ============================================================
-- PROD BOOTSTRAP 007 — ROW LEVEL SECURITY + GRANTS
-- ============================================================
--
-- profiles_update_admin below is the FINAL, narrowed version from
-- phase7-role-management.sql (using role = 'employee' in both USING
-- and WITH CHECK), not the original db-schema-V2.sql version that
-- let any admin update any profile including role. The original
-- version is never created here - going straight to the final
-- policy avoids the create-then-drop-then-recreate dance the DEV
-- database went through historically, with no difference in the
-- resulting behavior.
-- ============================================================


-- ------------------------------------------------------------
-- Enable RLS on every table
-- ------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.workplaces enable row level security;
alter table public.work_sessions enable row level security;
alter table public.audit_logs enable row level security;
alter table public.issue_reports enable row level security;
alter table public.password_reset_requests enable row level security;


-- ------------------------------------------------------------
-- PROFILES
-- ------------------------------------------------------------

-- Users can see their own profile.
create policy profiles_select_own
on public.profiles
for select
to authenticated
using (
    auth_user_id = auth.uid()
);

-- Admins can see all profiles.
create policy profiles_select_admin
on public.profiles
for select
to authenticated
using (
    public.is_admin()
);

-- Admins can update EMPLOYEE rows only (final, narrowed version -
-- see header). Every profile write that touches role/status goes
-- through a SECURITY DEFINER function regardless; this policy can
-- never be used to create or modify an admin/super_admin row.
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

-- No DELETE policy - employees are soft-deactivated instead.


-- ------------------------------------------------------------
-- DEVICES
-- ------------------------------------------------------------

-- Employees can view their own devices.
create policy devices_select_own
on public.devices
for select
to authenticated
using (
    employee_id = (
        select employee_id
        from public.profiles
        where auth_user_id = auth.uid()
    )
);

-- Admins can view all devices.
create policy devices_select_admin
on public.devices
for select
to authenticated
using (
    public.is_admin()
);

-- Admins can update/revoke devices.
create policy devices_update_admin
on public.devices
for update
to authenticated
using (
    public.is_admin()
)
with check (
    public.is_admin()
);

-- No DELETE policy - device history should remain.


-- ------------------------------------------------------------
-- WORKPLACES
-- ------------------------------------------------------------

-- Active users can view active workplaces.
create policy workplaces_select_active
on public.workplaces
for select
to authenticated
using (
    status = 'active'
    and public.is_active_user()
);

-- Admins can see all workplaces.
create policy workplaces_select_admin
on public.workplaces
for select
to authenticated
using (
    public.is_admin()
);

-- Admins can create workplaces.
create policy workplaces_insert_admin
on public.workplaces
for insert
to authenticated
with check (
    public.is_admin()
    and created_by = (
        select employee_id
        from public.profiles
        where auth_user_id = auth.uid()
    )
);

-- Admins can update workplaces.
create policy workplaces_update_admin
on public.workplaces
for update
to authenticated
using (
    public.is_admin()
)
with check (
    public.is_admin()
);

-- No DELETE policy - workplaces are deactivated instead.


-- ------------------------------------------------------------
-- WORK SESSIONS
-- ------------------------------------------------------------

-- Employees can view their own sessions.
create policy work_sessions_select_own
on public.work_sessions
for select
to authenticated
using (
    employee_id = (
        select employee_id
        from public.profiles
        where auth_user_id = auth.uid()
    )
);

-- Admins can view all sessions.
create policy work_sessions_select_admin
on public.work_sessions
for select
to authenticated
using (
    public.is_admin()
);

-- IMPORTANT: intentionally NO INSERT/UPDATE/DELETE policy for normal
-- authenticated clients. Starting/ending/editing sessions goes
-- through SECURITY DEFINER functions only (008_session_functions.sql),
-- so the client can never submit a fabricated started_at, another
-- employee's employee_id, or a fake workplace.


-- ------------------------------------------------------------
-- AUDIT LOGS
-- ------------------------------------------------------------

-- Only admins can read audit logs.
create policy audit_logs_select_admin
on public.audit_logs
for select
to authenticated
using (
    public.is_admin()
);

-- No normal INSERT policy - audit records are generated server-side
-- only, by the SECURITY DEFINER functions that write them.


-- ------------------------------------------------------------
-- ISSUE REPORTS
-- ------------------------------------------------------------

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

-- No INSERT/UPDATE policy for normal clients - see report_issue()
-- and admin_resolve_issue() in 011_issue_functions.sql.


-- ------------------------------------------------------------
-- PASSWORD RESET REQUESTS
-- ------------------------------------------------------------

-- Only admins can read requests - not even the requesting employee,
-- since they aren't authenticated when they submit one.
create policy password_reset_requests_select_admin
on public.password_reset_requests
for select
to authenticated
using (
    public.is_admin()
);

-- No INSERT/UPDATE policy for normal clients - see
-- request_password_reset() (granted to anon) and
-- admin_resolve_password_reset_request() in 012_password_reset_functions.sql.


-- ============================================================
-- TABLE-LEVEL GRANTS
-- ============================================================
--
-- RLS is the real gate; these grants set the outer bound (anon has
-- none, authenticated can attempt a SELECT which RLS then filters).
-- ============================================================

revoke all on public.profiles from anon;
revoke all on public.devices from anon;
revoke all on public.workplaces from anon;
revoke all on public.work_sessions from anon;
revoke all on public.audit_logs from anon;
revoke all on public.issue_reports from anon;
revoke all on public.password_reset_requests from anon;

grant select on public.profiles to authenticated;
grant select on public.devices to authenticated;
grant select on public.workplaces to authenticated;
grant select on public.work_sessions to authenticated;
grant select on public.audit_logs to authenticated;
grant select on public.issue_reports to authenticated;
grant select on public.password_reset_requests to authenticated;
