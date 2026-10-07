---
name: supabase
description: Change the SkyWatch Supabase backend safely - write a migration file, run it on the project, check the flow from inside Godot against the real server, and clean up test accounts. Use for any table, function, policy or auth-setting change, or when the owner says /supabase.
---

# Change the server

Project `nlaylfcbijvdwbbcuqhj` (free tier). The owner's Management API token is in
`tmp/supabase_token.txt` (git-ignored; full access to the account, so touch only this project and
say what will change before structural changes). The game talks to it from `scripts/autoload/cloud.gd`.

1. **Write a migration** in `supabase/migrations/<yyyymmdd>_<what>.sql` (idempotent: `if not exists`,
   `create or replace`). Keep row level security on; players may only read and write their own row
   unless the feature needs more, and then through a `security definer` function with a narrow job.
2. **Run it**: `python tools/supabase_sql.py -f supabase/migrations/<file>.sql`, and check the result
   with a query. Auth settings: `python tools/supabase_sql.py --auth-get <keys>`; change them with
   the `api("PATCH", "/config/auth", {...})` helper in that file.
3. **Check from the game**: extend `scripts/dev/cloud_check.gd` for the new flow and run
   `godot --headless --path . res://scenes/dev/cloud_check.tscn`. It uses throwaway accounts and must
   delete them (through `Cloud.delete_account`) or clean up with SQL afterwards.
4. Facts to keep: accounts need an account (no playing without); under-13 accounts have a made-up
   address from a hash of the name and sign in by name; email from 13; email confirmation is off;
   mail goes through Gmail SMTP of skywatchcom@gmail.com (app password in `tmp/smtp_password.txt`),
   templates in `supabase/templates/`.
5. Continue with /ship.
