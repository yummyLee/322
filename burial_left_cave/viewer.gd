extends Control

const OUTPUT_SIZE := Vector2i(1920,1080)
@onready var viewport: SubViewport = $WorldViewport
@onready var world: Node3D = $WorldViewport/World
@onready var camera: Camera3D = world.get_node("RenderRig/VillageCamera")
@onready var outline: MeshInstance3D = camera.get_node("PixelOutline")
@onready var picture: TextureRect = $Picture
@onready var settings: Control = $Settings
@onready var content: VBoxContainer = $Settings/Panel/Margin/Content
@onready var options: VBoxContainer = content.get_node("Options")
@onready var pixel_slider: HSlider = content.get_node("PixelSize")
@onready var zoom_slider: HSlider = content.get_node("Zoom")
var materials: Array[ShaderMaterial] = []
var initial: Transform3D
var initial_size: float
var pan := Vector3.ZERO
var angle := 0.0
var zoom := 1.0
var pixels := true
var pixel_size := 3
var snap := true
var orbit := false
var elapsed := 0.0
var captured := false

func _ready() -> void:
	initial = camera.transform
	initial_size = camera.size
	outline.visible = true
	picture.texture = viewport.get_texture()
	collect_materials(world)
	for button in options.get_children():
		button.toggled.connect(option_changed.bind(button.name))
	$Gear.pressed.connect(func(): open_settings(not settings.visible))
	content.get_node("Header/Close").pressed.connect(func(): open_settings(false))
	$Settings/Backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			open_settings(false)
			get_viewport().set_input_as_handled())
	pixel_slider.value_changed.connect(set_pixel_size)
	zoom_slider.value_changed.connect(func(value: float): set_zoom(value/100))
	content.get_node("Reset").pressed.connect(reset_camera)
	set_zoom(1)
	set_pixel_size(pixel_slider.value)
	resized.connect(layout_view)
	layout_view()
	if "--plain" in OS.get_cmdline_user_args():
		for key in ["pixel","outline","toon","highlight","snap"]:
			options.get_node(key).button_pressed = false
	if "--settings" in OS.get_cmdline_user_args():
		open_settings(true)

func collect_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var m = node.get_active_material(i)
			if m is ShaderMaterial and m.shader == preload("res://burial_left_cave/style.gdshader") and m not in materials:
				materials.append(m)
	for child in node.get_children():
		collect_materials(child)

func option_changed(enabled: bool, option: String) -> void:
	match option:
		"pixel":
			pixels = enabled
			set_pixel_size(pixel_size)
		"outline": outline.material_override.set_shader_parameter("outlines",enabled)
		"highlight": outline.material_override.set_shader_parameter("highlights",enabled)
		"toon":
			for m in materials:
				m.set_shader_parameter("toon_enabled",enabled)
		"snap": snap = enabled
		"orbit": orbit = enabled

func set_pixel_size(value: float) -> void:
	pixel_size = clampi(roundi(value),1,12)
	pixel_slider.set_value_no_signal(pixel_size)
	pixel_slider.editable = pixels
	outline.material_override.set_shader_parameter("pixel_size",float(pixel_size if pixels else 1))
	content.get_node("PixelLabel").text = "像素大小  %d × %d px%s" % [pixel_size,pixel_size,"" if pixels else "（已关闭）"]

func set_zoom(value: float) -> void:
	zoom = clampf(value,0.3,1.5)
	zoom_slider.set_value_no_signal(zoom*100)
	camera.size = initial_size*zoom
	content.get_node("ZoomLabel").text = "镜头可视范围  %.1f  /  %d%%" % [camera.size,roundi(zoom*100)]

func layout_view() -> void:
	viewport.size = OUTPUT_SIZE
	picture.size = Vector2(OUTPUT_SIZE)*minf(size.x/OUTPUT_SIZE.x,size.y/OUTPUT_SIZE.y)
	picture.position = (size-picture.size)/2
	$Status.position = Vector2(24,size.y-34)

func open_settings(enabled: bool) -> void:
	settings.visible = enabled
	if enabled:
		content.get_node("Header/Close").grab_focus()
	else:
		get_viewport().gui_release_focus()

func reset_camera() -> void:
	pan = Vector3.ZERO
	angle = 0
	set_zoom(1)
	options.get_node("orbit").button_pressed = false

func _process(delta: float) -> void:
	elapsed += delta
	if not settings.visible:
		pan += Vector3(Input.get_axis("ui_left","ui_right"),0,Input.get_axis("ui_up","ui_down"))*delta*8*zoom
		if orbit:
			angle += delta*0.12
	var basis := Basis(Vector3.UP,angle)
	camera.transform = Transform3D(basis*initial.basis,basis*initial.origin+pan)
	camera.size = initial_size*zoom
	if snap:
		var step_size := camera.size/viewport.size.y*(pixel_size if pixels else 1)
		var p := camera.basis.inverse()*camera.position
		p.x = snappedf(p.x,step_size)
		p.y = snappedf(p.y,step_size)
		camera.position = camera.basis*p
	$Status.text = "1920 × 1080  ·  方向键平移 / 滚轮缩放 / R 复位 / Esc 设置  ·  %d FPS" % Engine.get_frames_per_second()
	if "--capture" in OS.get_cmdline_user_args() and elapsed > 3 and not captured:
		captured = true
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var suffix := "_plain" if "--plain" in OS.get_cmdline_user_args() else "_settings" if "--settings" in OS.get_cmdline_user_args() else ""
	var err := get_viewport().get_texture().get_image().save_png("res://burial_left_cave/preview"+suffix+".png")
	print("Screenshot saved: ",err)
	get_tree().quit(err)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		open_settings(not settings.visible)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if settings.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom-0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom+0.1)
	if event is InputEventKey and event.pressed and not event.echo:
		var mapping := {KEY_1:"pixel",KEY_2:"outline",KEY_3:"toon",KEY_4:"highlight",KEY_5:"snap",KEY_SPACE:"orbit"}
		if event.keycode in mapping:
			var button = options.get_node(mapping[event.keycode])
			button.button_pressed = not button.button_pressed
		if event.keycode == KEY_R:
			reset_camera()
