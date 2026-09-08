-- ============================================================
-- PROD BOOTSTRAP 006 — TRIGGERS
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


-- Auth account created -> matching profiles row created automatically.
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();
