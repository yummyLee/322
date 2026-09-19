extends "res://northern_ridge/tools/extend_north.gd"
## One-time offline extension of the saved northern scene toward the east.
## It preserves the already-authored cave and writes every new node into world.tscn.
const EAST_OUTPUT := "res://northern_ridge/world.tscn"
var east_root: Node3D

func _initialize() -> void:
	if not "--apply" in OS.get_cmdline_user_args():
		quit(1)
		return
	scene_root=load(EAST_OUTPUT).instantiate()
	if scene_root.has_meta("east_extension_revision"):
		push_error("East extension already exists; edit the saved scene instead of reapplying.")
		quit(1)
		return
	root.add_child(scene_root)
	shader=load("res://village/style.gdshader")
	natural_noise.seed=917369
	natural_noise.frequency=0.12
	rng.seed=923741
	east_root=group(scene_root,"EastNorthExtension")
	obstacle_root=scene_root.get_node("SavedWalkCollisions")
	terrain_group=scene_root.get_node("ContinuousForestGround")
	terrain_material=terrain_group.get_child(0).get_node("BlendedTerrain").material_override
	road_root=scene_root.get_node("WindingTrails")
	# The existing last chunk is -32..-26, so start exactly at -26 to avoid a gap.
	for x in range(-26,26,8):
		for z in range(-82,-42,8):
			make_chunk(x,z,minf(x+8,26),minf(z+8,-42))
	move_boundaries()
	east_routes()
	make_rope_boundary()
	make_slope_bed()
	make_spring()
	make_wash_yard()
	make_orchard()
	make_east_forest()
	make_east_ecology()
	scene_root.set_meta("east_extension_revision",1)
	scene_root.set_meta("east_extension_range","X=-26..26 Z=-82..-42")
	assert(save_scene(EAST_OUTPUT)==OK)
	print("EAST EXTENSION SAVED")
	quit()

func move_boundaries() -> void:
	var east: CollisionShape3D=obstacle_root.get_node("EasternLimit")
	east.position=Vector3(26,2,-54.5)
	var east_shape:=east.shape.duplicate() as BoxShape3D
	east_shape.size=Vector3(0.6,8,45)
	east.shape=east_shape
	var north: CollisionShape3D=obstacle_root.get_node("NorthernLimit")
	north.position=Vector3(-31.5,2,-77)
	var north_shape:=north.shape.duplicate() as BoxShape3D
	north_shape.size=Vector3(115,8,0.6)
	north.shape=north_shape

func east_routes() -> void:
	add_east_route("CaveToSpringPath",[Vector2(-43,-51),Vector2(-36,-53),Vector2(-29,-57),Vector2(-21,-59),Vector2(-13,-57),Vector2(-6,-54)],1.75,false)
	add_east_route("VillageNorthFootpath",[Vector2(-20,-43),Vector2(-18,-49),Vector2(-14,-56),Vector2(-10,-63),Vector2(-6,-68)],1.55,false)
	add_east_route("EastForestLoop",[Vector2(-6,-54),Vector2(1,-56),Vector2(8,-60),Vector2(12,-67),Vector2(8,-74),Vector2(1,-76)],1.65,false)
	add_east_route("OldForestContinuation",[Vector2(-31,-69),Vector2(-25,-70),Vector2(-18,-69),Vector2(-11,-66),Vector2(-6,-62)],1.55,false)

func add_east_route(label: String,points: Array,width: float,cold: bool) -> void:
	var before:=road_root.get_child_count()
	add_route(label,points,width,cold)
	conform_east_mesh(road_root.get_child(before))

func conform_east_roads() -> void:
	# Only the four newly-added route children are conformed; existing roads were already baked.
	for label in ["CaveToSpringPath","VillageNorthFootpath","EastForestLoop","OldForestContinuation"]:
		if road_root.has_node(label):conform_east_mesh(road_root.get_node(label))

