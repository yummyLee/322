extends Control

@onready var viewport: SubViewport = $WorldViewport
@onready var picture: TextureRect = $Picture
@onready var world: Node3D = $WorldViewport/YaoVillage
@onready var camera: Camera3D = $WorldViewport/YaoVillage/RenderRig/VillageCamera
@onready var outline: MeshInstance3D = $WorldViewport/YaoVillage/RenderRig/VillageCamera/PixelOutline
@onready var status: Label = $Status
@onready var hero: CharacterBody3D = world.get_node_or_null("Hero")
@onready var character_rendering: Node = $CharacterRendering
var follow_position := Vector3.ZERO
var picture_home := Vector2.ZERO
var display_scale := 1.0
const RENDER_RESOLUTION := Vector2i(1920,1080)
@onready var settings: Control = $Settings
@onready var options: VBoxContainer = $Settings/Panel/Margin/Content/Options
@onready var zoom_slider: HSlider = $Settings/Panel/Margin/Content/Zoom
@onready var zoom_label: Label = $Settings/Panel/Margin/Content/ZoomLabel
@onready var pixel_slider: HSlider = $Settings/Panel/Margin/Content/PixelSize
@onready var pixel_label: Label = $Settings/Panel/Margin/Content/PixelLabel
var pixel_block_size := 3
var start_transform: Transform3D
var start_size: float
var pan := Vector3.ZERO
var orbit_angle := 0.0
var auto_orbit := false
var pixels := true
var snapping := true
var zoom := 1.0
var elapsed := 0.0
var pending_capture := false
var materials: Array[ShaderMaterial] = []

func _ready() -> void:
	start_transform = camera.transform
	start_size = camera.size
	apply_pending_spawn()
	if is_instance_valid(hero):
		hero.movement_camera = camera
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if is_instance_valid(hero):
		follow_position = hero.position + Vector3(0, 1, 0)
	outline.visible = true
	picture.texture = viewport.get_texture()
	collect_materials(world)
	for button in options.get_children():
		button.toggled.connect(option_changed.bind(button.name))
	$Gear.pressed.connect(func(): set_settings_open(not settings.visible))
	$Settings/Panel/Margin/Content/Header/Close.pressed.connect(func(): set_settings_open(false))
	$Settings/Backdrop.gui_input.connect(backdrop_input)
	$Settings/Panel/Margin/Content/Reset.pressed.connect(reset_camera)
	zoom_slider.value_changed.connect(func(value: float): set_zoom(value / 100.0))
	set_zoom(1.0)
	pixel_slider.value_changed.connect(set_pixel_size)
	set_pixel_size(pixel_slider.value)
	resized.connect(layout_view)
	layout_view()
	var args := OS.get_cmdline_user_args()
	if "--plain" in args:
		for key in ["pixel","outline","toon","highlight","snap"]:
			(options.get_node(key) as CheckButton).button_pressed = false
	if "--settings" in args:
		set_settings_open(true)
	if "--detail" in args:
		set_zoom(0.58)
		pan.z = 1.0
	character_rendering.configure()

func apply_pending_spawn() -> void:
	var root := get_tree().root
	var spawn_id := str(root.get_meta("scene_spawn_id", ""))
	if spawn_id.is_empty() or not is_instance_valid(hero):
		return
	for marker in world.find_children("*", "Marker3D", true, false):
		if str(marker.get_meta("spawn_id", "")) == spawn_id:
			hero.global_position = marker.global_position + Vector3(0, 0.03, 0)
			hero.velocity = Vector3.ZERO
			root.remove_meta("scene_spawn_id")
			return

func collect_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var material = node.get_active_material(i)
			if material is ShaderMaterial and (material.shader == preload("res://village/style.gdshader") or material.get_meta("village_toon",false)) and material not in materials:
				materials.append(material)
	for child in node.get_children():
		collect_materials(child)


func option_changed(enabled: bool, option: String) -> void:
	match option:
		"pixel":
			pixels = enabled
			apply_pixel_effect()
		"outline":
			outline.material_override.set_shader_parameter("outlines", enabled)
			character_rendering.set_outlines(enabled)
		"highlight":
			outline.material_override.set_shader_parameter("highlights", enabled)
			character_rendering.set_highlights(enabled)
		"toon":
			for material in materials:
				material.set_shader_parameter("toon_enabled",enabled)
		"snap": snapping = enabled
		"orbit": auto_orbit = enabled

func set_pixel_size(value: float) -> void:
	pixel_block_size = clampi(roundi(value),1,12)
	pixel_slider.set_value_no_signal(pixel_block_size)
	apply_pixel_effect()

func apply_pixel_effect() -> void:
	# Render the geometry and depth/normal edges on the same real pixel grid.
	# Do not subsample a high-resolution image again in the outline shader.
	outline.material_override.set_shader_parameter("pixel_size", 1.0)
	pixel_slider.editable = pixels
	pixel_label.text = "像素大小  %d × %d px%s" % [pixel_block_size,pixel_block_size,"" if pixels else "（已关闭）"]
	layout_view()

