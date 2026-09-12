-- ============================================================
-- FIX — "column end_verification is of type verification_method
-- but expression is of type text"
-- ============================================================
--
-- end_work_session_for_logout() (phase7-admin-self-sessions-and-
-- super-admin.sql) sets:
--   end_verification = case when v_is_admin then 'verified' else 'manual' end
--
-- Both branches are string literals with no other typed context, so
-- Postgres's type resolution falls back to `text` for the CASE
-- result (the "all inputs unknown -> text" rule) instead of leaving
-- it as an unresolved literal. Assigning that to the enum column
-- directly in an UPDATE ... SET then fails, since text -> enum has
-- no implicit assignment cast (a single bare literal like 'manual'
-- works elsewhere because an unresolved literal gets cast straight
-- to the target enum type instead).
--
-- Fix: cast the CASE expression explicitly. Rest of the function is
-- unchanged.
-- ============================================================

create or replace function public.end_work_session_for_logout()
returns public.work_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
    v_employee_id text;
    v_role public.user_role;
    v_is_admin boolean;
    v_active public.work_sessions;
    v_session public.work_sessions;
begin
    select employee_id, role into v_employee_id, v_role
    from public.profiles
    where auth_user_id = auth.uid();

    if v_employee_id is null then
        raise exception 'Profile not found for the current user.';
    end if;

    v_is_admin := v_role in ('admin', 'super_admin');

    select * into v_active
    from public.work_sessions
    where employee_id = v_employee_id
      and ended_at is null;

    if v_active.id is null then
        raise exception 'No active work session was found.';
    end if;

    update public.work_sessions
    set
        ended_at = now(),
        end_verification = (case when v_is_admin then 'verified' else 'manual' end)::public.verification_method,
        ended_by = v_employee_id,
        verified_by = case when v_is_admin then v_employee_id else verified_by end,
        notes = 'Session ended automatically: logged out while working.',
        updated_at = now()
    where id = v_active.id
    returning * into v_session;

    return v_session;
end;
$$;

grant execute on function public.end_work_session_for_logout() to authenticated;

-- ============================================================
-- END FIX
-- ============================================================
