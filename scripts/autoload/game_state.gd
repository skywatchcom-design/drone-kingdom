extends Node
## Player progress, saved as JSON in the app's user folder.

const SAVE_PATH := "user://save.json"

var coins := 0
var best_stars := {}
var base_index := 0


func _ready() -> void:
	load_game()


func record_raid(index: int, stars: int, banked: int) -> void:
	coins += banked
	var key := str(index)
	best_stars[key] = maxi(int(best_stars.get(key, 0)), stars)
	save_game()


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file")
		return
	file.store_string(JSON.stringify({"coins": coins, "best_stars": best_stars, "base_index": base_index}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		coins = int(data.get("coins", 0))
		best_stars = data.get("best_stars", {})
		base_index = int(data.get("base_index", 0))
