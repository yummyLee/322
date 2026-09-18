extends "res://burial_ridge/tools/verify_gpu.gd"
func capture(label: String) -> void:
	for i in range(14):await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://northern_ridge/preview_"+label+".png")==OK,"GPU screenshot: "+label)
func run() -> void:
	root.size=Vector2i(1920,1080)
	app=load("res://village/main.tscn").instantiate()
	root.add_child(app)
	for i in range(40):await process_frame
	check(app.hero.is_on_floor(),"Original village player spawn still grounded")
	check(app.world.has_node("NorthernRidge/RootWrappedStoneGate"),"Original game entry loads the saved northern extension")
	app.set_process(false)
	app.hero.set_physics_process(false)
	place_hero(Vector3(-61,0,-39))
	app.camera.rotation_degrees=Vector3(-47,0,0)
	app.camera.position=Vector3(-63,55,8)
	app.camera.size=45
	app.status.text="乱葬岭北侧 · 古树、根缠石门与路亭"
	await capture("overview")
	app.camera.position=Vector3(-30,80,51)
	app.camera.size=94
	app.status.text="北侧扩展 · 乱葬岭 · 窑村"
	await capture("joined")
	place_hero(Vector3(-55,0,-45))
	app.camera.position=Vector3(-60,17,-31)
	app.camera.look_at(Vector3(-55,1.8,-48))
	app.camera.size=13
	app.status.text="树根石门 · 保留入口与返回点"
	await capture("root_gate")
	place_hero(Vector3(-64,0,-34.5))
	app.camera.position=Vector3(-67,15,-21)
	app.camera.look_at(Vector3(-63,0.7,-36.5))
	app.camera.size=10
	app.status.text="旧路亭 · 木柱、残瓦与石供台"
	await capture("pavilion")
	place_hero(Vector3(-81,0,-61))
	app.camera.position=Vector3(-80,26,-39)
	app.camera.look_at(Vector3(-77,1,-64))
	app.camera.size=21
	app.status.text="红土缓坡 · 古树盘根与碎石小径"
	await capture("ancient_tree")
	place_hero(Vector3(-69,0,-42))
	app.camera.position=Vector3(-75,12,-28)
	app.camera.look_at(Vector3(-72,0.4,-42))
	app.camera.size=11
	app.status.text="药草洼地 · 苔土、杂草与旧铲"
	await capture("herb_hollow")
	app.camera.position=Vector3(-80,13,-37)
	app.camera.look_at(Vector3(-76,1.0,-58))
	app.camera.size=27
	app.status.text="北侧缓坡 · 起伏地形与顺坡小径"
	await capture("terrain_relief")
	app.camera.rotation_degrees=Vector3(-47,0,0)
	app.camera.position=Vector3(-67,28,-14)
	app.camera.size=25
	app.status.text="新旧地形衔接 · 墓地北侧"
	await capture("seam")
	app.camera.position=Vector3(-63,55,8)
	app.camera.size=45
	for key in ["pixel","outline","toon","highlight","snap"]:app.options.get_node(key).button_pressed=false
	var terrain: MeshInstance3D=app.world.get_node("NorthernRidge/ContinuousForestGround").get_child(0).get_node("BlendedTerrain")
	check(not terrain.material_override.get_shader_parameter("toon_enabled"),"New forest ground follows original toon toggle")
	await capture("plain")
	for key in ["pixel","outline","toon","highlight","snap"]:app.options.get_node(key).button_pressed=true
	app.get_node("Gear").pressed.emit()
	check(app.settings.visible and not app.hero.controls_enabled,"Original menu pauses player controls")
	app.pixel_slider.value=6
	await process_frame
	check(app.viewport.size==Vector2i(320,180),"Integer pixel scaling retained")
	app.pixel_slider.value=3
	app.get_node("Settings/Panel/Margin/Content/Header/Close").pressed.emit()
	check(not app.settings.visible and app.hero.controls_enabled,"Original menu closes and restores controls")
	print("NORTH GPU VALIDATION / failures=",failures)
	quit(0 if failures==0 else 1)
