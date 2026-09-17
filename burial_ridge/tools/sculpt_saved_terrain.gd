extends "refine_saved_scene.gd"
## One-time local terrain edit. Geometry, weights and matching collision are baked.
var natural_noise := FastNoiseLite.new()
var terrain_material: ShaderMaterial
var terrain_group: Node3D
var height_min := INF
var height_max := -INF

func _initialize() -> void:
	if not "--apply" in OS.get_cmdline_user_args():
		quit(1)
		return
	scene_root = load(OUTPUT).instantiate()
	if scene_root.has_meta("continuous_terrain_revision"):
		push_error("Terrain already sculpted. Edit saved terrain chunks instead of reapplying.")
		quit(1)
		return
	natural_noise.seed = 917369
	natural_noise.frequency = 0.12
	shader = load("res://village/style.gdshader")
	rng.seed = 172603
	remove_flat_blocks()
	# Conform existing authored content before adding the terrain nodes themselves.
	for section in ["Graveyard","BareRidgeTrees","LivingForest","BrokenRockTerraces","ForestHomesteads","MeadowAndGroundDetails","BrokenCobblestoneCrossing","AncientRoadsideDetails"]:
		conform(scene_root.get_node(section))
	conform(scene_root.get_node("TerrainAndPaths/HandWorkedRoads"))
	for shape in scene_root.get_node("SavedWalkCollisions").get_children():
		if shape.name == "Ground":
			shape.disabled = true
		elif shape is CollisionShape3D:
			shape.position.y += elevation(shape.position.x,shape.position.z)
	make_terrain()
	add_surface_ecology()
	scene_root.set_meta("continuous_terrain_revision",1)
	scene_root.set_meta("terrain_height_range",Vector2(height_min,height_max))
	var result := save_scene(OUTPUT)
	print("TERRAIN HEIGHT RANGE ",height_min," .. ",height_max)
	scene_root.free()
	quit(result)

func remove_flat_blocks() -> void:
	var ground := scene_root.get_node("TerrainAndPaths")
	for label in ["WesternForestFloor","OliveWoodlandTransition","ColdBurialSoil","GraveyardAsh"]:
		ground.get_node(label).free()
	# Large outlined flat spheroids looked like painted disks rather than soil.
	scene_root.get_node("MeadowAndGroundDetails/WeatheredGroundPatches").free()

func elevation(x: float,z: float) -> float:
	var west := 1.0-smoothstep(-64.0,-52.0,x)
	var north := 1.0-smoothstep(-2.0,11.0,z)
	var hill := 1.10*exp(-pow((x+77.0)/12.0,4.0)-pow((z+17.0)/13.0,4.0))
	var shoulder := 0.54*exp(-pow((x+67.5)/6.5,2.0)-pow((z+12.0)/10.0,2.0))
	var ripple := 0.12*(1.0+natural_noise.get_noise_2d(x*1.7,z*1.7))
	var drainage := 0.19*exp(-pow((x+73.0-z*0.13)/2.0,2.0))*exp(-pow((z+8)/20.0,2.0))
	var h := maxf(0.0,(hill+shoulder+ripple-drainage)*west*north)
	# Foreground rough ground has ankle-high undulations, easing to the road seam.
	h += 0.16*exp(-pow((x+78.0)/13.0,2.0)-pow((z-15.0)/12.0,2.0))*(1+natural_noise.get_noise_2d(x,z))
	return h*(1.0-smoothstep(-53.0,-43.0,x))

func ground_normal(x: float,z: float) -> Vector3:
	return Vector3(-(elevation(x+0.16,z)-elevation(x-0.16,z))/0.32,1,-(elevation(x,z+0.16)-elevation(x,z-0.16))/0.32).normalized()

func weights_at(x: float,z: float) -> Color:
	var boundary := -59.5-smoothstep(-2.0,27.0,z)*10.0+sin(z*0.23)*1.3+natural_noise.get_noise_2d(x*0.72,z*0.72)*2.5
	var mineral := 1.0-smoothstep(boundary-4.0,boundary+4.5,x)
	var mottled := natural_noise.get_noise_2d(x*2.1,z*2.1)
	mineral = clampf(mineral+mottled*0.12*mineral,0,1)
	var grass := 1.0-mineral
	var old_soil := (0.09+maxf(0,mottled)*0.23)*mineral
	var litter := (0.09+maxf(0,natural_noise.get_noise_2d(x,z))*0.36)*(1-mineral)
	# The southern gray meadow greens gradually; no horizontal cutoff.
	var meadow := smoothstep(-3.0,14.0,z)*0.35*mineral
	grass += meadow
	mineral -= meadow
	var edge := 1.0-smoothstep(-33.0,-26.0,x)
	old_soil *= edge
	litter *= edge
	mineral *= edge
	grass = 1.0-mineral-old_soil-litter
	return Color(grass,mineral,old_soil,litter)

func conform(node: Node) -> void:
	if node is Node3D and node.position.x < -20.0:
		node.position.y += elevation(node.position.x,node.position.z)
		return
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		# Ground decals have absolute XZ vertices. Drape them onto the saved relief.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			vertices[i].y += elevation(vertices[i].x,vertices[i].z)
			if normals.size() == vertices.size():
				normals[i] = ground_normal(vertices[i].x,vertices[i].z)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		var replacement := ArrayMesh.new()
		replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		node.mesh = replacement
	for child in node.get_children():
		conform(child)

