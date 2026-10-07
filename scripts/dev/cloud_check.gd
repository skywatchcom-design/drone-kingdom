extends Node
## Dev: checks the account flow against the real Supabase project with throwaway accounts (a
## child without an email and an adult with one), then deletes both through the game:
##   godot --headless --path . res://scenes/dev/cloud_check.tscn


func _ready() -> void:
	GameState.persist = false
	GameState.new_player()
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
