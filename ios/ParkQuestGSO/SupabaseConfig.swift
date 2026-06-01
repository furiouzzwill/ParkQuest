//
//  SupabaseConfig.swift
//  ParkQuestGSO
//
//  ────────────────────────────────────────────────────────────────
//  HOW TO SET UP
//  ────────────────────────────────────────────────────────────────
//  1. Create a project at https://supabase.com
//  2. Go to Project Settings → API
//  3. Copy "Project URL" → paste into projectURL below
//  4. Copy "anon / public" key → paste into anonKey below
//  5. Run the SQL in the comment at the bottom of this file in
//     your Supabase SQL Editor (Database → SQL Editor → New query)
//  ────────────────────────────────────────────────────────────────

enum SupabaseConfig {
    static let projectURL = "https://uhxifrgcwjrjqrxayjvn.supabase.co"
    static let anonKey    = "sb_publishable_R4Srb_e1mrQSqZrVhQwnQQ_0c27I74L"
}

// ────────────────────────────────────────────────────────────────
// SUPABASE SQL — run this once in your SQL Editor
// ────────────────────────────────────────────────────────────────
//
// -- 0. Cities (one row per deployed city instance)
// create table public.cities (
//   id          text        primary key,   -- e.g. 'gso'
//   name        text        not null,      -- e.g. 'Greensboro'
//   state       text        not null,      -- e.g. 'NC'
//   created_at  timestamptz not null default now()
// );
// insert into public.cities (id, name, state) values ('gso', 'Greensboro', 'NC');
//
// -- 1. Profiles (one row per device / user)
// --    user_type: 'explorer' (default end user) or 'city_admin' (city account manager)
// --    city_id:   references the city this account belongs to
// create table public.profiles (
//   id          uuid        primary key,
//   username    text        not null,
//   user_type   text        not null default 'explorer',
//   city_id     text        references cities(id) on delete set null,
//   created_at  timestamptz not null default now(),
//   updated_at  timestamptz not null default now()
// );
//
// -- 2. Quest check-ins
// create table public.check_ins (
//   id            uuid        primary key default gen_random_uuid(),
//   user_id       uuid        not null references profiles(id) on delete cascade,
//   quest_id      text        not null,
//   park_id       text        not null,
//   checked_in_at timestamptz not null default now(),
//   unique(user_id, quest_id)   -- prevents duplicate check-ins
// );
//
// -- 3. Earned badges
// create table public.earned_badges (
//   id        uuid        primary key default gen_random_uuid(),
//   user_id   uuid        not null references profiles(id) on delete cascade,
//   park_id   text        not null,
//   earned_at timestamptz not null default now(),
//   unique(user_id, park_id)
// );
//
// -- 4. Enable Row Level Security (recommended even for MVP)
// alter table public.profiles      enable row level security;
// alter table public.check_ins     enable row level security;
// alter table public.earned_badges enable row level security;
//
// -- 5. Permissive policies (tighten with auth later)
// create policy "anon_all" on public.profiles      for all using (true) with check (true);
// create policy "anon_all" on public.check_ins     for all using (true) with check (true);
// create policy "anon_all" on public.earned_badges for all using (true) with check (true);
//
// ────────────────────────────────────────────────────────────────
