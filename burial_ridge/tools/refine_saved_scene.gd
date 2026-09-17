extends "build_scene.gd"
## Authoring migration: load and edit saved nodes, never reconstruct the village.
## Refuses repeat execution so editor changes are never silently scaled twice.
var road_root: Node3D

func _initialize() -> void:
	if not "--apply" in OS.get_cmdline_user_args():
		quit(1)
		return
	scene_root = load(OUTPUT).instantiate()
	if scene_root.has_meta("human_scale_roads_revision"):
		push_error("Revision already applied. Edit the saved scene directly.")
		quit(1)
		return
	shader = load("res://village/style.gdshader")
	rng.seed = 917204
	calibrate_scale()
	replace_roads()
	roadside_life()
	scene_root.set_meta("human_scale_roads_revision",1)
	scene_root.set_meta("player_reference_height",1.86)
	var result := save_scene(OUTPUT)
	scene_root.free()
	quit(result)

func resize_obstacle(node: Node3D, factor: Vector3, collision_name: String) -> void:
	node.scale *= factor
	var collision := scene_root.get_node_or_null("SavedWalkCollisions/"+collision_name) as CollisionShape3D
	if collision:
		collision.position = node.position+(collision.position-node.position)*factor
		var shape := collision.shape.duplicate() as BoxShape3D
		shape.size *= factor
		collision.shape = shape

func calibrate_scale() -> void:
	for grave in scene_root.get_node("Graveyard").get_children():
		var label := str(grave.name)
		if label.begins_with("Grave_"):
			resize_obstacle(grave,Vector3.ONE*0.66,label+"_Stone")
		elif label == "TallBoundaryStele":
			resize_obstacle(grave,Vector3.ONE*0.56,label+"_Stone")
		elif label == "RidgeStoneShrine":
			resize_obstacle(grave,Vector3.ONE*0.61,"Shrine")
		elif label == "CollapsedStoneTomb":
			resize_obstacle(grave,Vector3.ONE*0.67,"StoneTomb")
		elif label == "AbandonedHandcart":
			grave.scale *= 0.64
	var homes := scene_root.get_node("ForestHomesteads")
	for pair in [["GraveKeeperCottage","KeeperWalls"],["WoodcutterCottage","WoodcutterWalls"]]:
		var home := homes.get_node(pair[0]) as Node3D
		resize_obstacle(home,Vector3(0.85,1,0.85),pair[1])
		# Keep door height for the human reference; lower only the wall crown/roof.
		home.get_node("Roof").scale.y *= 0.9
		for part in home.get_children():
			if str(part.name).begins_with("TimberPost") or part.name == "PlasterWalls":
				part.scale.y *= 0.9
				part.position.y *= 0.9
			if str(part.name).begins_with("Pot"):
				part.scale *= 0.72
			if part.name == "DryingRack":
				part.scale *= 0.83
	for section in ["BareRidgeTrees","LivingForest"]:
		for plant in scene_root.get_node(section).get_children():
			if str(plant.name).begins_with("DeadTree"):
				resize_obstacle(plant,Vector3.ONE*0.78,str(plant.name)+"_Trunk")
			elif str(plant.name).begins_with("BroadleafTree"):
				resize_obstacle(plant,Vector3.ONE*0.85,str(plant.name)+"_Trunk")
	for rock in scene_root.get_node("BrokenRockTerraces").find_children("*","MeshInstance3D",true,false):
		rock.scale *= Vector3(0.66,0.61,0.66)
		rock.position.y = 0.08+(rock.position.y-0.08)*0.61
	for plant in scene_root.get_node("MeadowAndGroundDetails").get_children():
		if str(plant.name).begins_with("ReedClump"):
			plant.scale *= 0.64
		elif str(plant.name).begins_with("GrassTuft"):
			plant.scale *= 0.72
		elif str(plant.name).begins_with("ScatteredStone"):
			plant.scale *= 0.60
	# The former uniform cemetery mounds are now low irregular earthen humps.
	for grave in scene_root.get_node("Graveyard").get_children():
		var mound := grave.get_node_or_null("SunkenGraveMound") as MeshInstance3D
		if mound:
			mound.scale *= Vector3(0.85,0.75,1.12)
			mound.position.y *= 0.75
	scene_root.get_node("Graveyard/OldWoodenMarkers").free()
	var markers := group(scene_root.get_node("Graveyard"),"WoodenSpiritTablets")
	for pos in [Vector3(-81,0.1,-4),Vector3(-70,0.1,-25),Vector3(-64,0.1,-19)]:
		var tablet := group(markers,"WeatheredWoodTablet",pos)
		tablet.rotation.z = rng.randf_range(-0.14,0.14)
		box(tablet,"TaperedWoodMarker",Vector3(0,0.48,0),Vector3(0.19,0.95,0.065),"756c52")
		box(tablet,"FadedInk",Vector3(0,0.62,0.036),Vector3(0.035,0.28,0.012),"494b3c")

