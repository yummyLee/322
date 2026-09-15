extends Control
@onready var viewport: SubViewport = $WorldViewport
@onready var picture: TextureRect = $Picture
@onready var hero: CharacterBody3D = $WorldViewport/TravelerWorld/Traveler
@onready var camera: Camera3D = $WorldViewport/TravelerWorld/FollowCamera
var pixels := true
var stable_edges := true

func _ready() -> void:
	picture.texture = viewport.get_texture()
	resized.connect(layout_picture)
	layout_picture()

func layout_picture() -> void:
	var integer_scale := maxi(1, floori(minf(size.x / 480.0, size.y / 270.0))) if pixels else 1
	var logical_size := Vector2i(maxi(1, floori(size.x / integer_scale)), maxi(1, floori(size.y / integer_scale)))
	viewport.size = logical_size * (2 if pixels and stable_edges else 1)
	picture.size = Vector2(logical_size) * integer_scale
	picture.position = ((size - picture.size) / 2.0).floor()
	camera.snap_to_pixels = pixels
	camera.stabilize_target = stable_edges
	camera.pixel_grid_height = logical_size.y
	picture.material.set_shader_parameter("pixel_grid",Vector2(logical_size))
	picture.material.set_shader_parameter("pixel_enabled",pixels)
	picture.material.set_shader_parameter("coverage_filter",stable_edges)

func _process(_delta: float) -> void:
	var state := {&"idle": "待机", &"walk": "行走", &"run": "跑步"}
	$HUD/State.text = "%s  /  %s" % [state.get(hero.locomotion, "待机"), ("稳定像素" if stable_edges else "原像素对比") if pixels else "原始 3D"]

func _input(event: InputEvent) -> void:
	# A TextureRect displays the SubViewport, so forward its non-mouse controls explicitly.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			pixels = not pixels
			layout_picture()
			return
		if event.keycode == KEY_B:
			stable_edges = not stable_edges
			layout_picture()
			return
	viewport.push_input(event)
