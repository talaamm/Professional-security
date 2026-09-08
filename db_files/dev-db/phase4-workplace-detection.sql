-- ============================================================
-- PHASE 4 — GPS + WORKPLACE DETECTION
-- ============================================================
--
-- Adds workplace detection to the start-work flow:
--
--   1. find_nearby_workplaces(lat, lon)
--      Read-only. Returns active workplaces whose configured
--      radius_meters covers the given coordinates, closest first.
--      Used by the app to let the employee confirm/pick a
--      workplace before starting.
--
--   2. start_work_session(...) is REPLACED to take GPS + an
--      optional workplace pick / manual location name.
--
-- IMPORTANT (core principle from requirements-and-architecture_V1.md
-- section 1.3 and 16.4): the client can suggest a workplace, but it
-- can never simply assert "I am at Event Hall A, verified=true".
-- start_work_session() re-derives the distance itself from the
-- submitted coordinates before it will mark a session verified.
-- A tampered workplace_id that isn't actually within range is
-- rejected, not silently trusted.
-- ============================================================


-- ------------------------------------------------------------
-- Haversine distance in meters between two lat/lon points.
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
-- Find active workplaces within their own allowed radius of the
-- given coordinates. Runs with the caller's own privileges, so
-- the existing workplaces_select_active RLS policy (active users
-- can see active workplaces) applies exactly as it does elsewhere.
-- ------------------------------------------------------------

create or replace function public.find_nearby_workplaces(
    p_latitude double precision,
    p_longitude double precision
)
returns table (
    workplace_id uuid,
    name text,
    distance_meters double precision
)
language sql
stable
set search_path = public
as $$
    select
        w.id,
        w.name,
        public._distance_meters(p_latitude, p_longitude, w.latitude, w.longitude)
    from public.workplaces w
    where w.status = 'active'
      and public._distance_meters(p_latitude, p_longitude, w.latitude, w.longitude)
            <= w.radius_meters
    order by 3 asc;
$$;

grant execute on function public.find_nearby_workplaces(double precision, double precision)
    to authenticated;


-- ------------------------------------------------------------
-- start_work_session now requires GPS coordinates + accuracy,
-- and either a workplace_id (re-validated server-side) or a
-- manual_location_name (recorded as an unverified/manual session
-- for later admin review).
-- ------------------------------------------------------------

drop function if exists public.start_work_session();

create or replace function public.start_work_session(
    p_latitude double precision,
    p_longitude double precision,
    p_accuracy double precision,
    p_workplace_id uuid default null,
    p_manual_location_name text default null
)
returns public.work_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
    v_employee_id text;
    v_status public.user_status;
    v_workplace public.workplaces;
    v_distance double precision;
    v_verification public.verification_method;
    v_manual_name text;
    v_session public.work_sessions;
begin
    select employee_id, status
    into v_employee_id, v_status
    from public.profiles
    where auth_user_id = auth.uid();

    if v_employee_id is null then
        raise exception 'Profile not found for the current user.';
    end if;

    if v_status <> 'active' then
        raise exception 'Your account is inactive. Please contact an administrator.';
    end if;

    if exists (
        select 1
        from public.work_sessions
        where employee_id = v_employee_id
          and ended_at is null
    ) then
        raise exception 'You already have an active work session.';
    end if;

    if p_workplace_id is not null then
        select * into v_workplace
        from public.workplaces
        where id = p_workplace_id
          and status = 'active';

        if v_workplace.id is null then
            raise exception 'The selected workplace is no longer available.';
        end if;

        v_distance := public._distance_meters(
            p_latitude, p_longitude,
            v_workplace.latitude, v_workplace.longitude
        );

        if v_distance > v_workplace.radius_meters then
            raise exception 'You are not currently within range of the selected workplace.';
        end if;

        v_verification := 'verified';
    else
        v_manual_name := nullif(trim(p_manual_location_name), '');

        if v_manual_name is null then
            raise exception 'Enter a workplace name or select a detected workplace.';
        end if;

        v_verification := 'manual';
    end if;

    insert into public.work_sessions (
        employee_id,
        workplace_id,
        started_at,
        start_latitude,
        start_longitude,
        start_accuracy,
        start_verification,
        manual_location_name,
        source
    )
    values (
        v_employee_id,
        p_workplace_id,
        now(),
        p_latitude,
        p_longitude,
        p_accuracy,
        v_verification,
        v_manual_name,
        'employee'
    )
    on conflict (employee_id) where ended_at is null do nothing
    returning * into v_session;

    if v_session.id is null then
        raise exception 'You already have an active work session.';
    end if;

    return v_session;
end;
$$;

grant execute on function public.start_work_session(
    double precision, double precision, double precision, uuid, text
) to authenticated;


-- ============================================================
-- END PHASE 4 WORKPLACE DETECTION
-- ============================================================