func conform_east_mesh(node: Node) -> void:
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		var arrays: Array=node.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			if vs[i].x < -26.0:continue
			vs[i].y+=elevation(vs[i].x,vs[i].z)
			if ns.size()==vs.size():ns[i]=ground_normal(vs[i].x,vs[i].z)
		arrays[Mesh.ARRAY_VERTEX]=vs
		arrays[Mesh.ARRAY_NORMAL]=ns
		var replacement:=ArrayMesh.new()
		replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		node.mesh=replacement
	for child in node.get_children():conform_east_mesh(child)

func make_rope_boundary() -> void:
	var g:=group(east_root,"NorthTrailRopeBoundary",ground(-10,-46))
	for x in [-1.35,1.35]:
		cylinder(g,"WeatheredBoundaryPost",Vector3(x,1.0,0),0.11,2.0,"705d43",0.075,7)
		ball(g,"PostStoneFoot",Vector3(x,0.10,0),Vector3(0.27,0.12,0.24),"777666")
	beam(g,"SaggingHempRope",Vector3(-1.28,1.55,0),Vector3(0,1.18,0.04),0.035,"7d6749")
	beam(g,"SaggingHempRope",Vector3(0,1.18,0.04),Vector3(1.28,1.55,0),0.035,"7d6749")
	for x in [-0.62,0.62]:
		var knot:=group(g,"RopeKnot",Vector3(x,1.37,0))
		ball(knot,"WornKnot",Vector3.ZERO,Vector3(0.09,0.10,0.09),"806449")

func make_slope_bed() -> void:
	var bed:=group(east_root,"ShallowRootCropHollow",ground(-17,-53))
	soft_patch(bed,"DarkLoamDepression",Vector2(3.3,2.2),"65694f")
	for i in range(24):
		var x:=rng.randf_range(-2.6,2.5)
		var z:=rng.randf_range(-1.55,1.5)
		var plant:=group(bed,"UntendedRootCrop",Vector3(x,elevation(-17+x,-53+z)-elevation(-17,-53),z))
		var h:=rng.randf_range(0.42,0.78)
		beam(plant,"BentStem",Vector3.ZERO,Vector3(rng.randf_range(-0.08,0.08),h,0),0.022,"65704d")
		for side in [-1,1]:
			var leaf:=ball(plant,"BroadCropLeaf",Vector3(side*0.12,h*0.57,0),Vector3(0.20,0.045,0.10),["71834f","849153","68784a"][i%3])
			leaf.rotation.z=side*0.48
	for p in [Vector2(-2.9,-1.3),Vector2(2.6,1.4),Vector2(2.8,-1.0)]:
		ball(bed,"HollowEdgeStone",Vector3(p.x,elevation(-17+p.x,-53+p.y)-elevation(-17,-53)+0.08,p.y),Vector3(0.28,0.15,0.22),"686b5c")

