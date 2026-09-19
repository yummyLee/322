extends "res://northern_ridge/tools/extend_east_saved.gd"
## One-time rework of the saved east extension.
## The reference layout is read as a continuous north-to-south space: the cave
## stays at west, the crop hollow and spring occupy the middle, and the hunter
## camp meets the north edge of Yao Village through a shallow sloped shelf.
const EAST_REWORK_OUTPUT := "res://northern_ridge/world.tscn"

func _initialize() -> void:
	if not "--apply" in OS.get_cmdline_user_args():
		quit(1)
		return
	scene_root=load(EAST_REWORK_OUTPUT).instantiate()
	if int(scene_root.get_meta("east_extension_revision",0)) < 1:
		push_error("The first east extension is required before this rework.")
		quit(1)
		return
	if int(scene_root.get_meta("east_relief_revision",0)) >= 1:
		push_error("East relief already sculpted; edit the saved terrain directly.")
		quit(1)
		return
	root.add_child(scene_root)
	shader=load("res://village/style.gdshader")
	natural_noise.seed=917369
	natural_noise.frequency=0.12
	rng.seed=926431
	obstacle_root=scene_root.get_node("SavedWalkCollisions")
	terrain_group=scene_root.get_node("ContinuousForestGround")
	terrain_material=terrain_group.get_child(0).get_node("BlendedTerrain").material_override
	road_root=scene_root.get_node("WindingTrails")
	remove_old_east_content()
	east_root=group(scene_root,"EastNorthExtension")
	resculpt_existing_east_terrain()
	scene_root.set_meta("east_relief_revision",1)
	add_south_transition_terrain()
	redesign_routes()
	make_transition_shelf()
	make_north_rope_gate()
	make_crop_hollow()
	make_spring()
	make_hunter_camp()
	make_orchard()
	make_forest_frame()
	make_ground_ecology()
	scene_root.set_meta("east_extension_revision",2)
	scene_root.set_meta("east_extension_range","X=-26..26 Z=-82..-32")
	scene_root.set_meta("east_village_transition","slope:-42..-32")
	assert(save_scene(EAST_REWORK_OUTPUT)==OK)
	print("EAST EXTENSION REWORK SAVED")
	quit()

func elevation(x: float,z: float) -> float:
	if x < -26.0:
		return super.elevation(x,z)
	if z <= -42.0:
		return super.elevation(x,z)+east_relief(x,z)
	# The east extension descends into the village's northern edge.  The seam
	# keeps the old north shelf height, then eases over ten metres instead of
	# leaving a floating strip or a hard horizontal step.
	var seam:=super.elevation(x,-42.0)+east_relief(x,-42.0)
	var zraw:=clampf((z+42.0)/10.4,0.0,1.0)
	var t:=zraw*zraw*zraw*(zraw*(zraw*6.0-15.0)+10.0)
	var ripple:=0.035*natural_noise.get_noise_2d(x*1.35,z*1.35)*(1.0-t)
	return lerpf(seam,0.0,t)+ripple

func east_relief(x: float,z: float) -> float:
	# A low woodland shelf rises from the old west edge over eight metres. It
	# keeps the x=-26 seam flush while giving the village approach a real bank.
	var raw:=clampf((x+26.0)/9.0,0.0,1.0)
	var lateral:=raw*raw*raw*(raw*(raw*6.0-15.0)+10.0)
	var broken:=0.035*natural_noise.get_noise_2d(x*0.8,z*0.8)
	return lateral*(0.58+broken)

func remove_old_east_content() -> void:
	for child in scene_root.get_children():
		if str(child.name).begins_with("EastNorthExtension"):
			child.free()
	for chunk in terrain_group.get_children():
		var chunk_label:=str(chunk.name)
		if chunk_label.begins_with("Ground_") and (chunk_label.contains("_-42") or chunk_label.contains("_-34")):
			chunk.free()
	var old_route_prefixes=["CaveToSpringPath","VillageNorthFootpath","EastForestLoop","OldForestContinuation","NorthForestPath","VillageNorthApproach","SpringToHunterCamp","OrchardServiceTrack","CropBedFootpath"]
	for old in road_root.get_children():
		for prefix in old_route_prefixes:
			if str(old.name).begins_with(prefix):
				road_root.remove_child(old)
				old.free()
				break
	for child in obstacle_root.get_children():
		var label:=str(child.name)
		if label.begins_with("OrchardTrunk") or label.begins_with("OrchardTreeTrunk") or label.begins_with("EastBroadleafTrunk") or label.begins_with("EastOldTreeTrunk") or label.begins_with("EastFrameBroadleafTrunk"):
			child.free()