func smooth_route(control: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in range(control.size()-1):
		var a: Vector2 = control[maxi(i-1,0)]
		var b: Vector2 = control[i]
		var c: Vector2 = control[i+1]
		var d: Vector2 = control[mini(i+2,control.size()-1)]
		var count := maxi(2,ceili(b.distance_to(c)/0.48))
		for j in range(count):
			var t := float(j)/count
			result.append(0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
	result.append(control[-1])
	return result

func road_band(parent: Node, label: String, points: Array[Vector2], widths: Array[float], ratio: float, color: String, height: float, shift: float = 0) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(points.size()):
		var direction := (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var normal := Vector2(-direction.y,direction.x)
		var wobble := sin(i*1.43)*0.055+sin(i*0.42)*0.075
		var l := points[i]+normal*(widths[i]*ratio*0.5+wobble+shift)
		var r := points[i]-normal*(widths[i]*ratio*0.5-wobble-shift)
		vertices.append_array(PackedVector3Array([Vector3(l.x,height,l.y),Vector3(r.x,height,r.y)]))
		if i>0:
			var k := i*2
			indices.append_array(PackedInt32Array([k-2,k-1,k,k,k-1,k+1,k,k-1,k-2,k+1,k-1,k]))
	solid(parent,label,vertices,indices,color,Vector3.UP)

func blot(parent: Node, label: String, pos: Vector2, radius: Vector2, color: String, height: float = 0.146) -> void:
	var pts: Array = []
	var turn := rng.randf()*TAU
	for i in range(8):
		var a := turn+i*TAU/8
		var r := rng.randf_range(0.73,1.18)
		pts.append(pos+Vector2(cos(a)*radius.x,sin(a)*radius.y)*r)
	patch(parent,label,pts,color,height)

func detailed_road(label: String, control: Array, width: float, cold: bool, carts: bool = false) -> void:
	var route := group(road_root,label)
	var points := smooth_route(control)
	var widths: Array[float] = []
	for i in range(points.size()):
		widths.append(width*(0.96+sin(i*0.33)*0.065+sin(i*0.91)*0.035))
	var outer: String = "9ea38f" if cold else "a1a17a"
	var shoulder: String = "aaae99" if cold else "b2ad85"
	var earth: String = "b6b8a3" if cold else "c3b78f"
	road_band(route,"TrampledGrassTransition",points,widths,1.42,outer,0.133)
	road_band(route,"CrumbledEarthShoulder",points,widths,1.19,shoulder,0.135)
	road_band(route,"WornEarth",points,widths,0.96,earth,0.137)
	var details := group(route,"RutsPebblesAndVerge")
	for i in range(1,points.size()-1):
		var normal := (points[i+1]-points[i-1]).normalized().orthogonal()
		var tangent := (points[i+1]-points[i-1]).normalized()
		for side in [-1,1]:
			var edge: Vector2 = points[i]+normal*side*widths[i]*rng.randf_range(0.50,0.75)
			blot(details,"FeatheredShoulder",edge,Vector2(rng.randf_range(0.17,0.45),rng.randf_range(0.12,0.32)),outer,0.143)
			if i%3 == 0:
				blot(details,"GrassEncroachment",edge+normal*side*0.2,Vector2(0.32,0.25),"92977b" if cold else "919477",0.149)
				tuft(details,Vector3(edge.x,0.145,edge.y),false,cold)
			if carts and i%9<6:
				var rut: Vector2 = points[i]+normal*side*0.48
				var groove := box(details,"InterruptedCartRut",Vector3(rut.x,0.144,rut.y),Vector3(rng.randf_range(0.22,0.44),0.008,0.055),"afa581")
				groove.rotation.y = -atan2(tangent.y,tangent.x)
		var worn := points[i]+normal*rng.randf_range(-widths[i]*0.34,widths[i]*0.34)
		if i%2 == 0:
			blot(details,"ScuffedFootfall",worn,Vector2(rng.randf_range(0.12,0.28),rng.randf_range(0.08,0.19)),"c0c0aa" if cold else "cec29b",0.146)
		if i%4 == 0:
			blot(details,"DampEarth",worn,Vector2(rng.randf_range(0.10,0.32),rng.randf_range(0.08,0.22)),"a4aa95" if cold else "b4ac89",0.148)
		for j in range(2):
			var pebb := points[i]+normal*rng.randf_range(-widths[i]*0.67,widths[i]*0.67)+tangent*rng.randf_range(-0.2,0.2)
			if rng.randf()<0.55:
				ball(details,"HalfBuriedPebble",Vector3(pebb.x,0.147,pebb.y),Vector3(rng.randf_range(0.035,0.10),0.025,rng.randf_range(0.03,0.07)),"989e8a" if cold else "a2a084")

func replace_roads() -> void:
	var ground := scene_root.get_node("TerrainAndPaths")
	for label in ["VillageLink","CemeteryApproach","BurialFootpath","LowerCottagePath","UpperCottagePath","KeeperCottageYard","WoodcutterYard"]:
		ground.get_node(label).free()
	scene_root.get_node("BrokenCobblestoneCrossing").free()
	road_root = group(ground,"HandWorkedRoads")
	detailed_road("VillageLink",[Vector2(-23,7),Vector2(-29,7),Vector2(-36,5.5),Vector2(-43,1.8),Vector2(-49,-0.3),Vector2(-57,0.5)],2.7,false,true)
	detailed_road("CemeteryApproach",[Vector2(-55,0.6),Vector2(-61,1.5),Vector2(-67,6),Vector2(-72,12),Vector2(-75,21),Vector2(-79,30)],1.8,true)
	detailed_road("BurialFootpath",[Vector2(-61,1.5),Vector2(-65,-5),Vector2(-69,-10),Vector2(-71,-17),Vector2(-71,-25)],1.35,true)
	detailed_road("LowerCottagePath",[Vector2(-47,0),Vector2(-48,-3),Vector2(-49,-6.8)],1.45,false)
	detailed_road("UpperCottagePath",[Vector2(-35,5),Vector2(-34,-2),Vector2(-33,-8),Vector2(-34,-15.8)],1.55,false)
	# Break up yards into overlapping irregular earth patches, with grass gaps.
	for p in [Vector2(-49,-6.6),Vector2(-34,-15.9)]:
		var yard := group(road_root,"CottageForecourt")
		blot(yard,"TrampledApron",p,Vector2(3.45,1.75),"aaa57e",0.136)
		blot(yard,"SweptEarth",p+Vector2(0,-0.1),Vector2(2.85,1.35),"bdb089",0.14)
		for i in range(23):
			var a := rng.randf()*TAU
			var loc: Vector2 = p+Vector2(cos(a)*3.0,sin(a)*1.4)
			blot(yard,"BrokenYardEdge",loc,Vector2(0.33,0.20),["b1aa80","969871","c3b58d"][i%3],0.15)
		for i in range(5):
			ball(yard,"DoorstepFlagstone",Vector3(p.x+sin(i*3.4)*0.09,0.17,p.y-0.75+i*0.32),Vector3(0.29,0.07,0.19),"a8aa90")
	var crossing := group(scene_root,"BrokenCobblestoneCrossing")
	for i in range(54):
		var x := rng.randf_range(-57.8,-50.5)
		var z := 0.3+(x+54)*0.04+rng.randf_range(-0.52,0.52)
		var stone := ball(crossing,"EmbeddedOldPaving",Vector3(x,0.163,z),Vector3(rng.randf_range(0.10,0.23),0.044,rng.randf_range(0.08,0.18)),["a8ac96","9da58f","b9bba3"][i%3])
		stone.rotation.y = rng.randf()*TAU
	# Fine stone-lined runoff outside the keeper's walking route.
	var gutter := group(road_root,"DryRunoffChannel")
	var points := smooth_route([Vector2(-52.4,-6.8),Vector2(-52.5,-4.4),Vector2(-53.1,-2.4),Vector2(-55,-1.7)])
	var widths: Array[float] = []
	for i in points.size():
		widths.append(0.15)
	road_band(gutter,"SiltBed",points,widths,1,"8a8e74",0.14)
	for i in range(0,points.size(),2):
		var p := points[i]
		ball(gutter,"LooseBankStone",Vector3(p.x-0.17,0.17,p.y),Vector3(0.12,0.075,0.16),"9caa91")

func offering(parent: Node, pos: Vector3) -> void:
	var g := group(parent,"HumbleOffering",pos)
	box(g,"RoughOfferingSlab",Vector3(0,0.08,0),Vector3(0.50,0.13,0.30),"969d89")
	cylinder(g,"ClayIncenseCup",Vector3(-0.08,0.19,0),0.095,0.15,"83725a",0.11)
	cylinder(g,"Ash",Vector3(-0.08,0.274,0),0.084,0.012,"575e52")
	for i in range(3):
		beam(g,"IncenseStick",Vector3(-0.11+i*0.032,0.27,0),Vector3(-0.10+i*0.032,0.47,0),0.008,"766d4d")
	cylinder(g,"SmallOfferingDish",Vector3(0.15,0.166,0.01),0.085,0.034,"aaa18a")

func roadside_life() -> void:
	var props := group(scene_root,"AncientRoadsideDetails")
	var marker := group(props,"RidgeWayStone",Vector3(-59.8,0.1,3.0))
	var stone := box(marker,"OldLowWaystone",Vector3(0,0.38,0),Vector3(0.28,0.72,0.18),"8b9685")
	stone.rotation.z = -0.13
	for i in range(3):
		box(marker,"WeatheredCarving",Vector3(0,0.54-i*0.12,0.105),Vector3(0.07,0.027,0.01),"687766")
	for p in [Vector3(-72.0,0.11,-19.1),Vector3(-78.0,0.11,-16.5),Vector3(-67.8,0.11,-2.0)]:
		offering(props,p)
	var bundle := group(props,"FirewoodBundle",Vector3(-47.0,0.15,-6.7))
	for i in range(6):
		beam(bundle,"ShortSplitFirewood",Vector3(-0.30,0.045+(i/3)*0.075,(i%3)*0.10),Vector3(0.35,0.065+(i/3)*0.075,(i%3)*0.10),0.044,"75684c")
	beam(bundle,"HempBinding",Vector3(0,0.05,-0.035),Vector3(0,0.17,0.26),0.018,"a49973")
	var jar := group(props,"BrokenWaterJar",Vector3(-35.9,0.1,-14.4))
	cylinder(jar,"LowerJar",Vector3(0,0.13,0),0.14,0.25,"8b7158",0.22)
	cylinder(jar,"BrokenOpening",Vector3(0,0.26,0),0.18,0.018,"575744")
	for i in range(5):
		var shard := box(jar,"PotteryShard",Vector3(rng.randf_range(-0.4,0.35),0.025,rng.randf_range(0.2,0.5)),Vector3(0.10,0.035,0.075),"9a8163")
		shard.rotation.y = rng.randf()*TAU
	var sticks := group(props,"StormFallenTwigs")
	for p in [Vector3(-44,0.17,0),Vector3(-66.5,0.16,3.8),Vector3(-73,0.16,14),Vector3(-34.7,0.15,-4)]:
		beam(sticks,"DryBranch",p,p+Vector3(0.55,0.03,0.24),0.028,"7c775a")
		beam(sticks,"DryFork",p+Vector3(0.2,0.02,0.09),p+Vector3(0.4,0.02,-0.14),0.018,"858064")
