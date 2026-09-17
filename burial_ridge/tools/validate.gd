extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ",message)
	if not value:
		failures += 1

func run() -> void:
	var ridge := load("res://burial_ridge/world.tscn").instantiate() as Node3D
	var mesh_count := 0
	var bad_nodes := 0
	for node in ridge.find_children("*","",true,false):
		if node.owner != ridge or node.get_script() != null:
			bad_nodes += 1
		if node is MeshInstance3D:
			mesh_count += 1
			if not node.mesh or not node.transform.is_finite():
				bad_nodes += 1
	check(bad_nodes == 0 and ridge.get_script() == null,"All extension nodes are saved, owned and have no runtime generator")
	check(mesh_count > 5000,"Actual editable 3D meshes: %d" % mesh_count)
	for path in ["Graveyard/RidgeStoneShrine","Graveyard/TallBoundaryStele","Graveyard/CollapsedStoneTomb","Graveyard/AbandonedHandcart","BareRidgeTrees","ForestHomesteads/GraveKeeperCottage","ForestHomesteads/WoodcutterCottage","MeadowAndGroundDetails","TerrainAndPaths/HandWorkedRoads/VillageLink","AncientRoadsideDetails","SavedWalkCollisions"]:
		check(ridge.has_node(path),"Reference landmark: "+path)
	var edited := ridge.get_node("Graveyard/Grave_01") as Node3D
	edited.position += Vector3(0.33,0,0.28)
	var expected := edited.transform
	var packed := PackedScene.new()
	check(packed.pack(ridge) == OK,"Edited subtree can be packed")
	var probe := "res://burial_ridge/_edit_probe.tscn"
	check(ResourceSaver.save(packed,probe) == OK,"Editor-style change saves to disk")
	var restored := (ResourceLoader.load(probe,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	check(restored.get_node("Graveyard/Grave_01").transform.is_equal_approx(expected),"Changed grave transform survives disk reload")
	restored.free()
	ridge.free()
	DirAccess.remove_absolute(probe)
	var world := load("res://village/yao_village.tscn").instantiate() as Node3D
	root.add_child(world)
	check(world.has_node("WesternBurialRidge"),"Original village loads the saved extension")
	check(world.get_node("WesternBurialRidge").scene_file_path == "res://burial_ridge/world.tscn","Runtime and editable extension are the same saved resource")
	check(world.is_editable_instance(world.get_node("WesternBurialRidge")),"Extension children can be selected/edited in the village scene")
	check(not world.get_node("RenderRig/VillageCamera/PixelOutline").visible,"Postprocess stays hidden in the editor")
	check(world.get_node("RenderRig/VillageCamera").size == 36,"Existing default camera size retained")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://village/main.tscn","F5 still runs the original village entry")
	check(world.get_node("WalkCollisions/CollisionShape3D").disabled,"Former west boundary opened")
	for name in ["BroadleafTree22","BroadleafTree23","BroadleafTree24","BroadleafTree55","BroadleafTree56","BroadleafTree57"]:
		var tree: Node3D = world.get_node("ForestBoundary/"+name)
		var shape: Node3D = world.get_node("WalkCollisions/"+name+"_Trunk")
		check(is_equal_approx(tree.position.x,shape.position.x) and is_equal_approx(tree.position.z,shape.position.z),name+" visual and collision positions match")
	# Same hero capsule, actually moved through the saved physics world.
	var hero := load("res://hero_v2/traveler.tscn").instantiate() as CharacterBody3D
	hero.set_script(load("res://hero_v2/hero_controller.gd"))
	world.add_child(hero)
	hero.position = Vector3(-22,0.1,7)
	hero.set_physics_process(false)
	await physics_frame
	await physics_frame
	var route := [Vector3(-29,0,7),Vector3(-36,0,5.5),Vector3(-43,0,1.8),Vector3(-49,0,-0.3),Vector3(-57,0,0.5),Vector3(-61,0,1.5),Vector3(-65,0,-5),Vector3(-69,0,-10),Vector3(-71,0,-17)]
	var route_ok := true
	for target in route:
		var arrived := false
		for frame in range(200):
			await physics_frame
			var difference: Vector3 = target-hero.position
			difference.y = 0
			if difference.length()<0.15:
				arrived = true
				break
			hero.velocity = difference.normalized()*minf(12.0,difference.length()*60)
			hero.velocity.y = -2.0
			hero.move_and_slide()
			if hero.position.y < -0.5:
				break
		check(arrived and hero.is_on_floor(),"Walkable segment reaches "+str(target)+"; actual="+str(hero.position))
		if not arrived:
			route_ok = false
			break
	check(route_ok,"Continuous traversal from old village through west seam into graveyard")
	world.queue_free()
	await process_frame
	print("WEST EXTENSION VALIDATION / failures=",failures)
	quit(0 if failures == 0 else 1)
