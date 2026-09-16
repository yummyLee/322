extends SceneTree
## GPU regression for real environment shadows and an independent opaque subject.
var failures := 0
var demo: Control

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		failures += 1

func settle() -> void:
	for i in 8:
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw

func difference(a: Image, b: Image) -> int:
	var changed := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)>0.04:
				changed += 1
	return changed

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This regression requires the GPU renderer")
		quit(1)
		return
	demo = load("res://hero_v2/main.tscn").instantiate()
	root.add_child(demo)
	demo.get_node("HUD").hide()
	await settle()
	demo.hero.set_physics_process(false)
	demo.hero.get_node("SecondaryMotion").set_physics_process(false)
	var animator: AnimationPlayer = demo.hero.get_node("AnimationPlayer")
	animator.pause()
	demo.environment_camera.size = 3.8
	await settle()
	var meshes: Array[Node] = demo.hero.find_children("*", "MeshInstance3D", true, false)
	var all_shadow_only := true
	for mesh in meshes:
		all_shadow_only = all_shadow_only and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	check(all_shadow_only and demo.hero.visible, "World character stays visible to real shadow rendering only")
	check(not demo.character_world.has_node("Shadow"), "No fake shadow plane in character stage")
	var resolve: ShaderMaterial = demo.character_picture.material
	check(resolve != null and resolve.get_shader_parameter("coverage_filter") == true and demo.character_viewport.size == demo.environment_viewport.size, "Subject retains its original supersampling and four-point resolve")
	check(demo.character_camera.global_transform.is_equal_approx(demo.environment_camera.global_transform), "Both layers use the same final camera transform")
	var env_image: Image = demo.environment_viewport.get_texture().get_image()
	var subject_image: Image = demo.character_viewport.get_texture().get_image()
	root.get_texture().get_image().save_png("res://hero_v2/preview/11_real_shadow.png")
	env_image.save_png("res://hero_v2/preview/12_environment_shadow.png")
	subject_image.save_png("res://hero_v2/preview/13_character_layer.png")
	var opaque := 0
	var transparent := 0
	var partial := 0
	for y in subject_image.get_height():
		for x in subject_image.get_width():
			var alpha := subject_image.get_pixel(x,y).a
			if alpha>0.99: opaque += 1
			elif alpha<0.01: transparent += 1
			else: partial += 1
	check(opaque>100 and transparent>opaque*2 and partial==0, "Character layer has crisp alpha and a transparent background")
	demo.hero.hide()
	await settle()
	var no_shadow: Image = demo.environment_viewport.get_texture().get_image()
	var shadow_pixels := difference(env_image,no_shadow)
	print("Real shadow pixel count: ", shadow_pixels)
	check(shadow_pixels>100, "Animated character geometry actually casts onto the environment")
	demo.hero.show()
	await settle()
	var sun: DirectionalLight3D = demo.environment_world.get_node("AfternoonSun")
	var env: Environment = demo.environment_world.get_node("Environment").environment
	sun.light_color = Color(1,0,0)
	sun.light_energy = 0.15
	env.ambient_light_color = Color(0,0,1)
	env.ambient_light_energy = 0.1
	await settle()
	check(difference(subject_image,demo.character_viewport.get_texture().get_image())==0, "Changing environment lighting does not affect the subject")
	check(difference(env_image,demo.environment_viewport.get_texture().get_image())>1000, "Environment lighting change really rendered")
	animator.play("run")
	animator.advance(0.17)
	animator.pause()
	demo.hero.get_node("Facing").rotation.y = PI/4
	demo.hero.get_node("Facing/Visual").outfit = 1
	demo.hero.get_node("Facing/Visual").show_hair = false
	await settle()
	var matching := true
	for bone in demo.source_rig.get_bone_count():
		matching = matching and demo.source_rig.get_bone_pose(bone).is_equal_approx(demo.display_rig.get_bone_pose(bone))
	check(matching, "All animation, hair and cloth bone poses match the shadow model")
	check(demo.display_hero.get_node("Facing/Visual/IndigoRobe").visible and not demo.display_hero.get_node("Facing/Visual/Hair").visible, "Outfit and hair visibility match the shadow model")
	check(demo.hero.get_node("Facing").transform.is_equal_approx(demo.display_hero.get_node("Facing").transform), "Eight-way facing matches between body and shadow")
	print("RENDER LAYERS FINISHED / failures=", failures)
	quit(0 if failures==0 else 1)
