-- ============================================================
-- EMPLOYEE WORK HOURS APP
-- V1 DATABASE SCHEMA
-- PostgreSQL / Supabase
-- ============================================================
--
-- Tables:
--   auth.users       -> Supabase authentication
--   profiles         -> Employees and administrators
--   devices          -> Registered employee devices
--   workplaces       -> Approved work locations
--   work_sessions    -> Employee work sessions
--   audit_logs       -> Important system/admin actions
--
-- Time:
--   All timestamps are stored as TIMESTAMPTZ.
--   PostgreSQL stores them consistently and the app/reporting
--   layer can display them in the desired local timezone.
-- ============================================================


-- ============================================================
-- 1. EXTENSIONS
-- ============================================================

create extension if not exists "pgcrypto";


-- ============================================================
-- 2. ENUMS
-- ============================================================

create type public.user_role as enum (
    'employee',
    'admin',
    'super_admin'
);

create type public.user_status as enum (
    'active',
    'inactive'
);

create type public.device_platform as enum (
    'ios',
    'android'
);

create type public.device_status as enum (
    'active',
    'revoked'
);

create type public.workplace_type as enum (
    'permanent',
    'temporary'
);

create type public.workplace_status as enum (
    'active',
    'inactive'
);

create type public.verification_method as enum (
    'verified',
    'manual',
    'unknown'
);

create type public.session_source as enum (
    'employee',
    'admin',
    'super_admin',
    'system'
);


-- ============================================================
-- 3. PROFILES
-- ============================================================
--
-- One profile = one employee/user.
--
-- employee_id:
--   Company's real employee ID.
--
-- auth_user_id:
--   Supabase Auth UUID.
--   Used ONLY to connect this profile to auth.users.
--
-- Passwords are NOT stored here.
-- ============================================================

create table public.profiles (

    employee_id text primary key,

    auth_user_id uuid not null unique
        references auth.users(id)
        on delete restrict,

    full_name text not null,

    role public.user_role not null default 'employee',

    status public.user_status not null default 'active',

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deactivated_at timestamptz,

    constraint profiles_employee_id_not_empty
        check (length(trim(employee_id)) > 0),

    constraint profiles_full_name_not_empty
        check (length(trim(full_name)) > 0),

    constraint profiles_status_dates
        check (
            (status = 'active' and deactivated_at is null)
            or
            (status = 'inactive' and deactivated_at is not null)
        )
);


-- ============================================================
-- 4. DEVICES
-- ============================================================
--
-- Employees can have more than one device over time.
--
-- Example:
--
-- Employee 00427
--     iPhone  -> revoked
--     Android -> active
--
-- Device identity is an additional security signal.
-- It is NOT proof of physical presence by itself.
-- ============================================================

create table public.devices (

    id uuid primary key default gen_random_uuid(),

    employee_id text not null
        references public.profiles(employee_id)
        on delete restrict,

    device_identifier text not null,

    platform public.device_platform not null,

    device_name text,

    app_version text,

    status public.device_status not null default 'active',

    registered_at timestamptz not null default now(),

    last_seen_at timestamptz,

    revoked_at timestamptz,

    constraint devices_identifier_not_empty
        check (length(trim(device_identifier)) > 0),

    constraint devices_status_dates
        check (
            (status = 'active' and revoked_at is null)
            or
            (status = 'revoked' and revoked_at is not null)
        )
);


-- ============================================================
-- 5. WORKPLACES
-- ============================================================
--
-- Represents an approved work location.
--
-- latitude + longitude:
--   Center of the workplace.
--
-- radius_meters:
--   Allowed GPS radius around the center.
-- ============================================================

create table public.workplaces (

    id uuid primary key default gen_random_uuid(),

    name text not null,

    latitude double precision not null,

    longitude double precision not null,

    radius_meters integer not null default 100,

    type public.workplace_type not null default 'temporary',

    status public.workplace_status not null default 'active',

    created_by text not null
        references public.profiles(employee_id)
        on delete restrict,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deactivated_at timestamptz,

    constraint workplaces_name_not_empty
        check (length(trim(name)) > 0),

    constraint workplaces_latitude_valid
        check (latitude between -90 and 90),

    constraint workplaces_longitude_valid
        check (longitude between -180 and 180),

    constraint workplaces_radius_positive
        check (radius_meters > 0),

    constraint workplaces_radius_reasonable
        check (radius_meters <= 10000),

    constraint workplaces_status_dates
        check (
            (status = 'active' and deactivated_at is null)
            or
            (status = 'inactive' and deactivated_at is not null)
        )
);


-- ============================================================
-- 6. WORK SESSIONS
-- ============================================================
--
-- One row = one work session.
--
-- Example:
--
-- 2026-09-03 23:00
--       ->
-- 2026-09-04 03:00
--
-- This is a valid 4-hour session.
--
-- ended_at = NULL means the employee is currently working.
-- ============================================================

