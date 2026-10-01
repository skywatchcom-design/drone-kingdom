# Drone Kingdom (working title)

Mobile raid game: draw a route over rooftops, launch your delivery drone, and take manual
control in slow motion when it flies into a defense's range. Grab the crates and the gold
vault, then make it home.

## Run

Open the folder in Godot 4.7 and press Play (F5). The mouse works as a finger.

From the command line:

```
godot --path .                      # play
godot --path . -- --autoplay        # demo: draws a route and flies it (drone can't die)
godot --headless --path . -s tests/run_tests.gd   # unit tests
```

## Layout

- `scripts/raid/raid.gd` – raid flow: plan → takeoff → fly (autopilot / manual) → landing → result
- `scripts/raid/drone.gd` – drone model and flight feel (tilt from acceleration, rotors, lights)
- `scripts/raid/city.gd` – rooftop city built from primitives
- `scripts/raid/defenses/` – laser tower, net launcher, jammer, bird flock
- `scripts/data/catalog.gd` – defense balancing numbers
- `scripts/data/bases.gd` – the three prototype bases
- `scripts/core/` – pure rules and helpers (unit tested)