func make_spring() -> void:
	var spring:=group(east_root,"StoneSpringAndRunoff",ground(-6,-54))
	soft_patch(spring,"ClearSpringPool",Vector2(2.05,1.28),"718f91")
	for p in [Vector3(-1.25,0.58,-1.02),Vector3(1.12,0.52,-1.08),Vector3(-0.15,0.82,-1.42)]:
		ball(spring,"SpringCliffStone",p,Vector3(0.72,0.85,0.55),["70776e","858b7d","96998a"][int(absf(p.x*10))%3])
	for p in [Vector3(-1.30,0.10,-0.15),Vector3(1.15,0.14,0.12),Vector3(-0.35,0.18,0.83),Vector3(0.45,0.24,-0.83)]:
		ball(spring,"WaterwornSpringRock",p,Vector3(0.45+rng.randf()*0.25,0.30+rng.randf()*0.18,0.40+rng.randf()*0.24),["858b7d","96998a","737d73"][int(absf(p.x*10))%3])
	var fall:=group(spring,"NarrowRockFall",Vector3(0,0,-0.92))
	beam(fall,"FallingWater",Vector3(0,2.10,0),Vector3(0,0.24,0),0.14,"89aeb0")
	beam(fall,"WetRockLip",Vector3(-0.34,0.74,0),Vector3(0.30,0.74,0),0.16,"72796f")
	for i in range(7):
		var p:=Vector2(-5.3-i*0.58,-55.1-i*0.22)
		soft_patch(spring,"RunoffWaterMark",Vector2(0.34,0.18),"7b9895")
		var mark:=spring.get_child(spring.get_child_count()-1)
		mark.position=Vector3(p.x+6,elevation(-6+p.x+6,-54+p.y)-elevation(-6,-54)+0.03,p.y+6)
		mark.rotation.y=rng.randf_range(-0.35,0.35)
	for i in range(10):
		var p:=Vector2(rng.randf_range(-2.6,2.6),rng.randf_range(-1.9,1.9))
		ball(spring,"WetPebble",Vector3(p.x,0.08,p.y),Vector3(0.12,0.07,0.16),["687a73","88928a","6c7772"][i%3])

func make_wash_yard() -> void:
	var yard:=group(east_root,"NorthVillageWashYard",ground(-5,-68))
	soft_patch(yard,"CompactedWashYard",Vector2(3.6,2.7),"9e9876")
	for p in [Vector3(-1.9,0.10,-0.8),Vector3(0.0,0.12,0.4),Vector3(1.65,0.10,-0.2)]:
		box(yard,"WornWashStone",p,Vector3(1.30,0.16,0.58),"999887")
	var rack:=group(yard,"LaundryRack",Vector3(-0.2,0,0.45))
	for x in [-1.15,1.15]:cylinder(rack,"RackPost",Vector3(x,1.0,0),0.075,2.0,"765d45",0.05,7)
	beam(rack,"DryingCord",Vector3(-1.12,1.65,0),Vector3(1.12,1.65,0),0.028,"806849")
	for i in range(5):
		var cloth:=box(rack,"HangingCloth",Vector3(-0.82+i*0.40,1.36,0.02),Vector3(0.30,0.66,0.035),["9c765e","a18b63","7c876c","a08876"][i%4])
		cloth.rotation.z=sin(i*1.7)*0.06
	box(yard,"StoneWashTrough",Vector3(1.85,0.34,0.85),Vector3(1.10,0.48,0.68),"77796d")
	box(yard,"TroughDarkWater",Vector3(1.85,0.60,0.85),Vector3(0.78,0.035,0.42),"6e8787")
	fence(yard,Vector3(-2.35,0,-1.35),Vector3(2.10,0,-1.35))
	box(yard,"FoldedClothStack",Vector3(-1.95,0.28,0.45),Vector3(0.65,0.15,0.42),"8c8169")
	box(yard,"WoodenWashBoard",Vector3(0.72,0.25,0.95),Vector3(0.50,0.08,0.32),"806348")
	pot(yard,Vector3(-2.4,0.04,0.8),0.25)

func make_orchard() -> void:
	var orchard:=group(east_root,"NorthFruitOrchard",Vector3.ZERO)
	for i in range(19):
		var x:=rng.randf_range(5.5,20.5)
		var z:=rng.randf_range(-73,-51)
		if path_distance(Vector2(x,z))<2.0:continue
		var before:=orchard.get_child_count()
		tree(orchard,ground(x,z),rng.randf_range(0.72,1.08),false)
		var t:=orchard.get_child(before)
		for j in range(4):
			var a:=rng.randf()*TAU
			ball(t,"OrangeFruit",Vector3(cos(a)*0.75,3.05+rng.randf_range(-0.15,0.45),sin(a)*0.65),Vector3(0.10,0.10,0.10),["b96736","c2783e","a95c32"][j%3])
		collision_box(obstacle_root,"OrchardTrunk",ground(x,z)+Vector3(0,1.4,0),Vector3(0.40,2.8,0.40))