func add_south_transition_terrain() -> void:
	# Existing east chunks stop at z=-42. Add two rows that land on the village
	# ground at z=-32. Their first edge uses the exact old seam height.
	for x in range(-26,26,8):
		make_chunk(x,-42.0,minf(x+8,26),-34.0)
		make_chunk(x,-34.0,minf(x+8,26),-32.0)

func resculpt_existing_east_terrain() -> void:
	for chunk in terrain_group.get_children():
		if chunk.position.x < -26.0 or chunk.position.z >= -42.0: continue
		var visual:=chunk.get_node_or_null("BlendedTerrain") as MeshInstance3D
		if visual==null or not visual.mesh is ArrayMesh: continue
		var arrays: Array=visual.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			var p: Vector3=vs[i]+chunk.position
			vs[i].y+=east_relief(p.x,p.z)
			if ns.size()==vs.size(): ns[i]=ground_normal(p.x,p.z)
		arrays[Mesh.ARRAY_VERTEX]=vs
		arrays[Mesh.ARRAY_NORMAL]=ns
		var replacement:=ArrayMesh.new()
		replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		visual.mesh=replacement
		var collider:=chunk.get_node_or_null("GroundCollision/MatchingSurface") as CollisionShape3D
		if collider: collider.shape=replacement.create_trimesh_shape()

func conform_new_mesh(node: Node) -> void:
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		var arrays: Array=node.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			vs[i].y+=elevation(vs[i].x,vs[i].z)
			if ns.size()==vs.size(): ns[i]=ground_normal(vs[i].x,vs[i].z)
		arrays[Mesh.ARRAY_VERTEX]=vs
		arrays[Mesh.ARRAY_NORMAL]=ns
		var replacement:=ArrayMesh.new()
		replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		node.mesh=replacement
	for child in node.get_children(): conform_new_mesh(child)

func add_route(label: String,points: Array,width: float,cold: bool) -> void:
	routes.append(points)
	var before:=road_root.get_child_count()
	detailed_road(label,points,width,cold)
	conform_new_mesh(road_root.get_child(before))

func redesign_routes() -> void:
	routes=[]
	add_route("NorthForestPath",[Vector2(-31,-69),Vector2(-26,-70),Vector2(-20,-75),Vector2(-13,-76),Vector2(-7,-72),Vector2(0,-70),Vector2(8,-70),Vector2(15,-65),Vector2(23,-61)],1.55,false)
	add_route("CaveToSpringPath",[Vector2(-31,-52),Vector2(-26,-53),Vector2(-21,-57),Vector2(-15,-60),Vector2(-8,-61),Vector2(0,-61),Vector2(8,-60),Vector2(14,-59)],1.62,false)
	add_route("VillageNorthApproach",[Vector2(-17,-43),Vector2(-17,-40),Vector2(-14,-37),Vector2(-10,-34),Vector2(-7,-32)],1.58,false)
	add_route("SpringToHunterCamp",[Vector2(14,-59),Vector2(17,-56),Vector2(19,-52),Vector2(20,-48),Vector2(19,-45)],1.38,false)
	add_route("OrchardServiceTrack",[Vector2(20,-47),Vector2(24,-44),Vector2(24,-39),Vector2(18,-36)],1.22,false)
	add_route("CropBedFootpath",[Vector2(-8,-61),Vector2(-6,-65),Vector2(-3,-68)],1.18,true)

func make_transition_shelf() -> void:
	var shelf:=group(east_root,"YaoVillageNorthSlopeTransition")
	for i in range(18):
		var x: float=-24.5+i*2.75
		var z: float=-40.8+sin(i*0.72)*0.32
		var p:=ground(x,z)
		var patch:=group(shelf,"FeatheredSlopeSoil",p)
		soft_patch(patch,"SlopeColorBlend",Vector2(1.28,0.72),["8f9675","9b9674","a19b77"][i%3])
		if i%2==0:
			ball(shelf,"SlopeEmbeddedStone",p+Vector3(0,0.08,0),Vector3(0.25,0.10,0.20),["7b806e","8c8f7b","727a6c"][i%3])
	for x in [-22,-15,-8,0,8,16,23]:
		var a:=ground(x,-41.8)
		var b:=ground(x+1.5,-35.0)
		beam(shelf,"BrokenSlopeRoot",a+Vector3(0,0.08,0),b+Vector3(0,0.06,0),0.055,"756449")
	for x in [-24,-19,-13,-6,2,10,18,24]:
		tuft(shelf,ground(x,-37.0),x%2==0,false)

