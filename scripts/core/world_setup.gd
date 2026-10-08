class_name WorldSetup
extends RefCounted
## Sky, sun, haze and the isometric orthographic camera shared by Home and Raid.
## The game is played sideways, so the camera keeps a fixed view height.
## The look is "late afternoon" (7.10.2026): a low warm sun with long shadows, a warm horizon
## and haze, a soft glow on fire and lit windows, and darker screen edges. Dev: `-- --mood
## classic` shows the earlier midday look for comparison.

const CAM_DIR := Vector3(1.0, 1.15, 1.0)
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
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	# A lower sun from the side: longer shadows that show the shapes.
	sun.rotation_degrees = Vector3(-38.0, 52.0, 0.0) if warm else Vector3(-52.0, 28.0, 0.0)
	sun.light_energy = (1.15 if compat else 1.85) if warm else (1.05 if compat else 1.7)
	sun.light_color = Color(1.0, 0.88, 0.72) if warm else Color(1.0, 0.92, 0.8)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 320.0
	parent.add_child(sun)
	if warm:
		_vignette(parent)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = view_height
	cam.near = 0.1
	cam.far = 600.0
	parent.add_child(cam)
	cam.make_current()
	place_camera(cam, Vector3(0, 10, 0))
	return cam


static func place_camera(cam: Camera3D, focus: Vector3) -> void:
	cam.position = focus + CAM_DIR.normalized() * CAM_DISTANCE
	cam.look_at(focus, Vector3.UP)


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
