-- ============================================================
-- PROD BOOTSTRAP 005 — HELPER FUNCTIONS
-- ============================================================
--
-- Placed before RLS (007) because policies call is_admin() /
-- is_active_user(); placed before triggers (006) because the trigger
-- functions themselves are defined here. This ordering differs from
-- the illustrative numbering in the original request (which listed
-- RLS at 005, helpers at 006) - swapped deliberately for dependency
-- safety, since a policy referencing a not-yet-created function
-- would fail on an empty database.
-- ============================================================


-- ------------------------------------------------------------
-- Haversine distance in meters between two lat/lon points.
-- Used by find_nearby_workplaces() and by start_/end_work_session()
-- to re-derive distance server-side rather than trusting the client.
-- ------------------------------------------------------------

create or replace function public._distance_meters(
    lat1 double precision,
    lon1 double precision,
    lat2 double precision,
    lon2 double precision
)
returns double precision
language sql
immutable
as $$
    select 2 * 6371000 * asin(
        sqrt(
            sin(radians(lat2 - lat1) / 2) ^ 2 +
            cos(radians(lat1)) * cos(radians(lat2)) *
            sin(radians(lon2 - lon1) / 2) ^ 2
        )
    );
$$;


-- ------------------------------------------------------------
-- Is the currently authenticated user an admin? Includes super_admin.
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


-- ------------------------------------------------------------
-- updated_at trigger function - used by profiles/workplaces/
-- work_sessions BEFORE UPDATE triggers (created in 006_triggers.sql).
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- New Supabase Auth user -> matching profiles row. Employee ID and
-- full name are expected in auth.users.raw_user_meta_data (set by
-- admin_create_employee() or Flutter's signUp() metadata). Role is
-- always 'employee' here - admin/super_admin accounts are never
-- created through this trigger.
-- ------------------------------------------------------------

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
