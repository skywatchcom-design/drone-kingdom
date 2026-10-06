extends Node
## Sound effects and phone vibration. Every sound is synthesized at startup (no audio files),
## so there is nothing to license and nothing to download.
##   Sfx.play("coin")          one-shot sound
##   Sfx.set_hum(0.6)          rotor hum volume during a battle (0 = silent)
##   Sfx.buzz(30)              short vibration on phones
##   Sfx.music(true)           the calm base theme (assets/audio/base_theme.ogg, an original
##                             piece composed in code by tools/make_music.py)

const RATE := 22050
const VOICES := 12

var enabled := true
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _hum: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_wanted := false
const MUSIC_DB := -15.0
var _last_played := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = GameState.sound_on
	_build_library()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_hum = AudioStreamPlayer.new()
	_hum.stream = _streams["hum"]
	_hum.volume_db = -80.0
	add_child(_hum)
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/audio/base_theme.ogg")
	_music.volume_db = MUSIC_DB
	add_child(_music)


## Plays a sound. Repeats of the same sound within `min_gap` seconds are skipped,
## so a swarm of drones firing at once doesn't turn into noise.
func play(sound: String, volume_db: float = 0.0, min_gap: float = 0.03) -> void:
	if not enabled or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -10.0)) < min_gap:
		return
	_last_played[sound] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	# Headroom: many sounds overlap in a battle, so everything sits 6 dB below full scale.
	p.volume_db = volume_db - 6.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()


func set_hum(level: float) -> void:
	if not enabled or level <= 0.01:
		if _hum.playing:
			_hum.stop()
		return
	if not _hum.playing:
		_hum.play()
	_hum.volume_db = linear_to_db(clampf(level, 0.0, 1.0)) - 18.0


func buzz(ms: int) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## Starts or fades out the base theme. It plays only while wanted and music is on.
func music(on: bool) -> void:
	_music_wanted = on
	var play := on and GameState.music_on
	if play and not _music.playing:
		_music.volume_db = -40.0
		_music.play()
		create_tween().tween_property(_music, "volume_db", MUSIC_DB, 1.5)
	elif not play and _music.playing:
		var tween := create_tween()
		tween.tween_property(_music, "volume_db", -40.0, 0.6)
		tween.tween_callback(_music.stop)


func refresh_music() -> void:
	music(_music_wanted)


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		set_hum(0.0)


# ---------------------------------------------------------------- synthesis

func _build_library() -> void:
	_streams["click"] = _tone(2200.0, 2000.0, 0.03, "sine", 0.35)
	_streams["deploy"] = _tone(380.0, 950.0, 0.18, "square", 0.25)
	_streams["shot_courier"] = _mix([_tone(1500.0, 650.0, 0.13, "sine", 0.45), _noise(0.05, 0.15, 0.6)])
	_streams["shot_scout"] = _tone(1900.0, 1200.0, 0.06, "square", 0.22)
	_streams["release"] = _tone(260.0, 120.0, 0.25, "saw", 0.3)
	_streams["impact"] = _noise(0.09, 0.4, 0.5)
	_streams["thud"] = _mix([_tone(95.0, 38.0, 0.45, "sine", 0.9), _noise(0.3, 0.6, 0.12)])
	_streams["collapse"] = _mix([_noise(1.0, 0.7, 0.08), _tone(70.0, 35.0, 0.8, "sine", 0.6)])
	_streams["net"] = _noise(0.35, 0.35, 0.25)
	_streams["drone_down"] = _tone(600.0, 90.0, 0.6, "saw", 0.35)
	_streams["rifle"] = _mix([_noise(0.05, 0.35, 0.7), _tone(900.0, 300.0, 0.05, "square", 0.12)])
	_streams["cannon"] = _mix([_tone(70.0, 30.0, 0.6, "sine", 1.0), _noise(0.45, 0.8, 0.1)])
	_streams["charge"] = _concat([_tone(1800.0, 1800.0, 0.05, "square", 0.15), _tone(1, 1, 0.05, "sine", 0.0), _tone(1800.0, 1800.0, 0.05, "square", 0.15)])
	_streams["breach"] = _mix([_noise(1.1, 0.9, 0.06), _tone(60.0, 25.0, 0.9, "sine", 0.9)])
	_streams["soldier_down"] = _tone(520.0, 260.0, 0.22, "sine", 0.3)
	_streams["jet"] = _mix([_noise(1.6, 0.5, 0.05), _tone(420.0, 160.0, 1.6, "saw", 0.12)])
	_streams["flare"] = _mix([_noise(0.5, 0.35, 0.4), _tone(900.0, 2400.0, 0.4, "sine", 0.15)])
	_streams["tank_down"] = _mix([_noise(0.8, 0.7, 0.1), _tone(110.0, 40.0, 0.7, "saw", 0.4)])
	# A soft, round two-note chime (was a sharp beep).
	_streams["coin"] = _concat([_tone(784.0, 784.0, 0.06, "sine", 0.22), _tone(1046.0, 1046.0, 0.14, "sine", 0.18)])
	_streams["build"] = _concat([_tone(523.0, 523.0, 0.08, "square", 0.2), _tone(784.0, 784.0, 0.14, "square", 0.2)])
	_streams["star"] = _concat([_tone(784.0, 784.0, 0.09, "sine", 0.45), _tone(1047.0, 1047.0, 0.09, "sine", 0.45), _tone(1568.0, 1568.0, 0.25, "sine", 0.45)])
	_streams["hum"] = _hum_loop()


