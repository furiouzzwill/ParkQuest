-- =====================================================================
-- ParkQuest — Complete Supabase Schema
-- =====================================================================
-- Recreates every table the iOS app currently uses. Paste this entire
-- file into Supabase → SQL Editor → New query → Run.
--
-- Safe to re-run: uses `drop ... if exists` and `create ... if not exists`
-- so you can iterate without wiping the whole project.
--
-- If you're setting up a fresh Supabase project:
--   1. Create the project at https://supabase.com
--   2. Project Settings → API → copy the "Project URL" + "anon" key
--      into ios/ParkQuestGSO/SupabaseConfig.swift
--   3. Authentication → Providers → Email → turn OFF "Confirm email"
--      (otherwise newly signed-up users can't get a session)
--   4. Paste this SQL into the SQL Editor and run it
-- =====================================================================


-- ---------------------------------------------------------------------
-- Clean slate (safe on a fresh project — the drops just no-op)
-- ---------------------------------------------------------------------
drop table if exists public.park_geofences cascade;
drop table if exists public.parks          cascade;
drop table if exists public.city_invites   cascade;
drop table if exists public.earned_badges  cascade;
drop table if exists public.check_ins      cascade;
drop table if exists public.profiles       cascade;
drop table if exists public.cities         cascade;


-- ---------------------------------------------------------------------
-- Cities
-- One row per city deployment. Greensboro is seeded below.
-- ---------------------------------------------------------------------
create table public.cities (
  id          text        primary key,     -- e.g. 'gso'
  name        text        not null,        -- e.g. 'Greensboro'
  state       text        not null,        -- e.g. 'NC'
  created_at  timestamptz not null default now()
);


-- ---------------------------------------------------------------------
-- Profiles
-- One row per user. `id` is the Supabase auth user id when auth is used,
-- or a device UUID for legacy local-auth installs (both flows are
-- currently supported in the iOS app).
-- ---------------------------------------------------------------------
create table public.profiles (
  id          uuid        primary key,
  username    text        not null,
  user_type   text        not null default 'explorer'
              check (user_type in ('explorer', 'city_admin')),
  city_id     text        references public.cities(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);


-- ---------------------------------------------------------------------
-- Check-ins
-- One row per (user, quest). The `unique` constraint prevents dupes so
-- the iOS `Prefer: resolution=ignore-duplicates` header quietly no-ops
-- when the user re-taps a completed quest.
-- ---------------------------------------------------------------------
create table public.check_ins (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null references public.profiles(id) on delete cascade,
  quest_id      text        not null,
  park_id       text        not null,
  checked_in_at timestamptz not null default now(),
  unique (user_id, quest_id)
);


-- ---------------------------------------------------------------------
-- Earned badges
-- One row per (user, park) once the user completes the park's quest set.
-- ---------------------------------------------------------------------
create table public.earned_badges (
  id        uuid        primary key default gen_random_uuid(),
  user_id   uuid        not null references public.profiles(id) on delete cascade,
  park_id   text        not null,
  earned_at timestamptz not null default now(),
  unique (user_id, park_id)
);


-- ---------------------------------------------------------------------
-- City invites
-- One-time codes used by city partners to claim their city_admin account
-- at signup. Atomic redemption is enforced client-side by filtering the
-- PATCH on `redeemed_at is null` — see SupabaseService.redeemInvite().
-- ---------------------------------------------------------------------
create table public.city_invites (
  code         text        primary key,     -- e.g. 'ASHEVILLE-2025'
  city_id      text        not null references public.cities(id) on delete cascade,
  created_at   timestamptz not null default now(),
  redeemed_at  timestamptz,
  redeemed_by  uuid                          -- not a FK; just an audit trail
);


-- ---------------------------------------------------------------------
-- Parks
-- Parks that city partners have set up via the in-app wizard. Separate
-- from the hardcoded SeedData parks the explorer sees today — those
-- (Barber Park, etc.) are compiled into the app. Rows here are the
-- ones a real city admin creates at runtime.
-- ---------------------------------------------------------------------
create table public.parks (
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
  admin_user_id  uuid,                        -- profile id of the creator; loose ref
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);


-- ---------------------------------------------------------------------
-- Park geofences (landmarks)
-- One row per landmark inside a park. The iOS wizard drops these via
-- either "use current GPS" or by tapping on a map.
-- ---------------------------------------------------------------------
create table public.park_geofences (
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


-- ---------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------
create index if not exists idx_profiles_city_id       on public.profiles(city_id);
create index if not exists idx_check_ins_user_id      on public.check_ins(user_id);
create index if not exists idx_earned_badges_user_id  on public.earned_badges(user_id);
create index if not exists idx_parks_city_id          on public.parks(city_id);
create index if not exists idx_parks_admin_user_id    on public.parks(admin_user_id);
create index if not exists idx_park_geofences_park_id on public.park_geofences(park_id);


-- ---------------------------------------------------------------------
-- Row Level Security
-- Permissive policies for the demo — anon key can do everything. Tighten
-- these before production (auth.uid() checks on writes, at minimum).
-- ---------------------------------------------------------------------
alter table public.cities         enable row level security;
alter table public.profiles       enable row level security;
alter table public.check_ins      enable row level security;
alter table public.earned_badges  enable row level security;
alter table public.city_invites   enable row level security;
alter table public.parks          enable row level security;
alter table public.park_geofences enable row level security;

create policy "anon_all" on public.cities         for all using (true) with check (true);
create policy "anon_all" on public.profiles       for all using (true) with check (true);
create policy "anon_all" on public.check_ins      for all using (true) with check (true);
create policy "anon_all" on public.earned_badges  for all using (true) with check (true);
create policy "anon_all" on public.city_invites   for all using (true) with check (true);
create policy "anon_all" on public.parks          for all using (true) with check (true);
create policy "anon_all" on public.park_geofences for all using (true) with check (true);


-- =====================================================================
-- SEED DATA
-- =====================================================================

-- Greensboro — the default city that the demo/explorer flow uses.
insert into public.cities (id, name, state)
values ('gso', 'Greensboro', 'NC')
on conflict (id) do nothing;

-- Sample invite code so you can test the City Partner signup flow right
-- after running this script. Sign up with role "City Partner" and this
-- code to claim the Greensboro admin account.
--
-- Add more codes per new city like this:
--   insert into public.cities (id, name, state) values ('avl', 'Asheville', 'NC');
--   insert into public.city_invites (code, city_id) values ('ASHEVILLE-2025', 'avl');
insert into public.city_invites (code, city_id)
values ('GREENSBORO-2025', 'gso')
on conflict (code) do nothing;
