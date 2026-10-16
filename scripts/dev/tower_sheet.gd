extends Node3D
## Dev: renders battle towers one by one for a contact sheet. Every 3rd frame is the next
## tower (15 shots, shot k is frame 3k+2). By default: mg, mortar, aa times merge levels 1-5.
## `-- --type mg` instead shows one tower: levels 1-5, then path A steps 1-3 at level 2 and
## step 3 at levels 4 and 5, then the same for path B.
## godot --path . res://scenes/dev/tower_sheet.tscn --write-movie tmp/sheet/s.png --fixed-fps 10 --quit-after 46
## Then `python tools/tower_sheet.py tmp/sheet out.png` glues them.

var _frame := 0
var _node: Node3D
var _shots: Array = []


func _ready() -> void:
	MeshKit.look = "leo"
	MeshKit.toy = true
	StructureModels.show_levels = false
	var cam := WorldSetup.create(self, 100.0)
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 28.0
	WorldSetup.place_camera(cam, Vector3(0, 4.0, 0))
	MeshKit.add(self, MeshKit.box(Vector3(80, 0.2, 80)), MeshKit.mat(Color(0.5, 0.58, 0.36), 0.9), Vector3(0, -0.1, 0))
	var args := OS.get_cmdline_user_args()
	if args.has("--type"):
		var type: String = args[args.find("--type") + 1]
		for lv in range(1, 6):
			_shots.append([type, lv, "", 0])
		for p in ["a", "b"]:
			for shot in [[2, 1], [2, 2], [2, 3], [4, 3], [5, 3]]:
				_shots.append([type, shot[0], p, shot[1]])
	else:
		for type in MergeGame.TOWER_ORDER:
			for lv in range(1, 6):
				_shots.append([type, lv, "", 0])


func _process(_delta: float) -> void:
	if _frame % 3 == 0:
		if _node != null:
			_node.queue_free()
		var shot: Array = _shots[(_frame / 3) % _shots.size()]
		_node = MergeGame.make_tower_node(self, shot[0], shot[1], shot[2], shot[3])
	_frame += 1