func make_terrain() -> void:
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = load("res://burial_ridge/terrain_blend.gdshader")
	terrain_material.set_shader_parameter("grass_color",Color("8f9c72"))
	terrain_material.set_shader_parameter("mineral_color",Color("a1a99b"))
	terrain_material.set_shader_parameter("loam_color",Color("a69d7e"))
	terrain_material.set_shader_parameter("litter_color",Color("7d8a6c"))
	terrain_material.set_meta("village_toon",true)
	terrain_group = group(scene_root.get_node("TerrainAndPaths"),"SculptedGround")
	# Saved local chunks are individually selectable. Vertex weights interpolate
	# across shared edges; analytic normals and positions match exactly at seams.
	var x0 := -112.0
	while x0 < -26.0:
		var z0 := -42.0
		while z0 < 42.0:
			make_chunk(x0,z0,minf(x0+8,-26),minf(z0+8,42))
			z0 += 8
		x0 += 8

func make_chunk(x0: float,z0: float,x1: float,z1: float) -> void:
	var chunk := group(terrain_group,"Ground_%d_%d" % [int(x0),int(z0)],Vector3(x0,0,z0))
	var nx := ceili((x1-x0)/0.5)
	var nz := ceili((z1-z0)/0.5)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for iz in range(nz+1):
		for ix in range(nx+1):
			var x := lerpf(x0,x1,float(ix)/nx)
			var z := lerpf(z0,z1,float(iz)/nz)
			var h := 0.07+elevation(x,z)
			height_min = minf(height_min,h)
			height_max = maxf(height_max,h)
			verts.append(Vector3(x-x0,h,z-z0))
			normals.append(ground_normal(x,z))
			colors.append(weights_at(x,z))
	for iz in range(nz):
		for ix in range(nx):
			var a := iz*(nx+1)+ix
			var b := a+1
			var c := a+nx+1
			var d := c+1
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var visual := mesh_node(chunk,"BlendedTerrain",mesh,Vector3.ZERO,"8f9c72")
	visual.material_override = terrain_material
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	chunk.add_child(body)
	body.owner = scene_root
	var collider := CollisionShape3D.new()
	collider.name = "MatchingSurface"
	collider.shape = mesh.create_trimesh_shape()
	(collider.shape as ConcavePolygonShape3D).backface_collision = true
	body.add_child(collider)
	collider.owner = scene_root

func near_path(p: Vector2) -> bool:
	var routes := [[Vector2(-23,7),Vector2(-29,7),Vector2(-36,5.5),Vector2(-43,1.8),Vector2(-49,-0.3),Vector2(-57,0.5)], [Vector2(-55,0.6),Vector2(-61,1.5),Vector2(-67,6),Vector2(-72,12),Vector2(-75,21),Vector2(-79,30)], [Vector2(-61,1.5),Vector2(-65,-5),Vector2(-69,-10),Vector2(-71,-17),Vector2(-71,-25)]]
	for route in routes:
		for i in range(route.size()-1):
			var a: Vector2 = route[i]
			var b: Vector2 = route[i+1]
			var t := clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
			if p.distance_to(a.lerp(b,t))<1.1:
				return true
	return false

func add_surface_ecology() -> void:
	var details := group(scene_root,"NaturalGroundDetails")
	var gravel := group(details,"WeatheredGravelPockets")
	var plants := group(details,"MixedEdgeVegetation")
	var flakes := group(details,"LeafLitterAndClayChips")
	for i in range(1100):
		var p := Vector2(rng.randf_range(-87,-31),rng.randf_range(-29,28))
		if near_path(p):
			continue
		if p.distance_to(Vector2(-49,-9))<3.9 or p.distance_to(Vector2(-34,-18))<3.6:
			continue
		var density := natural_noise.get_noise_2d(p.x*3.4,p.y*3.4)
		if density < -0.1:
			continue
		var gray := weights_at(p.x,p.y).g
		var h := elevation(p.x,p.y)
		if i%3 == 0:
			var pocket := group(gravel,"GravelPocket",Vector3(p.x,0.077+h,p.y))
			for j in range(rng.randi_range(3,6)):
				var offset := Vector3(rng.randf_range(-0.25,0.25),0.015,rng.randf_range(-0.19,0.19))
				ball(pocket,"EmbeddedFlake",offset,Vector3(rng.randf_range(0.035,0.11),rng.randf_range(0.012,0.037),rng.randf_range(0.028,0.085)),["949e8e","abb29e","7d8a78"][j%3])
		elif i%3 == 1:
			tuft(plants,Vector3(p.x,0.08+h,p.y),false,gray>0.5)
			var plant := plants.get_child(plants.get_child_count()-1) as Node3D
			plant.scale = Vector3.ONE*rng.randf_range(0.50,0.88)
		else:
			var leaf := box(flakes,"WeatheredLeaf",Vector3(p.x,0.08+h,p.y),Vector3(rng.randf_range(0.04,0.12),0.012,rng.randf_range(0.04,0.09)),"a0a17f" if gray>0.5 else "9d9569")
			leaf.rotation.y = rng.randf()*TAU
	# Small partly buried shale fragments explain the low graveyard shoulder.
	var shelf := group(details,"ExposedLowShale")
	for i in range(29):
		var p := Vector2(-85+i*0.66,-4.4+sin(i*0.29)*0.75)
		if near_path(p):
			continue
		var h := elevation(p.x,p.y)
		var flake := ball(shelf,"BuriedShaleFragment",Vector3(p.x,0.035+h,p.y),Vector3(rng.randf_range(0.23,0.48),rng.randf_range(0.07,0.13),rng.randf_range(0.16,0.30)),["949f8e","a4ad9a","818e7e"][i%3])
		flake.rotation.y = rng.randf()*TAU
