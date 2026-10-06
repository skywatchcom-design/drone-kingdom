class_name WorldSetup
extends RefCounted
## Sky, sun, haze and the isometric orthographic camera shared by Home and Raid.
## The game is played sideways, so the camera keeps a fixed view height.

const CAM_DIR := Vector3(1.0, 1.15, 1.0)
const CAM_DISTANCE := 150.0


static func create(parent: Node3D, view_height: float) -> Camera3D:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.62, 0.82)
	sky_mat.sky_horizon_color = Color(0.78, 0.84, 0.9)
	sky_mat.ground_horizon_color = Color(0.72, 0.74, 0.76)
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
	# Haze that only starts behind the focus point, so distant blocks fade into the sky.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.74, 0.81, 0.88)
	env.fog_depth_begin = CAM_DISTANCE + 20.0
	env.fog_depth_end = CAM_DISTANCE + 110.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	sun.light_energy = 1.7
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 320.0
	parent.add_child(sun)

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
