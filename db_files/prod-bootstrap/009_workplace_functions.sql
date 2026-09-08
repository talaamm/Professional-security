-- ============================================================
-- PROD BOOTSTRAP 009 — WORKPLACE FUNCTIONS
-- ============================================================
--
-- Direct workplace CRUD (create/update/deactivate) goes through the
-- RLS policies in 007, not a function - only the read-only proximity
-- lookup needs one, since it runs the haversine calculation.
-- ============================================================

-- Find active workplaces within their own allowed radius of the
-- given coordinates. NOT security definer - runs with the caller's
-- own privileges, so workplaces_select_active RLS applies exactly as
-- it does everywhere else.
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
