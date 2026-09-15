extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1920,1080)
	var app = load("res://village/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	assert(app.viewport.size == Vector2i(640,360))
	assert(not app.settings.visible)
	app.get_node("Gear").pressed.emit()
	assert(app.settings.visible)
	app.pixel_slider.value = 6
	assert(app.outline.material_override.get_shader_parameter("pixel_size") == 1.0)
	assert(app.viewport.size == Vector2i(320,180))
	app.zoom_slider.value = 60
	assert(is_equal_approx(app.camera.size,app.start_size*0.6))
	for key in ["pixel","outline","toon","highlight","snap"]:
		app.options.get_node(key).button_pressed = false
	assert(app.viewport.size == Vector2i(1920,1080))
	assert(not app.outline.material_override.get_shader_parameter("outlines"))
	assert(not app.outline.material_override.get_shader_parameter("highlights"))
	assert(not app.snapping)
	assert(app.outline.material_override.get_shader_parameter("pixel_size") == 1.0)
	assert(not app.pixel_slider.editable)
	app.options.get_node("pixel").button_pressed = true
	assert(app.viewport.size == Vector2i(320,180))
	assert(app.pixel_slider.editable)
	app.pixel_slider.value = 1
	assert(app.outline.material_override.get_shader_parameter("pixel_size") == 1.0)
	app.pixel_slider.value = 12
	assert(app.viewport.size == Vector2i(160,90))
	for material in app.materials:
		assert(not material.get_shader_parameter("toon_enabled"))
	app.pan = Vector3(3,0,5)
	app.get_node("Settings/Panel/Margin/Content/Reset").pressed.emit()
	assert(app.pan == Vector3.ZERO and app.zoom_slider.value == 100)
	app.get_node("Settings/Panel/Margin/Content/Header/Close").pressed.emit()
	assert(not app.settings.visible)
	app.size = Vector2(1280,720)
	app.layout_view()
	assert(app.viewport.size == Vector2i(106,60))
	assert(app.picture.size.is_equal_approx(Vector2(1272,720)))
	app.pixel_slider.value = 3
	assert(app.viewport.size == Vector2i(426,240))
	assert(app.picture.size.is_equal_approx(Vector2(1278,720)))
	print("PASS: native low resolution, integer scaling, menu signals, effect toggles, zoom/reset, display resizing")
	app.queue_free()
	await process_frame
	quit()

