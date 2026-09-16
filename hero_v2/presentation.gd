extends Control
## The world owns movement and real shadows. The separate stage displays the same pose.
@onready var environment_viewport: SubViewport = $EnvironmentViewport
@onready var character_viewport: SubViewport = $CharacterViewport
@onready var environment_world: Node3D = $EnvironmentViewport/EnvironmentWorld
@onready var character_world: Node3D = $CharacterViewport/CharacterWorld
@onready var environment_picture: TextureRect = $EnvironmentPicture
@onready var character_picture: TextureRect = $CharacterPicture
@onready var hero: CharacterBody3D = $EnvironmentViewport/EnvironmentWorld/Traveler
@onready var display_hero: CharacterBody3D = $CharacterViewport/CharacterWorld/Traveler
@onready var character_camera: Camera3D = $CharacterViewport/CharacterWorld/Camera
@onready var environment_camera: Camera3D = $EnvironmentViewport/EnvironmentWorld/FollowCamera
var pixels := true
var stable_edges := true
var pose_pairs: Array = []
var source_rig: Skeleton3D
var display_rig: Skeleton3D

func _ready() -> void:
	# Run after the movement, animation, secondary motion and follow camera.
	process_priority = 100
	process_physics_priority = 100
	environment_picture.texture = environment_viewport.get_texture()
	character_picture.texture = character_viewport.get_texture()
	configure_character_layer()
	resized.connect(layout_picture)
	layout_picture()
	sync_pose()
	display_hero.reset_physics_interpolation()
	sync_camera()

func configure_character_layer() -> void:
	# Keep the world model visible to the shadow pass, but omit its color pass.
	for mesh: MeshInstance3D in hero.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# Only the world instance runs the controller, animator, wardrobe and springs.
	display_hero.set_physics_process(false)
	display_hero.get_node("AnimationPlayer").active = false
	display_hero.get_node("SecondaryMotion").set_physics_process(false)
	display_hero.get_node("Facing/Visual").set_process_unhandled_key_input(false)
	pose_pairs.append([hero, display_hero])
	for source: Node3D in hero.find_children("*", "Node3D", true, false):
		var replica := display_hero.get_node_or_null(hero.get_path_to(source)) as Node3D
		if replica != null:
			pose_pairs.append([source, replica])
	source_rig = hero.get_node("Facing/Visual/Rig")
	display_rig = display_hero.get_node("Facing/Visual/Rig")

func layout_picture() -> void:
	var integer_scale := maxi(1, floori(minf(size.x / 480.0, size.y / 270.0))) if pixels else 1
	var logical_size := Vector2i(maxi(1, floori(size.x / integer_scale)), maxi(1, floori(size.y / integer_scale)))
	environment_viewport.size = logical_size * (2 if pixels and stable_edges else 1)
	# Preserve the character's original supersampling and resolve settings.
	character_viewport.size = environment_viewport.size
	for picture in [environment_picture, character_picture]:
		picture.size = Vector2(logical_size) * integer_scale
		picture.position = ((size - picture.size) / 2.0).floor()
	environment_camera.snap_to_pixels = pixels
	environment_camera.stabilize_target = stable_edges
	environment_camera.pixel_grid_height = logical_size.y
	for picture in [environment_picture, character_picture]:
		picture.material.set_shader_parameter("pixel_grid", Vector2(logical_size))
		picture.material.set_shader_parameter("pixel_enabled", pixels)
		picture.material.set_shader_parameter("coverage_filter", stable_edges)

func sync_pose() -> void:
	for pair in pose_pairs:
		pair[1].transform = pair[0].transform
		pair[1].visible = pair[0].visible
	for bone in source_rig.get_bone_count():
		display_rig.set_bone_pose_position(bone, source_rig.get_bone_pose_position(bone))
		display_rig.set_bone_pose_rotation(bone, source_rig.get_bone_pose_rotation(bone))
		display_rig.set_bone_pose_scale(bone, source_rig.get_bone_pose_scale(bone))

func sync_camera() -> void:
	character_camera.global_transform = environment_camera.global_transform
	character_camera.projection = environment_camera.projection
	character_camera.keep_aspect = environment_camera.keep_aspect
	character_camera.size = environment_camera.size
	character_camera.near = environment_camera.near
	character_camera.far = environment_camera.far

func _physics_process(_delta: float) -> void:
	sync_pose()

func _process(_delta: float) -> void:
	sync_camera()
	var state := {&"idle":"待机", &"walk":"行走", &"run":"跑步"}
	$HUD/State.text = "%s  / 人物独立渲染 / 环境真实投影" % state.get(hero.locomotion,"待机")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			pixels = not pixels
			layout_picture()
			return
		if event.keycode == KEY_B:
			stable_edges = not stable_edges
			layout_picture()
			return
	environment_viewport.push_input(event)
