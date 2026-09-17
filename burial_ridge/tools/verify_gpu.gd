extends SceneTree
var app: Control
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ",message)
	if not value:
		failures += 1

func capture(label: String) -> void:
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://burial_ridge/preview_"+label+".png") == OK,"GPU screenshot: "+label)

func run() -> void:
	root.size = Vector2i(1920,1080)
	app = load("res://village/main.tscn").instantiate()
	root.add_child(app)
	for i in range(40):
		await process_frame
	check(app.world.has_node("WesternBurialRidge"),"Actual game entry includes saved west expansion")
	check(app.hero.is_on_floor(),"Original hero spawn still stands on the village ground")
	await capture("village_start")
	app.set_process(false)
	app.hero.set_physics_process(false)
	app.hero.position = Vector3(-54,0.08,0)
	app.hero.reset_physics_interpolation()
	app.camera.rotation_degrees = Vector3(-47,0,0)
	app.camera.position = Vector3(-55,46,43)
	app.camera.size = 43
	app.status.text = "窑村西侧 · 乱葬岭"
	await capture("overview")
	app.camera.position = Vector3(-26,70,66)
	app.camera.size = 72
	await capture("joined")
	app.camera.position = Vector3(-72,39,21)
	app.camera.size = 23
	await capture("detail")
	app.hero.position = Vector3(-70.7,0.08,-18.4)
	app.hero.reset_physics_interpolation()
	app.camera.position = Vector3(-72,27,7)
	app.camera.size = 11
	app.status.text = "乱葬岭 · 玩家与墓碑、石龛比例"
	await capture("human_scale")
	app.hero.position = Vector3(-51,0.08,-0.3)
	app.hero.reset_physics_interpolation()
	app.camera.position = Vector3(-49,25,22.5)
	app.camera.size = 13
	app.status.text = "乱葬岭 · 土路、车辙与入户踏石"
	await capture("road_detail")
	app.hero.position = Vector3(-54,0.08,0)
	app.hero.reset_physics_interpolation()
	app.status.text = "窑村西侧 · 乱葬岭"
	app.camera.position = Vector3(-28,42,44)
	app.camera.size = 27
	await capture("seam")
	app.camera.position = Vector3(-55,46,43)
	app.camera.size = 43
	for key in ["pixel","outline","toon","highlight","snap"]:
		app.options.get_node(key).button_pressed = false
	check(app.viewport.size == Vector2i(1920,1080),"Plain mode renders full 1920x1080")
	await capture("plain")
	for key in ["pixel","outline","toon","highlight","snap"]:
		app.options.get_node(key).button_pressed = true
	app.get_node("Gear").pressed.emit()
	check(app.settings.visible and not app.hero.controls_enabled,"Existing settings menu opens and pauses movement")
	app.pixel_slider.value = 6
	await process_frame
	check(app.viewport.size == Vector2i(320,180),"Pixel size six uses existing integer viewport scaling")
	check(app.character_rendering.viewport.size == app.viewport.size,"Character and scenery grids still match")
	app.pixel_slider.value = 3
	app.options.get_node("outline").button_pressed = false
	check(not app.outline.material_override.get_shader_parameter("outlines"),"Existing outline toggle works")
	app.options.get_node("outline").button_pressed = true
	await capture("settings")
	app.get_node("Settings/Panel/Margin/Content/Header/Close").pressed.emit()
	check(not app.settings.visible and app.hero.controls_enabled,"Existing menu close restores controls")
	print("WEST GPU VALIDATION / failures=",failures)
	quit(0 if failures == 0 else 1)
