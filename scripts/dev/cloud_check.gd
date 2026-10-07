extends Node
## Dev: checks the account flow against the real Supabase project with a throwaway name:
##   godot --headless --path . res://scenes/dev/cloud_check.tscn
## Leaves the test account behind; delete it afterwards (tmp/sb/sql.py).


func _ready() -> void:
	GameState.persist = false
	GameState.new_player()
	var name := "Check_%d" % (randi() % 100000)
	print("name_problem bad: ", Cloud.name_problem("a b"), " | ok: '", Cloud.name_problem(name), "'")
	print("available: ", await Cloud.name_available(name))
	print("sign_up: '", await Cloud.sign_up(name, "secret123"), "' signed_in=", Cloud.signed_in())
	print("taken now: ", not await Cloud.name_available(name.to_upper()))
	GameState.coins = 777
	await Cloud._push()
	Cloud.sign_out()
	GameState.coins = 1
	print("wrong pw: '", await Cloud.sign_in(name, "nope12345"), "'")
	print("sign_in: '", await Cloud.sign_in(name, "secret123"), "' coins back=", GameState.coins)
	print("USER ", Cloud.user_id)
	Cloud.sign_out()
	get_tree().quit()
