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
	quit()
