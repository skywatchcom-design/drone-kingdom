-- Sign-up with a commander name and password (approved sketch Tnvwhfaq4KMqSS85z45tfx).
-- The game signs players up with a made-up address built from a hash of the name, so no email
-- is ever asked for or sent; the name itself lives here, unique regardless of case.

alter table public.players drop constraint if exists players_name_check;
alter table public.players add constraint players_name_check
  check (char_length(name) between 3 and 14 and name ~ '^[A-Za-z0-9_א-ת]+$');

create unique index if not exists players_name_lower_idx on public.players (lower(name));

-- Whether a commander name is still free. Callable before signing up; it reveals nothing but
-- a yes or no.
create or replace function public.name_available(n text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (select 1 from public.players where lower(name) = lower(n));
$$;

revoke all on function public.name_available(text) from public;
grant execute on function public.name_available(text) to anon, authenticated;