func layout_view() -> void:
	var block := pixel_block_size if pixels else 1
	viewport.size = Vector2i(maxi(1, floori(size.x / block)), maxi(1, floori(size.y / block)))
	display_scale = float(block)
	picture.size = Vector2(viewport.size) * display_scale
	picture_home = ((size - picture.size) / 2.0).floor()
	picture.position = picture_home
	$Settings/Panel/Margin/Content/Resolution.text = "%d × %d · 整数倍像素显示" % [viewport.size.x, viewport.size.y]
	status.position = Vector2(24,size.y-34)
	character_rendering.sync_layout()

func set_settings_open(open: bool) -> void:
	settings.visible = open
	if is_instance_valid(hero):
		hero.controls_enabled = not open
	if open:
		$Settings/Panel/Margin/Content/Header/Close.grab_focus()
	else:
		get_viewport().gui_release_focus()

func backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_settings_open(false)
		get_viewport().set_input_as_handled()

func set_zoom(value: float) -> void:
	zoom = clampf(value,0.3,1.5)
	zoom_slider.set_value_no_signal(zoom * 100.0)
	zoom_label.text = "镜头可视范围  %.1f  /  %d%%" % [start_size * zoom, roundi(zoom * 100)]
	camera.size = start_size * zoom

func reset_camera() -> void:
	pan = Vector3.ZERO
	orbit_angle = 0.0
	set_zoom(1.0)
	(options.get_node("orbit") as CheckButton).button_pressed = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_settings_open(not settings.visible)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	elapsed += delta
	# Sample the same interpolated transform that is displayed this frame.
	# A second camera smoothing filter made the character swim across pixel cells.
	if is_instance_valid(hero):
		follow_position = hero.get_global_transform_interpolated().origin + Vector3(0, 1, 0)
	elif not settings.visible:
		var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var right := camera.basis.x
		var forward := -camera.basis.z
		right.y = 0.0
		forward.y = 0.0
		pan += (right.normalized()*input.x-forward.normalized()*input.y)*delta*8.0*zoom
	if auto_orbit and not settings.visible:
		orbit_angle += delta*0.12
	var rotation_basis := Basis(Vector3.UP,orbit_angle)
	var offset := start_transform.basis.z * start_transform.origin.length()
	if not is_instance_valid(hero):
		offset = start_transform.origin
	camera.transform = Transform3D(rotation_basis*start_transform.basis, rotation_basis*offset+follow_position+pan)
	camera.size = start_size*zoom
	picture.position = picture_home
	if snapping:
		var pixel_size := camera.size/viewport.size.y
		var p := camera.basis.inverse()*camera.position
		var unsnapped := p
		p.x = snappedf(p.x,pixel_size)
		p.y = snappedf(p.y,pixel_size)
		camera.position = camera.basis*p
		# Restore the camera's fractional movement at presentation resolution.
		# The 3D grid stays fixed; the final image scrolls in one-screen-pixel steps.
		var remainder := Vector2(p.x-unsnapped.x, unsnapped.y-p.y)/pixel_size
		picture.position += (remainder*display_scale).round()
	var controls := "方向键：行走   Shift：跑步" if is_instance_valid(hero) else "方向键：平移镜头"
	status.text = "%d × %d  ·  %s   滚轮：缩放   R：重置镜头   Esc：设置   ·   %d FPS" % [viewport.size.x,viewport.size.y,controls,Engine.get_frames_per_second()]
	if "--capture" in OS.get_cmdline_user_args() and elapsed > 3 and not pending_capture:
		pending_capture = true
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var suffix := "_settings" if "--settings" in OS.get_cmdline_user_args() else "_plain" if "--plain" in OS.get_cmdline_user_args() else ("_detail" if "--detail" in OS.get_cmdline_user_args() else "")
	var err := get_viewport().get_texture().get_image().save_png("res://village/preview"+suffix+".png")
	var render_err := viewport.get_texture().get_image().save_png("res://village/render"+suffix+".png")
	print("Screenshot saved: ",err," viewport: ",render_err)
	get_tree().quit(maxi(err,render_err))

func _unhandled_input(event: InputEvent) -> void:
	if settings.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom-0.1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom+0.1)
	if event is InputEventKey and event.pressed and not event.echo:
		var mapping := {KEY_1:"pixel",KEY_2:"outline",KEY_3:"toon",KEY_4:"highlight",KEY_5:"snap",KEY_SPACE:"orbit"}
		if event.keycode in mapping:
			var button := options.get_node(mapping[event.keycode]) as CheckButton
			button.button_pressed = not button.button_pressed
		if event.keycode == KEY_R:
			reset_camera()

