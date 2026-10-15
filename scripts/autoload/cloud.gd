extends Node
## The player's account on Supabase (approved sketch Tnvwhfaq4KMqSS85z45tfx, owner 7.10.2026):
## commander name, birth month and year, password, and an email from age 13 (COPPA: none for
## younger players). Supabase wants an email for every account, so under-13 accounts get one made
## up from a hash of the name (nothing is ever sent to it). Players sign in with their email, or
## with the commander name when they have none. The name is kept, unique, in public.players.
## A signed-in player's save goes to their players row a few seconds after each change.

signal account_changed

const SESSION_PATH := "user://session.json"
const EMAIL_DOMAIN := "players.skywatch.invalid"
const PUSH_DELAY := 3.0
## Players this old or older sign up with an email.
const EMAIL_AGE := 13
## The terms and privacy policy the player agrees to; bump when they change.
const TERMS_VERSION := "2026-10-07"
const TERMS_URL := "https://skywatchcom-design.github.io/drone-kingdom/legal/terms-%s.html"
const PRIVACY_URL := "https://skywatchcom-design.github.io/drone-kingdom/legal/privacy-%s.html"
## Where the password-reset email sends the player to pick a new password.
const RESET_URL := "https://skywatchcom-design.github.io/drone-kingdom/account/reset.html"
const SUPPORT_EMAIL := "skywatchcom@gmail.com"
## Names nobody may take (checked without case), on top of the database's uniqueness.
const RESERVED := ["noa", "razor", "admin", "skywatch", "ironfang", "commander", "moderator"]
const BLOCKED := ["fuck", "shit", "sex", "porn", "nazi", "hitler", "זונה", "כוס", "זין", "מניאק", "שרמוטה"]

var commander := ""
## True for players under 13 (from the birth date at sign-up): no email, a parent gate in the store.
var child := false
var user_id := ""
var _access := ""
var _refresh := ""
var _expires := 0.0
var _push_in := -1.0
var _pushing := false
## Trophies and shield as the server last said (see settle_attacks).
var trophies := 0
## Unix time (this device's clock) the shield ends; 0 without one.
var shield_until := 0.0
## This device's clock minus the server's, in seconds.
var _skew := 0.0


func _ready() -> void:
	# Dev store screenshots (--showcase, --anon) show "Commander", never the real signed-in one.
	if OS.is_debug_build() and (OS.get_cmdline_user_args().has("--showcase") or OS.get_cmdline_user_args().has("--anon")):
		return
	_load_session()


func signed_in() -> bool:
	return user_id != ""


static func email_for(name: String) -> String:
	return "u%s@%s" % [name.to_lower().sha256_text().substr(0, 24), EMAIL_DOMAIN]


## Empty when `name` may be used; otherwise why not (before asking the server).
static func name_problem(name: String) -> String:
	var re := RegEx.create_from_string("^[A-Za-z0-9_\\x{05D0}-\\x{05EA}]{3,14}$")
	if re.search(name) == null:
		return I18n.t("3–14 letters, digits or _")
	var low := name.to_lower()
	if RESERVED.has(low):
		return I18n.t("That name is taken. Try another.")
	for bad: String in BLOCKED:
		if low.contains(bad):
			return I18n.t("Please choose another name")
	return ""


## Age in whole years for someone born in `month` of `year`.
static func age(year: int, month: int) -> int:
	var now := Time.get_date_dict_from_system()
	var years := int(now["year"]) - year
	return years - 1 if int(now["month"]) < month else years


static func email_problem(email: String) -> String:
	var re := RegEx.create_from_string("^[^@\\s]+@[^@\\s]+\\.[^@\\s]{2,}$")
	return "" if re.search(email.strip_edges()) != null else I18n.t("Check the email address")


## True when nobody has the name yet, false when taken, null without a connection.
func name_available(name: String) -> Variant:
	var r := await _call(HTTPClient.METHOD_POST, "/rest/v1/rpc/name_available", {"n": name}, false)
	return r["data"] if r["code"] == 200 else null


## Signs up and stores the current base in the cloud. `email` is "" for players under 13.
## Returns "" or what went wrong.
func sign_up(name: String, password: String, email: String, birth_year: int, birth_month: int) -> String:
	var why := name_problem(name)
	if why != "":
		return why
	child = age(birth_year, birth_month) < EMAIL_AGE
	if not child and email_problem(email) != "":
		return email_problem(email)
	var free = await name_available(name)
	if free == null:
		return I18n.t("No connection. Try again in a moment.")
	if not free:
		return I18n.t("That name is taken. Try another.")
	var address := email_for(name) if child else email.strip_edges().to_lower()
	var r := await _call(HTTPClient.METHOD_POST, "/auth/v1/signup", {"email": address, "password": password}, false)
	if r["code"] != 200 or not (r["data"] is Dictionary) or not r["data"].has("access_token"):
		if r["code"] in [400, 422]:
			return I18n.t("That name is taken. Try another.") if child else I18n.t("This email already has a base. Log in instead.")
		return I18n.t("No connection. Try again in a moment.")
	_take_session(r["data"], name)
	var row := {"id": user_id, "name": name, "hq_level": GameState.hq_level(), "save": GameState.save_data(),
		"birth_year": birth_year, "birth_month": birth_month, "is_child": child,
		"terms_version": TERMS_VERSION, "terms_accepted_at": Time.get_datetime_string_from_system(true) + "Z"}
	var made := await _call(HTTPClient.METHOD_POST, "/rest/v1/players", row)
	if made["code"] != 201:
		# The name went between the check and now: give the account back up.
		sign_out()
		return I18n.t("That name is taken. Try another.")
	account_changed.emit()
	return ""


