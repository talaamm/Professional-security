-- One-time setup: a simple log of which db_files/prod-bootstrap/* files
-- have actually been applied to PROD. Run this once, then insert one row
-- every time you (re-)apply a bootstrap file to prod, e.g.:
--
--   insert into public._prod_migrations_log (filename, notes)
--   values ('009_workplace_functions.sql', 'added admin_workplace_sessions_for_month');
--
-- Check what's been applied any time with:
--   select * from public._prod_migrations_log order by applied_at;

create table if not exists public._prod_migrations_log (
    id bigint generated always as identity primary key,
    filename text not null,
    applied_at timestamptz not null default now(),
    notes text
);

-- Backfill: everything confirmed applied as of the 2026-09-23 diagnostic
-- (exact original apply dates unknown, hence the shared backfill note).
insert into public._prod_migrations_log (filename, notes) values
    ('001_extensions.sql', 'backfilled 2026-09-23 - confirmed applied, exact date unknown'),
    ('002_types.sql', 'backfilled 2026-09-23 - confirmed applied, exact date unknown'),
    ('003_tables.sql', 'backfilled 2026-09-23 - confirmed applied incl. 2026-09-12 message-length change (verified via pg_constraint)'),
    ('004_indexes.sql', 'backfilled 2026-09-23 - confirmed applied, exact date unknown'),
    ('005_helper_functions.sql', 'backfilled 2026-09-23 - confirmed applied, exact date unknown'),
    ('006_triggers.sql', 'backfilled 2026-09-23 - confirmed applied, exact date unknown'),
    ('007_rls_policies.sql', 'backfilled 2026-09-23 - confirmed applied, exact date unknown'),
    ('008_session_functions.sql', 'backfilled 2026-09-23 - confirmed applied incl. 2026-09-12 body updates'),
    ('011_issue_functions.sql', 'backfilled 2026-09-23 - confirmed applied, exact date unknown'),
    ('012_password_reset_functions.sql', 'backfilled 2026-09-23 - confirmed applied incl. 2026-09-12 body updates'),
    ('create_first_super_admin.sql', 'backfilled 2026-09-23 - confirmed applied, exact date unknown');

-- Run these two AFTER you've applied 009 and 010 above:
-- insert into public._prod_migrations_log (filename, notes) values
-- ('009_workplace_functions.sql', 'applied 2026-09-23 - added admin_workplace_sessions_for_month (was missing since 2026-09-17)'),
-- ('010_admin_functions.sql', 'applied 2026-09-23 - added admin_monthly_active_employees (was missing since 2026-09-17)');
