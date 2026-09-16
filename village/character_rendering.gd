extends Node
## Adds the isolated hero to the existing village viewer; does not drive its UI,
## environment render settings, camera framing, or scene content.
@export var environment_compositor: Compositor
@export var character_compositor: Compositor
@onready var viewer: Control = get_parent()
@onready var viewport: SubViewport = $"../CharacterViewport"
@onready var picture: TextureRect = $"../CharacterPicture"
@onready var display_hero: CharacterBody3D = $"../CharacterViewport/CharacterWorld/Traveler"
@onready var camera: Camera3D = $"../CharacterViewport/CharacterWorld/Camera"
var hero: CharacterBody3D
var source_rig: Skeleton3D
var display_rig: Skeleton3D
var pose_pairs: Array = []
var configured := false

func configure() -> void:
	process_priority = 100
	process_physics_priority = 100
	hero = viewer.hero
	picture.texture = viewport.get_texture()
	for mesh: MeshInstance3D in hero.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	display_hero.set_physics_process(false)
	display_hero.get_node("AnimationPlayer").active = false
	display_hero.get_node("SecondaryMotion").set_physics_process(false)
	display_hero.get_node("Facing/Visual").set_process_unhandled_key_input(false)
	for source: Node3D in hero.find_children("*", "Node3D", true, false):
		var replica := display_hero.get_node_or_null(hero.get_path_to(source)) as Node3D
		if replica:
			pose_pairs.append([source, replica])
	source_rig = hero.get_node("Facing/Visual/Rig")
	display_rig = display_hero.get_node("Facing/Visual/Rig")
	viewer.camera.compositor = environment_compositor
	camera.compositor = character_compositor
	environment_compositor.compositor_effects[0].texture_ready.connect(_depth_texture_ready.bind("environment_depth"))
	character_compositor.compositor_effects[0].texture_ready.connect(_depth_texture_ready.bind("character_depth"))
	configured = true
	sync_layout()
	sync_pose()
	display_hero.reset_physics_interpolation()
	sync_camera()

func _depth_texture_ready(texture: Texture2DRD, parameter: String) -> void:
	picture.material.set_shader_parameter(parameter, texture)
	_update_depth_ready()

func _update_depth_ready() -> void:
	var environment_depth: Texture2D = picture.material.get_shader_parameter("environment_depth")
	var character_depth: Texture2D = picture.material.get_shader_parameter("character_depth")
	var ready := environment_depth != null and character_depth != null
	if ready:
		ready = Vector2i(environment_depth.get_size()) == viewer.viewport.size and Vector2i(character_depth.get_size()) == viewport.size
	picture.material.set_shader_parameter("depth_ready", ready)

func sync_layout() -> void:
	if not configured:
		return
	# The village still renders on its original grid. Only the independent hero
	# retains its four-point sampling; both layers share the existing UI pixel size.
	viewport.size = viewer.viewport.size * (2 if viewer.pixels else 1)
	picture.size = viewer.picture.size
	picture.position = viewer.picture.position
	picture.material.set_shader_parameter("pixel_grid", Vector2(viewer.viewport.size))
	picture.material.set_shader_parameter("pixel_enabled", viewer.pixels)
	picture.material.set_shader_parameter("coverage_filter", true)
	_update_depth_ready()

func sync_pose() -> void:
	display_hero.global_transform = hero.global_transform
	display_hero.visible = hero.visible
	for pair in pose_pairs:
		pair[1].transform = pair[0].transform
		pair[1].visible = pair[0].visible
	for bone in source_rig.get_bone_count():
		display_rig.set_bone_pose_position(bone, source_rig.get_bone_pose_position(bone))
		display_rig.set_bone_pose_rotation(bone, source_rig.get_bone_pose_rotation(bone))
		display_rig.set_bone_pose_scale(bone, source_rig.get_bone_pose_scale(bone))

func sync_camera() -> void:
	camera.global_transform = viewer.camera.global_transform
	camera.projection = viewer.camera.projection
	camera.keep_aspect = viewer.camera.keep_aspect
	camera.size = viewer.camera.size
	camera.near = viewer.camera.near
	camera.far = viewer.camera.far

func _physics_process(_delta: float) -> void:
	if configured:
		sync_pose()

func _process(_delta: float) -> void:
	if configured:
		sync_camera()
		# Preserve the village's existing fractional scroll correction exactly.
		picture.position = viewer.picture.position

func _unhandled_key_input(event: InputEvent) -> void:
	if configured and not viewer.settings.visible and event.keycode in [KEY_C, KEY_H]:
		viewer.viewport.push_input(event)
