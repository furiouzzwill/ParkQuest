-- =====================================================================
-- Migration 001: Add parks + park_geofences tables
-- =====================================================================
-- Additive migration for the "City Partner adds their own parks" flow.
-- Safe to run against a project that already has the base schema.
-- Does NOT touch cities/profiles/check_ins/earned_badges/city_invites.
--
-- To apply: Supabase Dashboard → SQL Editor → New query → paste → Run.
-- =====================================================================

create table if not exists public.parks (
  id             uuid        primary key default gen_random_uuid(),
  city_id        text        references public.cities(id) on delete set null,
  park_name      text        not null,
  park_type      text        not null default 'public_park',
  address        text,
  website        text,
  description    text,
  contact_name   text,
  contact_email  text,
  contact_phone  text,
  admin_user_id  uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists public.park_geofences (
  id             uuid        primary key default gen_random_uuid(),
  park_id        uuid        not null references public.parks(id) on delete cascade,
  name           text        not null,
  description    text,
  latitude       double precision not null,
  longitude      double precision not null,
  radius_meters  double precision not null default 50,
  reward_points  int         not null default 25,
  created_at     timestamptz not null default now()
);

create index if not exists idx_parks_city_id          on public.parks(city_id);
create index if not exists idx_parks_admin_user_id    on public.parks(admin_user_id);
create index if not exists idx_park_geofences_park_id on public.park_geofences(park_id);

alter table public.parks          enable row level security;
alter table public.park_geofences enable row level security;

drop policy if exists "anon_all" on public.parks;
drop policy if exists "anon_all" on public.park_geofences;

create policy "anon_all" on public.parks          for all using (true) with check (true);
create policy "anon_all" on public.park_geofences for all using (true) with check (true);
