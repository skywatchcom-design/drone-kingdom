-- Age screen, email from 13 and agreeing to the terms (owner, 7.10.2026).
-- Only the birth month and year are kept. Players under 13 sign up without an email (COPPA), so
-- their auth address stays the made-up one; older players sign up with their own email.

alter table public.players add column if not exists birth_year int check (birth_year between 1900 and 2100);
alter table public.players add column if not exists birth_month int check (birth_month between 1 and 12);
alter table public.players add column if not exists is_child boolean not null default true;
alter table public.players add column if not exists terms_version text;
alter table public.players add column if not exists terms_accepted_at timestamptz;

-- Deletes the signed-in player's account and everything in it (stores require this in the game).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
