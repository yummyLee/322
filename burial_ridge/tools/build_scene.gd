extends "village_parts.gd"
# One-time authoring only. Never attached to a runtime scene.
const OUTPUT := "res://burial_ridge/world.tscn"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--bake" in args or (FileAccess.file_exists(OUTPUT) and not "--overwrite" in args):
		push_error("Saved editable scene exists. Use --bake, and explicit --overwrite only for authoring revisions.")
		quit(1)
		return
	shader = load("res://village/style.gdshader")
	rng.seed = 917322
	scene_root = Node3D.new()
	scene_root.name = "WesternBurialRidge"
	terrain()
	burial_ground()
	homesteads()
	woodland()
	surface_details()
	collisions()
	var err := save_scene(OUTPUT)
	scene_root.free()
	quit(err)

func patch(parent: Node, label: String, points: Array, color: String, height: float = 0.09) -> void:
	var polygon := PackedVector2Array()
	var vertices := PackedVector3Array()
	for p in points:
		polygon.append(Vector2(p.x,p.y))
		vertices.append(Vector3(p.x,height,p.y))
	var triangulation := Geometry2D.triangulate_polygon(polygon)
	var indices := PackedInt32Array()
	for i in range(0,triangulation.size(),3):
		var a := triangulation[i]
		var b := triangulation[i+1]
		var c := triangulation[i+2]
		indices.append_array(PackedInt32Array([a,b,c,c,b,a]))
	solid(parent,label,vertices,indices,color,Vector3.UP)

func ribbon(parent: Node, label: String, points: Array, width: float, color: String, height: float = 0.12) -> void:
	var edges_a: Array = []
	var edges_b: Array = []
	for i in range(points.size()):
		var prev: Vector2 = points[maxi(i-1,0)]
		var next: Vector2 = points[mini(i+1,points.size()-1)]
		var tangent := (next-prev).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		edges_a.append(points[i]+normal*width*(0.47+rng.randf()*0.08))
		edges_b.push_front(points[i]-normal*width*(0.47+rng.randf()*0.08))
	edges_a.append_array(edges_b)
	patch(parent,label,edges_a,color,height)