func make_north_rope_gate() -> void:
	var g:=group(east_root,"NorthForestRopeBoundary",ground(-18,-76.4))
	for x in [-1.25,1.25]:
		cylinder(g,"WeatheredTrailPost",Vector3(x,1.0,0),0.10,2.0,"705d43",0.07,7)
		ball(g,"PostStoneFoot",Vector3(x,0.10,0),Vector3(0.27,0.12,0.24),"777666")
	beam(g,"SaggingHempRope",Vector3(-1.18,1.55,0),Vector3(0,1.18,0.05),0.035,"7d6749")
	beam(g,"SaggingHempRope",Vector3(0,1.18,0.05),Vector3(1.18,1.55,0),0.035,"7d6749")
	for x in [-0.60,0.60]: ball(g,"RopeKnot",Vector3(x,1.37,0),Vector3(0.09,0.10,0.09),"806449")

func make_crop_hollow() -> void:
	var bed:=group(east_root,"NorthRootCropHollow",ground(-2.4,-67.0))
	soft_patch(bed,"DarkUnevenLoam",Vector2(4.2,2.7),"625f48")
	soft_patch(bed,"MuddyCropEdge",Vector2(3.65,2.25),"7a7656")
	for p in [Vector2(-3.9,-1.8),Vector2(-2.6,2.0),Vector2(2.9,-1.5),Vector2(3.5,1.4)]:
		ball(bed,"LoamEdgeStone",Vector3(p.x,elevation(-2.4+p.x,-67+p.y)-elevation(-2.4,-67)+0.08,p.y),Vector3(0.30,0.15,0.24),"6e705a")
	for i in range(32):
		var x:=rng.randf_range(-3.0,3.0)
		var z:=rng.randf_range(-1.65,1.7)
		var plant:=group(bed,"UntendedMilletCrop",Vector3(x,elevation(-2.4+x,-67+z)-elevation(-2.4,-67),z))
		var h:=rng.randf_range(0.45,0.78)
		beam(plant,"BentCropStem",Vector3.ZERO,Vector3(rng.randf_range(-0.13,0.13),h,0),0.022,"65704d")
		for side in [-1,1]:
			var leaf:=ball(plant,"BroadCropLeaf",Vector3(side*0.13,h*rng.randf_range(0.45,0.68),0),Vector3(0.22,0.045,0.11),["71834f","849153","68784a"][i%3])
			leaf.rotation.z=side*0.48

func make_spring() -> void:
	var spring:=group(east_root,"EastStoneSpringAndRunoff",ground(15.2,-59.5))
	soft_patch(spring,"ClearSpringPool",Vector2(2.4,1.55),"708c8d")
	for p in [Vector3(-1.55,0.72,-0.82),Vector3(1.20,0.72,-0.94),Vector3(-0.20,0.98,-1.32),Vector3(1.65,0.44,0.15)]:
		ball(spring,"SpringCliffStone",p,Vector3(0.74,0.88,0.56),["70776e","858b7d","96998a"][int(absf(p.x*10))%3])
	var fall:=group(spring,"NarrowStoneWaterfall",Vector3(0,0,-0.86))
	beam(fall,"FallingWater",Vector3(0,2.20,0),Vector3(0,0.20,0),0.15,"89aeb0")
	beam(fall,"WetRockLip",Vector3(-0.42,0.76,0),Vector3(0.38,0.76,0),0.17,"72796f")
	for i in range(9):
		var p:=Vector2(1.0-i*0.32,0.2+i*0.55)
		soft_patch(spring,"SpringRunoffPatch",Vector2(0.34,0.18),"7b9895")
		var mark:=spring.get_child(spring.get_child_count()-1) as Node3D
		mark.position=Vector3(p.x,elevation(15.2+p.x,-59.5+p.y)-elevation(15.2,-59.5)+0.03,p.y)
		mark.rotation.y=rng.randf_range(-0.35,0.35)
	for i in range(16):
		var p:=Vector2(rng.randf_range(-2.9,2.9),rng.randf_range(-2.0,2.1))
		ball(spring,"WetPebble",Vector3(p.x,elevation(15.2+p.x,-59.5+p.y)-elevation(15.2,-59.5)+0.08,p.y),Vector3(0.12,0.07,0.16),["687a73","88928a","6c7772"][i%3])

