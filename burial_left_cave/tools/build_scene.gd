extends "scene_parts.gd"
const OUTPUT := "res://burial_left_cave/world.tscn"
const ROCK_PALETTE := ["25343d","30414a","3a4b52","46545a","526066"]

func _initialize() -> void:
	var args := OS.get_cmdline_args()
	if FileAccess.file_exists(OUTPUT) and not "--overwrite" in args:
		push_error("Saved editable cave exists. Remove it only for authoring revisions or pass --overwrite.")
		quit(1)
		return
	shader = load("res://burial_left_cave/style.gdshader")
	rng.seed = 19091926
	scene_root = Node3D.new()
	scene_root.name = "World"
	build_layout()
	lighting()
	var rig := scene_root.get_node("RenderRig")
	var env := rig.get_node("VillageEnvironment") as WorldEnvironment
	env.environment.background_color = Color("06090d")
	env.environment.ambient_light_energy = 0.72
	env.environment.ambient_light_color = Color("95a7b1")
	var sun := rig.get_node("AfternoonSun") as DirectionalLight3D
	sun.light_energy = 0.72
	sun.light_color = Color("b9c9d0")
	var camera := rig.get_node("VillageCamera") as Camera3D
	camera.size = 62
	camera.position = Vector3(0,52,46)
	camera.far = 180
	var err := save_scene(OUTPUT)
	scene_root.free()
	quit(err)

func patch(parent: Node, label: String, points: Array, y: float, color: String) -> Node3D:
	var g := group(parent,label)
	var center := Vector3.ZERO
	for p in points:
		center += p
	center /= points.size()
	var verts := PackedVector3Array([Vector3(center.x,y,center.z)])
	for p in points:
		verts.append(Vector3(p.x,y,p.z))
	var indices := PackedInt32Array()
	for i in range(points.size()):
		var j := (i + 1) % points.size()
		indices.append(0); indices.append(i + 1); indices.append(j + 1)
	solid(g,"Floor",verts,indices,color,Vector3.UP)
	return g

func rock(parent: Node, label: String, p: Vector3, s: Vector3, color := "") -> void:
	var c: String = color if color != "" else ROCK_PALETTE[rng.randi_range(0,ROCK_PALETTE.size()-1)]
	var n := ball(parent,label,p,s,c)
	n.rotation = Vector3(rng.randf_range(-0.18,0.18),rng.randf_range(0,TAU),rng.randf_range(-0.18,0.18))

func rim(parent: Node, points: Array, y: float, height: float, density: int = 2) -> void:
	for i in range(points.size()):
		var p: Vector3 = points[i]
		var next: Vector3 = points[(i+1)%points.size()]
		var edge := next-p
		var steps := maxi(1,int(edge.length()*density))
		for k in range(steps):
			var q := p.lerp(next,(k+0.35)/float(steps))
			var size := Vector3(rng.randf_range(0.35,0.8),rng.randf_range(height*0.45,height),rng.randf_range(0.35,0.8))
			rock(parent,"RimRock",Vector3(q.x,y+size.y*0.38,q.z),size)

func stalagmite(parent: Node, label: String, p: Vector3, h: float, r: float, color := "46545a") -> void:
	var s := cylinder(parent,label,Vector3(p.x,p.y+h/2,p.z),r,h,color,0.06,7)
	s.rotation.z = rng.randf_range(-0.16,0.16); s.rotation.x = rng.randf_range(-0.10,0.10)
	rock(parent,"BrokenTip",Vector3(p.x,p.y+h+0.04,p.z),Vector3(r*0.42,0.16,r*0.42),color)

func stalactite(parent: Node, label: String, p: Vector3, h: float, r: float, color := "33434b") -> void:
	var s := cylinder(parent,label,Vector3(p.x,p.y-h/2,p.z),r,h,color,0.05,7)
	s.rotation.z = rng.randf_range(-0.12,0.12); s.rotation.x = rng.randf_range(-0.08,0.08)

func torch(parent: Node, label: String, p: Vector3, warm := true) -> void:
	var t := group(parent,label,p)
	beam(t,"IronStake",Vector3(0,0.15,0),Vector3(0,1.18,0),0.07,"3b3026")
	box(t,"Brazier",Vector3(0,1.18,0),Vector3(0.32,0.13,0.32),"725039")
	ball(t,"Ember",Vector3(0,1.31,0),Vector3(0.16,0.20,0.16),"d98a45")
	var light := OmniLight3D.new()
	light.name = "WarmLight"; light.omni_range = 5.2; light.light_energy = 2.0 if warm else 1.2
	light.light_color = Color("f0a65d") if warm else Color("9bc1d0")
	t.add_child(light,true); light.owner = scene_root; light.position = Vector3(0,1.4,0)