## A tone that glides from `f0` to `f1` with a quick attack and an exponential fade.
func _samples_tone(f0: float, f1: float, dur: float, wave: String, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		var f := lerpf(f0, f1, k)
		phase += f / RATE
		var x := fmod(phase, 1.0)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if x < 0.5 else -1.0
			"saw":
				s = 2.0 * x - 1.0
			_:
				s = sin(TAU * x)
		var env := minf(1.0, k * 40.0) * exp(-k * 4.0)
		out[i] = s * env * vol
	return out


## White noise through a one-pole low-pass (`smooth` near 0 = darker), fading out.
func _samples_noise(dur: float, vol: float, smooth: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var k := float(i) / n
		y += (randf_range(-1.0, 1.0) - y) * smooth
		out[i] = y * vol * minf(1.0, k * 60.0) * exp(-k * 5.0) * (1.0 / maxf(smooth, 0.5))
	return out


func _tone(f0: float, f1: float, dur: float, wave: String, vol: float) -> AudioStreamWAV:
	return _to_wav(_samples_tone(f0, f1, dur, wave, vol))


func _noise(dur: float, vol: float, smooth: float) -> AudioStreamWAV:
	return _to_wav(_samples_noise(dur, vol, smooth))


func _mix(parts: Array) -> AudioStreamWAV:
	var longest := 0
	var decoded := []
	for p: AudioStreamWAV in parts:
		var s := _from_wav(p)
		decoded.append(s)
		longest = maxi(longest, s.size())
	var out := PackedFloat32Array()
	out.resize(longest)
	for s: PackedFloat32Array in decoded:
		for i in s.size():
			out[i] += s[i]
	return _to_wav(out)


func _concat(parts: Array) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for p: AudioStreamWAV in parts:
		out.append_array(_from_wav(p))
	return _to_wav(out)


## Seamless one-second rotor drone: stacked harmonics with a fast flutter, plus soft noise.
func _hum_loop() -> AudioStreamWAV:
	var n := RATE
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var flutter := 0.75 + 0.25 * sin(TAU * 30.0 * t)
		var s := sin(TAU * 110.0 * t) * 0.5 + sin(TAU * 220.0 * t) * 0.3 + sin(TAU * 330.0 * t) * 0.15
		y += (randf_range(-1.0, 1.0) - y) * 0.1
		out[i] = (s * flutter + y * 0.6) * 0.35
	var wav := _to_wav(out)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func _from_wav(wav: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := wav.data.size() / 2
	out.resize(n)
	for i in n:
		out[i] = wav.data.decode_s16(i * 2) / 32767.0
	return out
