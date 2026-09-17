extends "res://burial_ridge/tools/verify_gpu.gd"
func run() -> void:
	root.size=Vector2i(1920,1080)
	app=load("res://village/main.tscn").instantiate()
	root.add_child(app)
	for i in range(35): await process_frame
	check(app.hero.is_on_floor(),"Original spawn stands on ground")
	app.set_process(false)
	app.hero.set_physics_process(false)
	app.camera.rotation_degrees=Vector3(-47,0,0)
	app.camera.position=Vector3(0,43,35)
	app.camera.size=43
	app.status.text="窑村 · 旧土、旧屋与北侧院落"
	await capture("village_weathered_overview")
	place_hero(Vector3(-10,0,-1.6))
	app.camera.position=Vector3(-16,17,10)
	app.camera.look_at(Vector3(-10,0.8,-4.8))
	app.camera.size=10.5
	await capture("village_weathered_house")
	app.camera.rotation_degrees=Vector3(-47,0,0)
	app.camera.position=Vector3(0,26,8)
	app.camera.size=25
	app.status.text="窑村北侧 · 院落与疏开的林缘"
	await capture("village_north")
	place_hero(Vector3(-80,0,-24.8))
	app.camera.position=Vector3(-73,28,0)
	app.camera.size=24
	app.status.text="乱葬岭 · 圆顶石墓、石祠小庙与荒草"
	await capture("exploration_landmarks")
	app.camera.position=Vector3(-85,17,-13)
	app.camera.look_at(Vector3(-80,2,-28))
	app.camera.size=9
	await capture("dome_tomb_entry")
	place_hero(Vector3(-62,0,-20.7))
	app.camera.position=Vector3(-68,18,-10)
	app.camera.look_at(Vector3(-62,1.5,-24.5))
	app.camera.size=10
	await capture("stone_shrine_entry")
	app.options.get_node("toon").button_pressed=false
	var surface: MeshInstance3D=app.world.get_node("Terrain/BlendedVillageGround").get_child(0)
	check(not surface.material_override.get_shader_parameter("toon_enabled"),"Village blended soil follows original toon control")
	check(not app.world.get_node("Buildings/WestWorkshop/PlasterWalls").material_override.get_shader_parameter("toon_enabled"),"Weathered walls follow original toon control")
	app.options.get_node("toon").button_pressed=true
	app.get_node("Gear").pressed.emit()
	check(app.settings.visible and not app.hero.controls_enabled,"Original menu opens and pauses controls")
	app.pixel_slider.value=6
	await process_frame
	check(app.viewport.size==Vector2i(320,180),"Original pixel scaling retained")
	app.pixel_slider.value=3
	app.get_node("Settings/Panel/Margin/Content/Header/Close").pressed.emit()
	check(not app.settings.visible and app.hero.controls_enabled,"Closing menu restores controls")
	print("LIVED IN GPU VALIDATION / failures=",failures)
	quit(0 if failures==0 else 1)
