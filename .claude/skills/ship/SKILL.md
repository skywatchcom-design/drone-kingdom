---
name: ship
description: Finish a change to the SkyWatch game end to end - tests, in-game screenshots, commit on the session's own branch, a preview web build for the owner's iPad, and a short Hebrew summary; then, only after the owner approves, merge into main and publish the real site. Use after every finished game change, or when the owner says /ship, "תעלה", "תפרסם" or "תדחוף".
---

# Ship a change

Rule (owner, 15.10.2026): **nothing enters `main` without the owner's approval.** Each session works
on its own branch (a worktree under `.claude/worktrees/<topic>`, branch `<topic>`), shows the result,
and merges into `main` only after the owner says so in this chat ("מאשר", "תכניס", "כן תעלה" and
the like, about this change). Approval for one change does not cover the next one. Write every line
to the owner in Hebrew.

1. **Check the scripts and run the tests**
   - `godot --headless --path . --import` must print no `SCRIPT ERROR`.
   - `godot --headless --path . -s tests/run_tests.gd` must end with `0 failed`. Add tests for new
     rules in `tests/test_economy.gd` (functions `test_*` returning bool).
   - Godot is `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.
2. **Look at it in the game** for anything visible: run with
   `--write-movie tmp/<name>/f.png --fixed-fps 10 --quit-after 15 -- <flags>` and read the last frame
   (`f.avi` is much faster for long clips; pull frames with ffmpeg).
   Useful flags: `--fresh` (a new player, real save untouched), `--anon`, `--tutorial N|-1`,
   `--screenshot-shop|missions|daily|signup|signin|profile|upgrade|...`, raid `--syndicate N`.
   For the web look add `--rendering-method gl_compatibility`. Fix what looks wrong first.
3. **Update CLAUDE.md** on the branch when something new exists (a system, a flag, a decision).
4. **Commit on the branch and push the branch** (a backup, not main): message in
   `tmp/commit_msg.txt` (English, why over what, ends with the session's Co-Authored-By line),
   `git add <paths>` (never `tmp/`), `git commit -F tmp/commit_msg.txt`, `git push origin <topic>`.
5. **Publish a preview**: `powershell -ExecutionPolicy Bypass -File tools\publish_web.ps1 -Preview <topic>`
   -> `https://skywatchcom-design.github.io/drone-kingdom/preview/<topic>/` (the real site is untouched).
6. **Ask the owner in Hebrew**: what changed (short bullets), the in-game screenshot, the preview link
   (private tab for a fresh player), what was checked, and the question whether to put it into main
   (multiple choice: put it in / change something first / drop it).
7. **Only after an explicit yes**: `git fetch origin`, rebase the branch on `origin/main` (fix any
   conflict, rerun the tests), `git push origin <topic>:main`, then publish the real site with
   `tools\publish_web.ps1` (no `-Preview`), and tell the owner it is live with the `?v=` link.
   If the owner asks for changes, repeat from step 1 on the same branch. If the owner drops it, leave
   `main` untouched and say the branch stays aside.
8. **Google Play** is separate: a Play build is made only when the owner says "גרסה לגוגל", always from
   `main` (see "Android releases" in CLAUDE.md), and its commit gets a `play-<name>-v<code>` tag.