create table public.work_sessions (

    id uuid primary key default gen_random_uuid(),

    employee_id text not null
        references public.profiles(employee_id)
        on delete restrict,

    workplace_id uuid
        references public.workplaces(id)
        on delete restrict,

    -- Start time
    started_at timestamptz not null,

    -- End time
    -- NULL = currently working
    ended_at timestamptz,

    -- GPS when starting
    start_latitude double precision,
    start_longitude double precision,
    start_accuracy double precision,

    -- GPS when ending
    end_latitude double precision,
    end_longitude double precision,
    end_accuracy double precision,

    -- How the start was verified
    start_verification public.verification_method
        not null default 'unknown',

    -- How the end was verified
    end_verification public.verification_method
        not null default 'unknown',

    -- Used when automatic workplace detection fails at start
    manual_location_name text,

    -- Used when the end location doesn't match the start workplace
    -- (or the start workplace wasn't recognized) and the employee
    -- confirms their end location manually
    end_manual_location_name text,

    -- Who/what created the session
    source public.session_source
        not null default 'employee',

    -- Additional explanation
    notes text,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),


    -- --------------------------------------------------------
    -- Validation
    -- --------------------------------------------------------

    constraint work_sessions_end_after_start
        check (
            ended_at is null
            or ended_at >= started_at
        ),

    constraint work_sessions_start_latitude_valid
        check (
            start_latitude is null
            or start_latitude between -90 and 90
        ),

    constraint work_sessions_start_longitude_valid
        check (
            start_longitude is null
            or start_longitude between -180 and 180
        ),

    constraint work_sessions_end_latitude_valid
        check (
            end_latitude is null
            or end_latitude between -90 and 90
        ),

    constraint work_sessions_end_longitude_valid
        check (
            end_longitude is null
            or end_longitude between -180 and 180
        ),

    constraint work_sessions_start_accuracy_valid
        check (
            start_accuracy is null
            or start_accuracy >= 0
        ),

    constraint work_sessions_end_accuracy_valid
        check (
            end_accuracy is null
            or end_accuracy >= 0
        ),

    constraint work_sessions_manual_location_valid
        check (
            manual_location_name is null
            or length(trim(manual_location_name)) > 0
        ),

    constraint work_sessions_end_manual_location_valid
        check (
            end_manual_location_name is null
            or length(trim(end_manual_location_name)) > 0
        )
);


-- ============================================================
-- 7. AUDIT LOGS
-- ============================================================
--
-- Records important actions.
--
-- Examples:
--
-- Admin changed an employee's role.
-- Admin edited a work session.
-- Admin ended a session.
-- Employee was deactivated.
-- Workplace was created.
-- Device was revoked.
-- ============================================================

create table public.audit_logs (

    id uuid primary key default gen_random_uuid(),

    actor_employee_id text not null
        references public.profiles(employee_id)
        on delete restrict,

    action text not null,

    entity_type text not null,

    entity_id uuid,

    old_data jsonb,

    new_data jsonb,

    reason text,

    created_at timestamptz not null default now(),

    constraint audit_logs_action_not_empty
        check (length(trim(action)) > 0),

    constraint audit_logs_entity_type_not_empty
        check (length(trim(entity_type)) > 0)
);


-- ============================================================
-- 8. INDEXES
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

create index work_sessions_employee_id_idx
    on public.work_sessions(employee_id);

create index work_sessions_workplace_id_idx
    on public.work_sessions(workplace_id);

create index work_sessions_started_at_idx
    on public.work_sessions(started_at);

create index work_sessions_employee_started_idx
    on public.work_sessions(employee_id, started_at);


-- ------------------------------------------------------------
-- AUDIT LOGS
-- ------------------------------------------------------------

create index audit_logs_actor_idx
    on public.audit_logs(actor_employee_id);

create index audit_logs_entity_idx
    on public.audit_logs(entity_type, entity_id);

create index audit_logs_created_at_idx
    on public.audit_logs(created_at);


-- ============================================================
-- 9. ONE ACTIVE WORK SESSION PER EMPLOYEE
-- ============================================================
--
-- IMPORTANT:
--
-- This is NOT the user's login session.
--
-- It means the employee can only be clocked into ONE work
-- session at a time.
--
-- Example:
--
-- Employee 00427
--
-- 08:00 -> 12:00    finished
-- 13:00 -> 17:00    finished
-- 18:00 -> NULL      currently working
--
-- Another NULL session for 00427 is not allowed.
-- ============================================================

create unique index work_sessions_one_active_per_employee
    on public.work_sessions(employee_id)
    where ended_at is null;


