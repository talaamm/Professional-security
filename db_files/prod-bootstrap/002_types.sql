-- ============================================================
-- PROD BOOTSTRAP 002 — ENUM TYPES
-- ============================================================
--
-- issue_status is deduplicated here: db-schema-V2.sql's addendum
-- and phase7-issue-reports.sql both declare it identically. Declared
-- once; also used by password_reset_requests (phase7-password-reset.sql
-- deliberately reuses it instead of declaring a second status enum).
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

create type public.issue_status as enum (
    'open',
    'resolved'
);
