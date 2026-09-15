extends "res://village/tools/village_parts.gd"
# Optional authoring source. Never runs when playing the game.
const OUTPUT := "res://village/yao_village.tscn"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--bake" in args or (FileAccess.file_exists(OUTPUT) and not "--overwrite" in args):
		push_error("Authoring requires -- --bake; replacing the saved scene additionally requires --overwrite.")
		quit(1)
		return
	shader = load("res://village/style.gdshader")
	rng.seed = 821322
	scene_root = Node3D.new()
	scene_root.name = "YaoVillage"
	terrain()
	architecture()
	landmarks()
	nature()
	lighting()
	var err := save_scene(OUTPUT)
	scene_root.free()
	quit(err)

func terrain() -> void:
	var ground := group(scene_root,"Terrain")
	box(ground,"Earth",Vector3(0,-0.4,0),Vector3(80,0.8,64),"7d7955")
	box(ground,"ForestFloor",Vector3(0,0.015,0),Vector3(80,0.08,64),"8f9c72")
	var boundary := PackedVector3Array([Vector3(-24,0.07,-15),Vector3(-6,0.07,-16),Vector3(7,0.07,-16),Vector3(9,0.07,-8),Vector3(16,0.07,-6),Vector3(25,0.07,-5),Vector3(28,0.07,4),Vector3(26,0.07,10),Vector3(17,0.07,12),Vector3(11,0.07,18.5),Vector3(0,0.07,20),Vector3(-7,0.07,17.5),Vector3(-16,0.07,13),Vector3(-24,0.07,12),Vector3(-25,0.07,5),Vector3(-23,0.07,-2)])
	var ground_vertices := PackedVector3Array([Vector3(0,0.07,0)])
	ground_vertices.append_array(boundary)
	var ground_indices := PackedInt32Array()
	for i in range(boundary.size()):
		var a := i+1
		var b := (i+1)%boundary.size()+1
		ground_indices.append_array(PackedInt32Array([0,a,b,0,b,a]))
	solid(ground,"VillageSoil",ground_vertices,ground_indices,"d5c69b",Vector3.UP)
	# Irregular muted patches keep the paths broad and readable.
	for i in range(180):
		var x := rng.randf_range(-26,26)
		var z := rng.randf_range(-19,19)
		if absf(x)<13 and z>-10 and z<13:
			continue
		ball(ground,"MossPatch",Vector3(x,0.065,z),Vector3(rng.randf_range(0.4,1.5),0.07,rng.randf_range(0.3,1.1)),["919365","959468","a0a073"][i%3])
	var paths := group(ground,"WornPaths")
	for i in range(260):
		var x := rng.randf_range(-24,24)
		var z := rng.randf_range(-17,17)
		box(paths,"SoilFleck",Vector3(x,0.082,z),Vector3(rng.randf_range(0.04,0.22),0.018,rng.randf_range(0.04,0.13)),["ada573","d1bf85","9e9e72"][i%3])
	var stream := group(scene_root,"DrainageChannels")
	var routes := [[Vector3(-25,0,11),Vector3(-15,0,12),Vector3(-14,0,17),Vector3(-7,0,18),Vector3(-3,0,19)], [Vector3(3,0,19),Vector3(11,0,18),Vector3(16,0,13),Vector3(19,0,10),Vector3(27,0,10)]]
	for route in routes:
		for i in range(route.size()-1):
			var a: Vector3 = route[i]
			var b: Vector3 = route[i+1]
			var mid := (a+b)/2
			var bed := box(stream,"StoneBank",mid+Vector3.UP*0.07,Vector3(a.distance_to(b)+0.3,0.14,0.65),"747962")
			bed.rotation.y = -atan2(b.z-a.z,b.x-a.x)
			var water := box(stream,"Water",mid+Vector3.UP*0.15,Vector3(a.distance_to(b)+0.2,0.03,0.32),"748f8c")
			water.rotation.y = bed.rotation.y

