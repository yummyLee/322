extends Control

const TOON = preload("res://pixel_lab/toon.gdshader")
const WORLD = preload("res://pixel_lab/world.tscn")
var viewport: SubViewport
var picture: TextureRect
var camera: Camera3D
var post: ShaderMaterial
var materials: Array[ShaderMaterial] = []
var status: Label
var angle := 0.68
var target := Vector3(0, 0.6, 0)
var orbit := false
var snap := true
var pixelated := true
var toon := true
var elapsed := 0.0
var capture_frames := 0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("18232e"))
	var bg := ColorRect.new()
	bg.color = Color("18232e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	viewport = SubViewport.new()
	viewport.size = Vector2i(384, 216)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	picture = TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(picture)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("263b46")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a4bdd0")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	viewport.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("ffdfa3")
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	viewport.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.5
	camera.far = 100.0
	viewport.add_child(camera)
	camera.current = true
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	quad.mesh = mesh
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	post = ShaderMaterial.new()
	post.shader = preload("res://pixel_lab/outline.gdshader")
	quad.material_override = post
	camera.add_child(quad)
	quad.position.z = -1
	var world := WORLD.instantiate()
	viewport.add_child(world)
	collect_materials(world)
	build_ui()
	resized.connect(layout_picture)
	layout_picture()

func collect_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count() if node.mesh else 0):
			var mat = node.get_active_material(surface)
			if mat is ShaderMaterial and mat.shader == TOON and mat not in materials:
				materials.append(mat)
	for child in node.get_children():
		collect_materials(child)

func build_ui() -> void:
	var heading := Label.new()
	heading.text = "PIXEL / 03     ·     FOREST CROSSING"
	heading.position = Vector2(36, 20)
	heading.add_theme_font_size_override("font_size", 24)
	add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "t3ssel8r-inspired rendering study   /   Godot 4.7   /   editable 3D scene"
	subtitle.position = Vector2(36, 54)
	subtitle.modulate = Color("95aeb6")
	add_child(subtitle)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 16)
	add_child(status)
	var controls := HBoxContainer.new()
	controls.position = Vector2(36, 90)
	controls.add_theme_constant_override("separation", 16)
	add_child(controls)
	for entry in [["Pixel [1]", "pixel"], ["Outline [2]", "outline"], ["Light bands [3]", "toon"], ["Edge light [4]", "highlight"], ["Snap [5]", "snap"], ["Orbit [Space]", "orbit"]]:
		var button := CheckButton.new()
		button.text = entry[0]
		button.button_pressed = entry[1] != "orbit"
		button.toggled.connect(func(value: bool): set_option(entry[1], value))
		button.name = entry[1]
		controls.add_child(button)
	controls.name = "Options"

func set_option(option: String, value: bool) -> void:
	match option:
		"pixel":
			pixelated = value
			layout_picture()
		"outline": post.set_shader_parameter("outlines", value)
		"highlight": post.set_shader_parameter("highlights", value)
		"toon":
			toon = value
			for mat in materials:
				mat.set_shader_parameter("toon_enabled", value)
		"snap": snap = value
		"orbit": orbit = value

func layout_picture() -> void:
	var available := Vector2(maxf(size.x - 48, 384), maxf(size.y - 210, 216))
	var factor := maxf(1.0, floor(minf(available.x / 384.0, available.y / 216.0)))
	picture.size = Vector2(384, 216) * factor
	picture.position = Vector2((size.x - picture.size.x) / 2.0, 146 + (available.y - picture.size.y) / 2.0)
	viewport.size = Vector2i(384, 216) if pixelated else Vector2i(picture.size)
	status.position = Vector2(36, size.y - 48)

func _process(delta: float) -> void:
	elapsed += delta
	if orbit:
		angle += delta * 0.18
	var movement := Vector3(Input.get_axis("ui_left", "ui_right"), 0, Input.get_axis("ui_up", "ui_down"))
	target += movement * delta * 2.0
	camera.position = target + Vector3(sin(angle) * 16, 12, cos(angle) * 16)
	camera.look_at(target)
	if snap:
		var pixel_size := camera.size / float(viewport.size.y)
		var basis_view := camera.global_basis
		var local_position := basis_view.inverse() * camera.global_position
		local_position.x = snappedf(local_position.x, pixel_size)
		local_position.y = snappedf(local_position.y, pixel_size)
		camera.global_position = basis_view * local_position
	status.text = "%d × %d   |   Arrow keys: pan   ·   R: reset   |   %d FPS" % [viewport.size.x, viewport.size.y, Engine.get_frames_per_second()]
	if "--capture" in OS.get_cmdline_user_args():
		capture_frames += 1
		if capture_frames >= 90 and elapsed > 2.0:
			set_process(false)
			capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://pixel_lab/preview.png")
	get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var mapping := {KEY_1: "pixel", KEY_2: "outline", KEY_3: "toon", KEY_4: "highlight", KEY_5: "snap", KEY_SPACE: "orbit"}
	if event.keycode in mapping:
		var button := get_node("Options/" + mapping[event.keycode]) as CheckButton
		button.button_pressed = not button.button_pressed
	if event.keycode == KEY_R:
		target = Vector3(0, 0.6, 0)
		angle = 0.68
