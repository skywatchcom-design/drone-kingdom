extends Control
## Dev: renders every structure and unit at every level, and every cosmetic (on a level-3
## Command Tower), to tmp/bake/<name>_<black|white>.png, once over black and once over white, so
## tools/bake_pictures.py can work out true transparency (see-through parts like solar panels
## included) and write assets/textures/pictures/<name>.webp for ShopUI.picture and the store.
## The defense battle's towers bake as tower_<kind>_<level> (MergeHud's cards), apart from the
## city's defenses of the same name.
## Run again after a model changes (`-- --skins` bakes only the cosmetics, `-- --towers` only
## the battle towers):
##   godot --path . res://scenes/dev/bake_pictures.tscn
##   python tools/bake_pictures.py

const SIZE := 256


func _ready() -> void:
	var dir := ProjectSettings.globalize_path("res://tmp/bake")
	DirAccess.make_dir_recursive_absolute(dir)
	if OS.get_cmdline_user_args().has("--towers"):
		await _bake_towers(dir)
		get_tree().quit()
		return
	if not OS.get_cmdline_user_args().has("--skins"):
		var types: Array = ["hq"]
		for tab in Catalog.SHOP_ORDER:
			types.append_array(Catalog.SHOP_TABS[tab])
		types.append_array(Catalog.GROUND_ORDER)
		types.append_array(Catalog.DRONE_ORDER)
		# `-- --only spring,airmine` bakes just those types.
		var args := OS.get_cmdline_user_args()
		if args.has("--only"):
			types = Array(args[args.find("--only") + 1].split(","))
		else:
			await _bake_towers(dir)
		for type: String in types:
			# Traps have a single look.
			for level in range(1, (1 if Catalog.is_trap(type) else Catalog.MAX_LEVEL) + 1):
				await _bake(dir, "%s_%d" % [type, level], type, level)
	for id: String in Store.COSMETIC_ORDER:
		StructureModels.skin = {Store.COSMETICS[id]["slot"]: id}
		await _bake(dir, "skin_" + id, "hq", 3)
	StructureModels.skin = {}
	get_tree().quit()


func _bake_towers(dir: String) -> void:
	for kind: String in MergeGame.TOWER_ORDER:
		await _bake(dir, "tower_%s_1" % kind, "tower_" + kind, 1)


func _bake(dir: String, name: String, type: String, level: int) -> void:
	# One scene for both passes, only the background colour changes, so the two shots match
	# exactly (two separate scenes could catch different moments and leave a dark ghost).
	var pic := ShopUI.live_picture(type, level, Color.BLACK)
	pic.size = Vector2(SIZE, SIZE)
	add_child(pic)
	var vp := pic.get_child(0) as SubViewport
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Freeze every unit in its first pose (engineers would otherwise start kneeling mid-bake).
	for n in vp.find_children("*", "Node3D", true, false):
		if n is Unit:
			n.process_mode = Node.PROCESS_MODE_DISABLED
	var env := (vp.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	for bg: String in ["black", "white"]:
		env.background_color = Color.BLACK if bg == "black" else Color.WHITE
		for i in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s_%s.png" % [dir, name, bg])
	pic.queue_free()
	print("baked ", name)