func architecture() -> void:
	var buildings := group(scene_root,"Buildings")
	house(buildings,"NorthFarmhouse",Vector3(-1,0,-12),7.5,3.6,2.8,true,"c6bfa0")
	house(buildings,"NorthSideRoom",Vector3(5,0,-12.2),3.0,3.0,2.3,false,"a8a58e")
	stone_wall(buildings,"NorthCourtyardLeft",Vector3(-6.6,0,-7.8),Vector3(-1.7,0,-7.8))
	stone_wall(buildings,"NorthCourtyardRight",Vector3(0.3,0,-7.8),Vector3(7.2,0,-7.8))
	stone_wall(buildings,"NorthCourtyardSide",Vector3(-6.6,0,-7.8),Vector3(-6.6,0,-14.5))
	house(buildings,"ForestHut",Vector3(-19,0,-11),4.1,3.5,2.6,true,"9b9476").rotation.y = -0.23
	var hall := house(buildings,"AncestralHall",Vector3(0,0,-3.7),5.2,3.6,3.4,false,"778b87",true)
	for x in [-1,1]:
		box(hall,"RedDoorCouplet",Vector3(x*0.73,1.4,1.98),Vector3(0.12,2.1,0.035),"985646")
	for i in range(3):
		box(hall,"EntranceStep",Vector3(0,0.12+i*0.12,2.9-i*0.32),Vector3(3.2,0.22,0.72),"939680")
	stone_wall(buildings,"HallLeftWall",Vector3(-6,0,-3),Vector3(-2.7,0,-3),1.6)
	stone_wall(buildings,"HallRightWall",Vector3(2.7,0,-3),Vector3(6,0,-3),1.6)
	for x in [-4.4,4.4]:
		box(buildings,"WallTileCap",Vector3(x,1.68,-3),Vector3(3.4,0.15,0.65),"526667")
	for x in [-1.75,1.75]:
		var lion := group(buildings,"StoneGuardian",Vector3(x,0,0))
		box(lion,"Plinth",Vector3(0,0.23,0),Vector3(0.6,0.46,0.75),"888b78")
		ball(lion,"Body",Vector3(0,0.78,0),Vector3(0.23,0.43,0.27),"9a9c86")
		ball(lion,"Head",Vector3(0,1.17,0.13),Vector3(0.28,0.26,0.28),"aaa991")
	house(buildings,"WestWorkshop",Vector3(-10,0,-4.8),4.5,3.2,2.6,false)
	var wing := house(buildings,"WestWing",Vector3(-14,0,-2.8),4.3,2.8,2.5,false)
	wing.rotation.y = PI/2
	house(buildings,"WestDwelling",Vector3(-11,0,3),5.3,3.0,2.45,false,"a59a79")
	stone_wall(buildings,"WestYardWallLeft",Vector3(-15,0,5.5),Vector3(-11.7,0,5.5))
	stone_wall(buildings,"WestYardWallRight",Vector3(-10,0,5.5),Vector3(-7,0,5.5))
	stone_wall(buildings,"WestYardSide",Vector3(-7,0,5.5),Vector3(-7,0,-5.8))
	var kiln := house(buildings,"KilnWorkshop",Vector3(8.5,0,-3.7),5.4,4,2.8,false,"9e8b63")
	box(kiln,"Chimney",Vector3(-1.65,3.6,-0.5),Vector3(0.6,2.0,0.7),"7c7865")
	box(kiln,"ChimneyCap",Vector3(-1.65,4.6,-0.5),Vector3(0.76,0.2,0.84),"5b6054")
	house(buildings,"TextileShop",Vector3(14,0,1),4.3,3.0,2.5,false,"b1a98e")
	house(buildings,"EastCottage",Vector3(22,0,-0.7),5.3,3.3,2.6,false)
	house(buildings,"EastLonghouse",Vector3(19,0,9),8,3.4,2.5,false,"b09a69")
	house(buildings,"PotteryShed",Vector3(12.3,0,9.2),2.6,3,2.5,true,"b4a071")
	house(buildings,"SouthStorehouse",Vector3(-5.5,0,12.7),3.7,4.4,2.65,true,"aa976b").rotation.y = PI/2
	var wood := group(buildings,"FirewoodShelter",Vector3(-11.6,0,12.3))
	for x in [-1.8,0,1.8]:
		box(wood,"Post",Vector3(x,1.1,0),Vector3(0.15,2.2,0.18),"615137")
	roof(wood,4,2.0,2.2,true)
	for row in range(6):
		for col in range(12):
			var log_node := cylinder(wood,"StackedLog",Vector3(-1.65+col*0.3,0.2+row*0.28,0),0.135,1.65,"8d754b")
			log_node.rotation.x = PI/2
	for x in [19.7,24.3]:
		fence(buildings,Vector3(x,0,1.3),Vector3(x,0,3.0))
	fence(buildings,Vector3(19.7,0,3),Vector3(21.4,0,3))
	fence(buildings,Vector3(22.7,0,3),Vector3(24.3,0,3))

