-- ============================================================
-- SECURITY WORKFORCE ATTENDANCE SYSTEM
-- V1 INITIAL DATABASE SCHEMA
-- PostgreSQL / Supabase
-- ============================================================
--
-- Core entities:
--   auth.users       -> Supabase-managed authentication
--   profiles         -> Employees / Administrators
--   devices          -> Registered employee devices
--   workplaces       -> Approved work locations
--   work_sessions    -> Employee attendance sessions
--   audit_logs       -> Administrative/system audit trail
--
-- All timestamps are stored as TIMESTAMPTZ (UTC internally).
-- ============================================================


-- ============================================================
-- 0. EXTENSIONS
-- ============================================================

-- gen_random_uuid() is available through pgcrypto.
create extension if not exists "pgcrypto";


-- ============================================================
-- 1. ENUM TYPES
-- ============================================================

create type public.user_role as enum (
    'employee',
    'admin'
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
    'system'
);


-- ============================================================
-- 2. PROFILES
-- ============================================================
--
-- Extends Supabase's auth.users table.
--
-- IMPORTANT:
-- Passwords are NOT stored here.
-- Supabase Auth manages passwords and authentication.
-- ============================================================

create table public.profiles (
    id uuid primary key
        references auth.users(id)
        on delete restrict,

    employee_number text not null,

    full_name text not null,

    role public.user_role not null default 'employee',

    status public.user_status not null default 'active',

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deactivated_at timestamptz,

    constraint profiles_employee_number_unique
        unique (employee_number),

    constraint profiles_full_name_not_empty
        check (length(trim(full_name)) > 0),

    constraint profiles_deactivation_consistency
        check (
            (status = 'active' and deactivated_at is null)
            or
            (status = 'inactive' and deactivated_at is not null)
        )
);


-- ============================================================
-- 3. DEVICES
-- ============================================================
--
-- Stores devices associated with users.
--
-- A user may have multiple historical devices.
-- Normally only authorized active devices should be usable.
-- ============================================================

create table public.devices (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
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

    constraint devices_revocation_consistency
        check (
            (status = 'active' and revoked_at is null)
            or
            (status = 'revoked' and revoked_at is not null)
        )
);


-- ============================================================
-- 4. WORKPLACES
-- ============================================================
--
-- An approved location where employees may work.
--
-- latitude / longitude = center point
-- radius_meters = permitted area
-- ============================================================

create table public.workplaces (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    latitude double precision not null,

    longitude double precision not null,

    radius_meters integer not null default 100,

    type public.workplace_type not null default 'temporary',

    status public.workplace_status not null default 'active',

    created_by uuid not null
        references public.profiles(id)
        on delete restrict,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deactivated_at timestamptz,

    constraint workplaces_name_not_empty
        check (length(trim(name)) > 0),

    constraint workplaces_latitude_valid
        check (latitude >= -90 and latitude <= 90),

    constraint workplaces_longitude_valid
        check (longitude >= -180 and longitude <= 180),

    constraint workplaces_radius_positive
        check (radius_meters > 0),

    constraint workplaces_radius_reasonable
        check (radius_meters <= 10000),

    constraint workplaces_deactivation_consistency
        check (
            (status = 'active' and deactivated_at is null)
            or
            (status = 'inactive' and deactivated_at is not null)
        )
);


-- ============================================================
-- 5. WORK SESSIONS
-- ============================================================
--
-- One row = one employee work session.
--
-- A session may cross midnight.
--
-- Example:
--
-- started_at = 2026-09-03 23:00 UTC
-- ended_at   = 2026-09-04 03:00 UTC
--
-- This naturally represents a 4-hour session.
-- ============================================================

