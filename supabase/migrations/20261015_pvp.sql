-- Real attacks between players (owner's picks, 15.10.2026, on sketch NW7rzSLQsYyZ2g54BgcdTx):
-- search with "Next", Noa's welcome-back with a defense log and a damage map, and the soft rules:
-- the attacker takes up to 10% of the bank plus half of what waits in generators and pumps, the
-- defender gets an 8-hour shield after every attack, and nobody under Command Tower 2 can be attacked.
-- The game works out the loot from the defender's save (Pvp.loot_pool); the server only caps it.
-- pvp_trophies() must stay the same as Pvp.trophy_change in scripts/data/pvp.gd.

alter table public.players add column if not exists trophies int not null default 0;
alter table public.players add column if not exists shield_until timestamptz;
-- Someone is looking at or attacking this base right now; nobody else gets it until then.
alter table public.players add column if not exists lock_until timestamptz;
alter table public.players add column if not exists lock_by uuid;

create index if not exists players_hq_trophies_idx on public.players (hq_level, trophies);

create table if not exists public.attacks (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  attacker uuid references public.players(id) on delete set null,
  attacker_name text not null,
  defender uuid not null references public.players(id) on delete cascade,
  stars int not null check (stars between 0 and 3),
  percent int not null check (percent between 0 and 100),
  coins int not null default 0 check (coins >= 0),
  fuel int not null default 0 check (fuel >= 0),
  -- The defender's trophy change (negative when the attack won).
  trophies int not null default 0,
  -- For the damage map: {destroyed: [[c, r]], traps: [{cell, type, hits}], walls: [[c, r, d]], entry: [x, z], army: {type: n}}.
  report jsonb not null default '{}'::jsonb,
  -- The defender's game has taken the loss off its bank and shown the attack.
  seen boolean not null default false
);

create index if not exists attacks_defender_idx on public.attacks (defender, created_at desc);
alter table public.attacks enable row level security;
drop policy if exists "defenders read their attacks" on public.attacks;
create policy "defenders read their attacks" on public.attacks for select to authenticated using (defender = auth.uid());

-- The attacker's trophy change: a win earns 20/24/28 for 1/2/3 stars against an equal opponent, a
-- loss costs 12; up to 8 more (or less) against a stronger (or weaker) one.
create or replace function public.pvp_trophies(stars int, mine int, theirs int)
returns int
language sql
immutable
as $$
  select case when stars > 0
    then least(40, greatest(10, 16 + 4 * stars + least(8, greatest(-8, floor((theirs - mine) / 20.0)::int))))
    else -least(20, greatest(5, 12 - least(8, greatest(-8, floor((theirs - mine) / 20.0)::int))))
  end;
$$;

-- A base to attack: a real player within one Command Tower level, close in trophies, with no
-- shield and nobody else on it. Locks it for 5 minutes. Null when there is nobody (the game then
-- sends the player to an Iron Fang outpost instead). `skip` holds the bases "Next" passed over.
create or replace function public.find_opponent(skip uuid[] default '{}')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  me public.players;
  foe public.players;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  select * into me from public.players where id = auth.uid();
  if not found then
    raise exception 'no player';
  end if;
  -- Let go of the base this player was looking at before.
  update public.players set lock_until = null, lock_by = null where lock_by = me.id;
  select * into foe from public.players p
   where p.id <> me.id
     and not (p.id = any(coalesce(skip, '{}')))
     and p.hq_level >= 2
     and abs(p.hq_level - me.hq_level) <= 1
     and (p.shield_until is null or p.shield_until < now())
     and (p.lock_until is null or p.lock_until < now())
     and p.save ? 'structures'
   order by abs(p.trophies - me.trophies) + random() * 150
   limit 1
   for update skip locked;
  if not found then
    return null;
  end if;
  update public.players set lock_until = now() + interval '5 minutes', lock_by = me.id where id = foe.id;
  return jsonb_build_object(
    'id', foe.id, 'name', foe.name, 'hq_level', foe.hq_level, 'trophies', foe.trophies,
    'structures', foe.save -> 'structures', 'walls', coalesce(foe.save -> 'walls', '[]'::jsonb),
    'coins', coalesce((foe.save ->> 'coins')::int, 0), 'fuel', coalesce((foe.save ->> 'fuel')::int, 0),
    'city_seed', coalesce((foe.save ->> 'city_seed')::int, 7));
end;
$$;

-- The end of an attack. `foe` null means an Iron Fang outpost (only the attacker's trophies move).
-- Against a player: trophies both ways, the defender's 8-hour shield, the attacker's own shield
-- ends, and a row for the defender's log. Returns {change, trophies} for the attacker.
create or replace function public.report_attack(foe uuid, stars int, percent int, coins int, fuel int, report jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  me public.players;
  them public.players;
  change int;
  theirs int;
  total int;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  select * into me from public.players where id = auth.uid() for update;
  if not found then
    raise exception 'no player';
  end if;
  stars := least(3, greatest(0, coalesce(stars, 0)));
  percent := least(100, greatest(0, coalesce(percent, 0)));
  if foe is null then
    change := public.pvp_trophies(stars, me.trophies, me.trophies);
    update public.players set trophies = greatest(0, trophies + change) where id = me.id returning trophies into total;
  else
    select * into them from public.players where id = foe for update;
    if not found or foe = me.id then
      raise exception 'no such opponent';
    end if;
    change := public.pvp_trophies(stars, me.trophies, them.trophies);
    theirs := case when change > 0 then -round(change * 0.6)::int else -change end;
    update public.players set trophies = greatest(0, trophies + theirs),
      shield_until = now() + interval '8 hours', lock_until = null, lock_by = null
      where id = foe;
    insert into public.attacks (attacker, attacker_name, defender, stars, percent, coins, fuel, trophies, report)
      values (me.id, me.name, foe, stars, percent,
        least(greatest(coalesce(coins, 0), 0), floor(coalesce((them.save ->> 'coins')::int, 0) * 0.1)::int + 5000),
        least(greatest(coalesce(fuel, 0), 0), floor(coalesce((them.save ->> 'fuel')::int, 0) * 0.1)::int + 5000),
        theirs, coalesce(report, '{}'::jsonb));
    update public.players set trophies = greatest(0, trophies + change), shield_until = null
      where id = me.id returning trophies into total;
  end if;
  return jsonb_build_object('change', change, 'trophies', total);
end;
$$;

-- On the way into the game: the attacks the player hasn't seen yet (marked seen now, so their
-- loss is taken once), their trophies and shield, and the server's clock. Keeps the last 20 attacks.
create or replace function public.settle_attacks()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  me public.players;
  unseen jsonb;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  select * into me from public.players where id = auth.uid();
  if not found then
    raise exception 'no player';
  end if;
  with marked as (
    update public.attacks set seen = true where defender = me.id and not seen returning *
  )
  select coalesce(jsonb_agg(to_jsonb(marked) - 'defender' - 'attacker' - 'seen' order by created_at desc), '[]'::jsonb)
    into unseen from marked;
  delete from public.attacks where defender = me.id and id not in (
    select id from public.attacks where defender = me.id order by created_at desc limit 20);
  return jsonb_build_object('unseen', unseen, 'trophies', me.trophies, 'shield_until', me.shield_until, 'now', now());
end;
$$;

revoke all on function public.find_opponent(uuid[]) from public;
revoke all on function public.report_attack(uuid, int, int, int, int, jsonb) from public;
revoke all on function public.settle_attacks() from public;
grant execute on function public.find_opponent(uuid[]) to authenticated;
grant execute on function public.report_attack(uuid, int, int, int, int, jsonb) to authenticated;
grant execute on function public.settle_attacks() to authenticated;
