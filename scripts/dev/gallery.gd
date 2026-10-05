extends Node3D
## Dev tool: one structure, unit or drone at levels 1 to 5 side by side, to check that every
## level looks different. Run: godot --path . res://scenes/dev/gallery.tscn -- --type mg
## Defenses fire at a few dummy soldiers, tanks and drones passing in front.

var defenses: Array[Defense] = []
var dummies: Array[Unit] = []
var _t := 0.0


func _ready() -> void:
	var type := "mg"
	var args := OS.get_cmdline_user_args()
	var i := args.find("--type")
	if i >= 0 and i + 1 < args.size():
		type = args[i + 1]
	var cam := WorldSetup.create(self, 30.0)
	WorldSetup.place_camera(cam, Vector3(0, 1, 0))
	MeshKit.add(self, MeshKit.box(Vector3(200, 0.2, 200)), MeshKit.mat(Color(0.42, 0.6, 0.3), 0.95), Vector3(0, -0.1, 0))
	for lvl in range(1, Catalog.MAX_LEVEL + 1):
		var at := Vector3((lvl - 3) * 7.5, 0, -(lvl - 3) * 7.5)
		MeshKit.add(self, MeshKit.box(Vector3(5.4, 0.12, 5.4)), MeshKit.mat(Color(0.6, 0.67, 0.48), 0.9), at + Vector3(0, 0.06, 0))
		if Catalog.DRONES.has(type) or Catalog.GROUND.has(type):
			_unit_at(type, lvl, at)
		elif Catalog.is_defense(type):
			var d := Catalog.make_defense(type)
			add_child(d)
			d.position = at
			d.setup(Catalog.defense_stats(type, lvl), 0.12)
			d.show_range(false)
			defenses.append(d)
		else:
			StructureModels.build(self, type, lvl, at + Vector3(0, 0.12, 0))
	if not Catalog.is_defense(type):
		return
	for k in 4:
		var u: Unit
		if k == 3:
			var dr := Drone.new()
			dr.configure(Catalog.unit_stats("courier", 1))
			u = dr
		else:
			var g := GroundUnit.new()
			g.configure(Catalog.unit_stats("armor" if k == 2 else "infantry", 1))
			u = g
		u.invulnerable = true
		add_child(u)
		dummies.append(u)


## A unit at `lvl` on its pad, looping its showcase moves (drones hover above it).
func _unit_at(type: String, lvl: int, at: Vector3) -> void:
	var stats := Catalog.unit_stats(type, lvl)
	if Catalog.DRONES.has(type):
		var d := Drone.new()
		d.configure(stats)
		d.showcase = true
		d.position = at + Vector3(0, 2.4, 0)
		add_child(d)
		return
	var count := mini(int(stats.get("squad", 1)), 2)
	for i in count:
		var u := GroundUnit.new()
		u.configure(stats)
		u.showcase = true
		u.kneels = i % 2 == 1
		u.position = at + Vector3((i - (count - 1) / 2.0) * 1.8, 0.12, 0)
		add_child(u)


func _process(delta: float) -> void:
	_t += delta
	for k in dummies.size():
		var u := dummies[k]
		var s := fmod(_t * 3.0 + k * 9.0, 40.0) - 20.0
		var p := Vector3(s + 8.0, 0.0, s - 8.0)
		if u.flying:
			p.y = 7.0
		u.velocity = (p - u.position) / maxf(delta, 0.001)
		u.position = p
		u.health = u.max_health
	for d in defenses:
		d.tick(delta, dummies)