## Signs in with an email, or a commander name for accounts without one, and replaces the base
## on this device with the one in the cloud.
func sign_in(login: String, password: String) -> String:
	login = login.strip_edges()
	var address := login.to_lower() if login.contains("@") else email_for(login)
	var r := await _call(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": address, "password": password}, false)
	if r["code"] != 200 or not (r["data"] is Dictionary) or not r["data"].has("access_token"):
		if r["code"] in [400, 401]:
			return I18n.t("Wrong email or password") if login.contains("@") else I18n.t("Wrong name or password. From age 13, log in with your email.")
		return I18n.t("No connection. Try again in a moment.")
	_take_session(r["data"], login)
	var rows := await _call(HTTPClient.METHOD_GET, "/rest/v1/players?select=name,save,is_child&id=eq." + user_id)
	if rows["code"] == 200 and rows["data"] is Array and not rows["data"].is_empty():
		var row: Dictionary = rows["data"][0]
		commander = str(row["name"])
		child = bool(row.get("is_child", false))
		_save_session()
		if GameState.apply_save(row["save"]):
			GameState.save_game()
	account_changed.emit()
	return ""


## Asks Supabase to email a password-reset link. The answer is the same whether or not the
## email has an account, so nobody can use it to find out who plays.
func request_reset(email: String) -> String:
	var why := email_problem(email)
	if why != "":
		return why
	var r := await _call(HTTPClient.METHOD_POST, "/auth/v1/recover?redirect_to=" + RESET_URL.uri_encode(), {"email": email.strip_edges().to_lower()}, false)
	if r["code"] == 0 or r["code"] >= 500:
		return I18n.t("No connection. Try again in a moment.")
	if r["code"] == 429:
		return I18n.t("Too many requests. Try again in a few minutes.")
	return ""


## Deletes the account and its cloud base for good, then starts over on this device.
func delete_account() -> String:
	var r := await _call(HTTPClient.METHOD_POST, "/rest/v1/rpc/delete_my_account", {})
	if r["code"] >= 300 or r["code"] == 0:
		return I18n.t("No connection. Try again in a moment.")
	sign_out()
	GameState.new_player()
	return ""


# ---------------------------------------------------------------- attacks between players

## A real player's base to attack (see find_opponent in the pvp migration), as a battle base
## (Pvp.base_from_row); {} when nobody is free; null without a connection or an account.
func find_opponent(skip: Array) -> Variant:
	if not signed_in():
		return null
	var r := await _call(HTTPClient.METHOD_POST, "/rest/v1/rpc/find_opponent", {"skip": skip})
	if r["code"] != 200:
		return null
	return Pvp.base_from_row(r["data"], GameState.now()) if r["data"] is Dictionary else {}


## The next base to attack: a real player's (skipping GameState.pvp_skip), or an Iron Fang outpost
## when nobody is free, the player has no account, or there is no connection.
func next_base() -> Dictionary:
	var found: Variant = await find_opponent(GameState.pvp_skip)
	if found is Dictionary and not (found as Dictionary).is_empty():
		return found
	return Pvp.outpost(randi(), GameState.hq_level())


## Sends an attack's result. `foe` is "" for an Iron Fang outpost. Returns {change, trophies} or
## {} when it didn't get through.
func report_attack(foe: String, stars: int, percent: int, coins: int, fuel: int, report: Dictionary) -> Dictionary:
	if not signed_in():
		return {}
	var body := {"foe": foe if foe != "" else null, "stars": stars, "percent": percent, "coins": coins, "fuel": fuel, "report": report}
	var r := await _call(HTTPClient.METHOD_POST, "/rest/v1/rpc/report_attack", body)
	if r["code"] != 200 or not (r["data"] is Dictionary):
		return {}
	trophies = int(r["data"].get("trophies", trophies))
	if foe != "":
		shield_until = 0.0
	account_changed.emit()
	return r["data"]


## The attacks since the player was last here (each is handed out once), newest first; null
## without a connection. Also brings the trophies and the shield up to date.
func settle_attacks() -> Variant:
	if not signed_in():
		return null
	var r := await _call(HTTPClient.METHOD_POST, "/rest/v1/rpc/settle_attacks", {})
	if r["code"] != 200 or not (r["data"] is Dictionary):
		return null
	var d: Dictionary = r["data"]
	trophies = int(d.get("trophies", 0))
	shield_until = 0.0
	if d.get("now") != null:
		_skew = GameState.now() - _unix(str(d["now"]))
	if d.get("shield_until") != null and d.get("now") != null:
		# Counted from the server's clock, so a wrong clock on the device doesn't matter.
		var left := _unix(str(d["shield_until"])) - _unix(str(d["now"]))
		if left > 0.0:
			shield_until = GameState.now() + left
	account_changed.emit()
	return d.get("unseen", [])


## The last attacks on the player's base, newest first (up to 20); null without a connection.
func defense_log() -> Variant:
	if not signed_in():
		return null
	var r := await _call(HTTPClient.METHOD_GET, "/rest/v1/attacks?select=id,created_at,attacker_name,stars,percent,coins,fuel,trophies,report&order=created_at.desc&limit=20")
	return r["data"] if r["code"] == 200 and r["data"] is Array else null


## Seconds of shield left (0 without one).
func shield_left() -> float:
	return maxf(0.0, shield_until - GameState.now())


## Seconds since a server timestamp.
func seconds_since(stamp: String) -> float:
	return maxf(0.0, GameState.now() - _skew - _unix(stamp))


## A Postgres timestamp ("2026-10-15 10:20:30.123+00" or ISO) as unix seconds.
static func _unix(stamp: String) -> float:
	var s := stamp.replace(" ", "T")
	var frac := 0.0
	var dot := s.find(".")
	var zone := maxi(s.rfind("+"), s.rfind("Z"))
	if zone < 10:
		zone = s.length()
	if dot > 0 and dot < zone:
		frac = float("0" + s.substr(dot, zone - dot))
		s = s.substr(0, dot) + s.substr(zone)
		zone = dot
	return Time.get_unix_time_from_datetime_string(s.substr(0, zone)) + frac


func sign_out() -> void:
	commander = ""
	child = false
	user_id = ""
	trophies = 0
	shield_until = 0.0
	_access = ""
	_refresh = ""
	_push_in = -1.0
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	account_changed.emit()


## Called by GameState.save_game: sends the save soon, once, however many saves come first.
func queue_push() -> void:
	if signed_in() and _push_in < 0.0:
		_push_in = PUSH_DELAY


func _process(delta: float) -> void:
	if _push_in < 0.0:
		return
	_push_in -= delta
	if _push_in <= 0.0 and not _pushing:
		_push_in = -1.0
		_push()


func _push() -> void:
	_pushing = true
	var body := {"save": GameState.save_data(), "hq_level": GameState.hq_level()}
	var r := await _call(HTTPClient.METHOD_PATCH, "/rest/v1/players?id=eq." + user_id, body)
	_pushing = false
	if r["code"] >= 300 or r["code"] == 0:
		# Offline or the server said no: try again a bit later.
		_push_in = 20.0


# ---------------------------------------------------------------- session and requests

func _take_session(data: Dictionary, name: String) -> void:
	commander = name
	user_id = str(data["user"]["id"])
	_access = str(data["access_token"])
	_refresh = str(data["refresh_token"])
	_expires = Time.get_unix_time_from_system() + float(data.get("expires_in", 3600))
	_save_session()


func _save_session() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"name": commander, "child": child, "user": user_id, "access": _access, "refresh": _refresh, "expires": _expires}))