func corridor(parent: Node, label: String, points: Array, width: float, y: float, color := "57534a") -> void:
	var g := group(parent,label)
	for i in range(points.size()-1):
		var a: Vector3 = points[i]; var b: Vector3 = points[i+1]
		var dir := (b-a).normalized(); var side := Vector3(-dir.z,0,dir.x)
		patch(g,"Segment_%02d"%i,[a+side*width*0.5,b+side*width*0.5,b-side*width*0.5,a-side*width*0.5],y+lerpf(a.y,b.y,0.5),color)

func crate(parent: Node, label: String, p: Vector3, scale := Vector3.ONE) -> void:
	var c := group(parent,label,p)
	box(c,"Body",Vector3(0,0.42,0),Vector3(0.9,0.84,0.72)*scale,"624d3b")
	box(c,"BandA",Vector3(0,0.43,-0.38),Vector3(0.98,0.08,0.05)*scale,"9b7b50")
	box(c,"BandB",Vector3(0,0.43,0.38),Vector3(0.98,0.08,0.05)*scale,"9b7b50")
	c.rotation.y = rng.randf_range(-0.35,0.35)

func cart(parent: Node, p: Vector3) -> void:
	var c := group(parent,"OverturnedCorpseCart",p)
	box(c,"Bed",Vector3(0,0.62,0),Vector3(2.2,0.22,1.15),"5a4938")
	box(c,"SideRail",Vector3(0,1.02,-0.54),Vector3(2.1,0.62,0.10),"6e5740")
	box(c,"SideRail2",Vector3(0,1.02,0.54),Vector3(2.1,0.62,0.10),"6e5740")
	beam(c,"Axle",Vector3(-1.05,0.34,0),Vector3(1.05,0.34,0),0.10,"46392e")
	for x in [-1.1,1.1]:
		var w := cylinder(c,"WoodWheel",Vector3(x,0.47,0),0.52,0.16,"6b513b",0.52,10)
		w.rotation.z = PI/2
		for a in range(4):
			beam(c,"WheelSpoke",Vector3(x,0.47,0)+Vector3(0,cos(a*PI/2)*0.42,sin(a*PI/2)*0.42),Vector3(x,0.47,0)+Vector3(0,cos(a*PI/2+PI)*0.42,sin(a*PI/2+PI)*0.42),0.035,"a08058")
	c.rotation = Vector3(0.18,0.22,-0.24)

func bone_pile(parent: Node, label: String, p: Vector3, amount: int) -> void:
	var g := group(parent,label,p)
	for i in range(amount):
		var a := rng.randf()*TAU; var r := rng.randf_range(0.15,0.85)
		var q := Vector3(cos(a)*r,0.08+rng.randf_range(0,0.18),sin(a)*r)
		beam(g,"Bone",q,q+Vector3(rng.randf_range(-0.35,0.35),rng.randf_range(0.12,0.28),rng.randf_range(-0.35,0.35)),0.045,"b3aa8f")

func wall_marker(parent: Node, p: Vector3, h := 1.8) -> void:
	var m := group(parent,"NameMarker",p)
	box(m,"StoneSlab",Vector3(0,h/2,0),Vector3(0.42,h,0.22),"7c7b6d")
	box(m,"DarkCarving",Vector3(0,h*0.64,0.12),Vector3(0.23,0.055,0.03),"3c3a35")