func make_hide_sheet(parent: Node, label: String, pos: Vector3, size: Vector3, color: String, angle: float) -> void:
	var hide:=box(parent,label,pos,size,color)
	hide.rotation.z=angle
	box(parent,label+"RaggedEdge",pos+Vector3(0,-size.y*0.48,0.025),Vector3(size.x*0.72,0.035,0.045),"755b49")

func make_hunter_camp() -> void:
	var camp:=group(east_root,"AncientHunterCamp",ground(17.4,-46.0))
	soft_patch(camp,"CampWornEarth",Vector2(3.4,2.5),"9e8f6d")
	var tent:=group(camp,"HideLeanToTent",Vector3(-0.25,0,0.42))
	for x in [-1.15,1.15]:
		cylinder(tent,"TentPole",Vector3(x,0.95,0),0.07,1.90,"6c5540",0.05,7)
	var verts:=PackedVector3Array([Vector3(-1.38,0.10,0.48),Vector3(1.38,0.10,0.48),Vector3(0,1.85,0.48)])
	solid(tent,"TannedHideCanopy",verts,PackedInt32Array([0,1,2,2,1,0]),"8c7257",Vector3(0,1,0))
	beam(tent,"TentRidgePole",Vector3(-1.38,1.85,0.48),Vector3(1.38,1.85,0.48),0.06,"6a513c")
	box(tent,"RolledBedMat",Vector3(0,0.18,-0.28),Vector3(1.35,0.16,0.55),"75654e")
	var fire:=group(camp,"HunterFirePit",Vector3(1.40,0.0,-0.78))
	for a in range(6):
		var ang:=a*TAU/6
		ball(fire,"FirePitStone",Vector3(cos(ang)*0.45,0.10,sin(ang)*0.36),Vector3(0.17,0.10,0.15),["767362","8a806b","6b6a5c"][a%3])
	ball(fire,"ColdAsh",Vector3(0,0.19,0),Vector3(0.26,0.03,0.22),"514f42")
	var rack:=group(camp,"WildHideDryingRack",Vector3(2.22,0,0.22))
	for x in [-1.10,1.10]: cylinder(rack,"HideRackPost",Vector3(x,1.05,0),0.075,2.1,"765d45",0.05,7)
	beam(rack,"HideRackCrossbar",Vector3(-1.10,1.72,0),Vector3(1.10,1.72,0),0.06,"806849")
	for i in range(4):
		make_hide_sheet(rack,"TannedWildHide",Vector3(-0.78+i*0.52,1.27,0.03),Vector3(0.38,0.72,0.035),["9c765e","a18b63","7c876c","8f7057"][i],sin(i*1.7)*0.08)
	box(camp,"HunterBench",Vector3(0.95,0.24,1.45),Vector3(1.55,0.16,0.42),"80684e")
	box(camp,"SkinningBlock",Vector3(-1.55,0.22,-1.28),Vector3(0.70,0.34,0.62),"766149")
	pot(camp,Vector3(-2.15,0.04,-0.95),0.25)

func add_fruit_tree(parent: Node, x: float,z: float,scale_value: float) -> void:
	var pos:=ground(x,z)
	var before:=parent.get_child_count()
	tree(parent,pos,scale_value,false)
	var t:=parent.get_child(before)
	for j in range(5):
		var a:=rng.randf()*TAU
		ball(t,"OrangeFruit",Vector3(cos(a)*0.75,3.05+rng.randf_range(-0.15,0.45),sin(a)*0.65),Vector3(0.10,0.10,0.10),["b96736","c2783e","a95c32"][j%3])
	collision_box(obstacle_root,"OrchardTreeTrunk",pos+Vector3(0,1.35*scale_value,0),Vector3(0.40,2.7,0.40)*scale_value)

func make_orchard() -> void:
	var orchard:=group(east_root,"EastFruitOrchard")
	for p in [Vector2(21,-43),Vector2(24,-46),Vector2(22,-51),Vector2(24,-56),Vector2(20,-60),Vector2(18,-41),Vector2(15,-43),Vector2(24,-39)]:
		if path_distance(p)>1.8: add_fruit_tree(orchard,p.x,p.y,rng.randf_range(0.75,1.05))