func terrain() -> void:
	var g := group(scene_root,"TerrainAndPaths")
	box(g,"WesternEarth",Vector3(-76,-0.41,0),Vector3(74,0.8,86),"7d7955")
	box(g,"WesternForestFloor",Vector3(-76,0.015,0),Vector3(74,0.08,86),"8f9c72")
	patch(g,"OliveWoodlandTransition",[Vector2(-86,-30),Vector2(-27,-30),Vector2(-27,-16),Vector2(-32,-4),Vector2(-29,10),Vector2(-42,18),Vector2(-45,29),Vector2(-86,31)],"919477",0.065)
	patch(g,"ColdBurialSoil",[Vector2(-113,-43),Vector2(-60,-43),Vector2(-60,-22),Vector2(-57,-17),Vector2(-59,-10),Vector2(-58,-4),Vector2(-61,1),Vector2(-60,6),Vector2(-64,12),Vector2(-64,18),Vector2(-71,26),Vector2(-71,43),Vector2(-113,43)],"92968a",0.078)
	patch(g,"GraveyardAsh",[Vector2(-113,-33),Vector2(-68,-33),Vector2(-61,-22),Vector2(-60,-13),Vector2(-63,-7),Vector2(-66,-3),Vector2(-78,-4),Vector2(-113,-2)],"a8ac9d",0.084)
	ribbon(g,"VillageLink",[Vector2(-23,7),Vector2(-29,7),Vector2(-36,5.5),Vector2(-43,1.8),Vector2(-49,-0.3),Vector2(-57,0.5)],4.1,"d5c69b")
	ribbon(g,"CemeteryApproach",[Vector2(-55,0.6),Vector2(-61,1.5),Vector2(-67,6),Vector2(-72,12),Vector2(-75,21),Vector2(-79,30)],3.1,"b8b8a4",0.125)
	ribbon(g,"BurialFootpath",[Vector2(-61,1.5),Vector2(-65,-5),Vector2(-69,-10),Vector2(-71,-17),Vector2(-71,-25)],2.4,"bbbca9",0.126)
	ribbon(g,"LowerCottagePath",[Vector2(-47,0),Vector2(-48,-3),Vector2(-49,-6.5)],2.5,"d5c69b")
	ribbon(g,"UpperCottagePath",[Vector2(-35,5),Vector2(-34,-2),Vector2(-33,-8),Vector2(-34,-15)],2.7,"cbbb90")
	patch(g,"KeeperCottageYard",[Vector2(-54,-11),Vector2(-44,-12),Vector2(-43,-7),Vector2(-46,-3),Vector2(-54,-4)],"cbbb91",0.1)
	patch(g,"WoodcutterYard",[Vector2(-38,-21),Vector2(-30,-21),Vector2(-29,-14),Vector2(-32,-11),Vector2(-39,-14)],"cbbb91",0.1)
	var ledges := group(scene_root,"BrokenRockTerraces")
	for route in [[Vector2(-86,-4),Vector2(-80,-3),Vector2(-75,-2),Vector2(-71,-3)], [Vector2(-66,-25),Vector2(-62,-21),Vector2(-61,-16),Vector2(-60,-12)], [Vector2(-86,4),Vector2(-82,6),Vector2(-79,9)], [Vector2(-64,5),Vector2(-63,11),Vector2(-65,16),Vector2(-70,21)], [Vector2(-87,18),Vector2(-83,20),Vector2(-79,22)]]:
		var terrace := group(ledges,"LayeredOutcrop")
		for i in range(route.size()-1):
			var a: Vector2 = route[i]
			var b: Vector2 = route[i+1]
			var count := int(a.distance_to(b)/1.3)+1
			for j in range(count):
				var p := a.lerp(b,float(j)/count)+Vector2(rng.randf_range(-0.3,0.3),rng.randf_range(-0.4,0.4))
				var r := ball(terrace,"FracturedBase",Vector3(p.x,0.38,p.y),Vector3(rng.randf_range(0.8,1.4),rng.randf_range(0.4,0.75),rng.randf_range(0.8,1.3)),"7c847b")
				r.rotation.y = rng.randf()*TAU
				var cap := ball(terrace,"PaleStoneCap",Vector3(p.x-0.15,rng.randf_range(0.75,1.02),p.y-0.12),Vector3(rng.randf_range(0.7,1.25),0.24,rng.randf_range(0.67,1.0)),["b3b8ab","a4ad9f","bec0af"][j%3])
				cap.rotation.y = rng.randf()*TAU
				if j%3 == 0:
					ball(terrace,"SpalledFragment",Vector3(p.x+0.6,0.23,p.y+0.8),Vector3(0.7,0.3,0.5),"a5ad9f")

func dead_tree(parent: Node, label: String, pos: Vector3, s: float) -> void:
	var t := group(parent,label,pos)
	t.rotation.y = rng.randf()*TAU
	t.scale = Vector3.ONE*s
	var trunk := [Vector3.ZERO,Vector3(0.2,1.4,0),Vector3(-0.12,2.8,0.15),Vector3(0.38,4.0,0.08),Vector3(0.25,5.0,0.22)]
	for i in range(trunk.size()-1):
		beam(t,"TwistedTrunk",trunk[i],trunk[i+1],0.31-i*0.068,"666255")
	for i in range(5):
		var angle := i*2.3
		beam(t,"ExposedRoot",Vector3(0,0.3,0),Vector3(cos(angle)*1.1,0.07,sin(angle)*0.85),0.12,"726d5b")
		var start := Vector3(0,1.4+i*0.48,0)
		var elbow := start+Vector3(cos(angle)*0.85,0.5,sin(angle)*0.7)
		var fork := elbow+Vector3(cos(angle+0.2)*0.7,0.65,sin(angle+0.2)*0.65)
		beam(t,"CrookedBough",start,elbow,0.145,"625e52")
		beam(t,"BareFork",elbow,fork,0.095,"6f695c")
		beam(t,"BrokenTwig",fork,fork+Vector3(-0.12,0.72,0.1),0.044,"5c5b50")
		beam(t,"SideTwig",elbow,elbow+Vector3(cos(angle-0.8)*0.8,0.25,sin(angle-0.8)*0.8),0.055,"716b5e")

