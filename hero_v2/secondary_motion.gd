extends Node
## Small damped bone motions; never modifies mesh topology or creates scene content.
@export var enabled: bool = true
@export_range(0.0,1.5,0.05) var strength: float = 0.75
@export var stiffness: float = 85.0
@export var damping: float = 16.0
@onready var hero: CharacterBody3D = get_parent()
@onready var rig: Skeleton3D = hero.get_node("Facing/Visual/Rig")
@onready var facing: Node3D = hero.get_node("Facing")
@onready var animator: AnimationPlayer = hero.get_node("AnimationPlayer")
var previous_velocity := Vector3.ZERO
var previous_yaw := 0.0
var offsets: Dictionary = {}
var rates: Dictionary = {}
var indices: Dictionary = {}
const HAIR := ["HairFrontL","HairFrontR","HairSideL","HairSideR","HairTail"]
const CLOTH := ["HemFrontL","HemFrontR","HemBackL","HemBackR","CuffL","CuffR","SashTail"]

func _ready() -> void:
	process_physics_priority = 20
	previous_yaw = facing.rotation.y
	for name in HAIR+CLOTH:
		indices[name] = rig.find_bone(name)
		offsets[name] = Vector3.ZERO
		rates[name] = Vector3.ZERO

func _physics_process(delta: float) -> void:
	var step := minf(delta,1.0/30.0)
	var speed := Vector2(hero.velocity.x,hero.velocity.z).length()
	var drive := clampf(speed/maxf(hero.run_speed,0.1),0.0,1.0)
	var phase := animator.current_animation_position / maxf(animator.current_animation_length,0.001)*TAU if animator.is_playing() else 0.0
	var local_accel: Vector3 = facing.basis.inverse()*(hero.velocity-previous_velocity)
	var turning := clampf(angle_difference(previous_yaw,facing.rotation.y),-0.8,0.8)
	previous_yaw = facing.rotation.y
	previous_velocity = hero.velocity
	for name in indices:
		var bone: int = indices[name]
		if bone<0:
			continue
		if not enabled:
			offsets[name] = Vector3.ZERO
			rates[name] = Vector3.ZERO
			rig.set_bone_pose_rotation(bone,Quaternion.IDENTITY)
			continue
		var side := -1.0 if name.ends_with("L") else 1.0
		var wave := sin(phase+side*0.9)
		var desired := Vector3.ZERO
		if name in HAIR:
			desired = Vector3(-0.016*drive+0.023*drive*wave,0.014*drive*sin(phase+side),0.011*drive*wave)
			rates[name] += Vector3(-local_accel.z*0.025,-turning*0.48,local_accel.x*0.018)
		elif name.begins_with("Hem"):
			desired = Vector3(0.035*drive+0.10*drive*wave,0.017*drive*sin(phase),side*0.018*drive)
			rates[name] += Vector3(-local_accel.z*0.055,-turning*0.32,local_accel.x*0.02)
		elif name.begins_with("Cuff"):
			desired = Vector3(0.035*drive*wave,0,side*0.02*drive*sin(phase))
		else:
			desired = Vector3(0.15*drive+0.06*drive*sin(phase),0.04*drive*wave,0.035*drive*wave)
			rates[name] += Vector3(-local_accel.z*0.06,-turning*0.5,local_accel.x*0.025)
		desired *= strength
		var angle: Vector3 = offsets[name]
		var angular_velocity: Vector3 = rates[name]
		angular_velocity += ((desired-angle)*stiffness-angular_velocity*damping)*step
		angle += angular_velocity*step
		angle = angle.clamp(Vector3(-0.20,-0.14,-0.12),Vector3(0.20,0.14,0.12))
		offsets[name] = angle
		rates[name] = angular_velocity
		rig.set_bone_pose_rotation(bone,Quaternion.from_euler(angle))