func landmarks() -> void:
	var props := group(scene_root,"VillageLife")
	tree(props,Vector3(0,0,3),0.95)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.04
	ring.rings = 16
	ring.ring_segments = 5
	mesh_node(props,"SquareTreeStoneRing",ring,Vector3(0,0.12,3),"8f9178")
	var well := group(props,"VillageWell",Vector3(-0.8,0,7))
	for layer in range(3):
		for i in range(12):
			var a := (i+layer*0.5)*TAU/12
			var block := box(well,"WellStone",Vector3(cos(a)*0.6,0.14+layer*0.22,sin(a)*0.6),Vector3(0.31,0.2,0.28),"8e8b72" if layer%2==0 else "a3a087")
			block.rotation.y = -a
	cylinder(well,"WellInterior",Vector3(0,0.14,0),0.48,0.03,"303d34",-1,16)
	box(well,"WinchPost",Vector3(1.0,0.9,0),Vector3(0.13,1.8,0.13),"705a39")
	beam(well,"WinchHandle",Vector3(0.7,1.35,0),Vector3(1.35,1.35,0),0.055,"8b7247")
	var mill := group(props,"StoneMill",Vector3(4.5,0,5.8))
	cylinder(mill,"Base",Vector3(0,0.22,0),1.0,0.4,"97947b",-1,16)
	cylinder(mill,"GrindingBed",Vector3(0,0.47,0),0.85,0.16,"b1ac8b",-1,16)
	var wheel := cylinder(mill,"Wheel",Vector3(0,1.0,0),0.65,0.35,"93917c",-1,16)
	wheel.rotation.x = PI/2
	beam(mill,"WoodHandle",Vector3(0,1,0.22),Vector3(1.9,0.7,0.6),0.09,"7b623d")
	var gate := group(props,"VillageEntrance",Vector3(0,0,16.3))
	for x in [-1.65,1.65]:
		box(gate,"StoneFoot",Vector3(x,0.2,0),Vector3(0.9,0.4,0.9),"9a9781")
		box(gate,"StonePillar",Vector3(x,1.95,0),Vector3(0.43,3.6,0.48),"a2a089")
		box(gate,"PillarCap",Vector3(x,3.82,0),Vector3(0.6,0.2,0.64),"b0ac93")
	box(gate,"Lintel",Vector3(0,3.32,0),Vector3(3.5,0.44,0.4),"aaa286")
	box(gate,"PlaqueBacking",Vector3(0,2.92,0),Vector3(2.0,0.6,0.2),"6a6954")
	box(gate,"Plaque",Vector3(0,2.93,0.13),Vector3(1.84,0.45,0.035),"b4a780")
	var text := Label3D.new()
	text.name = "VillageName"
	text.text = "窑 村"
	text.font_size = 80
	text.pixel_size = 0.004
	text.modulate = Color("454936")
	text.outline_size = 0
	gate.add_child(text)
	text.owner = scene_root
	text.position = Vector3(0,2.92,0.16)
	for i in range(4):
		box(gate,"VillageStep",Vector3(0,0.08+i*0.09,2.1-i*0.28),Vector3(3.7,0.16,0.65),"9b9982")
	tree(props,Vector3(6.2,0,15.4),1.0,true)
	for x in [3.9,8.5]:
		box(props,"AncestorStele",Vector3(x,0.8,16),Vector3(0.42,1.6,0.5),"8e927d")
	box(props,"TreeBench",Vector3(6.2,0.42,17),Vector3(2,0.2,0.55),"9b9b80")
	for x in [5.4,7.0]:
		box(props,"BenchLeg",Vector3(x,0.18,17),Vector3(0.23,0.36,0.32),"838872")
	var board := group(props,"NoticeBoard",Vector3(3.1,0,0.8))
	for x in [-0.7,0.7]:
		box(board,"Post",Vector3(x,0.9,0),Vector3(0.1,1.8,0.12),"705b38")
	box(board,"Board",Vector3(0,1.18,0),Vector3(1.6,1.0,0.16),"8b7045")
	for x in [-0.4,0,0.4]:
		box(board,"PaperNotice",Vector3(x,1.2,0.09),Vector3(0.27,0.6,0.012),"d3c79e")
	box(board,"RainCover",Vector3(0,1.8,0),Vector3(1.85,0.12,0.5),"7e6842")
	for pos in [Vector3(7,0,-0.7),Vector3(8,0,0.2),Vector3(10,0,0.5),Vector3(11.4,0,11),Vector3(12.3,0,11),Vector3(-4,0,14),Vector3(-5,0,14),Vector3(-18,0,-8)]:
		pot(props,pos,rng.randf_range(0.25,0.45))
	for i in range(16):
		var coal := ball(props,"KilnCoal",Vector3(9+rng.randf_range(-0.8,0.8),0.12,1.2+rng.randf_range(-0.5,0.5)),Vector3(0.17,0.15,0.16),"41473c")
		coal.rotation.y = rng.randf()*TAU
	var rack := group(props,"TextileDryingRack",Vector3(15,0,3.3))
	for x in [-1.3,1.3]:
		box(rack,"Post",Vector3(x,1.0,0),Vector3(0.09,2.0,0.09),"746141")
	beam(rack,"Crossbar",Vector3(-1.4,1.9,0),Vector3(1.4,1.9,0),0.055,"867048")
	for i in range(7):
		box(rack,"DyedCloth",Vector3(-1.05+i*0.34,1.25,0),Vector3(0.26,1.25,0.035),["a55545","b78b52","6e8891","607a65","918199","9e5f55","bbac72"][i])
	for i in range(24):
		var x := 15.5+i*0.3
		beam(props,"DryingChili",Vector3(x,1.85,10.85),Vector3(x+0.07,1.35+rng.randf()*0.2,10.87),0.035,"963f2d")
	var cart := group(props,"Handcart",Vector3(-6.3,0,5))
	box(cart,"CartBed",Vector3(0,0.5,0),Vector3(1.0,0.15,1.6),"8c7448")
	for x in [-0.6,0.6]:
		var cart_wheel := cylinder(cart,"Wheel",Vector3(x,0.4,0),0.38,0.1,"594e37",-1,12)
		cart_wheel.rotation.z = PI/2
		beam(cart,"Handle",Vector3(x,0.55,0.5),Vector3(x,0.6,2.0),0.05,"8a7046")
	var crops := group(scene_root,"VegetableGardens")
	for origin in [Vector3(-21,0,0),Vector3(-20,0,4),Vector3(-5.6,0,-11.5)]:
		var plot := group(crops,"VegetablePlot",origin)
		box(plot,"GardenSoil",Vector3(0,0.08,0),Vector3(3.6,0.1,2.4),"8e8b56")
		for row in range(4):
			for col in range(7):
				ball(plot,"Cabbage",Vector3(-1.5+col*0.5,0.22,-0.9+row*0.55),Vector3(0.2,0.16,0.2),["6f8748","7f944f","8a9a5a"][(row+col)%3])
	fence(crops,Vector3(-23,0,-2),Vector3(-23,0,6))
	fence(crops,Vector3(-23,0,6),Vector3(-16,0,6))

