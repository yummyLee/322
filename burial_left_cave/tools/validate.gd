extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var world = load("res://burial_left_cave/world.tscn").instantiate()
	assert(world.get_script() == null)
	for node in world.find_children("*","",true,false):
		assert(node.owner == world, str(node.name))
	var camera = world.get_node("RenderRig/VillageCamera")
	var post = camera.get_node("PixelOutline")
	assert(not post.visible)
	assert(post.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	camera.position += Vector3(0.5,0,0)
	var edited := PackedScene.new()
	assert(edited.pack(world) == OK)
	var restored = edited.instantiate()
	assert(restored.get_node("RenderRig/VillageCamera").position.is_equal_approx(camera.position))
	restored.free()
	world.free()
	var app = load("res://burial_left_cave/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	assert(app.viewport.size == Vector2i(1920,1080))
	assert(not app.settings.visible)
	app.get_node("Gear").pressed.emit()
	assert(app.settings.visible)
	app.pixel_slider.value = 6
	assert(app.outline.material_override.get_shader_parameter("pixel_size") == 6.0)
	app.options.get_node("pixel").button_pressed = false
	assert(app.outline.material_override.get_shader_parameter("pixel_size") == 1.0)
	app.options.get_node("pixel").button_pressed = true
	assert(app.outline.material_override.get_shader_parameter("pixel_size") == 6.0)
	app.zoom_slider.value = 60
	assert(is_equal_approx(app.camera.size,app.initial_size*0.6))
	app.content.get_node("Reset").pressed.emit()
	assert(app.zoom_slider.value == 100)
	app.content.get_node("Header/Close").pressed.emit()
	assert(not app.settings.visible)
	assert(app.viewport.size == Vector2i(1920,1080))
	print("PASS: static editable scene, persistence, render rig, settings, pixel/zoom controls, 1080p")
	app.queue_free()
	await process_frame
	quit()
