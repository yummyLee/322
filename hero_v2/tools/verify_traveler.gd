extends SceneTree
## Integration verification and actual GPU captures, never a runtime dependency.
var failures: Array[String] = []
var demo: Node
var hero: CharacterBody3D
var camera: Camera3D
var world: Node3D

func _initialize() -> void:
	verify.call_deferred()

func check(condition: bool, message: String) -> void:
	print("PASS: " if condition else "FAIL: ",message)
	if not condition:
		failures.append(message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func shift(pressed: bool) -> void:
	key(KEY_SHIFT,pressed)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func screenshot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://hero_v2/preview/"+label+".png")
	check(result == OK,"GPU capture: "+label)

func verify() -> void:
	demo = load("res://hero_v2/main.tscn").instantiate()
	root.add_child(demo)
	current_scene = demo
	world = demo.get_node("EnvironmentViewport/EnvironmentWorld")
	hero = world.get_node("Traveler")
	camera = world.get_node("FollowCamera")
	await frames(30)
	check(hero.is_on_floor(),"Character rests on authored ground")
	check(camera.target == hero and hero.movement_camera == camera,"Saved camera and target references resolve")
	key(KEY_E,true)
	key(KEY_E,false)
	await frames(2)
	check(is_equal_approx(camera.orbit,PI/4),"E key reaches the SubViewport camera exactly once")
	key(KEY_R,true)
	key(KEY_R,false)
	key(KEY_F,true)
	key(KEY_F,false)
	await frames(2)
	check(is_equal_approx(camera.size,2.8),"F key selects character close-up")
	key(KEY_R,true)
	key(KEY_R,false)
	await frames(2)
	check(is_equal_approx(camera.size,7.0) and is_zero_approx(camera.orbit),"R restores authored framing")
	var rig: Skeleton3D = hero.get_node("Facing/Visual/Rig")
	var wardrobe: Node3D = hero.get_node("Facing/Visual")
	check(wardrobe.has_node("LinenRobe/CrossCollarTorso"),"Independent ancient outfit scene")
	check(rig.get_node("HeadSculpt").mesh.get_aabb().size.x<0.23,"Narrow anatomical head geometry")
	check(absf(rig.get_bone_global_rest(rig.find_bone("UpperArmL")).origin.x)<0.17,"Natural narrow shoulder spacing")
	check(wardrobe.get_node("Hair").get_child_count()>=10,"Separate editable hairstyle")
	check(rig.get_bone_count()>=30,"Saved shared skeleton includes cloth/hair bones")
	var invalid_skins := 0
	var blend_vertices := 0
	for mesh in hero.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null or mesh.get_node_or_null(mesh.skeleton)!=rig:
			invalid_skins += 1
		var weights: PackedFloat32Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_WEIGHTS]
		for i in range(0,weights.size(),4):
			if absf(weights[i]+weights[i+1]+weights[i+2]+weights[i+3]-1)>0.0001:
				invalid_skins += 1
			if weights[i]>0.001 and weights[i+1]>0.001:
				blend_vertices += 1
	check(invalid_skins==0,"All body, clothing and hair weights/bindings valid")
	check(blend_vertices>500,"Smooth skin blending across joints and flexible details")
	var player: AnimationPlayer = hero.get_node("AnimationPlayer")
	for name in ["idle","walk","run"]:
		check(player.has_animation(name),"Saved animation "+name)
		var clip := player.get_animation(name)
		for i in range(clip.get_track_count()):
			var path := clip.track_get_path(i)
			check(hero.has_node(NodePath(String(path).split(":")[0])),"Animation binding "+String(path))
	if DisplayServer.get_name() != "headless":
		await screenshot("01_world")
		camera.size = 3.8
		await frames(5)
		await screenshot("02_front")
		camera.orbit = PI/2
		await frames(5)
		await screenshot("03_side")
		camera.orbit = PI
		await frames(5)
		await screenshot("04_back")
		camera.orbit = 0
		camera.size = 2.8
		demo.pixels = false
		demo.layout_picture()
		await frames(5)
		await screenshot("08_model_detail")
		wardrobe.outfit = 1
		await frames(5)
		await screenshot("09_indigo_outfit")
		wardrobe.outfit = 2
		wardrobe.show_hair = false
		await frames(5)
		await screenshot("10_anatomy_study")
		wardrobe.outfit = 0
		wardrobe.show_hair = true
		demo.pixels = true
		demo.layout_picture()
		camera.orbit = 0
		camera.size = 7
	var origin := hero.position
	var camera_origin := camera.position
	key(KEY_RIGHT,true)
	await frames(60)
	var walking_distance := hero.position.distance_to(origin)
	check(hero.locomotion == &"walk", "Arrow input enters walk animation")
	if DisplayServer.get_name() != "headless":
		camera.size = 3.8
		await screenshot("06_walk")
	check(walking_distance > 1.6 and walking_distance < 2.2,"Walk speed / displacement")
	check((hero.position-origin).normalized().dot(Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()) > 0.98,"Right moves screen right")
	check(camera.position.distance_to(camera_origin) > 1.5,"Camera follows movement")
	await process_frame
	# The display copy and real shadow must interpolate from identical physics poses.
	check(hero.get_global_transform_interpolated().is_equal_approx(demo.display_hero.get_global_transform_interpolated()),"Moving body and environment shadow stay spatially synchronized")
	var poses_match := true
	for bone in rig.get_bone_count():
		poses_match = poses_match and rig.get_bone_pose(bone).is_equal_approx(demo.display_rig.get_bone_pose(bone))
	check(poses_match,"Moving body and environment shadow use identical bone poses")
	key(KEY_RIGHT,false)
	key(KEY_LEFT,true)
	await frames(2)
	var wanted := -Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
	check(hero.velocity.normalized().dot(wanted)>0.999,"Opposite key changes movement within one physics tick")
	var snapped_yaw := roundf(atan2(wanted.x,wanted.z)/(TAU/8.0))*(TAU/8.0)
	check(absf(angle_difference(hero.facing.rotation.y,snapped_yaw))<0.0001,"Facing switches immediately to a discrete 8-direction pose")
	key(KEY_LEFT,false)
	await frames(2)
	check(Vector2(hero.velocity.x,hero.velocity.z).length()<0.001,"Release stops without drifting")
	await frames(20)
	check(hero.locomotion == &"idle", "Release returns to idle")
	# Run across the clear center crossing, away from the planters.
	hero.position = Vector3(0,0.06,0)
	hero.velocity = Vector3.ZERO
	hero.reset_physics_interpolation()
	await frames(5)
	origin = hero.position
	shift(true)
	await frames(2)
	check(Input.is_physical_key_pressed(KEY_SHIFT),"Physical Shift event is recognized")
	key(KEY_DOWN,true)
	await frames(55)
	var running_distance := hero.position.distance_to(origin)
	print("RUN INPUT: down=",Input.is_physical_key_pressed(KEY_DOWN)," shift=",Input.is_physical_key_pressed(KEY_SHIFT)," position=",hero.position," velocity=",hero.velocity," actual=",hero.get_real_velocity())
	check(hero.locomotion == &"run", "Hold Shift enters run animation")
	check(absf(rig.get_bone_pose_rotation(rig.find_bone("ForearmL")).get_euler().x)>0.7,"Run bends actual skinned elbow")
	check(rig.get_bone_pose_rotation(rig.find_bone("Hips")).get_euler().x>0.08,"Run leans shared skeleton forward")
	check(rig.get_bone_pose_rotation(rig.find_bone("HairSideL")).angle_to(Quaternion.IDENTITY)>0.001,"Hair bones respond subtly to movement")
	check(rig.get_bone_pose_rotation(rig.find_bone("HemFrontL")).angle_to(Quaternion.IDENTITY)>0.001,"Robe hem has secondary movement")
	check(running_distance > 3.3 and running_distance > walking_distance*1.65,"Run is faster than walk")
	if DisplayServer.get_name() != "headless":
		camera.size = 3.8
		await screenshot("05_run")
		camera.orbit = PI/2
		# Keep a real run pose while the camera rotates for silhouette inspection.
		await screenshot("07_run_side")
		camera.orbit = 0
	shift(false)
	await frames(12)
	check(hero.locomotion == &"walk", "Releasing Shift while moving restores walk")
	key(KEY_DOWN,false)
	await frames(20)
	# Turning the camera must turn the screen-space movement basis with it.
	camera.orbit = PI/2
	hero.position = Vector3(0,0.06,0)
	hero.velocity = Vector3.ZERO
	hero.reset_physics_interpolation()
	await frames(5)
	origin = hero.position
	key(KEY_UP,true)
	await frames(30)
	var forward := -camera.global_basis.z
	forward.y = 0
	check((hero.position-origin).normalized().dot(forward.normalized()) > 0.97,"Up stays screen up after camera orbit")
	key(KEY_UP,false)
	await frames(20)
	# Probe a real scene obstacle using CharacterBody3D's collision solver.
	hero.position = Vector3(-4.4,0.03,0.3)
	hero.velocity = Vector3.ZERO
	hero.reset_physics_interpolation()
	await frames(5)
	check(hero.test_move(hero.global_transform,Vector3(0,0,2)),"Authored planter blocks character")
	# Diagonal normalization on clear ground.
	hero.position = Vector3(0,0.06,0)
	hero.velocity = Vector3.ZERO
	hero.reset_physics_interpolation()
	key(KEY_UP,true)
	key(KEY_RIGHT,true)
	await frames(20)
	check(absf(Vector2(hero.velocity.x,hero.velocity.z).length()-hero.walk_speed)<0.03,"Diagonal speed is normalized")
	key(KEY_UP,false)
	key(KEY_RIGHT,false)
	await frames(20)
	var idle_clip := player.get_animation("idle")
	check(idle_clip.track_get_key_value(0,0)!=idle_clip.track_get_key_value(0,12),"Idle has subtle vertical motion")
	key(KEY_B,true)
	key(KEY_B,false)
	await frames(2)
	check(not camera.stabilize_target and not demo.stable_edges,"B enables old rendering for comparison")
	key(KEY_B,true)
	key(KEY_B,false)
	await frames(2)
	check(camera.stabilize_target and demo.stable_edges,"B restores stable character rendering")
	key(KEY_P,true)
	key(KEY_P,false)
	await frames(2)
	check(not demo.pixels and not camera.snap_to_pixels,"P shows native-resolution 3D")
	key(KEY_P,true)
	key(KEY_P,false)
	await frames(2)
	check(demo.pixels and camera.stabilize_target,"P restores stable pixel presentation")
	key(KEY_C,true)
	key(KEY_C,false)
	await frames(2)
	check(wardrobe.get_node("IndigoRobe").visible and not wardrobe.get_node("LinenRobe").visible,"C changes outfit while retaining shared body")
	key(KEY_C,true)
	key(KEY_C,false)
	await frames(2)
	check(not wardrobe.get_node("IndigoRobe").visible and rig.visible,"C exposes independent body study")
	key(KEY_C,true)
	key(KEY_C,false)
	key(KEY_H,true)
	key(KEY_H,false)
	await frames(2)
	check(not wardrobe.get_node("Hair").visible,"Hairstyle can be hidden independently")
	await frames(90)
	check(rig.get_bone_pose_rotation(rig.find_bone("HairSideL")).angle_to(Quaternion.IDENTITY)<0.003,"Hair settles after movement stops")
	check(rig.get_bone_pose_rotation(rig.find_bone("HemFrontL")).angle_to(Quaternion.IDENTITY)<0.003,"Cloth settles after movement stops")
	print("VERIFICATION FINISHED / failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
