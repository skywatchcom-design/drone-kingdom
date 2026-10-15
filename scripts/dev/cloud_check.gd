extends Node
## Dev: checks the account flow against the real Supabase project with throwaway accounts (a
## child without an email and an adult with one), then deletes both through the game:
##   godot --headless --path . res://scenes/dev/cloud_check.tscn
## With `-- --pvp` it checks attacks between players instead: a defender at Command Tower 2, an
## attacker who finds and beats them, the defender's shield, log and loss, then deletes both.


func _ready() -> void:
	GameState.persist = false
	GameState.new_player()
	if OS.get_cmdline_user_args().has("--pvp"):
		await _check_pvp()
		get_tree().quit()
		return
	var kid := "Kid_%d" % (randi() % 100000)
	var adult := "Adult_%d" % (randi() % 100000)
	var mail := "%s@example.com" % adult.to_lower()
	var year := int(Time.get_date_dict_from_system()["year"])
	print("age 9: ", Cloud.age(year - 9, 1), " | email check: '", Cloud.email_problem("a@b"), "'")
	print("kid sign_up: '", await Cloud.sign_up(kid, "secret123", "", year - 9, 3), "'")
	GameState.coins = 555
	await Cloud._push()
	Cloud.sign_out()
	print("kid sign_in by name: '", await Cloud.sign_in(kid, "secret123"), "' coins=", GameState.coins)
	print("kid delete: '", await Cloud.delete_account(), "' signed_in=", Cloud.signed_in())
	print("kid gone: ", "'" + await Cloud.sign_in(kid, "secret123") + "'")
	print("adult sign_up: '", await Cloud.sign_up(adult, "secret123", mail, year - 30, 6), "'")
	Cloud.sign_out()
	print("adult by name: '", await Cloud.sign_in(adult, "secret123"), "'")
	print("adult by email: '", await Cloud.sign_in(mail, "secret123"), "' name=", Cloud.commander)
	print("adult delete: '", await Cloud.delete_account(), "'")
	get_tree().quit()


func _check_pvp() -> void:
	var year := int(Time.get_date_dict_from_system()["year"])
	var defender := "Def_%d" % (randi() % 100000)
	var attacker := "Att_%d" % (randi() % 100000)
	# The defender: Command Tower 2, 3000 coins in the bank.
	for s in GameState.structures:
		if s["type"] == "hq":
			s["level"] = 2
	GameState.coins = 3000
	print("defender sign_up: '", await Cloud.sign_up(defender, "secret123", "", year - 9, 3), "'")
	var defender_id := Cloud.user_id
	Cloud.sign_out()
	GameState.new_player()
	print("attacker sign_up: '", await Cloud.sign_up(attacker, "secret123", "", year - 9, 3), "'")
	# Other real players at this level may come first: skip them until the test defender shows up.
	var found: Variant = {}
	var skip := []
	for i in 30:
		found = await Cloud.find_opponent(skip)
		if not (found is Dictionary) or (found as Dictionary).is_empty() or found["player_id"] == defender_id:
			break
		skip.append(found["player_id"])
	var ok: bool = found is Dictionary and found.get("player_id", "") == defender_id
	print("found the defender: ", ok, " | pool: ", found.get("loot_pool", {}) if found is Dictionary else found)
	var result := await Cloud.report_attack(defender_id, 2, 64, 300, 0, {"destroyed": [[4, 4]], "entry": [30.0, 34.0]})
	print("report: ", result, " (expected change ", Pvp.trophy_change(2, 0, 0), ")")
	var again: Variant = await Cloud.find_opponent([])
	print("shielded defender not offered again: ", not (again is Dictionary) or again.get("player_id", "") != defender_id)
	print("attacker delete: '", await Cloud.delete_account(), "'")
	print("defender sign_in: '", await Cloud.sign_in(defender, "secret123"), "'")
	var unseen: Variant = await Cloud.settle_attacks()
	print("unseen: ", (unseen as Array).size() if unseen is Array else unseen, " | trophies ", Cloud.trophies,
		" | shield hours ", snappedf(Cloud.shield_left() / 3600.0, 0.1))
	if unseen is Array and not (unseen as Array).is_empty():
		var a: Dictionary = unseen[0]
		print("attack: ", a.get("attacker_name"), " stars ", a.get("stars"), " coins ", a.get("coins"), " trophies ", a.get("trophies"),
			" | ago ", DefenseUI.ago(Cloud.seconds_since(str(a.get("created_at")))))
	var twice: Variant = await Cloud.settle_attacks()
	print("handed out once: ", twice is Array and (twice as Array).is_empty())
	var log_rows: Variant = await Cloud.defense_log()
	print("log rows: ", (log_rows as Array).size() if log_rows is Array else log_rows)
	print("defender delete: '", await Cloud.delete_account(), "'")
