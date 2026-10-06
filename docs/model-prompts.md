# 3D model prompts

Tripo's free plan does not allow exporting (7.10.2026), so models come from Microsoft TRELLIS.2
(MIT license, free for commercial use) on Hugging Face: https://huggingface.co/spaces/microsoft/TRELLIS.2
TRELLIS turns one picture into a 3D model, so each model takes two steps:

1. Make a picture with any AI image tool the owner already uses (Gemini, ChatGPT, Copilot):
   the image prompt below plus this ending:
   > 3/4 view from slightly above, the whole object visible, plain white background, soft even
   > light, no shadows on the background, stylized realistic military mobile game art, Boom Beach
   > style, no text, no real insignia
2. Upload the picture to the TRELLIS.2 space, generate, and download the GLB.
   Save the picture and the GLB into `assets/models/incoming/` with the name from the list.

Import step (Claude): pull the albedo texture out of the GLB (resized to 1024, saved as
`assets/models/<name>_albedo.webp`), then slim the mesh:
`godot --headless --path . -s scripts/dev/slim_model.gd -- res://assets/models/incoming/<name>.glb res://assets/models/<name>.res 6000 1.0`
(Godot's LODs first, then vertex clustering that keeps texture seams). The source GLBs stay out of
git. Done so far: `infantry` (7,350 triangles, from 297,000) and `tank` (hull 10,073 + turret 4,046,
split with `90 -0.035 0.12 0` so the turret turns on its own).

Claude imports them and keeps the five level looks by adding level parts and colors in code, so
each item needs only one model. The free Hugging Face GPU time is limited per day; signing in
with a free Hugging Face account gives more.

## The list, in priority order
1. `infantry.glb` – A modern soldier standing, olive camouflage uniform, covered helmet with
   goggles, plate carrier vest with pouches, small backpack, holding a compact carbine across
   the chest, boots, neutral standing pose, full body.
2. `engineer.glb` – A combat engineer soldier standing, olive uniform, sand-orange vest with
   pouches, helmet, small shovel strapped to a backpack, coil of detonating cord on the
   shoulder, holding a carbine, full body.
3. `tank.glb` – A modern main battle tank in desert sand color, long low hull, flat wedge-shaped
   turret, long main gun, side skirts over the tracks, chain curtain at the back of the turret,
   stowage boxes and a tarp roll.
4. `jeep.glb` – A light military utility jeep in desert sand color, open back, roll bar,
   spare wheel at the back, big off-road tires, small antenna.
5. `command_post.glb` – A small reinforced concrete military command post, square two-storey
   block, a strip of windows, steel door with steps, flat roof with a parapet, air conditioner
   and antennas on the roof, sandbags at the corners.
6. `fuel_tank.glb` – A white cylindrical military fuel storage tank with a pink stripe, ladder,
   pipes and valves, standing on a concrete base with a low concrete wall around it.
7. `quadcopter.glb` – A small white military quadcopter drone, four arms with propellers, a
   camera under the nose, small antennas.
8. `mg_nest.glb` – A machine gun position: a heavy machine gun on a tripod behind a ring of
   sandbags, ammo boxes beside it.

After these eight, the next batch: hangar with a curved roof, garage, army tents, AA gun,
anti-tank gun, mortar position, the Syndicate robot guard, and Razor.