func gravestone(parent: Node, label: String, pos: Vector3, h: float, lean: float) -> void:
	var g := group(parent,label,pos)
	g.rotation.y = rng.randf_range(-0.25,0.25)
	ball(g,"SunkenGraveMound",Vector3(0,0.16,0.62),Vector3(0.65,0.22,1.0),"898d79")
	var slab := group(g,"WeatheredStele",Vector3(0,0.05,-0.3))
	slab.rotation.z = lean
	var w := h*0.47
	var profile := [Vector2(-w/2,0),Vector2(w/2,0),Vector2(w/2,h*0.76),Vector2(w*0.3,h*0.97),Vector2(-w*0.13,h),Vector2(-w/2,h*0.82)]
	var verts := PackedVector3Array()
	for z in [-0.15,0.15]:
		for p in profile:
			verts.append(Vector3(p.x,p.y,z))
	var indices := PackedInt32Array()
	for i in range(1,5):
		indices.append_array(PackedInt32Array([0,i+1,i,6,6+i,7+i]))
	for i in range(6):
		var j := (i+1)%6
		indices.append_array(PackedInt32Array([i,j,j+6,i,j+6,i+6]))
	solid(slab,"ChippedStone",verts,indices,["939d93","a1a99c","838f87"][rng.randi_range(0,2)])
	# Shallow abstract erosion marks, not legible invented epitaphs.
	for i in range(7):
		var x := -w*0.19+(i%2)*w*0.26
		var y := h*0.69-(i/2)*h*0.105
		box(slab,"WornInscription",Vector3(x,y,0.155),Vector3(rng.randf_range(0.035,0.10),0.022,0.012),"626f68")
	ball(g,"FootStone",Vector3(0.3,0.1,0.15),Vector3(0.28,0.19,0.22),"a4ac9b")

func burial_ground() -> void:
	var graves := group(scene_root,"Graveyard")
	var locations := [Vector2(-81,-21),Vector2(-76,-22),Vector2(-67,-23),Vector2(-82,-16),Vector2(-78,-17),Vector2(-74,-18),Vector2(-65,-17),Vector2(-80,-12),Vector2(-76,-13),Vector2(-72,-13),Vector2(-63,-12),Vector2(-83,-8),Vector2(-79,-7),Vector2(-75,-8),Vector2(-69,-7),Vector2(-66,-8),Vector2(-77,-4),Vector2(-71,-4),Vector2(-64,-5),Vector2(-84,-23),Vector2(-73,-24),Vector2(-61,-15)]
	for i in range(locations.size()):
		var p: Vector2 = locations[i]
		gravestone(graves,"Grave_%02d" % (i+1),Vector3(p.x,0.1,p.y),rng.randf_range(0.85,1.55),rng.randf_range(-0.15,0.15))
	gravestone(graves,"TallBoundaryStele",Vector3(-68,0.1,-2.5),2.75,-0.12)
	var tomb := group(graves,"CollapsedStoneTomb",Vector3(-80,0.1,-10))
	for row in range(3):
		for j in range(4-row):
			var block := box(tomb,"DisplacedMasonry",Vector3((j-(3-row)/2.0)*0.68,0.2+row*0.38,0),Vector3(0.64,0.34,1.25-row*0.21),["8e9587","a6ad9c","7d877e"][j%3])
			block.rotation.y = rng.randf_range(-0.09,0.09)
	var shrine := group(graves,"RidgeStoneShrine",Vector3(-72,0.1,-20))
	box(shrine,"StonePlinth",Vector3(0,0.19,0),Vector3(2.5,0.38,1.8),"8b9381")
	for side in [-1,1]:
		for row in range(4):
			box(shrine,"StonePier",Vector3(side*0.72,0.52+row*0.32,0),Vector3(0.43,0.29,1.2),"999d88")
	box(shrine,"DarkAlcove",Vector3(0,0.85,-0.4),Vector3(1.1,1.2,0.2),"454d43")
	box(shrine,"Lintel",Vector3(0,1.8,0),Vector3(2.05,0.32,1.45),"a8aa91")
	for i in range(3):
		box(shrine,"CorbelledCap",Vector3(0,2.05+i*0.23,0),Vector3(1.95-i*0.43,0.22,1.5-i*0.24),"8a8f78")
	pot(shrine,Vector3(0,0.38,0.4),0.22)
	var cart := group(graves,"AbandonedHandcart",Vector3(-76,0.15,-20.5))
	cart.rotation.y = -0.32
	for i in range(5):
		box(cart,"BedPlank",Vector3(-0.6+i*0.3,0.6,0),Vector3(0.26,0.12,1.8),"746951")
	for s in [-1,1]:
		box(cart,"CartSide",Vector3(s*0.76,0.91,0),Vector3(0.10,0.52,1.8),"80735a")
		beam(cart,"Shaft",Vector3(s*0.5,0.6,0.5),Vector3(s*0.55,0.18,2.8),0.07,"71664e")
		var wheel := cylinder(cart,"WoodWheel",Vector3(s*0.85,0.48,0.1),0.48,0.14,"514f41",-1,12)
		wheel.rotation.z = PI/2
		for j in range(4):
			var a := j*PI/4
			beam(cart,"WheelSpoke",Vector3(s*0.94,0.48+cos(a)*0.4,0.1+sin(a)*0.4),Vector3(s*0.94,0.48-cos(a)*0.4,0.1-sin(a)*0.4),0.037,"9c8a65")
	var stakes := group(graves,"OldWoodenMarkers")
	for p in [Vector3(-81,0,-4),Vector3(-70,0,-25),Vector3(-64,0,-19)]:
		beam(stakes,"RoughMarker",p,p+Vector3(0.06,1.8,0),0.085,"6e6555")
		beam(stakes,"BrokenCrosspiece",p+Vector3(-0.38,1.28,0),p+Vector3(0.38,1.4,0),0.06,"807563")
	var trees := group(scene_root,"BareRidgeTrees")
	var positions := [Vector2(-85,-22),Vector2(-79,-26),Vector2(-73,-28),Vector2(-64,-26),Vector2(-59,-22),Vector2(-59,-16),Vector2(-63,-4),Vector2(-59,-3),Vector2(-57,-5),Vector2(-84,12)]
	for i in range(positions.size()):
		dead_tree(trees,"DeadTree_%02d" % i,Vector3(positions[i].x,0.1,positions[i].y),rng.randf_range(0.85,1.24))