func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
	if d is Dictionary:
		commander = str(d.get("name", ""))
		child = bool(d.get("child", false))
		user_id = str(d.get("user", ""))
		_access = str(d.get("access", ""))
		_refresh = str(d.get("refresh", ""))
		_expires = float(d.get("expires", 0.0))


## Swaps the refresh token for a new access token once the old one is about to run out.
func _fresh_token() -> void:
	if Time.get_unix_time_from_system() < _expires - 60.0 or _refresh == "":
		return
	var r := await _call(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh}, false)
	if r["code"] == 200 and r["data"] is Dictionary and r["data"].has("access_token"):
		_take_session(r["data"], commander)


## One request to Supabase: {code (0 = no connection), data (parsed JSON or null)}.
func _call(method: int, path: String, body: Variant = null, as_player: bool = true) -> Dictionary:
	if as_player:
		await _fresh_token()
	var headers := PackedStringArray(["apikey: " + BackendConfig.PUBLISHABLE_KEY, "Content-Type: application/json"])
	if as_player and _access != "":
		headers.append("Authorization: Bearer " + _access)
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var err := http.request(BackendConfig.URL + path, headers, method, JSON.stringify(body) if body != null else "")
	if err != OK:
		http.queue_free()
		return {"code": 0, "data": null}
	var res: Array = await http.request_completed
	http.queue_free()
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(res[1]) if int(res[0]) == HTTPRequest.RESULT_SUCCESS else 0,
		"data": JSON.parse_string(text) if text != "" else null}
