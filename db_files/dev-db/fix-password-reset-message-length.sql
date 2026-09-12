-- ============================================================
-- FIX — password_reset_requests.message limit: 200 -> 50 chars
-- ============================================================
--
-- Matches issue_reports.message's existing 50-char limit.
-- ============================================================

alter table public.password_reset_requests
    drop constraint if exists password_reset_requests_message_length;

alter table public.password_reset_requests
    add constraint password_reset_requests_message_length
        check (message is null or length(message) <= 50);

create or replace function public.request_password_reset(
    p_employee_id text,
    p_message text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_employee_id text;
    v_message text;
begin
    v_employee_id := trim(p_employee_id);

    if v_employee_id !~ '^[0-9]{9}$' then
        raise exception 'Enter your 9-digit Employee ID.';
    end if;

    if not exists (
        select 1 from public.profiles
        where employee_id = v_employee_id
          and role = 'employee'
    ) then
        raise exception 'Employee ID not found.';
    end if;

    v_message := nullif(trim(p_message), '');
    if v_message is not null and length(v_message) > 50 then
        raise exception 'Please keep your message to 50 characters or fewer.';
    end if;

    insert into public.password_reset_requests (employee_id, message)
    values (v_employee_id, v_message);
end;
$$;

grant execute on function public.request_password_reset(text, text) to anon, authenticated;

-- ============================================================
-- END FIX
-- ============================================================