func homesteads() -> void:
	var homes := group(scene_root,"ForestHomesteads")
	var keeper := house(homes,"GraveKeeperCottage",Vector3(-49,0.1,-9),6.0,4.1,2.6,true,"a7a48a")
	var cutter := house(homes,"WoodcutterCottage",Vector3(-34,0.1,-18),5.0,3.7,2.7,true,"b0ac92")
	for h in [keeper,cutter]:
		var rack := group(h,"DryingRack",Vector3(-3.8,0,2.4))
		for x in [-0.85,0.85]:
			beam(rack,"Tripod",Vector3(x-0.25,0,-0.3),Vector3(x,2.2,0),0.065,"786546")
			beam(rack,"Tripod",Vector3(x+0.23,0,0.3),Vector3(x,2.2,0),0.065,"786546")
		beam(rack,"DryingPole",Vector3(-1.0,2.13,0),Vector3(1,2.13,0),0.065,"94805a")
		for j in range(2):
			box(rack,"HangingHide",Vector3(-0.47+j*0.85,1.49,0.04),Vector3(0.68,1.12,0.055),["b49065","9b7758"][j])
		pot(h,Vector3(3.0,0,2.0),0.43)
		pot(h,Vector3(1.6,0,2.55),0.24)
		for j in range(5):
			beam(h,"StoredFirewood",Vector3(2.5+j*0.08,0.1,2.5),Vector3(2.3+j*0.08,1.35,2.1),0.065,"6d6848")
		for j in range(5):
			box(h,"ExposedStonework",Vector3(-2.35+j*0.95,0.52,2.09 if h == keeper else 1.89),Vector3(0.52,0.25,0.06),"858d7c")
	var details := group(homes,"YardTools")
	var chopping := cylinder(details,"ChoppingStump",Vector3(-38,0.42,-13.5),0.43,0.72,"777253",0.37)
	beam(chopping,"AxeHandle",Vector3(0,0.4,0),Vector3(0.45,1.1,0),0.042,"947a52")
	box(chopping,"AxeHead",Vector3(0.08,0.52,0),Vector3(0.36,0.22,0.08),"6d7770")
	for j in range(4):
		beam(details,"FallenLog",Vector3(-42+j*0.24,0.15,-13),Vector3(-41+j*0.24,0.15,-14.3),0.12,"6e634c")
	var garden := group(homes,"SmallHerbBed",Vector3(-43,0.1,-10))
	for x in range(3):
		for z in range(5):
			ball(garden,"Herbs",Vector3(x*0.35,0.17,z*0.38),Vector3(0.2,0.22,0.18),"74814f")

