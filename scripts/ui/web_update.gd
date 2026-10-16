class_name WebUpdate
extends CanvasLayer
## Web build only (owner, 16.10.2026: "save it on the iPad and just press refresh"): every
## publish writes version.json next to the game (tools/publish_web.ps1). The game knows its own
## stamp (the ?v= on index.js), checks the file now and then, and when a newer build is up it
## shows "New version, tap to update" at the top. Updating saves first, then reloads the page
## past every cache. Settings also has "Refresh game".

const CHECK_SECONDS := 45.0

var _mine := ""
var _http: HTTPRequest
var _button: Button


static func install(tree: SceneTree) -> void:
	if not OS.has_feature("web"):
		return
	var w := WebUpdate.new()
	w.layer = 119
	tree.root.add_child.call_deferred(w)


## Saves, then reloads the page with a fresh address so no cache serves the old game.
static func reload(tree: SceneTree) -> void:
	if not OS.has_feature("web"):
		return
	var state := tree.root.get_node_or_null("GameState")
	if state != null:
		state.save_game()
	await tree.create_timer(0.6).timeout
	JavaScriptBridge.eval("location.replace(location.pathname + '?r=' + Date.now())")


func _ready() -> void:
	_mine = str(JavaScriptBridge.eval(
		"(function(){var s=document.querySelector('script[src*=\"index.js\"]');" +
		"return s ? (new URL(s.src)).searchParams.get('v') || '' : '';})()", true))
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_done)
	_button = Button.new()
	_button.text = I18n.t("New version, tap to update")
	_button.add_theme_font_size_override("font_size", 24)
	for st in ["normal", "hover", "pressed"]:
		_button.add_theme_stylebox_override(st, UiTheme.box(UiTheme.OLIVE.lightened(0.1 if st == "hover" else 0.0), UiTheme.RADIUS, UiTheme.SAND_LINE, 1))
	_button.anchor_left = 0.5
	_button.anchor_right = 0.5
	_button.offset_left = -230
	_button.offset_right = 230
	_button.offset_top = 196
	_button.offset_bottom = 252
	_button.visible = false
	_button.pressed.connect(func() -> void: WebUpdate.reload(get_tree()))
	add_child(_button)
	var timer := Timer.new()
	timer.wait_time = CHECK_SECONDS
	timer.autostart = true
	timer.timeout.connect(_check)
	add_child(timer)
	get_tree().create_timer(5.0).timeout.connect(_check)


func _check() -> void:
	if _mine == "" or _button.visible or _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var folder := str(JavaScriptBridge.eval("location.href.split('?')[0].split('#')[0].replace(/[^\\/]*$/, '')", true))
	_http.request(folder + "version.json?r=%d" % Time.get_ticks_msec())


func _on_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data is Dictionary and str(data.get("v", "")) != "" and str(data["v"]) != _mine:
		_button.visible = true
		Audio.play("star", -8.0)
