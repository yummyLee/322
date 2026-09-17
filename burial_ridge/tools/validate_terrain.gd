extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,label: String) -> void:
	print("PASS: " if value else "FAIL: ",label)
	if not value:
		failures += 1

func run() -> void:
	var world := load("res://burial_ridge/world.tscn").instantiate() as Node3D
	root.add_child(world)
	var terrain: Node3D = world.get_node("TerrainAndPaths/SculptedGround")
	var edges: Dictionary = {}
	var mismatch := 0
	var samples: Array[Vector3] = []
	var min_y := INF
	var max_y := -INF
	var mixed := 0
	for chunk in terrain.get_children():
		var mesh: MeshInstance3D = chunk.get_node("BlendedTerrain")
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in verts.size():
			var p: Vector3 = verts[i]+chunk.position
			min_y = minf(min_y,p.y)
			max_y = maxf(max_y,p.y)
			var key := Vector2(p.x,p.z)
			if edges.has(key):
				var old: Array = edges[key]
				if absf(old[0]-p.y)>0.0001 or not (old[1] as Vector3).is_equal_approx(normals[i]) or not (old[2] as Color).is_equal_approx(colors[i]):
					mismatch += 1
			else:
				edges[key] = [p.y,normals[i],colors[i]]
			if colors[i].r>0.15 and colors[i].g>0.15:
				mixed += 1
		if chunk.position.x>=-88 and chunk.position.x<=-56 and chunk.position.z>=-26 and chunk.position.z<=10:
			samples.append(verts[verts.size()/2]+chunk.position)
	check(mismatch==0,"Terrain chunks share identical edge heights, normals and material weights")
	check(max_y-min_y>1 and max_y-min_y<2,"Gentle real relief: %.3f to %.3f" % [min_y,max_y])
	check(mixed>1500,"Broad mixed green/gray transition vertices: %d" % mixed)
	check(world.get_node("SavedWalkCollisions/Ground").disabled,"Previous flat ground no longer overrides the raised collision")
	await physics_frame
	await physics_frame
	var missed := 0
	for p in samples:
		var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.25,p-Vector3.UP*0.2)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or absf(hit.position.y-p.y)>0.035:
			missed += 1
	check(missed==0,"Saved relief collision matches visible mesh at %d sampled points" % samples.size())
	var ungrounded := 0
	for grave in world.get_node("Graveyard").get_children():
		if not str(grave.name).begins_with("Grave_"):
			continue
		var p: Vector3 = grave.position
		# Ray beside the narrow stele, beneath the decorative mound top.
		var query := PhysicsRayQueryParameters3D.create(p+Vector3(0.4,0.12,-0.2),p+Vector3(0.4,-0.3,-0.2))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or absf(hit.position.y-(p.y-0.03))>0.13:
			ungrounded += 1
	check(ungrounded==0,"All 22 grave anchors remain seated on the raised soil")
	print("TERRAIN VALIDATION / failures=",failures)
	world.queue_free()
	await process_frame
	quit(failures)