func nature() -> void:
	var forest := group(scene_root,"ForestBoundary")
	for i in range(16):
		tree(forest,Vector3(-28+i*2.4,0,-21.5+rng.randf_range(-0.5,0.5)),rng.randf_range(1.0,1.5))
	for i in range(10):
		tree(forest,Vector3(-29,0,-13+i*3.3),rng.randf_range(0.9,1.4))
	for i in range(22):
		tree(forest,Vector3(-26+i*2.3,0,-18+rng.randf_range(-1.2,1.2)),rng.randf_range(0.85,1.45))
	for i in range(11):
		tree(forest,Vector3(-26+rng.randf_range(-0.5,1.5),0,-14+i*2.9),rng.randf_range(0.85,1.3))
	for i in range(11):
		tree(forest,Vector3(-25+i*1.6,0,17+rng.randf_range(0,2)),rng.randf_range(0.8,1.3))
	for p in [Vector3(-16,0,-8),Vector3(-16,0,8),Vector3(-8,0,-15),Vector3(24,0,6),Vector3(22,0,15),Vector3(26,0,15)]:
		tree(forest,p,1.0)
	var mountain := group(scene_root,"NortheastCliffs")
	for i in range(14):
		var x := 10+(i%7)*2.7
		var z := -17+(i/7)*3.2
		var rock := ball(mountain,"RockFace",Vector3(x,1.4,z),Vector3(rng.randf_range(2,3.5),rng.randf_range(4,7),rng.randf_range(2,3)),["858779","949789","767f70","a0a294"][i%4])
		rock.rotation.z = rng.randf_range(-0.2,0.2)
	var trail := group(scene_root,"MountainTrail")
	for i in range(15):
		var p := Vector3(14.3+sin(i*0.2)*0.8,0.18+i*0.16,-8-i*0.52)
		box(trail,"TrailStone",p,Vector3(1.0,0.16,0.65),"b4ac86")
	var orchard := group(scene_root,"PersimmonOrchard")
	for i in range(4):
		var p := Vector3(19.5+i*1.8,0,-8.5+rng.randf_range(-0.5,0.5))
		cylinder(orchard,"OrchardTrunk",p+Vector3.UP,0.12,2,"9b9877",0.07)
		for j in range(4):
			var end := p+Vector3(cos(j*1.8)*0.9,2.6,sin(j*1.8)*0.7)
			beam(orchard,"FruitBranch",p+Vector3.UP*1.4,end,0.045,"83795b")
			ball(orchard,"SparseLeaves",end,Vector3(0.48,0.42,0.45),"859458")
			for k in range(3):
				ball(orchard,"Persimmon",end+Vector3(rng.randf_range(-0.4,0.4),-0.35,rng.randf_range(-0.3,0.3)),Vector3.ONE*0.1,"c07b38")
	var details := group(scene_root,"NaturalDetails")
	for i in range(55):
		var x := rng.randf_range(-25,25)
		var z := rng.randf_range(-18,18)
		if absf(x)<14 and absf(z)<12:
			continue
		ball(details,"Boulder",Vector3(x,0.16,z),Vector3(rng.randf_range(0.25,0.7),rng.randf_range(0.2,0.55),rng.randf_range(0.25,0.6)),"989d84")
	ball(details,"GardenBoulder",Vector3(-20,0.45,2),Vector3(1.5,0.6,0.95),"a4a58e")
	for i in range(380):
		var p := Vector3(rng.randf_range(-26,26),0.1,rng.randf_range(-19,19))
		if absf(p.x)<16 and absf(p.z)<14:
			continue
		var tuft := group(details,"GrassTuft",p)
		for j in range(3):
			beam(tuft,"Blade",Vector3(j*0.06,0,0),Vector3(j*0.1-0.08,rng.randf_range(0.18,0.45),0),0.023,"8f965a")

func lighting() -> void:
	var rig := group(scene_root,"RenderRig")
	var env_node := WorldEnvironment.new()
	env_node.name = "VillageEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6b775b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d6dfe5")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	rig.add_child(env_node)
	env_node.owner = scene_root
	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-58,-28,0)
	sun.light_color = Color("fff4df")
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	rig.add_child(sun)
	sun.owner = scene_root
	var camera := Camera3D.new()
	camera.name = "VillageCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 36
	camera.far = 160
	camera.position = Vector3(0,46,43)
	camera.rotation_degrees = Vector3(-47,0,0)
	camera.current = true
	rig.add_child(camera)
	camera.owner = scene_root
	var quad := MeshInstance3D.new()
	quad.name = "PixelOutline"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2,2)
	quad.mesh = mesh
	quad.extra_cull_margin = 16384
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var post := ShaderMaterial.new()
	post.shader = load("res://pixel_lab/outline.gdshader")
	quad.material_override = post
	quad.visible = false
	camera.add_child(quad)
	quad.owner = scene_root
	quad.position.z = -1






