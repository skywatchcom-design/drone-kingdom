extends Control
## Dev: renders every structure and unit at every level, and every cosmetic (on a level-3
## Command Tower), to tmp/bake/<name>_<black|white>.png, once over black and once over white, so
## tools/bake_pictures.py can work out true transparency (see-through parts like solar panels
## included) and write assets/textures/pictures/<name>.webp for ShopUI.picture and the store.
## Run again after a model changes (`-- --skins` bakes only the cosmetics):
##   godot --path . res://scenes/dev/bake_pictures.tscn
##   python tools/bake_pictures.py

const SIZE := 256


func _ready() -> void:
	var dir := ProjectSettings.globalize_path("res://tmp/bake")
	DirAccess.make_dir_recursive_absolute(dir)
	if not OS.get_cmdline_user_args().has("--skins"):
		var types: Array = ["hq"]
		for tab in Catalog.SHOP_ORDER:
			types.append_array(Catalog.SHOP_TABS[tab])
		types.append_array(Catalog.GROUND_ORDER)
		types.append_array(Catalog.DRONE_ORDER)
		for type: String in types:
			for level in range(1, Catalog.MAX_LEVEL + 1):
				await _bake(dir, "%s_%d" % [type, level], type, level)
	for id: String in Store.COSMETIC_ORDER:
		StructureModels.skin = {Store.COSMETICS[id]["slot"]: id}
		await _bake(dir, "skin_" + id, "hq", 3)
	StructureModels.skin = {}
	get_tree().quit()


func _bake(dir: String, name: String, type: String, level: int) -> void:
	for bg: String in ["black", "white"]:
		var pic := ShopUI.live_picture(type, level, Color.BLACK if bg == "black" else Color.WHITE)
		pic.size = Vector2(SIZE, SIZE)
		add_child(pic)
		for i in 4:
			await RenderingServer.frame_post_draw
		var vp := pic.get_child(0) as SubViewport
		vp.get_texture().get_image().save_png("%s/%s_%s.png" % [dir, name, bg])
		pic.queue_free()
	print("baked ", name)
