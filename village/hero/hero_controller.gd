extends CharacterBody3D

@export var walk_speed := 2.4
@export var run_speed := 4.8
@export var acceleration := 18.0
@export var turn_speed := 14.0
var controls_enabled := true
var movement_camera: Camera3D
@onready var visual: Node3D = $Visual
@onready var animator: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# Joint animation and movement must share the physics clock before interpolation.
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") if controls_enabled else Vector2.ZERO
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if is_instance_valid(movement_camera):
		right = movement_camera.global_basis.x
		forward = -movement_camera.global_basis.z
		right.y = 0
		forward.y = 0
		right = right.normalized()
		forward = forward.normalized()
	var direction := right * input.x - forward * input.y
	var running := Input.is_action_pressed("hero_run")
	var speed := run_speed if running else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0
	move_and_slide()
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-turn_speed * delta))
	var moving := Vector2(velocity.x, velocity.z).length() > 0.15 and direction.length_squared() > 0.01
	var clip := ("run" if running else "walk") if moving else "idle"
	if animator.current_animation != clip:
		animator.play(clip, 0.16)
	animator.speed_scale = clampf(Vector2(velocity.x, velocity.z).length() / speed, 0.35, 1.15) if moving else 1.0

