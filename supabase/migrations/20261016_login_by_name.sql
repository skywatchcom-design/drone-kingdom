-- Players who signed up with an email (13+) can also log in with their commander name
-- (owner, 16.10.2026: after a password reset he tried his name and the new password and it
-- failed, because name logins only worked for accounts without an email). Given the name and
-- the password, this returns the account's email only when the password is right, so it never
-- tells anyone else which email belongs to a name. The game then logs in with that email.
create or replace function public.login_email(p_name text, p_password text)
returns text
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
	addr text;
	hash text;
begin
	select u.email, u.encrypted_password into addr, hash
	from public.players p
	join auth.users u on u.id = p.id
	where lower(p.name) = lower(trim(p_name));
	if addr is null or hash is null or p_password is null then
		return null;
	end if;
	if extensions.crypt(p_password, hash) = hash then
		return addr;
	end if;
	return null;
end;
$$;

revoke all on function public.login_email(text, text) from public;
grant execute on function public.login_email(text, text) to anon, authenticated;
