-- ============================================================
-- PROD BOOTSTRAP 003 — TABLES
-- ============================================================
--
-- Each table below is the FINAL shape after folding in every
-- ALTER TABLE from later phase files (fresh installs don't need the
-- incremental history) plus the 7 DEV-approved length CHECK
-- constraints. Source of every column/constraint, for traceability:
--
--   profiles          - db-schema-V2.sql (+ 2 new length checks)
--   devices           - db-schema-V2.sql (unchanged; not yet used by
--                        the Flutter app, but explicitly required -
--                        see prod-bootstrap report)
--   workplaces        - db-schema-V2.sql (+ 1 new length check)
--   work_sessions     - db-schema-V2.sql, + verified_by
--                        (phase6-admin-dashboard.sql), + ended_by
--                        (phase7-admin-self-sessions-and-super-admin.sql)
--                        (+ 3 new length checks)
--   audit_logs        - db-schema-V2.sql (+ 1 new length check)
--   issue_reports     - db-schema-V2.sql addendum (identical
--                        duplicate in phase7-issue-reports.sql, not
--                        repeated here) - message length left at the
--                        original 50 chars, unchanged per instructions
--   password_reset_requests - phase7-password-reset.sql - message
--                        length capped at 50 chars, same limit as
--                        issue_reports.message
-- ============================================================


-- ============================================================
-- PROFILES
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

    -- Employee accounts use a 9-digit numeric ID (may start with 0,
    -- hence text not int). Admins/super_admins are provisioned
    -- directly in Supabase, so they're excluded from this rule.
    constraint profiles_employee_id_format
        check (role <> 'employee' or employee_id ~ '^[0-9]{9}$'),

    constraint profiles_full_name_not_empty
        check (length(trim(full_name)) > 0),

    constraint profiles_status_dates
        check (
            (status = 'active' and deactivated_at is null)
            or
            (status = 'inactive' and deactivated_at is not null)
        ),

    -- DEV-approved (2026-09-08): actual DEV max was 16 chars.
    constraint profiles_full_name_length
        check (length(full_name) <= 150),

    -- DEV-approved (2026-09-08): actual DEV max was 9 chars.
    -- Applies to every role - the original format check above only
    -- constrains role = 'employee', so this closes the previously
    -- open-ended admin/super_admin case too.
    constraint profiles_employee_id_length
        check (length(employee_id) <= 32)
);


-- ============================================================
-- DEVICES
-- ============================================================
--
-- Not currently read or written anywhere in the Flutter app -
-- pre-built schema for a planned-but-not-yet-implemented device
-- registration/revocation feature. Included unmodified because
-- section 7 of the bootstrap requirements explicitly lists it as a
-- required table.
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
-- WORKPLACES
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
        ),

    -- DEV-approved (2026-09-08): actual DEV max was 14 chars.
    constraint workplaces_name_length
        check (length(name) <= 120)
);


-- ============================================================
-- WORK SESSIONS
-- ============================================================
--
-- verified_by and ended_by were added to the live schema later
-- (phase6-admin-dashboard.sql, phase7-admin-self-sessions-and-super-admin.sql)
-- via ALTER TABLE; folded directly into CREATE TABLE here since this
-- is a fresh install.
-- ============================================================

create table public.work_sessions (

    id uuid primary key default gen_random_uuid(),

    employee_id text not null
        references public.profiles(employee_id)
        on delete restrict,

    workplace_id uuid
        references public.workplaces(id)
        on delete restrict,

    started_at timestamptz not null,

    -- NULL = currently working
    ended_at timestamptz,

    start_latitude double precision,
    start_longitude double precision,
    start_accuracy double precision,

    end_latitude double precision,
    end_longitude double precision,
    end_accuracy double precision,

    start_verification public.verification_method
        not null default 'unknown',

    end_verification public.verification_method
        not null default 'unknown',

    -- Used when automatic workplace detection fails at start
    manual_location_name text,

    -- Used when the end location doesn't match the start workplace
    -- (or the start workplace wasn't recognized) and the employee
    -- confirms their end location manually
    end_manual_location_name text,

    -- Who is vouching for this session's accuracy: the employee
    -- themself (auto-set when both start and end were GPS-verified,
    -- or always for an admin/super_admin's own session), or the
    -- admin who reviewed and corrected an unverified session. NULL
    -- means the session still needs admin review.
    verified_by text
        references public.profiles(employee_id)
        on delete restrict,

    -- Who actually performed the end action: the employee themself,
    -- or the admin who force-ended it from the dashboard. Distinct
    -- from verified_by (see phase7-admin-self-sessions-and-super-admin.sql).
    ended_by text
        references public.profiles(employee_id)
        on delete restrict,

    -- Who/what created the session
    source public.session_source
        not null default 'employee',

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
        ),

    -- DEV-approved (2026-09-08): actual DEV max was 10 chars (both).
    constraint work_sessions_manual_location_name_length
        check (length(manual_location_name) <= 120),

    constraint work_sessions_end_manual_location_name_length
        check (length(end_manual_location_name) <= 120),

    -- DEV-approved (2026-09-08): actual DEV max was 22 chars.
    constraint work_sessions_notes_length
        check (length(notes) <= 500)
);


-- ============================================================
-- AUDIT LOGS
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
        check (length(trim(entity_type)) > 0),

    -- DEV-approved (2026-09-08): actual DEV max was 22 chars.
    constraint audit_logs_reason_length
        check (length(reason) <= 500)
);


-- ============================================================
-- ISSUE REPORTS
-- ============================================================
--
-- message length intentionally left at 50 chars, unchanged - already
-- appropriately constrained, per instructions.
-- ============================================================

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


-- ============================================================
-- PASSWORD RESET REQUESTS
-- ============================================================
--
-- message length capped at 50 chars, same limit as issue_reports.message.
-- Reuses public.issue_status rather than a second status enum (matches
-- phase7-password-reset.sql).
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
        check (message is null or length(message) <= 50),

    constraint password_reset_requests_resolved_dates
        check (
            (status = 'open' and resolved_at is null and resolved_by is null)
            or
            (status = 'resolved' and resolved_at is not null and resolved_by is not null)
        )
);