create table public.work_sessions (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete restrict,

    workplace_id uuid
        references public.workplaces(id)
        on delete restrict,

    started_at timestamptz not null,

    ended_at timestamptz,

    -- Start GPS information
    start_latitude double precision,

    start_longitude double precision,

    start_accuracy double precision,

    -- End GPS information
    end_latitude double precision,

    end_longitude double precision,

    end_accuracy double precision,

    -- How the start/end location was verified
    start_verification public.verification_method
        not null default 'unknown',

    end_verification public.verification_method
        not null default 'unknown',

    -- Used when GPS cannot identify an approved workplace
    manual_location_name text,

    -- Who/what created the attendance action
    source public.session_source not null default 'employee',

    notes text,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    -- --------------------------------------------------------
    -- Constraints
    -- --------------------------------------------------------

    constraint work_sessions_end_after_start
        check (
            ended_at is null
            or ended_at >= started_at
        ),

    constraint work_sessions_start_latitude_valid
        check (
            start_latitude is null
            or (start_latitude >= -90 and start_latitude <= 90)
        ),

    constraint work_sessions_start_longitude_valid
        check (
            start_longitude is null
            or (start_longitude >= -180 and start_longitude <= 180)
        ),

    constraint work_sessions_end_latitude_valid
        check (
            end_latitude is null
            or (end_latitude >= -90 and end_latitude <= 90)
        ),

    constraint work_sessions_end_longitude_valid
        check (
            end_longitude is null
            or (end_longitude >= -180 and end_longitude <= 180)
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

    constraint work_sessions_manual_location_not_empty
        check (
            manual_location_name is null
            or length(trim(manual_location_name)) > 0
        ),

    -- If manually specifying a location, there must actually
    -- be a manual location value.
    constraint work_sessions_manual_verification_consistency
        check (
            start_verification <> 'manual'
            or manual_location_name is not null
            or workplace_id is not null
        )
);


-- ============================================================
-- 6. AUDIT LOGS
-- ============================================================
--
-- Records important actions performed by administrators/system.
--
-- old_data and new_data use JSONB so we can preserve exactly
-- what changed without creating a separate audit table for
-- every entity.
-- ============================================================

create table public.audit_logs (
    id uuid primary key default gen_random_uuid(),

    actor_user_id uuid not null
        references public.profiles(id)
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
-- 7. INDEXES
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

create index devices_user_id_idx
    on public.devices(user_id);

create index devices_status_idx
    on public.devices(status);

create index devices_user_status_idx
    on public.devices(user_id, status);


-- ------------------------------------------------------------
-- WORKPLACES
-- ------------------------------------------------------------

create index workplaces_status_idx
    on public.workplaces(status);

create index workplaces_type_idx
    on public.workplaces(type);

create index workplaces_created_by_idx
    on public.workplaces(created_by);


-- ------------------------------------------------------------
-- WORK SESSIONS
-- ------------------------------------------------------------

create index work_sessions_user_id_idx
    on public.work_sessions(user_id);

create index work_sessions_workplace_id_idx
    on public.work_sessions(workplace_id);

create index work_sessions_started_at_idx
    on public.work_sessions(started_at);

create index work_sessions_user_started_idx
    on public.work_sessions(user_id, started_at);

create index work_sessions_active_idx
    on public.work_sessions(user_id)
    where ended_at is null;


-- ------------------------------------------------------------
-- AUDIT LOGS
-- ------------------------------------------------------------

create index audit_logs_actor_user_id_idx
    on public.audit_logs(actor_user_id);

create index audit_logs_entity_idx
    on public.audit_logs(entity_type, entity_id);

create index audit_logs_created_at_idx
    on public.audit_logs(created_at);

create index audit_logs_action_idx
    on public.audit_logs(action);


-- ============================================================
-- 8. CRITICAL UNIQUE INDEX
-- ============================================================
--
-- An employee can NEVER have two active sessions.
--
-- An active session = ended_at IS NULL.
--
-- This is enforced by PostgreSQL itself.
--
-- Flutter MUST NOT be the only layer responsible for this.
-- ============================================================

create unique index work_sessions_one_active_per_user
    on public.work_sessions(user_id)
    where ended_at is null;


-- ============================================================
-- 9. DEVICE CONSTRAINT
-- ============================================================
--
-- A device identifier should not be registered as an active
-- device for multiple users simultaneously.
--
-- Historical/revoked records may remain.
-- ============================================================

create unique index devices_one_active_owner_per_identifier
    on public.devices(device_identifier)
    where status = 'active';


-- ============================================================
-- 10. UPDATED_AT FUNCTION
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
-- 11. UPDATED_AT TRIGGERS
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
-- 12. PROFILE CREATION FUNCTION
-- ============================================================
--
-- Automatically creates a profile whenever a new Supabase
-- Auth user is created.
--
-- NOTE:
-- The application/admin onboarding flow should provide:
--
--   employee_number
--   full_name
--   role
--
-- through user metadata.
--
-- Example metadata:
--
-- {
--   "employee_number": "EMP-1001",
--   "full_name": "Tala Abu Alamm",
--   "role": "employee"
-- }
--
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    requested_role public.user_role;
begin

    requested_role :=
        case
            when new.raw_user_meta_data->>'role' = 'admin'
                then 'admin'::public.user_role
            else
                'employee'::public.user_role
        end;

    insert into public.profiles (
        id,
        employee_number,
        full_name,
        role
    )
    values (
        new.id,

        coalesce(
            new.raw_user_meta_data->>'employee_number',
            'PENDING-' || substr(new.id::text, 1, 8)
        ),

        coalesce(
            new.raw_user_meta_data->>'full_name',
            'Unnamed User'
        ),

        requested_role
    );

    return new;
end;
$$;


-- ============================================================
-- 13. AUTH USER → PROFILE TRIGGER
-- ============================================================

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();


-- ============================================================
-- 14. HELPER FUNCTIONS FOR AUTHORIZATION
-- ============================================================

-- ------------------------------------------------------------
-- Check whether current user is an active administrator.
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
        where id = auth.uid()
          and role = 'admin'
          and status = 'active'
    );
$$;


-- ------------------------------------------------------------
-- Check whether current user is active.
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
        where id = auth.uid()
          and status = 'active'
    );
