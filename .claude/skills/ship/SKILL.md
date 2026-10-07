---
name: ship
description: Finish a change to the SkyWatch game end to end without asking - tests, in-game screenshots, git commit and push to main, publish the web build for the owner's iPad, update CLAUDE.md, and a short Hebrew summary. Use after every finished game change, or when the owner says /ship, "תעלה", "תפרסם" or "תדחוף".
---

# Ship a change

The owner approved doing all of this automatically after every change (7.10.2026). Do not ask
before committing, pushing or publishing. Write every line to the owner in Hebrew.

1. **Check the scripts and run the tests**
   - `godot --headless --path . --import` must print no `SCRIPT ERROR`.
   - `godot --headless --path . -s tests/run_tests.gd` must end with `0 failed`. Add tests for new
     rules in `tests/test_economy.gd` (functions `test_*` returning bool).
   - Godot is `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.
2. **Look at it in the game** for anything visible: run with
   `--write-movie tmp/<name>/f.png --fixed-fps 10 --quit-after 15 -- <flags>` and read the last frame.
   Useful flags: `--fresh` (a new player, real save untouched), `--tutorial N|-1`,
   `--screenshot-shop|missions|daily|signup|signin|profile|upgrade|...`, raid `--syndicate N`.
   For the web look add `--rendering-method gl_compatibility`. Fix what looks wrong first.
   For a whole flow, `--fresh --tutorial-bot` plays Noa's tutorial and saves pictures to tmp/bot.
3. **Update CLAUDE.md** when something new exists (a system, a flag, a decision the owner made).
4. **Commit and push**: write the message to `tmp/commit_msg.txt` (English, why over what, ends with
   the Co-Authored-By line from the session) and run `git add <paths>` (never `tmp/`), then
   `git commit -F tmp/commit_msg.txt` and `git push origin main`. If GitHub fails, retry later in the
   session and say so.
5. **Publish the web build**: `powershell -ExecutionPolicy Bypass -File tools\publish_web.ps1`.
   Pages takes a few minutes; check new files with curl before telling the owner they are live.
6. **Tell the owner in Hebrew**: what changed (short bullets), the iPad link
   `https://skywatchcom-design.github.io/drone-kingdom/?v=<next number>` (a private tab for a fresh
   player), what was checked and how, and anything that needs them. Show the in-game screenshot
   for visual changes.
