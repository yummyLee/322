extends SceneTree
## Verify the existing village viewer and menu with only the new hero added.
var failures := 0
var app: Control

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print("PASS: " if condition else "FAIL: ",message)
	if not condition: failures += 1

func frames(count: int) -> void:
	for i in count: await physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func rendered_frame() -> Image:
	await frames(10)
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func changed_pixels(a: Image,b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x,y)
			var cb := b.get_pixel(x,y)
			if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)>0.025: count += 1
	return count

func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	app = load("res://village/main.tscn").instantiate()
	root.add_child(app)
	await frames(60)
	var hero: CharacterBody3D = app.hero
	var layer: Node = app.character_rendering
	check(hero.is_on_floor(),"New hero stands on existing village collision ground")
	check(app.world.scene_file_path=="res://village/yao_village.tscn","Original village scene is instanced unchanged")
	check(app.start_size==36 and app.zoom==1.0 and app.camera.global_basis.x.is_equal_approx(Vector3.RIGHT),"Original camera angle and default framing are retained")
	check(app.pixel_block_size==3 and app.outline.visible and layer.outline.visible,"Original pixel size and character/environment outline remain active")
	check(app.world.get_world_3d()!=layer.display_hero.get_world_3d(),"Character lighting remains independent")
	check(hero.movement_camera==app.camera,"Character follows original village camera controls")
	var image := await rendered_frame()
	image.save_png("res://village/preview_with_character.png")
	var start := hero.position
	key(KEY_RIGHT,true)
	await frames(40)
	check(hero.position.x>start.x+1.1 and hero.locomotion==&"walk","Arrow keys move the new hero")
	key(KEY_RIGHT,false)
	key(KEY_SHIFT,true)
	key(KEY_LEFT,true)
	await frames(30)
	check(hero.locomotion==&"run" and absf(hero.velocity.x)>4.3,"Shift selects original run animation and speed")
	key(KEY_LEFT,false)
	key(KEY_SHIFT,false)
	app.get_node("Gear").pressed.emit()
	check(app.settings.visible and not hero.controls_enabled,"Original gear menu opens and pauses movement")
	start = hero.position
	key(KEY_UP,true)
	await frames(20)
	key(KEY_UP,false)
	check(Vector2(hero.position.x-start.x,hero.position.z-start.z).length()<0.01,"Arrow keys cannot move hero while menu is open")
	image = await rendered_frame()
	image.save_png("res://village/preview_with_character_settings.png")
	app.options.get_node("outline").button_pressed = false
	await frames(5)
	check(not layer.outline.material_override.get_shader_parameter("outlines"),"Menu outline toggle synchronizes character outline")
	app.options.get_node("outline").button_pressed = true
	app.pixel_slider.value = 6
	await frames(10)
	check(app.viewport.size==Vector2i(app.size/6.0) and layer.viewport.size==app.viewport.size,"Existing pixel slider adjusts both aligned 1:1 layers")
	app.options.get_node("pixel").button_pressed = false
	await frames(10)
	check(layer.viewport.size==app.viewport.size and layer.picture.material.get_shader_parameter("depth_ready"),"Original pixel switch also retains native-resolution occlusion")
	app.options.get_node("pixel").button_pressed = true
	app.pixel_slider.value = 3
	app.zoom_slider.value = 30
	await frames(10)
	check(is_equal_approx(app.camera.size,10.8) and is_equal_approx(layer.camera.size,10.8),"Original zoom slider synchronizes the character camera")
	app.get_node("Settings/Panel/Margin/Content/Header/Close").pressed.emit()
	check(not app.settings.visible and hero.controls_enabled,"Original close button restores movement")
	key(KEY_C,true)
	key(KEY_C,false)
	await frames(3)
	check(layer.display_hero.get_node("Facing/Visual/IndigoRobe").visible,"Wardrobe keys reach the existing world viewport")
	hero.get_node("Facing/Visual").outfit = 0
	image = await rendered_frame()
	image.save_png("res://village/preview_with_character_detail.png")
	hero.set_physics_process(false)
	hero.get_node("AnimationPlayer").pause()
	hero.get_node("SecondaryMotion").set_physics_process(false)
	hero.position = Vector3(0.15,0.08,2.35)
	hero.reset_physics_interpolation()
	layer.sync_pose()
	layer.display_hero.reset_physics_interpolation()
	var masked := await rendered_frame()
	masked.save_png("res://village/preview_with_character_occlusion.png")
	layer.picture.hide()
	var background := await rendered_frame()
	layer.picture.show()
	layer.picture.material.set_shader_parameter("occlusion_enabled",false)
	var overlay := await rendered_frame()
	var visible_count := changed_pixels(masked,background)
	var old_count := changed_pixels(overlay,background)
	check(old_count>100 and visible_count<old_count*0.8,"Original village tree and render grid occlude the independent hero (%d/%d)" % [visible_count,old_count])
	check(layer.picture.position.is_equal_approx(app.picture.position),"Character follows original camera pixel-scroll correction")
	print("VILLAGE INTEGRATION FINISHED / failures=",failures)
	quit(0 if failures==0 else 1)