$$;


-- ============================================================
-- 15. ENABLE ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles
enable row level security;

alter table public.devices
enable row level security;

alter table public.workplaces
enable row level security;

alter table public.work_sessions
enable row level security;

alter table public.audit_logs
enable row level security;


-- ============================================================
-- 16. PROFILES RLS
-- ============================================================

-- Users may read their own profile.
create policy profiles_select_own
on public.profiles
for select
to authenticated
using (
    id = auth.uid()
);


-- Admins may read all profiles.
create policy profiles_admin_select
on public.profiles
for select
to authenticated
using (
    public.is_admin()
);


-- Admins may create/update profiles.
create policy profiles_admin_insert
on public.profiles
for insert
to authenticated
with check (
    public.is_admin()
);


create policy profiles_admin_update
on public.profiles
for update
to authenticated
using (
    public.is_admin()
)
with check (
    public.is_admin()
);


-- IMPORTANT:
-- No DELETE policy.
--
-- Employees are soft-deleted/deactivated.
-- Profiles should not be physically deleted through the app.


-- ============================================================
-- 17. DEVICES RLS
-- ============================================================

-- Employees can see their own devices.
create policy devices_select_own
on public.devices
for select
to authenticated
using (
    user_id = auth.uid()
);


-- Admins can see all devices.
create policy devices_admin_select
on public.devices
for select
to authenticated
using (
    public.is_admin()
);


-- Device registration should eventually go through a secure
-- server-side function/Edge Function.
--
-- We intentionally DO NOT give arbitrary clients an INSERT
-- policy here yet.


-- Admins can update/revoke devices.
create policy devices_admin_update
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
-- Historical device records should remain.


-- ============================================================
-- 18. WORKPLACES RLS
-- ============================================================

-- Active users may view active workplaces.
create policy workplaces_active_select
on public.workplaces
for select
to authenticated
using (
    status = 'active'
    and public.is_active_user()
);


-- Admins can view all workplaces, including inactive ones.
create policy workplaces_admin_select
on public.workplaces
for select
to authenticated
using (
    public.is_admin()
);


-- Only admins may create workplaces.
create policy workplaces_admin_insert
on public.workplaces
for insert
to authenticated
with check (
    public.is_admin()
    and created_by = auth.uid()
);


-- Only admins may update workplaces.
create policy workplaces_admin_update
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
-- 19. WORK SESSIONS RLS
-- ============================================================

-- Employees can read their own sessions.
create policy sessions_select_own
on public.work_sessions
for select
to authenticated
using (
    user_id = auth.uid()
);


-- Admins can read all sessions.
create policy sessions_admin_select
on public.work_sessions
for select
to authenticated
using (
    public.is_admin()
);


-- IMPORTANT:
-- We intentionally DO NOT allow normal clients to freely
-- INSERT or UPDATE work_sessions.
--
-- Start/end operations should go through controlled database
-- functions or Supabase Edge Functions.
--
-- This prevents a malicious client from doing:
--
--   started_at = '3 hours ago'
--   user_id = someone else
--   workplace_id = fake location
--
-- etc.


-- ============================================================
-- 20. AUDIT LOG RLS
-- ============================================================

-- Admins can read audit logs.
create policy audit_logs_admin_select
on public.audit_logs
for select
to authenticated
using (
    public.is_admin()
);


-- IMPORTANT:
-- No normal INSERT policy.
--
-- Audit records should be generated server-side.
-- This prevents users from creating fake audit records.
--
-- We will implement secure audit logging functions later.


-- ============================================================
-- 21. PRIVILEGES
-- ============================================================
--
-- Explicitly restrict access to the public schema tables.
--
-- Supabase's API uses the authenticated/anon roles.
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
grant select on public.audit_logs to authenticated;


-- Admin/controlled modifications will be handled by
-- RLS + secure functions rather than unrestricted table access.


-- ============================================================
-- 22. COMMENTS
-- ============================================================

comment on table public.profiles is
'Application-level employee/admin profiles extending Supabase auth.users.';

comment on table public.devices is
'Registered employee devices used as an additional attendance security signal.';

comment on table public.workplaces is
'Approved geographic locations where employees may work.';

comment on table public.work_sessions is
'Employee work attendance sessions. Timestamps are stored in UTC.';

comment on table public.audit_logs is
'Immutable-style audit history of important administrative/system actions.';

comment on column public.work_sessions.started_at is
'Official server-generated UTC start timestamp.';

comment on column public.work_sessions.ended_at is
'Official server-generated UTC end timestamp.';

comment on column public.work_sessions.manual_location_name is
'Human-entered location when automatic workplace detection is unavailable.';


-- ============================================================
-- END OF V1 INITIAL SCHEMA
-- ============================================================