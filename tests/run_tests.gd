extends SceneTree
## Minimal test runner, no plugins needed:
##   godot --headless --path . -s tests/run_tests.gd
## Every method named test_* in the files below must return true.

const FILES := [
	"res://tests/test_raid_rules.gd",
	"res://tests/test_path_utils.gd",
]


func _init() -> void:
	var passed := 0
	var failed := 0
	for file in FILES:
		var suite = load(file).new()
		for method in suite.get_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			if suite.call(name) == true:
				passed += 1
			else:
				failed += 1
				print("FAIL  %s :: %s" % [file.get_file(), name])
	print("Tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
