extends SceneTree

var failures := 0
var world: Node3D
var hero: CharacterBody3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func place(p: Vector2) -> void:
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,8,p.y),Vector3(p.x,-8,p.y))
	query.exclude = [hero.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	hero.position = Vector3(p.x, (hit.position.y + 0.04) if not hit.is_empty() else 0.04, p.y)
	hero.velocity = Vector3.ZERO
	hero.reset_physics_interpolation()

func walk_to(p: Vector2) -> bool:
	for i in range(520):
		await physics_frame
		var ground_query := PhysicsRayQueryParameters3D.create(Vector3(hero.position.x,8,hero.position.z),Vector3(hero.position.x,-8,hero.position.z))
		ground_query.exclude = [hero.get_rid()]
		var ground_hit := world.get_world_3d().direct_space_state.intersect_ray(ground_query)
		if not ground_hit.is_empty(): hero.position.y = ground_hit.position.y + 0.04
		var diff := Vector3(p.x,hero.position.y,p.y)-hero.position
		if Vector2(diff.x,diff.z).length() < 0.24: return true
		hero.velocity = Vector3(diff.x,0,diff.z).normalized()*10.0
		hero.move_and_slide()
	return false

func walk_route(label: String, points: Array) -> void:
	place(points[0])
	var reached := 0
	for i in range(1,points.size()):
		if await walk_to(points[i]): reached += 1
		else:
			print("STOP route=",label," at ",hero.position," target ",points[i])
			break
	check(reached == points.size()-1,label+" route reaches every marked waypoint (%d/%d)" % [reached,points.size()-1])

func run() -> void:
	world = load("res://burial_left_cave/world.tscn").instantiate()
	root.add_child(world)
	hero = load("res://hero_v2/traveler.tscn").instantiate()
	hero.set_script(load("res://hero_v2/hero_controller.gd"))
	world.add_child(hero)
	hero.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(world.get_node("SavedWallCollisions") != null,"saved wall collision group exists")
	check(world.get_node("SavedWallCollisions").get_child_count() >= 12,"multiple enclosed region wall collisions are saved")
	await walk_route("J0-J1-J8",[Vector2(0,22),Vector2(0,16),Vector2(-1,1),Vector2(-1,-2)])
	await walk_route("J8-J2-J4",[Vector2(8,4),Vector2(14,3),Vector2(18,-3),Vector2(19,-8)])
	await walk_route("J4-J11-J5",[Vector2(24,-12),Vector2(28,-16),Vector2(30,-18),Vector2(25,-20),Vector2(19,-20)])
	await walk_route("J5-J10-J12-J13",[Vector2(4,-26),Vector2(-5,-27),Vector2(-9,-29),Vector2(4,-29),Vector2(19,-29),Vector2(34,-29),Vector2(38,-29)])
	await walk_route("J8-J3-J9-J6",[Vector2(-9,4),Vector2(-16,4),Vector2(-21,-3),Vector2(-22,-8),Vector2(-22,-15),Vector2(-22,-18)])
	print("CAVE WALK VALIDATION / failures=",failures)
	world.free()
	quit(0 if failures == 0 else 1)
