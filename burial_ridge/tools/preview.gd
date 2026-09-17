extends SceneTree
# Screenshot harness: loads the actual game entrance; no scene generation.
var app: Control

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1920,1080)
	app = load("res://village/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.hero.set_physics_process(false)
	app.hero.position = Vector3(-54,0.08,0)
	app.hero.reset_physics_interpolation()
	app.camera.position = Vector3(-55,46,43)
	app.camera.rotation_degrees = Vector3(-47,0,0)
	app.camera.size = 43
	var args := OS.get_cmdline_user_args()
	var suffix := "overview"
	if "--joined" in args:
		suffix = "joined"
		app.camera.position = Vector3(-26,70,66)
		app.camera.size = 72
	if "--detail" in args:
		suffix = "detail"
		app.camera.position = Vector3(-72,39,21)
		app.camera.size = 23
	if "--seam" in args:
		suffix = "seam"
		app.camera.position = Vector3(-28,42,44)
		app.camera.size = 27
	if "--plain" in args:
		suffix += "_plain"
		for key in ["pixel","outline","toon","highlight","snap"]:
			app.options.get_node(key).button_pressed = false
	if "--settings" in args:
		suffix += "_settings"
		app.set_settings_open(true)
	app.status.text = "窑村西侧 · 乱葬岭"
	for i in range(40):
		await process_frame
	await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png("res://burial_ridge/preview_"+suffix+".png")
	print("CAPTURE ",suffix," result=",err)
	quit(err)