func make_east_forest() -> void:
	var forest:=group(east_root,"EastForestBoundary")
	# A broad eastern woodland wall keeps the new area from ending as an exposed rectangle.
	for i in range(110):
		var x:=rng.randf_range(0.0,24.0)
		var z:=rng.randf_range(-80.0,-44.5)
		if path_distance(Vector2(x,z))<2.1:continue
		if Vector2(x,z).distance_to(Vector2(-6,-54))<4.5 or Vector2(x,z).distance_to(Vector2(-5,-68))<4.5:continue
		if i%3==0:
			var pos:=ground(x,z)
			tree(forest,pos,rng.randf_range(0.78,1.14),false)
			collision_box(obstacle_root,"EastBroadleafTrunk",pos+Vector3(0,1.45,0),Vector3(0.40,2.9,0.40))
		else:conifer(forest,ground(x,z),rng.randf_range(0.75,1.12))
	for p in [Vector2(10,-48),Vector2(16,-48),Vector2(22,-55),Vector2(22,-72)]:
		conifer(forest,ground(p.x,p.y),rng.randf_range(0.85,1.12))
	var old_tree_pos:=ground(9.2,-50.2)
	tree(forest,old_tree_pos,1.28,true)
	var old_tree: Node3D=forest.get_child(forest.get_child_count()-1)
	collision_box(obstacle_root,"EastOldTreeTrunk",old_tree_pos+Vector3(0,2.4,0),Vector3(1.0,4.8,1.0))
	for i in range(7):
		var a:=i*TAU/7.0+rng.randf_range(-0.20,0.20)
		var end:=Vector3(cos(a)*rng.randf_range(2.0,3.8),0.08,sin(a)*rng.randf_range(1.5,3.4))
		tapered_root(old_tree,"EastOldTreeRoot",[Vector3(cos(a)*0.28,1.2,sin(a)*0.25),Vector3(cos(a)*0.9,0.34,sin(a)*0.8),end*0.72,end],0.18,"766449")

func make_east_ecology() -> void:
	var details:=group(east_root,"EastGroundEcology")
	var grasses:=group(details,"EastTallGrass")
	var stones:=group(details,"EastScatteredStone")
	var shrubs:=group(details,"EastLowShrubClusters")
	for i in range(250):
		var p:=Vector2(rng.randf_range(-24,23),rng.randf_range(-79,-44))
		if path_distance(p)<1.35 or p.distance_to(Vector2(-6,-54))<3.2 or p.distance_to(Vector2(-5,-68))<4.2:continue
		if i%3==0:
			tuft(grasses,ground(p.x,p.y),i%7==0,p.x<0)
		else:
			var stone:=ball(stones,"HalfBuriedEastStone",ground(p.x,p.y)+Vector3(0,0.06,0),Vector3(rng.randf_range(0.12,0.33),rng.randf_range(0.07,0.15),rng.randf_range(0.13,0.30)),["858b7b","929486","727c70"][i%3])
			stone.rotation.y=rng.randf()*TAU
	for i in range(72):
		var p:=Vector2(rng.randf_range(-23,23),rng.randf_range(-78,-45))
		if path_distance(p)<2.2 or p.distance_to(Vector2(-6,-54))<4.5 or p.distance_to(Vector2(-5,-68))<4.5:continue
		var clump:=group(shrubs,"MossyEastShrub",ground(p.x,p.y))
		for j in range(3+rng.randi_range(0,2)):
			var a:=rng.randf()*TAU
			ball(clump,"RoundedEastLeaf",Vector3(cos(a)*rng.randf_range(0.12,0.45),rng.randf_range(0.24,0.43),sin(a)*rng.randf_range(0.12,0.45)),Vector3(0.34,0.26,0.31),["566a4b","66774e","788259","4e634a"][rng.randi_range(0,3)])
