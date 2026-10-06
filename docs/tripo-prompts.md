# Tripo prompts (3D models)

The owner generates these on tripo3d.ai (free plan) and drops the GLB files into
`assets/models/incoming/`. Claude imports them into the game and keeps the five level looks by
adding level parts and colors in code, so each item needs only one model.

Free plan: models are public, CC BY 4.0 with Tripo's "non-commercial" wording. The owner chose to
stay on the free plan (7.10.2026); the credits screen must name Tripo. Before launch, check the
license again.

## Settings for every model
- Mode: Text to 3D (or Image to 3D if a sketch picture is attached).
- Texture: on, PBR if offered. Style: none / realistic.
- Topology: low poly or "smart mesh" if offered, about 5,000-10,000 faces (phones).
- Download: GLB.
- File name: the name in the list below (for example `infantry.glb`).

Add this ending to every prompt:

> stylized realistic military mobile game asset, Boom Beach style, clean readable shapes,
> PBR textures, game ready, single object centered, no ground, no base, no text, no flags,
> no real insignia

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
