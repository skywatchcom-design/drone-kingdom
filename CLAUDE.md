# SkyWatch (working folder: drone-kingdom)

Mobile strategy game in the spirit of Clash of Clans / Boom Beach: build a modern military base,
train a combined army (infantry, tanks, combat engineers and drones), raid other players' bases
and the fictional "Syndicate". Light, humorous tone; fictional army with subtle Israeli roots
(no real IDF names, emblems or units; enemies are only other players or the Syndicate).

The full product spec is `docs/GDD.md`; market research is in `docs/market-research.md`.
Read the GDD before changing gameplay: it records every product decision made with the owner.

## Working with the owner
- The owner (Nitay) writes in Hebrew; answer in Hebrew. Code, commits and comments stay in English.
- Visual changes go through a live sketch first (Artifact page), and are built in the game only after
  the owner approves. Show screenshots of in-game results.
- Ask before big direction changes; the owner likes multiple-choice questions.
- Keep development and server costs near zero (Godot, Supabase free tier, async PvP only).

## Stack and commands
- Godot 4.7.2, GDScript. Godot binary (winget):
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
- Play: `Play.bat`. Editor: `Edit.bat`.
- Import / check scripts: `godot --headless --path . --import`
- Unit tests: `godot --headless --path . -s tests/run_tests.gd` (no plugins; tests set `I18n.lang = "en"`).
- Battle demo without input: `godot --path . res://scenes/raid/raid.tscn -- --autoplay`
- Screenshots for checking visuals: add `--write-movie tmp/x/f.png --fixed-fps 10 --quit-after N`
  (frames land in `tmp/`, which is git-ignored). Home sheets: `-- --screenshot-panel|--screenshot-hq|--screenshot-hangar`.
- Movie-writer audio is 32-bit stereo WAV.
- Repo: https://github.com/skywatchcom-design/drone-kingdom (branch `main`). Commit messages via a file
  (`git commit -F`) because PowerShell mangles quotes in inline messages.

## Code map
- `scripts/autoload/game_state.gd` – the save and every economy rule (build/upgrade/army/collect).
  Settings (language, sound, dev infinite coins) live in a separate `user://settings.json`.
- `scripts/autoload/sfx.gd` + `scripts/core/audio.gd` – synthesized sounds; call `Audio.play(...)`, never `Sfx` directly.
- `scripts/core/i18n.gd` – English keys, Hebrew table; wrap all user-facing text in `I18n.t()`.
- `scripts/data/catalog.gd` – all numbers (costs, HP, limits, unit and defense stats).
- `scripts/data/bases.gd` – starter enemy bases and the generator for the rest.
- `scripts/raid/city.gd` – the flat countryside compound (world builder). `drone.gd` + `drone_models.gd` – the three approved drones.
- `scripts/raid/raid.gd` – battle (deploy, unit AI, effects). `scripts/home/home.gd` – the base screen.
- Dev-only infinite coins exist only when `OS.is_debug_build()`.

## Status (3.10.2026)
Working today: flat world, base building/upgrades, coins from generators, hangar with 3 drones,
autonomous Clash-style raids with health bars and effects, sound, Hebrew/English toggle.

Week 1 rules done (save v4): 9x9 base, coins + fuel + gems, Fuel Pump and Fuel Tank (gray-box),
build timers with 2 workers (3rd for gems), gem speed-ups. Landscape (1280x720) with the approved
layout B (https://claude.ai/artifact/1wkMTctCpsPu4sa8wBtP6r): resources and badge in the top corners,
round Attack and Hangar/Build/Settings at the bottom, info sheets as a bottom-middle card.
Godot mirrors anchors of a control that is itself RTL; `HomeHud._pin` accounts for that. Then ground units, new defenses (MG, AT, AA), support abilities,
Syndicate PvE map, Supabase backend, onboarding. Soft launch target: ~2 months, Android + iOS together.

Approved 3.10.2026: ground-forces sketch (https://claude.ai/artifact/BD7VJUbaPSCevXsmgRoS2o) and casualty
style (hit soldier vanishes, a small helmet rolls on the ground). Next sketch: new defenses (MG, AT, AA, mortar).
Still waiting on the owner: Apple Developer and Google Play accounts.
