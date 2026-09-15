extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var scene = load("res://village/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var hero = scene.hero
	var anim: Animation = hero.animator.get_animation("run")
	for path in ["Visual/Hips/Torso:rotation", "Visual/Hips/LeftLeg/Knee:rotation", "Visual/Hips/Torso/LeftArm/Elbow:rotation"]:
		var track := anim.find_track(NodePath(path),Animation.TYPE_VALUE)
		assert(track >= 0)
		var rotation: Vector3 = anim.track_get_key_value(track,1)
		if "Elbow" in path:
			assert(rotation.x < 0,"Elbow bends forward for +Z character")
		else:
			assert(rotation.x > 0,"Torso leans forward; knee folds backward")
	assert(scene.viewport.size == Vector2i(640,360))
	assert(scene.outline.material_override.get_shader_parameter("pixel_size") == 1.0)
	assert(ProjectSettings.get_setting("physics/common/physics_interpolation"))
	assert(hero.get_node("Visual/Hips/Torso/Tunic").mesh is ArrayMesh)
	# Actual rendered leftward run. Capture three phases and measure screen root stability.
	scene.set_zoom(0.58)
	hero.position = Vector3(-2,0.1,3)
	hero.reset_physics_interpolation()
	for i in range(15): await physics_frame
	Input.action_press("ui_left")
	Input.action_press("hero_run")
	var min_x := INF
	var max_x := -INF
	for i in range(72):
		await process_frame
		await RenderingServer.frame_post_draw
		if i > 16:
			var p: Vector2 = scene.camera.unproject_position(hero.get_global_transform_interpolated().origin)
			p = p*scene.display_scale + scene.picture.position
			min_x = minf(min_x,p.x)
			max_x = maxf(max_x,p.x)
		if i in [24,40,56] and DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png("res://village/hero/run_left_%d.png"%i)
	assert(hero.visual.basis.z.x < -0.95,"Character faces left when running left")
	assert(max_x-min_x <= 1.1,"Camera root drift must stay within one output pixel")
	Input.action_release("ui_left")
	Input.action_release("hero_run")
	print("PASS: +Z knee/elbow/lean, refined saved mesh, true 640x360 rendering, interpolation, left facing; horizontal screen drift=",max_x-min_x," output pixels")
	scene.free()
	quit()
