# SkyWatch (working folder: drone-kingdom)

Mobile strategy game in the spirit of Clash of Clans / Boom Beach: build a modern military base,
train a combined army (infantry, tanks, combat engineers and drones), raid other players' bases
and the fictional "Syndicate". Light, humorous tone; fictional army with subtle Israeli roots
(no real IDF names, emblems or units; enemies are only other players or the Syndicate).

The full product spec is `docs/GDD.md`; market research is in `docs/market-research.md`.
Read the GDD before changing gameplay: it records every product decision made with the owner.

## Working with the owner (agreed 7.10.2026)
- **Every line to the owner is in Hebrew**, including short status lines and final summaries. Code,
  commits and comments stay in English.
- **After every change, without asking** (skill `/ship`): import + tests, an in-game screenshot for
  anything visible, update this file, commit (message via a file), `git push origin main`, publish
  the web build (`tools/publish_web.ps1`), then a short Hebrew summary with the iPad link
  (`?v=N`, private tab for a new player) and what still needs the owner.
- **Sketch first only for new screens, characters and big design changes** (skill `/sketch`): 2-3
  working directions over real game screenshots, the owner picks. Small UI fixes go straight into
  the game, shown with a screenshot.
- Ask before big direction changes; the owner likes multiple-choice questions. Give an honest
  opinion when asked (e.g. against switching to a Clash Royale concept).
- Keep development and server costs near zero (Godot, Supabase free tier, Gemini free tier, Gmail SMTP,
  GitHub Pages, async PvP only).
- Secrets live only in `tmp/` (git-ignored): `gemini_key.txt`, `supabase_token.txt`,
  `smtp_password.txt`. Never commit them or put them in the game. The owner checks on an iPad
  (Safari) through the web build.
