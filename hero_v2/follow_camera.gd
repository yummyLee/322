extends Camera3D
## The authored camera transform is the reference. Runtime only follows/offsets it.
@export var target: Node3D
@export var target_height: float = 0.9
@export var snap_to_pixels: bool = true
var authored_transform: Transform3D
var authored_size: float
var orbit: float = 0.0
var close_up: bool = false

func _ready() -> void:
	authored_transform = transform
	authored_size = size
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_priority = 10

func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	var center := target.get_global_transform_interpolated().origin + Vector3.UP * target_height
	var pivot := Basis(Vector3.UP, orbit)
	global_transform = Transform3D(pivot * authored_transform.basis, center + pivot * (authored_transform.origin - Vector3.UP * target_height))
	if snap_to_pixels:
		var unit := size / float(get_viewport().get_visible_rect().size.y)
		var p := global_basis.inverse() * global_position
		p.x = snappedf(p.x, unit)
		p.y = snappedf(p.y, unit)
		global_position = global_basis * p

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_Q:
		orbit -= PI / 4.0
	if event.keycode == KEY_E:
		orbit += PI / 4.0
	if event.keycode == KEY_F:
		close_up = not close_up
		size = 3.8 if close_up else authored_size
	if event.keycode == KEY_R:
		orbit = 0.0
		close_up = false
		size = authored_size

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = maxf(3.0, size - 0.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = minf(14.0, size + 0.5)
