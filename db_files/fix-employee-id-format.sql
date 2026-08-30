-- ============================================================
-- FIX — EMPLOYEE ID MUST BE EXACTLY 9 DIGITS
-- ============================================================
--
-- The Flutter Register/Login screens now enforce this client-side
-- (numeric keyboard, digits-only input, exactly 9 characters), but
-- per CLAUDE.md's own rule ("never trust frontend validation
-- alone"), the database needs the same rule as a backstop - a
-- client-side check can always be bypassed by calling
-- supabase.auth.signUp() directly.
--
-- Scoped to role = 'employee' only: admins/super_admins are
-- provisioned directly in Supabase by you, not through this app's
-- Register screen, so their employee_id isn't subject to this rule.
--
-- Added NOT VALID so it does not retroactively fail on any existing
-- test rows that don't match this format - it only applies going
-- forward, to every new insert/update. Once you've confirmed all
-- existing employee rows already conform (or cleaned up any that
-- don't), you can optionally run:
--   alter table public.profiles validate constraint profiles_employee_id_format;
-- to also confirm the existing data - this is not required for the
-- constraint to protect new data.
-- ============================================================

alter table public.profiles
    drop constraint if exists profiles_employee_id_format;

alter table public.profiles
    add constraint profiles_employee_id_format
        check (role <> 'employee' or employee_id ~ '^[0-9]{9}$')
        not valid;

-- ============================================================
-- END FIX
-- ============================================================
