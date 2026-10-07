extends Control
## Dev: renders every structure and unit at every level to
## tmp/bake/<type>_<level>_<black|white>.png, once over black and once over white, so
## tools/bake_pictures.py can work out true transparency (see-through parts like solar panels
## included) and write assets/textures/pictures/<type>_<level>.webp for ShopUI.picture.
## Run again after a model changes:
##   godot --path . res://scenes/dev/bake_pictures.tscn
##   python tools/bake_pictures.py

const SIZE := 256


func _ready() -> void:
	var types: Array = ["hq"]
	for tab in Catalog.SHOP_ORDER:
		types.append_array(Catalog.SHOP_TABS[tab])
	types.append_array(Catalog.GROUND_ORDER)
	types.append_array(Catalog.DRONE_ORDER)
	var dir := ProjectSettings.globalize_path("res://tmp/bake")
	DirAccess.make_dir_recursive_absolute(dir)
	for type: String in types:
		for level in range(1, Catalog.MAX_LEVEL + 1):
			for bg: String in ["black", "white"]:
				var pic := ShopUI.live_picture(type, level, Color.BLACK if bg == "black" else Color.WHITE)
				pic.size = Vector2(SIZE, SIZE)
				add_child(pic)
				for i in 4:
					await RenderingServer.frame_post_draw
				var vp := pic.get_child(0) as SubViewport
				vp.get_texture().get_image().save_png("%s/%s_%d_%s.png" % [dir, type, level, bg])
				pic.queue_free()
			print("baked ", type, " ", level)
	get_tree().quit()
