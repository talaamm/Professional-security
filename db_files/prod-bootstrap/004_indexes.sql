-- ============================================================
-- PROD BOOTSTRAP 004 — INDEXES
-- ============================================================
--
-- Final DEV-approved index set (2026-09-08). work_sessions_employee_id_idx
-- is intentionally NOT recreated here - it was dropped on DEV as
-- redundant, fully superseded by work_sessions_employee_started_idx's
-- leftmost column. The 4 new partial indexes below are included from
-- the start, unlike DEV where they were added after the fact.
-- ============================================================


-- ------------------------------------------------------------
-- PROFILES
-- ------------------------------------------------------------

create index profiles_role_idx
    on public.profiles(role);

create index profiles_status_idx
    on public.profiles(status);

create index profiles_full_name_idx
    on public.profiles(full_name);


-- ------------------------------------------------------------
-- DEVICES
-- ------------------------------------------------------------

create index devices_employee_id_idx
    on public.devices(employee_id);

create index devices_status_idx
    on public.devices(status);

-- A device identifier can only belong to one active employee.
-- Old/revoked device records remain for history.
create unique index devices_one_active_owner
    on public.devices(device_identifier)
    where status = 'active';


-- ------------------------------------------------------------
-- WORKPLACES
-- ------------------------------------------------------------

create index workplaces_status_idx
    on public.workplaces(status);

create index workplaces_type_idx
    on public.workplaces(type);


-- ------------------------------------------------------------
-- WORK SESSIONS
-- ------------------------------------------------------------
-- (work_sessions_employee_id_idx deliberately omitted - see header)

create index work_sessions_workplace_id_idx
    on public.work_sessions(workplace_id);

create index work_sessions_started_at_idx
    on public.work_sessions(started_at);

create index work_sessions_employee_started_idx
    on public.work_sessions(employee_id, started_at);

-- Only one active (ended_at null) session per employee at a time.
-- This is a business-rule constraint, not the user's login session.
create unique index work_sessions_one_active_per_employee
    on public.work_sessions(employee_id)
    where ended_at is null;

-- DEV-approved (2026-09-08): admin_active_sessions() dashboard query.
create index work_sessions_active_started_idx
    on public.work_sessions(started_at)
    where ended_at is null;

-- DEV-approved (2026-09-08): admin_unverified_sessions() review queue.
create index work_sessions_unverified_idx
    on public.work_sessions(started_at)
    where ended_at is not null
    and verified_by is null;


-- ------------------------------------------------------------
-- AUDIT LOGS
-- ------------------------------------------------------------

create index audit_logs_actor_idx
    on public.audit_logs(actor_employee_id);

create index audit_logs_entity_idx
    on public.audit_logs(entity_type, entity_id);

create index audit_logs_created_at_idx
    on public.audit_logs(created_at);


-- ------------------------------------------------------------
-- ISSUE REPORTS
-- ------------------------------------------------------------

-- DEV-approved (2026-09-08): admin_list_open_issues() review queue.
create index issue_reports_open_idx
    on public.issue_reports(created_at)
    where status = 'open';


-- ------------------------------------------------------------
-- PASSWORD RESET REQUESTS
-- ------------------------------------------------------------

-- DEV-approved (2026-09-08): admin_list_open_password_reset_requests().
create index password_reset_requests_open_idx
    on public.password_reset_requests(created_at)
    where status = 'open';