func woodland() -> void:
	var woods := group(scene_root,"LivingForest")
	for i in range(19):
		var x := -57+i*1.65
		for row in range(2):
			tree(woods,Vector3(x+rng.randf_range(-0.45,0.45),0,-26+row*3.3+rng.randf_range(-0.8,0.8)),rng.randf_range(1.0,1.45))
	for p in [Vector3(-56,0,-13),Vector3(-55,0,-18),Vector3(-43,0,-19),Vector3(-42,0,-15),Vector3(-41,0,-10),Vector3(-40,0,-6),Vector3(-39,0,-3),Vector3(-30,0,-10)]:
		tree(woods,p,rng.randf_range(1.0,1.28))
	for i in range(18):
		var x := -62+i*1.8
		var z := 22.0-5.0*sin(float(i)/17*PI)
		tree(woods,Vector3(x,0,z+rng.randf_range(-1.5,1.5)),rng.randf_range(1.0,1.4))
		if i%2 == 0:
			tree(woods,Vector3(x+0.6,0,z+4),rng.randf_range(1.1,1.5))
	var rocks := group(woods,"ForestBoulders")
	ball(rocks,"SplitBoulder",Vector3(-47,1.0,18),Vector3(1.5,2.8,1.3),"8c9783")
	ball(rocks,"SplitBoulderFoot",Vector3(-45.7,0.5,18.5),Vector3(0.9,1.4,1.0),"a3ac95")
	for p in [Vector3(-55,0.1,11),Vector3(-52,0.1,13),Vector3(-42,0.1,-2)]:
		var root := group(woods,"ExposedStump",p)
		cylinder(root,"Stump",Vector3(0,0.35,0),0.4,0.7,"777052",0.25)
		for j in range(4):
			beam(root,"Root",Vector3(0,0.3,0),Vector3(cos(j*1.6)*1.25,0.08,sin(j*1.6)*1.0),0.12,"80785c")

func tuft(parent: Node, p: Vector3, large: bool, cold: bool) -> void:
	var t := group(parent,"ReedClump" if large else "GrassTuft",p)
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var count := 8 if large else 4
	for j in range(count):
		var a := rng.randf()*TAU
		var height := rng.randf_range(0.75,1.65) if large else rng.randf_range(0.22,0.52)
		var base := Vector3(cos(a)*0.16,0,sin(a)*0.16)
		var bend := Vector3(cos(a)*height*0.32,height*0.65,sin(a)*height*0.32)
		var tip := Vector3(cos(a)*height*0.58,height,sin(a)*height*0.58)
		var across := Vector3(-sin(a),0,cos(a))*(0.075 if large else 0.045)
		var start := verts.size()
		verts.append_array(PackedVector3Array([base-across,base+across,bend+across*0.6,bend-across*0.6,tip]))
		for tri in [[0,1,2],[0,2,3],[3,2,4]]:
			indices.append_array(PackedInt32Array([start+tri[0],start+tri[1],start+tri[2],start+tri[2],start+tri[1],start+tri[0]]))
	solid(t,"BentBlades",verts,indices,(["7e8a7c","8f9989","a8ad91"][rng.randi_range(0,2)] if cold else ["98975f","86884e","afb076"][rng.randi_range(0,2)]))