func build_layout() -> void:
	var terrain := group(scene_root,"CaveTerrain")
	var rock_shell := group(scene_root,"CaveRockShell")
	var props := group(scene_root,"ExplorationProps")
	var lights := group(scene_root,"Lanterns")

	var j0_points=[Vector3(-6,0,25),Vector3(4,0,27),Vector3(8,0,23),Vector3(6,0,17),Vector3(1,0,14),Vector3(-5,0,16),Vector3(-9,0,21)]
	patch(terrain,"J0_EntranceHall",j0_points,0.0,"625e52"); rim(rock_shell,j0_points,0.0,1.8)
	corridor(terrain,"J1_LowerMainS",[Vector3(0,0,16),Vector3(-2,0,11),Vector3(2,0,6),Vector3(-1,0,1)],5.0,0.0,"57564c")
	var j8_points=[Vector3(-12,0,6),Vector3(-8,0,12),Vector3(3,0,13),Vector3(12,0,8),Vector3(12,0,-2),Vector3(6,0,-7),Vector3(-6,0,-7),Vector3(-13,0,-2)]
	patch(terrain,"J8_OldCartYard",j8_points,0.0,"6c6252"); rim(rock_shell,j8_points,0.0,2.4)
	corridor(terrain,"J0_to_J1",[Vector3(0,0,22),Vector3(0,0,16)],4.5,0.0,"5d5a4e")
	corridor(terrain,"J1_to_J8",[Vector3(-1,0,2),Vector3(-1,0,-2)],5.0,0.0,"57564c")

	var j2_points=[Vector3(12,0,7),Vector3(19,0,8),Vector3(23,0,4),Vector3(22,0,-1),Vector3(17,0,-4),Vector3(12,0,-2)]
	patch(terrain,"J2_BoneSortingLedge",j2_points,1.8,"575650"); rim(rock_shell,j2_points,1.75,1.6)
	corridor(terrain,"J8_to_J2",[Vector3(9,1,4),Vector3(14,1.8,3)],4.0,1.0,"615c50")
	corridor(terrain,"J2_to_J4",[Vector3(18,1.8,-3),Vector3(19,3.0,-8)],3.4,2.4,"4d5050")
	var j4_points=[Vector3(12,0,-9),Vector3(18,0,-10),Vector3(25,0,-8),Vector3(29,0,-11),Vector3(27,0,-15),Vector3(18,0,-16),Vector3(13,0,-13)]
	patch(terrain,"J4_UpperFissureWalk",j4_points,3.8,"454d52"); rim(rock_shell,j4_points,3.75,2.4)
	corridor(terrain,"J4_to_J11",[Vector3(24,3.8,-12),Vector3(28,3.6,-16)],2.8,3.7,"40494e")

	var j11 := group(terrain,"J11_SuspendedBoneBridge")
	beam(j11,"BridgeBeamA",Vector3(25,4.0,-16),Vector3(31,4.0,-18),0.14,"6b513b")
	beam(j11,"BridgeBeamB",Vector3(25,4.18,-16.7),Vector3(31,4.18,-18.7),0.14,"6b513b")
	for i in range(8):
		var t := i/7.0; var p := Vector3(25,4.05,-16).lerp(Vector3(31,4.05,-18),t)
		box(j11,"BridgePlank",p,Vector3(0.72,0.12,2.1),"806447")
		for side in [-1,1]: beam(j11,"RopeRail",p+Vector3(0,0.15,side*0.85),p+Vector3(0,1.05,side*0.70),0.05,"a08a5e")
	corridor(terrain,"J11_to_J5",[Vector3(30,3.8,-18),Vector3(19,2.4,-20)],3.0,3.0,"4e4e4a")
	var j5_points=[Vector3(6,0,-22),Vector3(15,0,-20),Vector3(21,0,-21),Vector3(23,0,-27),Vector3(18,0,-31),Vector3(7,0,-31),Vector3(1,0,-27),Vector3(1,0,-24)]
	patch(terrain,"J5_BoneCairnHall",j5_points,2.4,"5b5449"); rim(rock_shell,j5_points,2.35,2.8)
	var j6_points=[Vector3(-27,0,-12),Vector3(-19,0,-10),Vector3(-15,0,-14),Vector3(-16,0,-21),Vector3(-23,0,-23),Vector3(-29,0,-19)]
	patch(terrain,"J6_SunkenPit",j6_points,-2.2,"3d4b50"); rim(rock_shell,j6_points,-2.1,3.0)
	corridor(terrain,"J6_to_J5_OneWay",[Vector3(-17,-2,-16),Vector3(-10,0,-19),Vector3(1,2.4,-23)],2.8,0.0,"4e4d49")

	var j3_points=[Vector3(-28,0,7),Vector3(-20,0,11),Vector3(-13,0,8),Vector3(-12,0,1),Vector3(-17,0,-4),Vector3(-26,0,-4),Vector3(-32,0,1)]
	patch(terrain,"J3_SeepingThroat",j3_points,-0.8,"2f5b61"); rim(rock_shell,j3_points,-0.65,2.5)
	corridor(terrain,"J8_to_J3",[Vector3(-10,-0.2,4),Vector3(-16,-0.6,4)],3.6,-0.4,"38545a")
	var j9_points=[Vector3(-30,0,-4),Vector3(-25,0,-7),Vector3(-16,0,-7),Vector3(-11,0,-12),Vector3(-15,0,-18),Vector3(-24,0,-18),Vector3(-31,0,-14)]
	patch(terrain,"J9_StonePillarForest",j9_points,-1.4,"3d5055"); rim(rock_shell,j9_points,-1.3,2.8)
	corridor(terrain,"J3_to_J9",[Vector3(-21,-0.8,-3),Vector3(-22,-1.2,-8)],3.5,-1.0,"36545a")
	corridor(terrain,"J9_to_J6",[Vector3(-22,-1.4,-15),Vector3(-23,-2.0,-18)],3.0,-1.6,"35484e")

	var j10_points=[Vector3(-28,0,-22),Vector3(-20,0,-24),Vector3(-12,0,-23),Vector3(-9,0,-27),Vector3(-13,0,-33),Vector3(-22,0,-34),Vector3(-29,0,-30)]
	patch(terrain,"J10_GreyWaterTerraces",j10_points,0.8,"565852"); rim(rock_shell,j10_points,0.75,2.6)
	corridor(terrain,"J5_to_J10",[Vector3(4,2.4,-26),Vector3(-5,1.4,-27),Vector3(-12,0.8,-28)],3.8,1.6,"55564f")
	var j7_points=[Vector3(-33,0,-24),Vector3(-29,0,-24),Vector3(-29,0,-29),Vector3(-34,0,-31)]
	patch(terrain,"J7_SealedWestFissure",j7_points,0.9,"252d32"); rim(rock_shell,j7_points,0.8,3.0)
	var j12_points=[Vector3(21,0,-24),Vector3(28,0,-23),Vector3(34,0,-25),Vector3(36,0,-30),Vector3(31,0,-34),Vector3(22,0,-33),Vector3(18,0,-28)]
	patch(terrain,"J12_CollapseQuarry",j12_points,3.0,"50504c"); rim(rock_shell,j12_points,2.95,2.3)
	corridor(terrain,"J10_to_J12",[Vector3(-9,0.8,-29),Vector3(4,1.7,-30),Vector3(19,3,-29)],3.4,2.0,"4d4e4a")
	var j13_points=[Vector3(35,0,-25),Vector3(42,0,-25),Vector3(45,0,-29),Vector3(43,0,-34),Vector3(36,0,-34),Vector3(33,0,-30)]
	patch(terrain,"J13_NameWallChamber",j13_points,3.0,"494b49"); rim(rock_shell,j13_points,2.95,2.6)
	corridor(terrain,"J12_to_J13",[Vector3(34,3,-29),Vector3(37,3,-29)],2.5,3.0,"474a47")

	var ceiling := group(scene_root,"CeilingFormations")
	for p in [Vector3(-31,5,18),Vector3(-18,6,14),Vector3(10,6,15),Vector3(27,7,6),Vector3(-35,5,-2),Vector3(-34,6,-17),Vector3(-27,6,-34),Vector3(-7,7,-37),Vector3(17,7,-37),Vector3(39,7,-36),Vector3(47,7,-27)]:
		stalactite(ceiling,"CeilingFang",p,rng.randf_range(1.4,3.1),rng.randf_range(0.25,0.55))
	for p in [Vector3(-25,-0.8,4),Vector3(-18,-0.8,7),Vector3(-22,-1.4,-4),Vector3(-17,-1.4,-13),Vector3(-26,-2.2,-17),Vector3(-18,0.8,-28),Vector3(-14,0.8,-31)]:
		stalagmite(rock_shell,"LimestoneSpire",p,rng.randf_range(1.2,2.8),rng.randf_range(0.20,0.45))

	var water := group(scene_root,"WaterFeatures")
	patch(water,"J3_ReflectingPool",[Vector3(-29,-0.15,4),Vector3(-24,-0.15,7),Vector3(-17,-0.15,5),Vector3(-16,-0.15,0),Vector3(-22,-0.15,-2),Vector3(-29,-0.15,0)],-0.22,"2f6570")
	patch(water,"J10_ShallowCascade",[Vector3(-26,0,-27),Vector3(-20,0,-29),Vector3(-13,0,-28),Vector3(-12,0,-32),Vector3(-21,0,-33),Vector3(-27,0,-31)],0.12,"3b6266")
	for p in [Vector3(-25,-0.05,3),Vector3(-20,-0.05,5),Vector3(-18,-0.05,1),Vector3(-21,0,-30),Vector3(-16,0,-31)]:
		rock(water,"WaterWornStone",p,Vector3(0.35,0.22,0.35),"708084")

	var entrance := group(props,"J0_EntranceDetails")
	for x in [-2.2,2.2]: beam(entrance,"DoorPost",Vector3(x,0.1,27.1),Vector3(x,2.7,27.1),0.16,"4e4035")
	beam(entrance,"DoorHeader",Vector3(-2.35,2.65,27.1),Vector3(2.35,2.65,27.1),0.18,"544335")
	for z in [26.2,26.8]: beam(entrance,"DoorBar",Vector3(-2.1,0.5,z),Vector3(2.1,0.5,z),0.07,"8d704b")
	for x in [-3.1,0,3.1]: pot(entrance,Vector3(x,0.05,23.1),0.42)
	rock(entrance,"ColdLightStone",Vector3(0,0.06,27.35),Vector3(2.2,0.04,0.55),"9db7c0")
	torch(lights,"J0_LanternWest",Vector3(-4.6,0.0,23.0),false); torch(lights,"J0_LanternEast",Vector3(4.6,0.0,23.0),false)

	cart(props,Vector3(-1.0,0.0,3.6)); crate(props,"J8_LimePallet",Vector3(4.7,0.0,0.9),Vector3(1.1,1.0,1.0)); crate(props,"J8_BrokenCrate",Vector3(-5.0,0.0,-1.0),Vector3(0.8,0.8,0.8))
	for p in [Vector3(-8,0,7),Vector3(8,0,5),Vector3(0,0,9)]: torch(lights,"J8_WorkLantern",p)
	for p in [Vector3(15,1.8,3),Vector3(19,1.8,1),Vector3(16,1.8,-1)]: bone_pile(props,"J2_ScatteredBones",p,6)
	wall_marker(props,Vector3(21,1.8,0.2),1.2)

	for p in [Vector3(6,2.4,-25),Vector3(10,2.4,-27),Vector3(14,2.4,-24)]: bone_pile(props,"J5_OrderedBoneRack",p,12)
	for p in [Vector3(4,2.4,-29),Vector3(16,2.4,-29),Vector3(18,2.4,-27)]: bone_pile(props,"J5_DisturbedDragPile",p,10)
	for p in [Vector3(5,2.4,-24),Vector3(18,2.4,-25),Vector3(12,2.4,-29)]: wall_marker(props,p,1.1)
	torch(lights,"J5_WarmLantern",Vector3(10,2.4,-22),true); torch(lights,"J5_WarmLantern2",Vector3(19,2.4,-27),true)
	var pit := group(props,"J6_PitEvidence",Vector3(-22,-2.15,-16))
	beam(pit,"RopeFrameA",Vector3(-2,0,-1),Vector3(0,2.4,0),0.10,"66533b"); beam(pit,"RopeFrameB",Vector3(2,0,1),Vector3(0,2.4,0),0.10,"66533b"); beam(pit,"Crossbar",Vector3(-2,2.1,-1),Vector3(2,2.1,1),0.10,"66533b")
	cylinder(pit,"RustBell",Vector3(0,0.4,0),0.16,0.34,"89644a",0.10,8); torch(lights,"J6_BottomLantern",Vector3(-22,-2.1,-16),false)
	for p in [Vector3(27,3.8,-16),Vector3(31,3.8,-18)]: torch(lights,"J11_BridgeLantern",p,true)

	for i in range(3): box(props,"J10_CalcifiedStep",Vector3(-20,0.35+i*0.24,-27.0-i*0.8),Vector3(7.0,0.18,0.55),"a6a18b")
	for p in [Vector3(-14,0.8,-30),Vector3(-23,0.8,-31)]: torch(lights,"J10_WaterLantern",p,false)
	var quarry := group(props,"J12_QuarrySupports")
	for z in [-26.0,-30.5,-33.0]:
		beam(quarry,"OldSupport",Vector3(23,3,z),Vector3(23,5.4,z),0.12,"6b5540"); beam(quarry,"OldCrossbeam",Vector3(22,5.2,z),Vector3(31,5.2,z),0.14,"6b5540")
	crate(props,"J12_ToolCrate",Vector3(27,3,-27),Vector3(0.9,0.9,0.9)); crate(props,"J12_ToolCrate2",Vector3(30,3,-31),Vector3(0.65,0.65,0.65))
	for p in [Vector3(37,3,-27),Vector3(41,3,-31),Vector3(37,3,-32)]: wall_marker(props,p,1.55)
	torch(lights,"J12_WorkLight",Vector3(27,3,-25),true); torch(lights,"J13_QuietLantern",Vector3(39,3,-29),true)
	for i in range(5): box(props,"J13_NameBox",Vector3(36.0+i*1.45,3.35,-32.6),Vector3(1.0,0.55,0.55),"725a43")

	var scale_ref := group(scene_root,"ScaleReference")
	cylinder(scale_ref,"PlayerHeightMarker",Vector3(-7,1.0,22),0.06,2.0,"c6b08a",0.06,6)
