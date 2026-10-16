class_name WorldSetup
extends RefCounted
## Sky, sun, haze and the isometric orthographic camera shared by Home and Raid.
## The game is played sideways, so the camera keeps a fixed view height.
## The look is "late afternoon" (7.10.2026): a low warm sun with long shadows, a warm horizon
## and haze, a soft glow on fire and lit windows, and darker screen edges. Dev: `-- --mood
## classic` shows the earlier midday look for comparison.

const CAM_DIR := Vector3(1.0, 1.15, 1.0)
## The "leo" look views a little lower, like the reference: buildings show more of their walls.
static var cam_dir := CAM_DIR
## In portrait the camera keeps the width; view sizes (and zoom limits) scale by this.
static var size_scale := 1.0
const CAM_DISTANCE := 150.0


static func create(parent: Node3D, view_height: float) -> Camera3D:
	var warm := not OS.get_cmdline_user_args().has("classic")
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.42, 0.58, 0.8) if warm else Color(0.45, 0.62, 0.82)
	sky_mat.sky_horizon_color = Color(0.96, 0.82, 0.64) if warm else Color(0.78, 0.84, 0.9)
	sky_mat.ground_horizon_color = Color(0.8, 0.72, 0.6) if warm else Color(0.72, 0.74, 0.76)
	sky_mat.ground_bottom_color = Color(0.32, 0.34, 0.37)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_exposure = 0.92
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# Haze that only starts behind the focus point, so distant ground fades into the sky.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.9, 0.84, 0.74) if warm else Color(0.74, 0.81, 0.88)
	env.fog_depth_begin = CAM_DISTANCE + (35.0 if warm else 20.0)
	env.fog_depth_end = CAM_DISTANCE + (150.0 if warm else 110.0)
	if warm:
		# A soft glow on bright things (fire, flashes, lit windows) and a touch more colour.
		env.glow_enabled = true
		env.glow_intensity = 0.55
		env.glow_strength = 0.9
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 0.9
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.15
		env.adjustment_contrast = 1.1
	# The web build runs the Compatibility renderer, which lights everything brighter and
	# flatter: pull exposure and ambient down there so it matches the phone look.
	if compat:
		env.tonemap_exposure = 0.85
		env.ambient_light_energy = 0.3
	if MeshKit.toy:
		# Look trial: clean midday light like a toy model on a table, no grade, no haze.
		env.glow_enabled = false
		env.adjustment_enabled = false
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.9
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.86, 0.9, 1.0)
		env.ambient_light_energy = 0.32 if compat else 0.45
		sky_mat.sky_top_color = Color(0.62, 0.8, 0.96)
		sky_mat.sky_horizon_color = Color(0.86, 0.93, 0.98)
		sky_mat.ground_horizon_color = Color(0.86, 0.93, 0.98)
		env.fog_light_color = Color(0.86, 0.93, 0.98)
		if MeshKit.look in ["diorama", "town", "leo"]:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.95, 0.96, 0.97)
			env.fog_enabled = false
		if MeshKit.look == "leo":
			# Firmer shading, a grey backdrop.
			env.background_color = Color(0.82, 0.82, 0.8) if MeshKit.palette == "mil" else Color(0.88, 0.88, 0.88)
			env.ambient_light_energy *= 0.63
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	# A lower sun from the side: longer shadows that show the shapes.
	sun.rotation_degrees = Vector3(-38.0, 52.0, 0.0) if warm else Vector3(-52.0, 28.0, 0.0)
	sun.light_energy = (1.15 if compat else 1.85) if warm else (1.05 if compat else 1.7)
	sun.light_color = Color(1.0, 0.88, 0.72) if warm else Color(1.0, 0.92, 0.8)
	if MeshKit.toy:
		sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
		sun.light_energy = 0.85 if compat else 1.15
	if MeshKit.look == "leo":
		sun.rotation_degrees = Vector3(-50.0, 20.0, 0.0)
		sun.light_energy *= 1.25
		sun.light_color = Color(1.0, 0.98, 0.94)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 320.0
	parent.add_child(sun)
	if warm and not MeshKit.toy:
		_vignette(parent)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = view_height
	cam_dir = Vector3(1.0, 0.85, 1.0) if MeshKit.look == "leo" else CAM_DIR
	var screen := parent.get_viewport().get_visible_rect().size
	size_scale = 1.0
	if screen.y > screen.x:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		size_scale = 1.4
		cam.size = view_height * size_scale
	cam.near = 0.1
	cam.far = 600.0
	parent.add_child(cam)
	cam.make_current()
	place_camera(cam, Vector3(0, 10, 0))
	return cam


static func place_camera(cam: Camera3D, focus: Vector3) -> void:
	cam.position = focus + cam_dir.normalized() * CAM_DISTANCE
	cam.look_at(focus, Vector3.UP)


## Dev, for store videos: `--no-hud` hides the HUD; `--cinema A,B,S[,DX,DZ]` moves the camera over
## S seconds from A to B times its starting view size while sliding DX/DZ meters (screen-ish axes).
static func dev_camera(owner: Node, cam: Camera3D, hud: CanvasLayer, focus: Vector3) -> void:
	if not OS.is_debug_build():
		return
	var args := OS.get_cmdline_user_args()
	if args.has("--no-hud"):
		hud.visible = false
	if not args.has("--cinema"):
		return
	var p: PackedStringArray = args[args.find("--cinema") + 1].split(",")
	var size0 := cam.size
	var secs := float(p[2])
	var slide := Vector3(float(p[3]), 0.0, float(p[4])) if p.size() >= 5 else Vector3.ZERO
	cam.size = size0 * float(p[0])
	place_camera(cam, focus - slide * 0.5)
	var tw := owner.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "size", size0 * float(p[1]), secs)
	tw.tween_method(func(f: Vector3) -> void: place_camera(cam, f), focus - slide * 0.5, focus + slide * 0.5, secs)


## Darker screen edges, under the HUD, so the eye goes to the middle.
static func _vignette(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	parent.add_child(layer)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.06, 0.04, 0.0))
	grad.set_color(1, Color(0.05, 0.06, 0.04, 0.5))
	grad.add_point(0.62, Color(0.05, 0.06, 0.04, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
