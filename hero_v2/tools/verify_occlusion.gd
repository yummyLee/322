extends SceneTree
## GPU regression: compare the final composite with the same environment alone.
var failures := 0
var demo: Control
var wall: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition: failures += 1

func settle() -> void:
	for i in 10:
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw

func changed_pixels(a: Image, b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x,y)
			var cb := b.get_pixel(x,y)
			if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)>0.025:
				count += 1
	return count

func visible_pixels() -> int:
	demo.character_picture.show()
	await settle()
	var combined := root.get_texture().get_image()
	demo.character_picture.hide()
	await settle()
	var environment := root.get_texture().get_image()
	demo.character_picture.show()
	return changed_pixels(combined,environment)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	demo = load("res://hero_v2/main.tscn").instantiate()
	root.add_child(demo)
	demo.get_node("HUD").hide()
	await settle()
	demo.hero.set_physics_process(false)
	demo.hero.get_node("SecondaryMotion").set_physics_process(false)
	demo.hero.get_node("AnimationPlayer").pause()
	demo.environment_camera.size = 3.8
	wall = load("res://hero_v2/tools/occlusion_fixture.tscn").instantiate()
	demo.environment_world.add_child(wall)
	var toward_camera := Vector3(demo.environment_camera.global_basis.z.x, 0, demo.environment_camera.global_basis.z.z).normalized()
	wall.rotation.y = atan2(toward_camera.x,toward_camera.z)
	var shader: ShaderMaterial = demo.character_picture.material
	for mode in ["stable", "unfiltered", "native"]:
		demo.pixels = mode != "native"
		demo.stable_edges = mode != "unfiltered"
		demo.layout_picture()
		wall.position = demo.hero.position + toward_camera*1.0
		wall.scale = Vector3.ONE
		await settle()
		check(shader.get_shader_parameter("depth_ready"), mode+": depth textures match resized viewports")
		var hidden_count := await visible_pixels()
		check(hidden_count==0, mode+": foreground wall fully hides hero (%d visible pixels)" % hidden_count)
		shader.set_shader_parameter("occlusion_enabled",false)
		var old_count := await visible_pixels()
		check(old_count>500, mode+": old overlay would incorrectly show the hero")
		shader.set_shader_parameter("occlusion_enabled",true)
		wall.scale.y = 0.38
		var partial_count := await visible_pixels()
		check(partial_count>100 and partial_count<old_count*0.9, mode+": low wall hides only the lower body (%d/%d pixels)" % [partial_count,old_count])
		await settle()
		if mode == "stable":
			root.get_texture().get_image().save_png("res://hero_v2/preview/14_partial_occlusion.png")
		wall.position = demo.hero.position - toward_camera*1.5
		wall.scale.y = 1.0
		var front_count := await visible_pixels()
		check(front_count>old_count*0.9, mode+": hero in front of wall stays visible")
		await settle()
		var front_composite := root.get_texture().get_image()
		shader.set_shader_parameter("occlusion_enabled",false)
		await settle()
		check(changed_pixels(front_composite,root.get_texture().get_image())<30, mode+": unobscured subject retains original color and sampling")
		shader.set_shader_parameter("occlusion_enabled",true)
	# Rotate the real camera while the wall is kept between it and the character.
	for orbit in [PI/2, PI, -PI/4]:
		demo.environment_camera.orbit = orbit
		await settle()
		toward_camera = Vector3(demo.environment_camera.global_basis.z.x,0,demo.environment_camera.global_basis.z.z).normalized()
		wall.rotation.y = atan2(toward_camera.x,toward_camera.z)
		wall.position = demo.hero.position+toward_camera
		check(await visible_pixels()==0, "Camera orbit %.2f preserves foreground occlusion" % orbit)
	# Resize repeatedly to catch stale depth resources and invalid GPU bindings.
	for dimensions in [Vector2(1280,720),Vector2(1600,900),Vector2(1440,810)]:
		demo.size = dimensions
		demo.layout_picture()
		check(await visible_pixels()==0, "Resize %s preserves occlusion" % dimensions)
	# Use an existing authored tree as well as the controlled test wall.
	wall.hide()
	demo.pixels = true
	demo.stable_edges = true
	demo.layout_picture()
	demo.environment_camera.orbit = 0
	await settle()
	toward_camera = Vector3(demo.environment_camera.global_basis.z.x,0,demo.environment_camera.global_basis.z.z).normalized()
	var tree: Node3D = demo.environment_world.get_node("CourtyardProps/Tree2")
	demo.hero.position = tree.position - toward_camera*0.65 + demo.environment_camera.global_basis.x*0.18
	demo.hero.reset_physics_interpolation()
	demo.sync_pose()
	demo.display_hero.reset_physics_interpolation()
	var tree_visible := await visible_pixels()
	await settle()
	root.get_texture().get_image().save_png("res://hero_v2/preview/15_tree_occlusion.png")
	shader.set_shader_parameter("occlusion_enabled",false)
	var tree_overlay := await visible_pixels()
	check(tree_visible>0 and tree_visible<tree_overlay*0.85, "Existing courtyard tree naturally occludes the hero (%d/%d pixels)" % [tree_visible,tree_overlay])
	print("OCCLUSION FINISHED / failures=",failures)
	quit(0 if failures==0 else 1)
