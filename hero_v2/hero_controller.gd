extends CharacterBody3D
## A saved, articulated 3D character. Forward is local +Z; feet are at Y=0.
@export var walk_speed: float = 2.0
@export var run_speed: float = 4.4
@export var controls_enabled: bool = true
@export var movement_camera: Camera3D
@onready var facing: Node3D = $Facing
@onready var animator: AnimationPlayer = $AnimationPlayer
var locomotion: StringName = &"idle"
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func _ready() -> void:
	animator.play(&"idle")

func _physics_process(delta: float) -> void:
	# Read the four physical arrow keys so project UI/gamepad bindings cannot drive this character.
	var axis := Vector2.ZERO
	if controls_enabled:
		axis = Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))).limit_length()
	var camera := movement_camera if is_instance_valid(movement_camera) else get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	var back := Vector3.BACK
	if camera:
		right = camera.global_basis.x
		back = camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		right = right.normalized()
		back = back.normalized()
	var direction := right * axis.x + back * axis.y
	var running := controls_enabled and Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := run_speed if running else walk_speed
	# Direct screen-space velocity: reversing a key never spends time braking first.
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if direction.length_squared() > 0.01:
		facing.rotation.y = atan2(direction.x, direction.z)
	var actual_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	var next: StringName = &"idle" if actual_speed < 0.08 else (&"run" if running else &"walk")
	if next != locomotion:
		locomotion = next
		animator.play(next, 0.16)
	animator.speed_scale = 1.0 if locomotion == &"idle" else clampf(actual_speed / speed, 0.4, 1.25)