-- ============================================================
-- 10. ONE ACTIVE DEVICE OWNER
-- ============================================================
--
-- A device identifier can only belong to one active employee.
--
-- Old/revoked device records remain for history.
-- ============================================================

create unique index devices_one_active_owner
    on public.devices(device_identifier)
    where status = 'active';


-- ============================================================
-- 11. UPDATED_AT FUNCTION
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;


-- ============================================================
-- 12. UPDATED_AT TRIGGERS
-- ============================================================

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();


create trigger workplaces_set_updated_at
before update on public.workplaces
for each row
execute function public.set_updated_at();


create trigger work_sessions_set_updated_at
before update on public.work_sessions
for each row
execute function public.set_updated_at();


-- ============================================================
-- 13. NEW SUPABASE USER → PROFILE
-- ============================================================
--
-- When a Supabase Auth account is created, create the matching
-- profile.
--
-- The employee ID and name are expected in user metadata.
--
-- Example:
--
-- {
--   "employee_id": "00427",
--   "full_name": "Tala Abu Alamm"
-- }
--
-- IMPORTANT:
-- Admin/super_admin creation should eventually be controlled
-- through a secure admin function instead of allowing clients
-- to freely choose their role.
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

    insert into public.profiles (
        employee_id,
        auth_user_id,
        full_name,
        role
    )
    values (
        new.raw_user_meta_data->>'employee_id',
        new.id,
        coalesce(
            new.raw_user_meta_data->>'full_name',
            'Unnamed User'
        ),
        'employee'
    );

    return new;

end;
$$;


-- ============================================================
-- 14. AUTH → PROFILE TRIGGER
-- ============================================================

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();


-- ============================================================
-- 15. AUTHORIZATION HELPERS
-- ============================================================

-- ------------------------------------------------------------
-- Is the currently authenticated user an admin?
-- Includes super_admin.
-- ------------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.profiles
        where auth_user_id = auth.uid()
          and status = 'active'
          and role in ('admin', 'super_admin')
    );
$$;


-- ------------------------------------------------------------
-- Is the currently authenticated user a super admin?
-- ------------------------------------------------------------

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.profiles
        where auth_user_id = auth.uid()
          and status = 'active'
          and role = 'super_admin'
    );
$$;


-- ------------------------------------------------------------
-- Is the currently authenticated user active?
-- ------------------------------------------------------------

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.profiles
        where auth_user_id = auth.uid()
          and status = 'active'
    );
$$;


-- ============================================================
-- 16. ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles enable row level security;

alter table public.devices enable row level security;

alter table public.workplaces enable row level security;

alter table public.work_sessions enable row level security;

alter table public.audit_logs enable row level security;


-- ============================================================
-- 17. PROFILE POLICIES
-- ============================================================

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


-- Admins can update employee information.
--
-- Role-management restrictions will be handled by secure
-- functions later.
create policy profiles_update_admin
on public.profiles
for update
to authenticated
using (
    public.is_admin()
)
with check (
    public.is_admin()
);


-- No DELETE policy.
--
-- Employees are soft-deactivated instead.


-- ============================================================
-- 18. DEVICE POLICIES
-- ============================================================

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


-- No DELETE policy.
-- Device history should remain.


-- ============================================================
-- 19. WORKPLACE POLICIES
-- ============================================================

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


-- No DELETE policy.
-- Workplaces are deactivated instead.


-- ============================================================
-- 20. WORK SESSION POLICIES
-- ============================================================

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


-- IMPORTANT:
--
-- There is intentionally NO INSERT/UPDATE policy for normal
-- authenticated clients here.
--
-- Starting/ending/editing sessions should go through secure
-- database functions or Supabase Edge Functions.
--
-- This prevents the Flutter client from simply submitting:
--
-- started_at = yesterday
-- employee_id = another employee
-- fake workplace
--
-- etc.


-- ============================================================
-- 21. AUDIT LOG POLICIES
-- ============================================================

-- Only admins can read audit logs.
create policy audit_logs_select_admin
on public.audit_logs
for select
to authenticated
using (
    public.is_admin()
);


-- No normal INSERT policy.
--
-- Audit records should be generated server-side.


-- ============================================================
-- 22. BASIC GRANTS
-- ============================================================

revoke all on public.profiles from anon;
revoke all on public.devices from anon;
revoke all on public.workplaces from anon;
revoke all on public.work_sessions from anon;
revoke all on public.audit_logs from anon;


grant select on public.profiles to authenticated;
grant select on public.devices to authenticated;
grant select on public.workplaces to authenticated;
grant select on public.work_sessions to authenticated;


-- Audit logs are read through RLS.
grant select on public.audit_logs to authenticated;


-- ============================================================
-- END OF V1 SCHEMA
-- ============================================================