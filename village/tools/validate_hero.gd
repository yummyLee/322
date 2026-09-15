extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var scene = load("res://village/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var hero = scene.hero
	hero.position = Vector3(-4,0.1,5)
	for i in range(10):
		await physics_frame
	assert(hero.is_on_floor(),"Hero must land on saved ground")
	var start: Vector3 = hero.position
	Input.action_press("ui_right")
	for i in range(40):
		await physics_frame
	assert(hero.position.x > start.x+1.0,"Right arrow must move hero right")
	assert(hero.animator.current_animation == "walk")
	assert(absf(hero.velocity.length()-hero.walk_speed)<0.1)
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	assert(InputMap.event_is_action(shift, "hero_run"))
	Input.parse_input_event(shift)
	Input.action_press("ui_right")
	for i in range(30):
		await physics_frame
	print("Run check: ", Input.is_action_pressed("hero_run"), " clip=", hero.animator.current_animation, " velocity=",hero.velocity)
	assert(hero.animator.current_animation == "run")
	assert(absf(hero.velocity.length()-hero.run_speed)<0.1)
	Input.action_release("ui_right")
	shift.pressed = false
	Input.parse_input_event(shift)
	for i in range(25):
		await physics_frame
	assert(hero.animator.current_animation == "idle")
	scene.set_settings_open(true)
	start = hero.position
	Input.action_press("ui_up")
	for i in range(15):
		await physics_frame
	assert(hero.position.distance_to(start)<0.01,"Settings must suppress movement")
	Input.action_release("ui_up")
	scene.set_settings_open(false)
	# Verify saved collision contact independently of keyboard input.
	hero.position = Vector3(38.8,0.1,10)
	Input.action_press("ui_right")
	for i in range(60):
		await physics_frame
	Input.action_release("ui_right")
	assert(hero.position.x < 39.4,"Saved boundary must block travel")
	assert(scene.follow_position.distance_to(hero.position+Vector3(0,1,0))<0.5)
	for clip in ["idle","walk","run"]:
		assert(hero.animator.has_animation(clip))
	print("PASS: ground, camera-relative walk, Shift run, idle, menu suppression, boundary collision, camera follow, saved animation clips")
	scene.free()
	quit()






