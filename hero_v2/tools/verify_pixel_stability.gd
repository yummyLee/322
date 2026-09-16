extends SceneTree
## Isolated GPU regression: freeze pose/lighting, translate the same saved mesh,
## compare raster silhouette hashes and projected anchor span between old/new modes.
var demo: Control
var hero: CharacterBody3D
var camera: Camera3D
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func mask(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		mask(child,material)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("GPU rendering is required for this test")
		quit(1)
		return
	demo = load("res://hero_v2/main.tscn").instantiate()
	root.add_child(demo)
	demo.get_node("HUD").hide()
	var world := demo.get_node("EnvironmentViewport/EnvironmentWorld")
	hero = world.get_node("Traveler")
	camera = world.get_node("FollowCamera")
	hero.set_physics_process(false)
	hero.get_node("SecondaryMotion").set_physics_process(false)
	demo.set_physics_process(false)
	hero.get_node("AnimationPlayer").play("RESET")
	hero.get_node("AnimationPlayer").advance(0)
	hero.get_node("AnimationPlayer").pause()
	for child in world.get_children():
		if child is Node3D and child!=hero and child!=camera:
			child.hide()
	var environment: Environment = world.get_node("Environment").environment
	environment.background_color = Color.BLACK
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.WHITE
	mask(demo.display_hero,material)
	demo.sync_pose()
	await frame()
	for zoom in [7.0,3.8]:
		camera.size = zoom
		for mode in [false,true]:
			demo.stable_edges = mode
			demo.layout_picture()
			for direction in [Vector3(1,0,0),Vector3(0.6,0,0.8)]:
				hero.position = Vector3(0,0,0)
				hero.reset_physics_interpolation()
				demo.sync_pose()
				demo.display_hero.reset_physics_interpolation()
				await frame()
				var unique_frames := {}
				var low := Vector2(INF,INF)
				var high := Vector2(-INF,-INF)
				for i in range(40):
					hero.position += direction * 4.4 / 60.0
					hero.reset_physics_interpolation()
					demo.sync_pose()
					demo.display_hero.reset_physics_interpolation()
					await frame()
					var p: Vector2 = demo.character_camera.unproject_position(hero.get_global_transform_interpolated().origin)
					low = low.min(p)
					high = high.max(p)
					var im: Image = demo.character_viewport.get_texture().get_image()
					unique_frames[hash(im.get_data())] = true
				var span := high-low
				print("STABILITY mode=", "NEW" if mode else "OLD", " size=",zoom," direction=",direction," anchor_span_pixels=",span," distinct_masks=",unique_frames.size()," /40")
				if mode and (span.length()>0.002 or unique_frames.size()>2):
					failures += 1
	print("PIXEL STABILITY FINISHED / failures=",failures)
	quit(0 if failures==0 else 1)
