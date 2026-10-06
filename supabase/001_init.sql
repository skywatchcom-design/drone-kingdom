-- SkyWatch backend, step 1: players, cloud save, base snapshot for attackers, shield.
-- Run once in Supabase: SQL Editor -> New query -> paste -> Run.
-- Players sign in anonymously (device id); linking an account is optional later.

create table if not exists public.players (
  id           uuid primary key references auth.users(id) on delete cascade,
  name         text not null default 'Commander' check (char_length(name) between 2 and 16),
  trophies     int  not null default 0 check (trophies >= 0),
  hq_level     int  not null default 1,
  shield_until timestamptz,
  save         jsonb not null default '{}'::jsonb,   -- the full private save (same JSON as user://save.json)
  base         jsonb not null default '{}'::jsonb,   -- public snapshot attackers see: structures, walls, seed, pad
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists players_trophies_idx on public.players (trophies);

alter table public.players enable row level security;

-- A player reads and writes only their own row (including the private save).
create policy "own row: select" on public.players for select using (auth.uid() = id);
create policy "own row: insert" on public.players for insert with check (auth.uid() = id);
create policy "own row: update" on public.players for update using (auth.uid() = id) with check (auth.uid() = id);

-- Attackers never read other rows directly (that would expose saves).
-- They go through this function, which returns only the public part of a few opponents
-- near the caller's trophies, skipping shielded players and the caller.
create or replace function public.find_opponents(max_count int default 3)
returns table (id uuid, name text, trophies int, hq_level int, base jsonb)
language sql
security definer
set search_path = public
as $$
  select p.id, p.name, p.trophies, p.hq_level, p.base
  from public.players p
  where p.id <> auth.uid()
    and p.base <> '{}'::jsonb
    and (p.shield_until is null or p.shield_until < now())
  order by abs(p.trophies - coalesce((select trophies from public.players where id = auth.uid()), 0)), random()
  limit least(max_count, 10);
$$;

revoke all on function public.find_opponents(int) from public, anon;
grant execute on function public.find_opponents(int) to authenticated;

-- Keep updated_at honest.
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create trigger players_touch before update on public.players
for each row execute function public.touch_updated_at();
