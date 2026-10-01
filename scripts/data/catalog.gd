class_name Catalog
extends RefCounted
## Balancing numbers for every defense. Tune here without touching behaviour code.

const DEFENSES := {
	"laser": {"radius": 11.0, "dps": 45.0, "sweep": 1.1},
	"net": {"radius": 12.0, "speed": 16.0, "cooldown": 3.5},
	"jammer": {"radius": 8.0},
	"birds": {"radius": 8.0, "count": 6, "speed": 1.3, "damage": 15.0},
}


static func make_defense(type: String) -> Defense:
	match type:
		"laser":
			return LaserTower.new()
		"net":
			return NetLauncher.new()
		"jammer":
			return Jammer.new()
		"birds":
			return BirdFlock.new()
	push_error("Unknown defense type: %s" % type)
	return Defense.new()