func add_frame_tree(parent: Node, x: float,z: float,scale_value: float, broadleaf: bool) -> void:
	var pos:=ground(x,z)
	if broadleaf:
		tree(parent,pos,scale_value,false)
		collision_box(obstacle_root,"EastFrameBroadleafTrunk",pos+Vector3(0,1.40*scale_value,0),Vector3(0.40,2.8,0.40)*scale_value)
	else:
		conifer(parent,pos,scale_value,false)

func make_forest_frame() -> void:
	var forest:=group(east_root,"EastForestFrame")
	var top_positions: Array[Vector2]=[]
	for x in range(-24,25,3):
		top_positions.append(Vector2(x+rng.randf_range(-0.7,0.7),rng.randf_range(-80,-75)))
	for p in top_positions: add_frame_tree(forest,p.x,p.y,rng.randf_range(0.82,1.12),rng.randf()>0.36)
	for z in range(-73,-32,4):
		add_frame_tree(forest,rng.randf_range(22.0,25.0),z,rng.randf_range(0.84,1.12),rng.randf()>0.30)
	for p in [Vector2(-23,-72),Vector2(-20,-68),Vector2(-17,-63),Vector2(-19,-57),Vector2(-23,-52),Vector2(-22,-47),Vector2(-21,-39),Vector2(7,-77),Vector2(-12,-80)]:
		add_frame_tree(forest,p.x,p.y,rng.randf_range(0.78,1.06),rng.randf()>0.40)
	# One old tree sends roots toward the spring, echoing the reference's giant root system.
	var old_pos:=ground(19.0,-66.0)
	tree(forest,old_pos,1.28,true)
	var old_tree: Node3D=forest.get_child(forest.get_child_count()-1)
	for i in range(7):
		var a:=i*TAU/7.0+rng.randf_range(-0.20,0.20)
		var end:=Vector3(cos(a)*rng.randf_range(2.0,3.8),0.08,sin(a)*rng.randf_range(1.5,3.4))
		tapered_root(old_tree,"GiantSpringTreeRoot",[Vector3(cos(a)*0.28,1.2,sin(a)*0.25),Vector3(cos(a)*0.9,0.34,sin(a)*0.8),end*0.72,end],0.18,"766449")

func make_ground_ecology() -> void:
	var details:=group(east_root,"EastGroundEcology")
	var grass:=group(details,"EastTallGrass")
	var stones:=group(details,"EastScatteredStone")
	var shrubs:=group(details,"EastLowShrubClusters")
	for i in range(430):
		var p:=Vector2(rng.randf_range(-24,24),rng.randf_range(-79,-33))
		if path_distance(p)<1.2 or p.distance_to(Vector2(15.2,-59.5))<3.2 or p.distance_to(Vector2(17.4,-46.0))<3.3 or p.distance_to(Vector2(-2.4,-67))<4.5:continue
		if i%3==0: tuft(grass,ground(p.x,p.y),i%7==0,p.x<0)
		else:
			var stone:=ball(stones,"HalfBuriedEastStone",ground(p.x,p.y)+Vector3(0,0.06,0),Vector3(rng.randf_range(0.12,0.33),rng.randf_range(0.07,0.15),rng.randf_range(0.13,0.30)),["858b7b","929486","727c70"][i%3])
			stone.rotation.y=rng.randf()*TAU
	for i in range(95):
		var p:=Vector2(rng.randf_range(-23,23),rng.randf_range(-78,-34))
		if path_distance(p)<2.0:continue
		var clump:=group(shrubs,"MossyEastShrub",ground(p.x,p.y))
		for j in range(3+rng.randi_range(0,2)):
			var a:=rng.randf()*TAU
			ball(clump,"RoundedEastLeaf",Vector3(cos(a)*rng.randf_range(0.12,0.45),rng.randf_range(0.24,0.43),sin(a)*rng.randf_range(0.12,0.45)),Vector3(0.34,0.26,0.31),["566a4b","66774e","788259","4e634a"][rng.randi_range(0,3)])
	for p in [Vector2(-11,-45),Vector2(-3,-43),Vector2(5,-40),Vector2(9,-35),Vector2(20,-36)]:
		var patch:=group(details,"MottledSoilPocket",ground(p.x,p.y))
		soft_patch(patch,"SmallNaturalColorShift",Vector2(1.2,0.75),["8f9675","9d9877","7f8b6d"][int(absf(p.x))%3])
