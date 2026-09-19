extends SceneTree

func _initialize() -> void:
	check.call_deferred()

func check() -> void:
	var world: Node3D = load("res://burial_left_cave/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var camera: Camera3D = world.get_node("RenderRig/VillageCamera") as Camera3D
	print("CAVE RUNTIME SMOKE: nodes=%d camera_current=%s portal=%s" % [world.find_children("*", "", true, false).size(), camera.current, world.get_node("EntranceTransition/ExitToNorthernRidge").get_meta("target_scene")])
	world.free()
	var app: Control = load("res://burial_left_cave/main.tscn").instantiate()
	root.add_child(app)
	for i in range(30):
		await physics_frame
	var hero: CharacterBody3D = app.get_node("WorldViewport/YaoVillage/Hero") as CharacterBody3D
	print("CAVE PLAYER SPAWN: position=%s on_floor=%s" % [hero.position, hero.is_on_floor()])
	var safe_spawn := hero.position.y > -0.2 and hero.is_on_floor()
	app.free()
	quit(0 if safe_spawn else 1)