func surface_details() -> void:
	var g := group(scene_root,"MeadowAndGroundDetails")
	for i in range(440):
		var x := rng.randf_range(-92,-65)
		var z := rng.randf_range(3,29)
		if absf(x-(-67-(z-6)*0.48))<2.1:
			continue
		tuft(g,Vector3(x,0.1,z),true,true)
		if i%2 == 0:
			tuft(g,Vector3(x+0.35,0.1,z+0.25),true,true)
	for i in range(190):
		var p := Vector3(rng.randf_range(-83,-31),0.11,rng.randf_range(-24,23))
		if p.x>-58 and p.z>-3 and p.z<8:
			continue
		if p.distance_to(Vector3(-49,0,-9))<5 or p.distance_to(Vector3(-34,0,-18))<4:
			continue
		tuft(g,p,false,p.x<-59)
	for i in range(75):
		var x := rng.randf_range(-62,-46)
		var z := rng.randf_range(5,15)
		tuft(g,Vector3(x,0.12,z),i%3 == 0,false)
	var paving := group(scene_root,"BrokenCobblestoneCrossing")
	for i in range(95):
		var x := rng.randf_range(-61,-46)
		var z := 0.3+(x+54)*0.08+rng.randf_range(-1.15,1.2)
		ball(paving,"WornPavingStone",Vector3(x,0.17,z),Vector3(rng.randf_range(0.16,0.4),0.08,rng.randf_range(0.14,0.32)),["a5a999","909a8e","bbc0ad"][i%3])
	for i in range(145):
		var p := Vector3(rng.randf_range(-85,-32),0.13,rng.randf_range(-25,26))
		if p.x>-58 and p.z>-2 and p.z<8:
			continue
		ball(g,"ScatteredStone",p,Vector3(rng.randf_range(0.13,0.43),rng.randf_range(0.1,0.25),rng.randf_range(0.1,0.33)),"a5ac98" if p.x<-59 else "9a9f7e")
	var patches := group(g,"WeatheredGroundPatches")
	for i in range(180):
		var p := Vector3(rng.randf_range(-91,-31),0.085,rng.randf_range(-27,26))
		if p.x>-58 and p.z>-3 and p.z<8:
			continue
		if p.distance_to(Vector3(-49,0,-9))<5 or p.distance_to(Vector3(-34,0,-18))<4:
			continue
		var tint: String = (["9ca394","9ca190","899585"][i%3] if p.x<-61 else ["92976f","9c9e74","858b66"][i%3])
		ball(patches,"MossAndAsh",p,Vector3(rng.randf_range(0.4,1.4),0.018,rng.randf_range(0.3,1.0)),tint)
	for i in range(125):
		var x := rng.randf_range(-84,-30)
		var z := rng.randf_range(-25,25)
		box(patches,"SoilFleck",Vector3(x,0.135,z),Vector3(rng.randf_range(0.08,0.24),0.012,rng.randf_range(0.04,0.14)),"939a86")

func collision_box(parent: Node, label: String, pos: Vector3, dimensions: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = label
	var mesh := BoxShape3D.new()
	mesh.size = dimensions
	shape.shape = mesh
	parent.add_child(shape,true)
	shape.owner = scene_root
	shape.position = pos

func collisions() -> void:
	var body := StaticBody3D.new()
	body.name = "SavedWalkCollisions"
	scene_root.add_child(body)
	body.owner = scene_root
	collision_box(body,"Ground",Vector3(-63,-0.13,0),Vector3(48,0.4,64))
	collision_box(body,"WestLimit",Vector3(-87,0,0),Vector3(1,8,64))
	collision_box(body,"NorthLimit",Vector3(-63,0,-32),Vector3(48,8,1))
	collision_box(body,"SouthLimit",Vector3(-63,0,32),Vector3(48,8,1))
	collision_box(body,"KeeperWalls",Vector3(-49,1.4,-9),Vector3(6,2.6,4.1))
	collision_box(body,"WoodcutterWalls",Vector3(-34,1.4,-18),Vector3(5,2.7,3.7))
	collision_box(body,"Shrine",Vector3(-72,1.3,-20),Vector3(2.3,2.5,1.7))
	collision_box(body,"StoneTomb",Vector3(-80,0.6,-10),Vector3(2.8,1.1,1.4))
	for section in ["BareRidgeTrees","LivingForest"]:
		for n in scene_root.get_node(section).get_children():
			if n.name.begins_with("DeadTree") or n.name.begins_with("BroadleafTree"):
				collision_box(body,str(n.name)+"_Trunk",n.position+Vector3.UP*1.2,Vector3(0.52,2.4,0.52)*n.scale)
	for g in scene_root.get_node("Graveyard").get_children():
		if g.name.begins_with("Grave_") or g.name == "TallBoundaryStele":
			collision_box(body,str(g.name)+"_Stone",g.position+Vector3(0,0.65,-0.3),Vector3(0.65,1.3,0.38))
