extends "village_parts.gd"

func lighting() -> void:
	var rig := group(scene_root,"RenderRig")
	var env_node := WorldEnvironment.new()
	env_node.name = "VillageEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6b775b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d6dfe5")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	rig.add_child(env_node)
	env_node.owner = scene_root
	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-58,-28,0)
	sun.light_color = Color("fff4df")
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	rig.add_child(sun)
	sun.owner = scene_root
	var camera := Camera3D.new()
	camera.name = "VillageCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 36
	camera.far = 160
	camera.position = Vector3(0,46,43)
	camera.rotation_degrees = Vector3(-47,0,0)
	camera.current = true
	rig.add_child(camera)
	camera.owner = scene_root
	var quad := MeshInstance3D.new()
	quad.name = "PixelOutline"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2,2)
	quad.mesh = mesh
	quad.extra_cull_margin = 16384
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var post := ShaderMaterial.new()
	post.shader = load("res://burial_left_cave/outline.gdshader")
	quad.material_override = post
	quad.visible = false
	camera.add_child(quad)
	quad.owner = scene_root
	quad.position.z = -1






