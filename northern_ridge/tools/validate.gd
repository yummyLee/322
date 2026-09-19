extends "res://village/tools/validate_lived_in.gd"

func terrain_height(north: Node3D,target: Vector2) -> float:
	var best:=INF
	var result:=0.0
	for chunk in north.get_node("ContinuousForestGround").get_children():
		if not chunk.has_node("BlendedTerrain"):continue
		var arr: Array=chunk.get_node("BlendedTerrain").mesh.surface_get_arrays(0)
		for vertex in arr[Mesh.ARRAY_VERTEX]:
			var p: Vector3=vertex+chunk.position
			var d:=Vector2(p.x,p.z).distance_to(target)
			if d<best:
				best=d
				result=p.y
	return result

func run() -> void:
	world=load("res://village/yao_village.tscn").instantiate()
	root.add_child(world)
	var north: Node3D=world.get_node("NorthernRidge")
	var ridge: Node3D=world.get_node("WesternBurialRidge")
	check(north.scene_file_path=="res://northern_ridge/world.tscn" and world.is_editable_instance(north),"Original village uses the editable saved northern scene")
	var bad:=0
	var meshes:=0
	for n in north.find_children("*","",true,false):
		if n.owner!=north or n.get_script()!=null:bad+=1
		if n is MeshInstance3D:
			meshes+=1
			if not n.mesh or not n.transform.is_finite():bad+=1
	check(bad==0 and north.get_script()==null,"All northern nodes have saved ownership and no runtime generator")
	print("Editable mesh count: ",meshes)
	for p in ["RootWrappedStoneGate","WeatheredWaysidePavilion","AncientRootTree","DampHerbHollow","MixedNorthernForest","WindingTrails","BrokenRedSlopeTerraces"]:
		check(north.has_node(p),"Reference landmark: "+p)
	check(ridge.get_node("SavedWalkCollisions/NorthLimit").disabled,"Former burial-ridge north boundary is open")
	check(world.get_node("RenderRig/VillageCamera").size==36 and ProjectSettings.get_setting("application/run/main_scene")=="res://village/main.tscn","Original camera and game entry retained")
	var portal: Area3D=north.get_node("RootWrappedStoneGate/ReservedEntrance")
	check(portal.monitoring and portal.get_meta("target_scene")=="res://burial_left_cave/main.tscn" and portal.get_meta("target_spawn")=="root_cave_entry" and portal.get_meta("door_link_id")=="northern_root_cave_door","Root gate links to the saved cave scene and entry spawn")
	var old_edges: Dictionary={}
	for chunk in ridge.get_node("TerrainAndPaths/SculptedGround").get_children():
		var arr: Array=chunk.get_node("BlendedTerrain").mesh.surface_get_arrays(0)
		for i in arr[Mesh.ARRAY_VERTEX].size():
			var p: Vector3=arr[Mesh.ARRAY_VERTEX][i]+chunk.position
			if absf(p.z+42)<0.001:old_edges[snappedf(p.x,0.5)]=[p.y,arr[Mesh.ARRAY_NORMAL][i],arr[Mesh.ARRAY_COLOR][i]]
	var seam_count:=0
	var seams_bad:=0
	var max_normal_error:=0.0
	var samples: Array[Vector3]=[]
	for chunk in north.get_node("ContinuousForestGround").get_children():
		if not chunk.has_node("BlendedTerrain"):continue
		var arr: Array=chunk.get_node("BlendedTerrain").mesh.surface_get_arrays(0)
		for i in arr[Mesh.ARRAY_VERTEX].size():
			var p: Vector3=arr[Mesh.ARRAY_VERTEX][i]+chunk.position
			if absf(p.z+42)<0.001:
				seam_count+=1
				var old: Array=old_edges[snappedf(p.x,0.5)]
				max_normal_error=maxf(max_normal_error,(old[1] as Vector3).distance_to(arr[Mesh.ARRAY_NORMAL][i]))
				if absf(p.y-old[0])>0.0001 or not (old[2] as Color).is_equal_approx(arr[Mesh.ARRAY_COLOR][i]):
					seams_bad+=1
		samples.append(arr[Mesh.ARRAY_VERTEX][arr[Mesh.ARRAY_VERTEX].size()/2]+chunk.position)
	check(seam_count>170 and seams_bad==0 and max_normal_error<0.005,"New/old terrain joins without height or material-weight gaps (%d vertices; normal delta %.5f)" % [seam_count,max_normal_error])
	var cave_front:=terrain_height(north,Vector2(-55,-47))
	var cave_mid:=terrain_height(north,Vector2(-55,-52))
	var cave_north:=terrain_height(north,Vector2(-55,-56))
	var cave_side:=(terrain_height(north,Vector2(-67,-52))+terrain_height(north,Vector2(-43,-52)))*0.5
	check(cave_north-cave_front>0.80 and cave_mid-cave_side>0.35,"Cave terrain forms a raised north shelf with sloped side transitions (front %.2f, north %.2f, side %.2f)" % [cave_front,cave_north,cave_side])
	hero=load("res://hero_v2/traveler.tscn").instantiate()
	hero.set_script(load("res://hero_v2/hero_controller.gd"))
	world.add_child(hero)
	hero.set_physics_process(false)
	await physics_frame
	await physics_frame
	var gate: Node3D=north.get_node("RootWrappedStoneGate")
	check(terrain_height(north,Vector2(-55,-48.5))>gate.position.y+2.55,"Continuous earth covers the passage roof behind the lintel")
	var passage_clear:=true
	for x in [-55.45,-55.0,-54.55]:
		for h in [0.5,1.2,2.0]:
			var q:=PhysicsRayQueryParameters3D.create(Vector3(x,gate.position.y+h,-46.6),Vector3(x,gate.position.y+h,-48.7))
			q.exclude=[hero.get_rid()]
			if not world.get_world_3d().direct_space_state.intersect_ray(q).is_empty():passage_clear=false
	check(passage_clear,"Embedded entrance has clear body/head space below the terrain roof")
	var missed:=0
	for p in samples:
		var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.2,p-Vector3.UP*0.2)
		q.exclude=[hero.get_rid()]
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or absf(hit.position.y-p.y)>0.035:missed+=1
	check(missed==0,"Saved new terrain matches collision at %d sampled positions" % samples.size())
	place(Vector2(-71,-25))
	check(await walk([Vector2(-70.5,-29),Vector2(-68,-32.5),Vector2(-65,-35),Vector2(-61.5,-35.7),Vector2(-57.8,-37.8),Vector2(-56,-42),Vector2(-55,-45.6),Vector2(-55,-47.3),Vector2(-55,-48),Vector2(-55,-45.6)]),"Actual player walks from old cemetery through pavilion route and into/out of stone gate")
	place(Vector2(-40,-18))
	check(await walk([Vector2(-40,-23),Vector2(-40,-28),Vector2(-41,-33),Vector2(-42,-38),Vector2(-44,-43),Vector2(-43,-48),Vector2(-39,-52),Vector2(-34,-55),Vector2(-31,-61),Vector2(-31,-69)]),"Actual player walks the eastern woodland connection to the north forest")
	place(Vector2(-69,-32.5))
	check(await walk([Vector2(-72,-36),Vector2(-78,-43),Vector2(-81,-48),Vector2(-79,-54),Vector2(-83,-61),Vector2(-83,-70)]),"Actual player climbs the red-earth route beside the ancient tree")
	place(Vector2(-79,-54))
	check(await walk([Vector2(-73,-53),Vector2(-67,-54.5),Vector2(-60,-56),Vector2(-52,-56),Vector2(-45,-55),Vector2(-39,-52)]),"Actual player crosses the northern forest junction")
	var source: Node3D=load("res://northern_ridge/world.tscn").instantiate()
	var pavilion: Node3D=source.get_node("WeatheredWaysidePavilion")
	pavilion.position+=Vector3(0.23,0,0.19)
	var expected:=pavilion.transform
	var pack:=PackedScene.new()
	check(pack.pack(source)==OK,"Northern scene can be packed after editing a landmark")
	var probe:="res://northern_ridge/_edit_probe.tscn"
	check(ResourceSaver.save(pack,probe)==OK,"Edited northern scene saves to disk")
	var restored: Node3D=ResourceLoader.load(probe,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	check(restored.get_node("WeatheredWaysidePavilion").transform.is_equal_approx(expected),"Edited pavilion transform survives saved-scene reload")
	restored.free()
	source.free()
	DirAccess.remove_absolute(probe)
	print("NORTH VALIDATION / failures=",failures)
	world.free()
	quit(0 if failures==0 else 1)
