extends Node
## The player's account on Supabase (approved sketch Tnvwhfaq4KMqSS85z45tfx): a commander name and
## a password, no email. Supabase wants an email, so the game makes one up from a hash of the
## name (nothing is ever sent to it); the name itself is kept, unique, in public.players.
## A signed-in player's save goes to their players row a few seconds after each change.

signal account_changed

const SESSION_PATH := "user://session.json"
const EMAIL_DOMAIN := "players.skywatch.invalid"
const PUSH_DELAY := 3.0
## Names nobody may take (checked without case), on top of the database's uniqueness.
const RESERVED := ["noa", "razor", "admin", "skywatch", "ironfang", "commander", "moderator"]
const BLOCKED := ["fuck", "shit", "sex", "porn", "nazi", "hitler", "זונה", "כוס", "זין", "מניאק", "שרמוטה"]

var commander := ""
var user_id := ""
var _access := ""
var _refresh := ""
var _expires := 0.0
var _push_in := -1.0
var _pushing := false


func _ready() -> void:
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


## True when nobody has the name yet, false when taken, null without a connection.
func name_available(name: String) -> Variant:
	var r := await _call(HTTPClient.METHOD_POST, "/rest/v1/rpc/name_available", {"n": name}, false)
	return r["data"] if r["code"] == 200 else null


## Signs up and stores the current base in the cloud. Returns "" or what went wrong.
func sign_up(name: String, password: String) -> String:
	var why := name_problem(name)
	if why != "":
		return why
	var free = await name_available(name)
	if free == null:
		return I18n.t("No connection. Try again in a moment.")
	if not free:
		return I18n.t("That name is taken. Try another.")
	var r := await _call(HTTPClient.METHOD_POST, "/auth/v1/signup", {"email": email_for(name), "password": password}, false)
	if r["code"] != 200 or not (r["data"] is Dictionary) or not r["data"].has("access_token"):
		return I18n.t("That name is taken. Try another.") if r["code"] in [400, 422] else I18n.t("No connection. Try again in a moment.")
	_take_session(r["data"], name)
	var row := {"id": user_id, "name": name, "hq_level": GameState.hq_level(), "save": GameState.save_data()}
	var made := await _call(HTTPClient.METHOD_POST, "/rest/v1/players", row)
	if made["code"] != 201:
		# The name went between the check and now: give the account back up.
		sign_out()
		return I18n.t("That name is taken. Try another.")
	account_changed.emit()
	return ""


## Signs in and replaces the base on this device with the one in the cloud.
func sign_in(name: String, password: String) -> String:
	var r := await _call(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": email_for(name.strip_edges()), "password": password}, false)
	if r["code"] != 200 or not (r["data"] is Dictionary) or not r["data"].has("access_token"):
		return I18n.t("Wrong name or password") if r["code"] in [400, 401] else I18n.t("No connection. Try again in a moment.")
	_take_session(r["data"], name.strip_edges())
	var rows := await _call(HTTPClient.METHOD_GET, "/rest/v1/players?select=name,save&id=eq." + user_id)
	if rows["code"] == 200 and rows["data"] is Array and not rows["data"].is_empty():
		var row: Dictionary = rows["data"][0]
		commander = str(row["name"])
		_save_session()
		if GameState.apply_save(row["save"]):
			GameState.save_game()
	account_changed.emit()
	return ""


func sign_out() -> void:
	commander = ""
	user_id = ""
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
		f.store_string(JSON.stringify({"name": commander, "user": user_id, "access": _access, "refresh": _refresh, "expires": _expires}))


func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
	if d is Dictionary:
		commander = str(d.get("name", ""))
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