- Skills in `.claude/skills/`: `/ship`, `/sketch`, `/noa-voice` (Noa's lines, `tools/voice/noa_line.py`),
  `/supabase` (migrations and checks, `tools/supabase_sql.py`).

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

## Download size budget (owner, 7.10.2026)
The store download must stay under 150 MB (aim for under 80). Rules: textures at most 1024 px
(webp/jpg sources, VRAM-compressed on import); AI models slimmed to about 10k triangles; audio as
ogg; ship arm64 only; the export must exclude `assets/models/incoming/` (source GLBs), `tmp/`,
`tools/`, `tests/` and `docs/`. `tmp/` holds a `.gdignore` so Godot never imports screenshots.
Check the exported size on every build.

## Code map
- `scripts/autoload/game_state.gd` – the save and every economy rule (build/upgrade/army/collect).
  Settings (language, sound, dev infinite coins) live in a separate `user://settings.json`.
- `scripts/autoload/sfx.gd` + `scripts/core/audio.gd` – synthesized sounds; call `Audio.play(...)`, never `Sfx` directly.
- `scripts/core/i18n.gd` – English keys, Hebrew table; wrap all user-facing text in `I18n.t()`.
- `scripts/data/catalog.gd` – all numbers (costs, HP, limits, unit and defense stats).
- `scripts/data/bases.gd` – starter enemy bases and the generator for the rest.
- `scripts/raid/city.gd` – the flat countryside compound (world builder). `drone.gd` + `drone_models.gd` – the three approved drones.
- `scripts/raid/raid.gd` – battle (deploy, drone and ground-unit AI, fence breaches, effects). `scripts/home/home.gd` – the base screen.
- Dev-only infinite coins exist only when `OS.is_debug_build()`.

## Status (3.10.2026)
Working today: flat world, base building/upgrades, coins from generators, hangar with 3 drones,
autonomous Clash-style raids with health bars and effects, sound, Hebrew/English toggle.

Week 1 rules done (save v4): 9x9 base, coins + fuel + gems, Fuel Pump and Fuel Tank (gray-box),
build timers with 2 workers (3rd for gems), gem speed-ups. Landscape (1280x720) with the approved
layout B (https://claude.ai/artifact/1wkMTctCpsPu4sa8wBtP6r): resources and badge in the top corners,
round Attack and Hangar/Build/Settings at the bottom, info sheets as a bottom-middle card.
Godot mirrors anchors of a control that is itself RTL; `HomeHud._pin` accounts for that.
Week 2 done (save v5, v4 saves migrate): Training Camp (queue, fuel + time), Quarters (army
space), Garage (unlocks/upgrades ground units; Hangar does drones), army used up per attack.
Ground units (`ground_unit.gd`, `unit_models.gd`, shared `Unit` base with drones): infantry
squads, engineers who breach the fence (`City.breach`), heavy tank (unit key `armor`; `tank` is
the Fuel Tank). The fence stops ground units: `RaidRules.ground_waypoint` routes via the gate or
breaches. Until week 3's defenses, only the Laser hits ground units. Camp/Quarters/Garage gray-box.
Week 3 (5.10.2026): new defenses with a look per level, sketch-based buildings, defending squad
from Quarters, energy + air strike + flare in battle. Dev: `res://scenes/dev/gallery.tscn -- --type mg`
shows one structure at all levels; raid takes `--enemy N` and `--army infantry:2,courier:2`.
Week 3 extras (5.10.2026): player-built walls (`Walls`, wall mode, battle routing), Support Base with
prepared air strikes/flares (no energy), build menu picture cards, five-level looks for every unit,
drone, plane and building (level colors none/silver/blue/red/gold + ring under units). Save v8.
Next: Supabase backend (shield after being attacked comes with it), onboarding. Soft launch target: ~2 months, Android + iOS together.

Approved 3.10.2026: ground-forces sketch (https://claude.ai/artifact/BD7VJUbaPSCevXsmgRoS2o) and casualty
style (hit soldier vanishes, a small helmet rolls on the ground). Next sketch: new defenses (MG, AT, AA, mortar).
Approved 4.10.2026: defenses and buildings sketch with a look per level
(https://claude.ai/artifact/MTz3BL4Yz9u3mj78fV3NZr): MG nest, AT gun, AA battery (replaces laser),
mortar (in launch, HQ 3), military jammer, camp, quarters, garage, fuel pump, fuel tank.
Approved 5.10.2026: support abilities sketch (https://claude.ai/artifact/QeVxT8PzJLE2KijtoK89GN):
energy bar (+15 per building, +40 HQ, max 100), air strike 60, direction flare 20 (6 s), red ring
under defending soldiers.
Approved 5.10.2026: walls/support/build-menu/level-looks sketch (https://claude.ai/artifact/Th5mNJUuSD5d77XEMeRnqE):
player-built walls on the paths between pads (outer fence removed), Support Base with prepared air
strikes and flares (no energy), build menu cards with pictures, and dramatic 5-level looks for units,
drones, air strike and flare (level colors none/silver/blue/red/gold).
Approved 6.10.2026: Clash-style base screen (https://claude.ai/artifact/4WKjsEP2MoNrBQh5iGnwTF), same layout
in both languages: badge top left, workers top middle, resources top right, Attack + Army bottom left,
Settings + Shop bottom right; Shop tabs army/resources/defenses/walls with picture cards; tapping a
building shows Info / Upgrade / own action; big upgrade and info windows (`ShopUI`, `Icons` from SVG).
Approved 6.10.2026: Syndicate sketch (https://claude.ai/artifact/G1Y41QRsCwW8TVG8wyP9NB) with leader RAZOR
(scarred mercenary commander, red implant eye, metal jaw, spiked armor; aggressive taunts).
Week 4 (6.10.2026): Syndicate campaign: `Syndicate` (10 missions, bases from specs, Razor's lines, paint
swap), map scene `scenes/syndicate/map.tscn` (briefing, stars, locks), robot guards (`UnitModels._robot`),
Attack opens a choice (campaign or raid). Each mission hands out a fixed task force at the mission's level (`Syndicate.FORCES`);
the player's own army and support stay home. Raid flags: `--syndicate N`; map flag: `--mission N`.
Approved 6.10.2026: battle cards and deploying (https://claude.ai/artifact/Fy11Uvx52E8AXFytERpDZa): Clash-style
unit cards (picture at the unit's level, count, level badge, name strip) and deploying anywhere except a
square around each standing building (red squares flash after a bad tap). Raid flag `--show-zones`.
Approved 6.10.2026: art direction B+ "stylized-realistic, improved" (https://claude.ai/artifact/2CogN9cX5xuLj8cwdXBn67):
sky lighting, soft contact shadows, grime low on walls and hulls, textured grass/dirt/concrete/camo,
rolling ground with grass tufts, more parts per model. Free only: everything built in code.
Approved 6.10.2026: living base with photo textures (https://claude.ai/artifact/Wh6JXRFwid3cJxTbP8DZsG).
In game (7.10.2026): Poly Haven CC0 photo textures in `assets/textures` used by `MeshKit.mat/surface`
(triplanar, bump maps); B+ Command Tower; `BaseLife` (home: patrol, jeep, workers at sites, smoke from
"smoke" markers, blinking "blink" lights, patrol drone, birds). AI models: TRELLIS.2 GLBs from the owner
in `assets/models/incoming` (git-ignored), slimmed by `scripts/dev/slim_model.gd` into
`assets/models/<name>.res` + `<name>_albedo.webp`; see `docs/model-prompts.md`. Done: infantry, tank
(hull + turret). Tripo's free plan cannot export, so it is not used.
7.10.2026 (owner feedback): AI soldiers walk on a 5-bone leg skeleton (`UnitModels._leg_skeleton`,
weights painted by height in `_skinned`); small coin/fuel markers with no number; softer coin chime;
slow martial base music (D minor, 70 BPM) `assets/audio/base_theme.ogg` composed by `tools/make_music.py` (Sfx.music, settings
toggle, off in battles); Army window in Shop style (`ShopUI.army`, unit info with "!").
Approved 6.10.2026: Noa's tutorial sketch (https://claude.ai/artifact/MGyZi8x3roSUiJFQpDLzYt). In game (7.10.2026,
save v9): `Tutorial` overlay (`scripts/ui/tutorial.gd`, steps and lines in `TutorialSteps`) with Noa's three
Gemini-painted faces (`assets/textures/noa`) and her Gemini "Leda" voice (`assets/audio/noa/<lang>_<step>.ogg`,
made with `tmp/noa/gem/leda.py`, every clip checked by transcription). Scenes call `Tutorial.attach(self)`;
targets are controls tagged with `Tutorial.tag(control, key)` or rects from the scene's `tutorial_target(key)`;
steps end on `GameState.tutorial_event(...)`. New players start without the MG Nest (Noa has them build it),
get a free speed-up and a coin top-up for the HQ upgrade, and 100 gems at the end. Settings has
"Replay tutorial" (tap-through only). Dev: `-- --fresh` (new player, real save untouched),
`--tutorial N` (jump to a step), `--tutorial-bot` (plays the tutorial by tapping and saves pictures to tmp/bot).
7.10.2026 (owner): the enemy faction is called **Iron Fang** (Hebrew: ניב הברזל) on screen; code names stay
`Syndicate`. Unit and structure pictures (battle cards, shop, upgrade/info windows) are baked images in
`assets/textures/pictures/<type>_<level>.webp`, because Safari on iPad left live 3D pictures blank. After a
model changes, rebake: `godot --path . res://scenes/dev/bake_pictures.tscn` then `python tools/bake_pictures.py`
(renders over black and white to get true transparency). On the web Noa's first line waits for the first tap.
Approved 7.10.2026: missions and sign-up sketch (https://claude.ai/artifact/Tnvwhfaq4KMqSS85z45tfx). In game (save v10):
`Missions` data (12 starter missions over 3 days, each day opens when the one before is claimed; 3 daily
missions picked by date from a pool, +10 gems for all three; 7-day login gift), progress in `GameState`
(`stats` counters, `mission_progress`, `claim_*`), window `MissionsUI` behind the HUD "Missions" button
(red badge = rewards waiting; hidden during Noa). "Go" opens the place where a mission is done. Dev:
`--screenshot-missions|--screenshot-daily`. Sign-up (7.10.2026): `Cloud` autoload
(`scripts/autoload/cloud.gd`) signs up/in on Supabase with a commander name + password; the auth email is
made up from a hash of the name (`players.skywatch.invalid`, email confirmation off, nothing is sent); the
name is unique in `public.players` (`name_available` RPC; schema changes in `supabase/migrations/`). The
save (`GameState.save_data/apply_save`) goes to the player's row 3 s after a change; signing in replaces
the local base. Sign-up fields (owner, 7.10.2026): commander name, birth month + year
(neutral age screen), email only from 13 (COPPA; under 13 keep the made-up address and sign in by name),
password twice, and a terms checkbox (`Cloud.TERMS_VERSION`; drafts in `web/legal/`, published with the
web build to `/legal/terms-he.html` etc.). Settings > Account has Delete account (`delete_my_account` RPC;
stores require it). Forgot password: the sign-in window asks Supabase to email a link
(`Cloud.request_reset`) to `web/account/reset.html` (published at /account/reset.html, supabase-js from
jsdelivr) where the new password is set; emails go through Gmail SMTP (skywatchcom@gmail.com, app password in
tmp/smtp_password.txt) with the bilingual template `supabase/templates/recovery.html`, approved 7.10.2026
direction A "a picture from the game" (https://claude.ai/artifact/GdxsmW8DHjzNvreCKDLjVL): a real base
screenshot banner with Noa (`web/email/banner.jpg`), the game's green button, signed by Noa. Approved 7.10.2026: sign-up look B "two steps" (https://claude.ai/artifact/Aoa9vgoFSHQ9wN4f6Vf9aQ)
in `AccountUI` (bright card, Noa bubble, step chips, white fields, green button; `show_modal(..., bare)`). Tapping the
badge/name opens `ProfileUI` (record, army and building levels). Contact for docs: skywatchcom@gmail.com,
operator "SkyWatch". The web build busts caches per publish (`?v=` on index.pck and index.js).
`AccountUI` opens after Noa (finished or skipped) and on every start without an account; it cannot be closed (owner: an account is required to keep playing). Settings shows the account and Log out. Dev check:
`godot --headless --path . res://scenes/dev/cloud_check.tscn` (delete its test user afterwards). The
owner's Management API token sits in `tmp/supabase_token.txt` (git-ignored); `tools/supabase_sql.py` runs SQL.
The owner considered a Clash Royale-style concept (7.10.2026) and decided to stay with this one.
Approved 7.10.2026: gem shop layout A "everything in one scroll" (https://claude.ai/artifact/WqAsDumRoAXDrToDiHBMDn).
In game (save v11): `Store` data (5 gem packs in ₪/$, one-time starter pack with the gold flag, cosmetics bought
with gems: Desert/Night/Snow Command Tower skins via `StructureModels.skin` + `HQ_SKINS`, gold flag), `StoreUI`
(opened from the gems "+" and the Shop's first "Gems" tab), `GameState.cosmetics_owned/worn`, `buy_cosmetic`,
`grant_purchase`. Players under 13 (`Cloud.child`) pass a parent gate (number in words → digits) before real
money. Real payments need the store accounts: release/web builds say "purchases open when SkyWatch is in the
stores", dev builds grant the purchase to test. Free-gem videos (13+) wait for an ad network. Tapping the Command Tower shows a Skins action
(`_open_skins`, `StoreUI.skins_window`): classic + every tower skin and flag, wear or buy there. Cosmetic pictures:
`skin_<id>.webp`, baked with `bake_pictures.tscn -- --skins`.
Approved 7.10.2026 (from an in-game prototype video, https://claude.ai/artifact/Pqa146jhWERmPaHPQSH9gt; painted
sketches of effects were rejected as looking bad, so judge effects from real recordings): battle opens centred on
the enemy base and zoomed to fit (`raid._frame_base`), no "Lv" labels in battle (`StructureModels.show_levels`),
`Fx` v2 (soft camera-facing puffs from code textures: fireball, black smoke, flames, sparks, flying debris, dust
ring, scorch marks, camera shake via h/v offsets), burning damaged buildings and smouldering ruins
(`raid._burn`). Dev: raid `--view N` (camera height), `--fx-demo` (damaged base + repeated explosions).
Approved 8.10.2026 (real before/after screenshots, https://claude.ai/artifact/2wKP1j2WYAmJ6ZywcSh1To): the
"late afternoon" look in `WorldSetup.create` for base and battle: a lower warm sun from the side (long shadows),
warm horizon, haze only in the distance, +saturation/contrast adjustments, soft glow, and a screen-edge
vignette on a CanvasLayer under the HUD. Dev: `-- --mood classic` shows the old midday look; home
`--screenshot-base` opens the base with no window (clean pictures).
Approved 8.10.2026 (https://claude.ai/artifact/RoZCVzsvoELfzxDFXHFn6G): the player's base ground. `City.build(seed,
pads, used_cells)`: free pads are subtle plots with white corner stakes (only built pads are concrete), worn
ground under buildings and grass patches (`_add_patches`), and a camp outside the jeep's lap (`_add_camp`: lamp
posts with "lamp" bulbs BaseLife flickers, crates, barrels, sandbags, water tower, camo store, gate booth and
barrier). BaseLife smoke and jeep dust use `Fx.smoke` soft puffs.
Approved 9.10.2026: strategy and pay-to-progress sketch (https://claude.ai/artifact/FXGoTcv7xRzZbR5GDqE6S3), rules in
GDD §10/§10א. In game (round 1): every structure has a Move action (`GameState.move`, free; `_start_move` shows all
defense ranges), range rings show what a defense hits (`Defense.hits_air`: green ground, blue air, red mortar dead
zone), target badges `Icons.target(type)` (`t_any|loot|defense|fence`) on battle cards and Army cards, picking a card
says what it goes for (`Catalog.target_text`), a dashed line after each deploy to the first target (`raid._show_aim`),
and a Command Tower "Levels" window (`ShopUI.hq_ladder`, `Catalog.ladder_lines`). Home flags `--screenshot-ladder|move`.
Round 2 (9.10.2026): hidden traps `Catalog.TRAPS` (Spring Mine from HQ 2 against soldiers, Air Mine from HQ 3 against
drones). They live in `GameState.structures` like buildings but cost coins only (no worker, no timer, no upgrades),
take a free pad, look like `StructureModels.trap`, and re-arm by themselves. In battle they are not targets: `raid.traps`
holds them hidden (their pad looks empty) until a unit comes within `trigger`, then `_spring_trap` pops the model and
blows. Generated enemy bases get traps on their own RNG (`Bases.generate`). Raid flag `--enemy-hq N`; picture bake
`bake_pictures.tscn -- --only spring,airmine`.
Approved 10.2026 (owner, 9-10.10.2026): "general" attack planning, built on branch `feature/general-strategy`
(not merged to main yet). Sketches: target marking https://claude.ai/artifact/XPhDU6EL4YeN3Qjka2A2P6, Planning HQ window
https://claude.ai/artifact/3ybncHdm6sxxuWetMYLJBg (direction B "orders"). Rules the owner chose: it opens only at Command Tower 4
through a new building **Planning HQ** (Hebrew: מטה תכנון; `Catalog.LIMITS["planning"] = [0,0,0,1,1]`, 600 coins, up to 5 levels),
so new players never see it; saved plans (slots = building level), plans survive upgrades, and a Syndicate mission remembers the
orders used there last. A plan = one order per force (`Catalog.PLAN_UNITS`: infantry, armor, courier, scout, heavy; engineers keep
breaching) from `Catalog.PLAN_TARGETS` (auto, defense, loot, hq). In game (save v12): `GameState.plans/plan_active/campaign_plans`
(`set_plan_order`, `battle_orders`, `mission_orders`), `RaidRules.pick_target` takes "hq", `PlanningUI` window (tap the marked word to
cycle the order), plan buttons over the battle cards until the first unit is sent (`RaidHud.set_plans`), order badge `Icons.target(type,
order)` and `raid._prefers_of`. Later tools by building level (not built yet): intel preview, timing/waves, decoys. Dev: home
`--fresh --tutorial -1 --screenshot-planning`, raid `--planning-demo` and `--orders armor:hq,courier:loot`.
Still to build from that sketch: defense log + replay (needs real PvP on Supabase first: today every raid is against a
generated base), saved layouts, camo net, medic / jammer drone, season pass.
**Open task (10.10.2026): real PvP + defense log on Supabase.** Sketch https://claude.ai/artifact/NW7rzSLQsYyZ2g54BgcdTx
waits for the owner's pick (ask again first): finding an opponent (A search with "Next" / B board of 3 opponents /
C ladder + revenge), defense report (A welcome-back from Noa + log / B log only / C damage map instead of replay),
rules (A like Clash 20% / B soft 10% + 8 h shield + protected until HQ 2 / C only uncollected loot). Recommended:
B, A+C (replay later), B. Then build the server side (opponent pick, battle results, loot taken from the defender,
shield, trophies) with `/supabase`, and the log screen.
**Next (owner, 8.10.2026): early-retention campaign** - a serious first-week campaign that is fun, teaches and makes
players not want to leave (tie Noa, missions and Iron Fang into one story with a daily "wow" and a reward
waiting for tomorrow). Sketch first.
Approved 9.10.2026: the app icon, a realistic Gemini-app picture (drone over an advancing squad, "1 wide" crop;
comparison at https://claude.ai/artifact/3HnFRCZDriQd6awAMRSRh9). Files in `assets/icon` (`icon.png` is the project/web
icon; Android adaptive layers keep the whole picture inside the 72/108 visible zone, background is a blurred copy),
Play listing icon `docs/store/play_icon_512.png`. The API's free tier cannot make images (limit 0), so the owner makes
pictures in the Gemini app from prompts we write. Android preset (`export_presets.cfg`, arm64, AAB, gradle build):
release export takes the keystore from env vars `GODOT_ANDROID_KEYSTORE_RELEASE_PATH|USER|PASSWORD`
(`tmp/skywatch-release.keystore`, alias `skywatch`, password in `tmp/android_keystore_password.txt`).
Google Play: the identity check is pending (9.10.2026). A new personal account needs a 14-day closed test with 12 testers
before production. Approved 10.10.2026: logo A "field stencil" (https://claude.ai/artifact/FZPuGpNxs2ucs3SLEUgLWa):
Black Ops One letters, "Sky" sand + "Watch" gold with a dark olive drop, top-view drone mark, no tagline (owner: the game is base + combined army, not only drones).
`assets/icon/logo.png` (transparent, rendered from canvas) and the boot splash `assets/icon/splash.png` (also the web
loading picture). Store banner `docs/store/feature_graphic_1024x500.png` (owner's Gemini picture + logo; `_clean` without).
Store screenshots (10.10.2026): `docs/store/screenshots/{en,he}_1..5.jpg` (1920x1080: battle, base, campaign map,
shop, Noa). Dev flags for them: `--fresh --showcase N` (developed HQ-N base, full army, no tutorial, no level labels,
never saved), `--anon` (skip the saved login so the badge says "Commander"), `--lang en|he`; 1080p needs a temporary
`override.cfg` with `display/window/size/window_width_override=1920` / `height=1080` (never commit it).
Play Console answers and listing text: `docs/store/play-console-answers.md`. Play Console (10.10.2026): app created
(English default + Hebrew), internal test release 1 (0.1.0) uploaded, App content forms done (ratings PEGI 7 / ESRB E10+,
audience 9+ so the Families policy applies), reviewer account `PlayReviewer` (password in `tmp/play_reviewer.txt`).
Next: closed test (Alpha) with a Google Group of 12+ testers for 14 days, then production access.
Account deletion page for Google Play (10.10.2026): `web/account/delete.html`, published at
https://skywatchcom-design.github.io/drone-kingdom/account/delete.html (`?lang=he|en`). Log in by commander name or
email (same made-up address as `Cloud.email_for`), tick a box, `delete_my_account`; the players row goes by cascade.
Lists what is deleted; no-email players (under 13) ask by email. Linked from both privacy pages; checked against the
live server with a throwaway account.
Still waiting on the owner: Apple Developer and Google Play accounts.
