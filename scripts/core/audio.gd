class_name Audio
extends RefCounted
## Static front door to the Sfx autoload. Game code calls Audio.play(...) instead of Sfx
## directly, so scripts still compile (and stay silent) where autoloads aren't loaded,
## such as the headless unit-test runner.


static func play(sound: String, volume_db: float = 0.0, min_gap: float = 0.03) -> void:
	var sfx = _sfx()
	if sfx != null:
		sfx.play(sound, volume_db, min_gap)


static func hum(level: float) -> void:
	var sfx = _sfx()
	if sfx != null:
		sfx.set_hum(level)


static func buzz(ms: int) -> void:
	var sfx = _sfx()
	if sfx != null:
		sfx.buzz(ms)


static func set_enabled(on: bool) -> void:
	var sfx = _sfx()
	if sfx != null:
		sfx.set_enabled(on)


static func _sfx() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Sfx")
