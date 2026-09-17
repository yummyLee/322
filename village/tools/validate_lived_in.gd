extends SceneTree
var failures:=0
var world: Node3D
var hero: CharacterBody3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures+=1
func walk(points: Array) -> bool:
	for p in points:
		var arrived:=false
		for i in range(220):
			await physics_frame
			var diff: Vector3=Vector3(p.x,hero.position.y,p.y)-hero.position
			if diff.length()<0.12:
				arrived=true
				break
			hero.velocity=diff.normalized()*minf(8,diff.length()*60)
			hero.velocity.y=-2
			hero.move_and_slide()
		if not arrived or not hero.is_on_floor():
			print("STOP at ",hero.position," target ",p)
			return false
	return true
func place(p: Vector2) -> void:
	var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,8,p.y),Vector3(p.x,-2,p.y))
	q.exclude=[hero.get_rid()]
	var hit:=world.get_world_3d().direct_space_state.intersect_ray(q)
	hero.position=Vector3(p.x,hit.position.y+0.015,p.y)
func run() -> void:
	world=load("res://village/yao_village.tscn").instantiate()
	root.add_child(world)
	var ridge: Node3D=world.get_node("WesternBurialRidge")
	check(world.get_node("Buildings/NorthFarmhouse").position.z==-17,"North farmhouse moved five units north")
	var mismatches:=0
	for tree in world.get_node("ForestBoundary").get_children():
		var found:=false
		for shape in world.get_node("WalkCollisions").get_children():
			if "Trunk" in str(shape.name) and Vector2(shape.position.x,shape.position.z).distance_to(Vector2(tree.position.x,tree.position.z))<0.02: found=true
		if not found: mismatches+=1
	check(mismatches==0,"Every retained village boundary tree has its matching moved collision")
	check(world.get_node("WalkCollisions/NorthFarmhouse_PlasterWalls").position.z==-17,"North farmhouse collision moved with the house")
	check(is_equal_approx(world.get_node("WalkCollisions/NorthSideRoom_PlasterWalls").position.z,-17.2),"North side-room collision moved with the house")
	check(world.get_meta("northern_trees_removed")==7,"Seven trees removed to open the north silhouette")
	var source: Node3D=load("res://burial_ridge/world.tscn").instantiate()
	check(ridge.get_node("BareRidgeTrees/DeadTree_01").transform.is_equal_approx(source.get_node("BareRidgeTrees/DeadTree_01").transform),"Village uses current saved ridge without stale transform overrides")
	source.free()
	check(ridge.get_node("GraveyardWildGrass").get_child_count()>250,"Clustered graveyard weeds saved as editable nodes")
	for b in ridge.get_node("ExplorationLandmarks").get_children():
		check(b.has_node("EntryPoint") and b.has_node("ExitSpawn") and b.has_node("ReservedEntrance/TriggerVolume"),str(b.name)+" has entrance and return markers")
		check(not b.get_node("ReservedEntrance").monitoring and b.get_node("ReservedEntrance").get_meta("target_scene")=="",str(b.name)+" reserves a future interior without a broken scene link")
	hero=load("res://hero_v2/traveler.tscn").instantiate()
	hero.set_script(load("res://hero_v2/hero_controller.gd"))
	world.add_child(hero)
	hero.set_physics_process(false)
	await physics_frame
	await physics_frame
	place(Vector2(-0.7,-9))
	check(await walk([Vector2(-0.7,-12),Vector2(-0.7,-13.6),Vector2(-1,-14.5)]),"Player walks through the shifted north courtyard gate")
	place(Vector2(-71,-25))
	check(await walk([Vector2(-74,-25.4),Vector2(-77,-24.5),Vector2(-80,-23),Vector2(-80,-25.4),Vector2(-80,-26.5),Vector2(-80,-25.4),Vector2(-80,-23)]),"Player walks into and back out of the dome tomb doorway")
	place(Vector2(-70,-18))
	check(await walk([Vector2(-68,-19.7),Vector2(-64,-20.3),Vector2(-62,-21.6),Vector2(-62,-23.1),Vector2(-62,-21.6),Vector2(-64,-20.3)]),"Player walks into and back out of the stone shrine doorway")
	print("LIVED IN VALIDATION / failures=",failures)
	world.free()
	quit(0 if failures==0 else 1)
