extends Control
@onready var viewport: SubViewport = $WorldViewport
@onready var picture: TextureRect = $Picture
@onready var hero: CharacterBody3D = $WorldViewport/TravelerWorld/Traveler
@onready var camera: Camera3D = $WorldViewport/TravelerWorld/FollowCamera
var pixels := true

func _ready() -> void:
	picture.texture = viewport.get_texture()
	resized.connect(layout_picture)
	layout_picture()

func layout_picture() -> void:
	var integer_scale := maxi(1, floori(minf(size.x / 480.0, size.y / 270.0))) if pixels else 1
	viewport.size = Vector2i(maxi(1, floori(size.x / integer_scale)), maxi(1, floori(size.y / integer_scale)))
	picture.size = Vector2(viewport.size) * integer_scale
	picture.position = ((size - picture.size) / 2.0).floor()
	camera.snap_to_pixels = pixels

func _process(_delta: float) -> void:
	var state := {&"idle": "待机", &"walk": "行走", &"run": "跑步"}
	$HUD/State.text = "%s  /  %s" % [state.get(hero.locomotion, "待机"), "像素视图" if pixels else "原始 3D"]

func _input(event: InputEvent) -> void:
	# A TextureRect displays the SubViewport, so forward its non-mouse controls explicitly.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		pixels = not pixels
		layout_picture()
	else:
		viewport.push_input(event)
