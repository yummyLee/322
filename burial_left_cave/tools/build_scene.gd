extends "res://village/tools/build_village.gd"
## Clean authoring source for the 乱葬岭左山洞 v4 rebuild.

const CAVE_OUTPUT := "res://burial_left_cave/world.tscn"
const ROCK := "5a605a"
const ROCK_DARK := "353d3d"
const ROCK_LIGHT := "899085"
const FLOOR := "6b6654"
const SOIL := "5e5142"
const WATER := "275461"
const WATER_EDGE := "a5ad99"
const WOOD := "6f5439"
const BONE := "c2b998"

var cave_terrain: Node3D
var architecture_root: Node3D
var water_root: Node3D
var life_root: Node3D
var mine_root: Node3D
var entry_root: Node3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--bake" in args or (FileAccess.file_exists(CAVE_OUTPUT) and not "--overwrite" in args):
		push_error("Authoring requires -- --bake --overwrite")
		quit(1)
		return
	shader = load("res://village/style.gdshader")
	rng.seed = 190919
	scene_root = Node3D.new()
	scene_root.name = "BurialLeftCave"
	scene_root.set_meta("reference_image", "E:/GameDev/openworldtest/resources/map/architecture乱葬岭左山洞/乱葬岭左山洞.png")
	scene_root.set_meta("description_document", "docs/scenes/乱葬岭左山洞场景描述.md")
	scene_root.set_meta("scene_id", "northern_root_cave_v4")
	scene_root.set_meta("layout_revision", 4)
	scene_root.set_meta("layout_scale", 1.0)
	cave_terrain = group(scene_root, "CaveTerrain")
	group(scene_root, "CaveRockShell")
	architecture_root = group(scene_root, "CaveArchitecture")
	water_root = group(scene_root, "WaterfallsAndPools")
	life_root = group(scene_root, "CaveLifeAndRemains")
	mine_root = group(scene_root, "MineWorks")
	group(scene_root, "LowerStalactitePools")
	build_layout()
	build_details()
	build_entry()
	build_lighting()
	var err := save_scene(CAVE_OUTPUT)
	scene_root.free()
	quit(err)

func add_collision(parent: Node, label: String, pos: Vector3, size: Vector3) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	node.name = label
	var shape := BoxShape3D.new()
	shape.size = size
	node.shape = shape
	node.position = pos
	parent.add_child(node, true)
	node.owner = scene_root
	return node

func floor_mesh(parent: Node, label: String, points: Array, color := FLOOR, y := 0.0, depth := 1.0, collision_parent: Node = null) -> void:
	var vertices := PackedVector3Array()
	for p in points:
		vertices.append(Vector3(p.x, y, p.y))
	var indices := PackedInt32Array()
	for i in range(1, points.size() - 1):
		indices.append_array(PackedInt32Array([0, i, i + 1]))
	solid(parent, label + "Floor", vertices, indices, color, Vector3.UP)
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var mid := (a + b) * 0.5
		var d := b - a
		var length := d.length()
		var wall := box(parent, "WallBand_%02d" % i, Vector3(mid.x, y - depth * 0.42, mid.y), Vector3(length + 0.16, depth, 0.38), ROCK_DARK if i % 2 else ROCK)
		wall.rotation.y = -atan2(d.y, d.x)
		var cap := box(parent, "WallCap_%02d" % i, Vector3(mid.x, y + 0.12, mid.y), Vector3(length + 0.12, 0.22, 0.52), ROCK_LIGHT if i % 3 == 0 else ROCK)
		cap.rotation.y = wall.rotation.y
		for j in range(2):
			var t := (float(j) + 0.35) / 2.0
			var p := a.lerp(b, t)
			ball(parent, "RimStone", Vector3(p.x, y + 0.2 + 0.12 * ((i + j) % 2), p.y), Vector3(0.38, 0.24, 0.3), ROCK_LIGHT)
	if collision_parent != null:
		var body := StaticBody3D.new()
		body.name = label + "WalkCollision"
		collision_parent.add_child(body, true)
		body.owner = scene_root
		var shape := ConcavePolygonShape3D.new()
		var data := PackedVector3Array()
		for i in range(1, points.size() - 1):
			data.append(Vector3(points[0].x, y - 0.02, points[0].y))
			data.append(Vector3(points[i].x, y - 0.02, points[i].y))
			data.append(Vector3(points[i + 1].x, y - 0.02, points[i + 1].y))
		shape.data = data
		var collision := CollisionShape3D.new()
		collision.name = "FloorTriangles"
		collision.shape = shape
		body.add_child(collision, true)
		collision.owner = scene_root

func route(parent: Node, collision_parent: Node, label: String, points: Array[Vector3], width: float, color := SOIL) -> void:
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in range(points.size()):
		var tangent: Vector2
		if i == 0:
			tangent = Vector2(points[1].x - points[0].x, points[1].z - points[0].z).normalized()
		elif i == points.size() - 1:
			tangent = Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).normalized()
		else:
			var before := Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).normalized()
			var after := Vector2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z).normalized()
			tangent = (before + after).normalized()
		var normal := Vector2(-tangent.y, tangent.x) * width * 0.5
		left.append(Vector3(points[i].x + normal.x, 0.025, points[i].z + normal.y))
		right.append(Vector3(points[i].x - normal.x, 0.025, points[i].z - normal.y))
	var verts := PackedVector3Array()
	for p in left: verts.append(p)
	for p in right: verts.append(p)
	var ids := PackedInt32Array()
	for i in range(points.size() - 1):
		ids.append_array(PackedInt32Array([i, i + 1, points.size() + i, i + 1, points.size() + i + 1, points.size() + i]))
	solid(parent, label + "ContinuousFloor", verts, ids, color, Vector3.UP)
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var mid := (a + b) * 0.5
		var segment := add_collision(collision_parent, label + "Walk_%02d" % i, Vector3(mid.x, -0.03, mid.z), Vector3(a.distance_to(b) + width * 0.35, 0.25, width))
		segment.rotation.y = -atan2(b.z - a.z, b.x - a.x)
		for side in [-1.0, 1.0]:
			var d := Vector2(b.x - a.x, b.z - a.z).normalized()
			var n: Vector2 = Vector2(-d.y, d.x) * (width * 0.54) * side
			var bank := box(parent, label + "Bank", Vector3(mid.x + n.x, -0.12, mid.z + n.y), Vector3(a.distance_to(b), 0.3, 0.34), ROCK)
			bank.rotation.y = -atan2(b.z - a.z, b.x - a.x)

func pillar(parent: Node, label: String, pos: Vector3, radius: float, height: float, color := ROCK_LIGHT, inverted := false) -> void:
	var p := group(parent, label, pos)
	for i in range(4):
		var t := float(i) / 3.0
		var r := radius * (0.78 + 0.3 * sin(t * PI)) * (1.0 + rng.randf_range(-0.1, 0.1))
		var y := (height * t if not inverted else height * (1.0 - t))
		cylinder(p, "Ring_%02d" % i, Vector3(0, y, 0), r, height / 4.0 + 0.12, color if i % 2 else ROCK, -1, 7)
	cylinder(p, "Point", Vector3(0, height if not inverted else 0.0, 0), radius * 0.16, radius * 1.8, color, 0.02, 7)

func build_layout() -> void:
	var collisions := StaticBody3D.new()
	collisions.name = "SavedWalkCollisions"
	cave_terrain.add_child(collisions, true)
	collisions.owner = scene_root
	var zones := {
		"J0_EntranceHall": [Vector2(-8,34),Vector2(8,34),Vector2(11,27),Vector2(8,21),Vector2(-6,21),Vector2(-11,27)],
		"J1_MainS_Corridor": [Vector2(-5,22),Vector2(7,22),Vector2(8,12),Vector2(4,5),Vector2(-5,5),Vector2(-8,12)],
		"J8_OldCartYard": [Vector2(-13,7),Vector2(5,6),Vector2(14,1),Vector2(11,-8),Vector2(0,-11),Vector2(-14,-7),Vector2(-18,0)],
		"J2_BoneShelf": [Vector2(14,3),Vector2(28,1),Vector2(32,-7),Vector2(27,-14),Vector2(15,-12),Vector2(11,-5)],
		"J3_WetThroat": [Vector2(-33,5),Vector2(-19,6),Vector2(-15,0),Vector2(-19,-9),Vector2(-31,-11),Vector2(-38,-4)],
		"J4_UpperFissure": [Vector2(10,-14),Vector2(31,-14),Vector2(36,-18),Vector2(31,-22),Vector2(11,-21),Vector2(7,-18)],
		"J9_PillarForest": [Vector2(-39,-13),Vector2(-25,-14),Vector2(-19,-20),Vector2(-23,-30),Vector2(-37,-31),Vector2(-44,-24)],
		"J6_PitWell": [Vector2(-56,-16),Vector2(-47,-14),Vector2(-43,-21),Vector2(-46,-30),Vector2(-56,-31),Vector2(-60,-24)],
		"J11_SuspendedBridge": [Vector2(33,-20),Vector2(46,-20),Vector2(48,-25),Vector2(43,-29),Vector2(32,-28),Vector2(29,-24)],
		"J5_BoneHall": [Vector2(-13,-28),Vector2(5,-28),Vector2(15,-24),Vector2(15,-34),Vector2(1,-38),Vector2(-17,-36),Vector2(-22,-32)],
		"J10_GreyTerraces": [Vector2(-42,-27),Vector2(-27,-27),Vector2(-20,-32),Vector2(-23,-39),Vector2(-39,-40),Vector2(-48,-34)],
		"J7_SealedFissure": [Vector2(-56,-36),Vector2(-49,-36),Vector2(-48,-41),Vector2(-56,-42)],
		"J12_QuarryGallery": [Vector2(13,-33),Vector2(28,-33),Vector2(35,-38),Vector2(31,-44),Vector2(16,-43),Vector2(10,-38)],
		"J13_NameRoom": [Vector2(42,-35),Vector2(56,-35),Vector2(59,-41),Vector2(53,-46),Vector2(42,-44),Vector2(38,-40)]
	}
	var disconnected := group(cave_terrain, "DisconnectedPlatforms")
	for key in zones:
		var room := group(disconnected, key)
		floor_mesh(room, key, zones[key], FLOOR, 0.0, 1.7, collisions)
	var branches := group(cave_terrain, "BranchingStonePaths")
	route(branches, collisions, "SouthToCart", [Vector3(0,0,30),Vector3(3,0,22),Vector3(-3,0,15),Vector3(5,0,7),Vector3(0,0,0)], 5.4)
	route(branches, collisions, "CartToEastHigh", [Vector3(4,0,0),Vector3(15,0,-5),Vector3(25,0,-9),Vector3(18,0,-17),Vector3(31,0,-18),Vector3(39,0,-24)], 4.2, "665b4a")
	route(branches, collisions, "CartToWetRing", [Vector3(-7,0,0),Vector3(-17,0,-3),Vector3(-28,0,-7),Vector3(-32,0,-18),Vector3(-37,0,-26),Vector3(-50,0,-22)], 4.6, "4e5e5c")
	route(branches, collisions, "BoneToGreyQuarry", [Vector3(-5,0,-30),Vector3(-15,0,-34),Vector3(-27,0,-34),Vector3(-38,0,-34),Vector3(-31,0,-39),Vector3(-5,0,-38),Vector3(18,0,-38),Vector3(25,0,-40),Vector3(43,0,-40)], 4.8, "635648")
	route(branches, collisions, "UpperDropToEntrance", [Vector3(15,0,-17),Vector3(9,0,-10),Vector3(5,0,-3),Vector3(2,0,20)], 2.7, "5b5547")
	route(branches, collisions, "QuarryGateToCart", [Vector3(20,0,-38),Vector3(18,0,-28),Vector3(12,0,-17),Vector3(7,0,-8),Vector3(8,0,-2)], 3.1, "5b5144")
	var dividers := group(architecture_root, "ChamberDividers")
	for p in [Vector3(-17,0,-5),Vector3(12,0,-5),Vector3(-21,0,-24),Vector3(17,0,-29),Vector3(36,0,-30)]:
		for j in range(3):
			pillar(dividers, "DividerStone", p + Vector3(j*0.9,0,sin(j)*0.8), 0.32, 1.6 + j*0.25, ROCK)
	group(architecture_root, "ChamberMouths")
	var bounds := StaticBody3D.new()
	bounds.name = "MapBoundaries"
	cave_terrain.add_child(bounds, true)
	bounds.owner = scene_root
	for spec in [[Vector3(0,-1.5,-47),Vector3(128,3,1)], [Vector3(0,-1.5,38),Vector3(128,3,1)], [Vector3(-63,-1.5,-4),Vector3(1,3,86)], [Vector3(63,-1.5,-4),Vector3(1,3,86)]]:
		add_collision(bounds, "Perimeter", spec[0], spec[1])
	add_collision(collisions, "VoidSafetyCatch", Vector3(0,-4.5,-5), Vector3(128,0.4,90))

func build_details() -> void:
	var pillars := group(architecture_root, "FineStonePillars")
	for i in range(22):
		var a := float(i) * 2.399
		var pos := Vector3(-32 + cos(a) * (5.0 + (i % 3) * 1.4), 0, -22 + sin(a) * (5.5 + (i % 4) * 0.9))
		pillar(pillars, "J9_Stalagmite_%02d" % i, pos, 0.28 + (i % 4) * 0.08, 1.4 + (i % 5) * 0.45, ROCK_LIGHT)
	for i in range(8):
		pillar(pillars, "CeilingStalactite_%02d" % i, Vector3(-40 + i*4.1, 5.3, -9 - (i%2)*3), 0.25, 1.2 + (i%3)*0.4, ROCK_DARK, true)
	var wet := group(water_root, "J3_ShallowPools")
	for i in range(7):
		var p := Vector3(-32 + (i%3)*4.2, 0.08, -5 - (i/3)*3.1)
		ball(wet, "Pool", p, Vector3(2.0,0.035,1.2), WATER)
		ball(wet, "CalciteRim", p + Vector3(0,0.05,0), Vector3(2.15,0.08,1.35), WATER_EDGE)
	var terraces := group(water_root, "J10_CalciteTerraces")
	for i in range(4):
		var y := 0.12 + i * 0.32
		box(terraces, "WhiteShelf", Vector3(-34, y, -34 + i*1.9), Vector3(13 - i*1.2, 0.18, 2.2), WATER_EDGE)
		box(terraces, "BluePool", Vector3(-34, y+0.11, -33.3 + i*1.9), Vector3(10 - i*0.8, 0.05, 1.25), WATER)
		box(terraces, "Waterfall", Vector3(-34, y-0.02, -32.2 + i*1.9), Vector3(1.0, 0.45, 0.08), WATER)
	var lower := scene_root.get_node("LowerStalactitePools")
	for i in range(12):
		pillar(lower, "PoolStalagmite_%02d" % i, Vector3(-38 + (i%4)*2.2, 0.05, -31 + (i/4)*2.3), 0.18 + i%3*0.05, 0.7 + i%4*0.25, ROCK)
	var pit := group(water_root, "J6_DeepPit")
	box(pit, "BlackWater", Vector3(-51,-1.7,-23), Vector3(10,0.12,9), "18282c")
	for x in [-55,-52,-49,-46]:
		beam(pit, "RopeFrame", Vector3(x,0,-19), Vector3(x+1.5,2.6,-19), 0.07, WOOD)
	var bones := group(life_root, "BoneBurialFields")
	var orderly := group(bones, "J5_OrderlyRows")
	group(bones, "J5_BoneRackFrames")
	for row in range(4):
		for col in range(5):
			var p := Vector3(-1 + col*2.0, 0.2, -31 + row*1.3)
			beam(orderly, "LongBone", p, p + Vector3(1.1,0.12,0), 0.07, BONE)
			ball(orderly, "Skull", p + Vector3(0.75,0.12,0.25), Vector3(0.2,0.16,0.2), BONE)
	var scattered := group(bones, "J5_ScatteredBones")
	for i in range(30):
		var p := Vector3(-17 + rng.randf_range(0,14), 0.18, -34 + rng.randf_range(-2.2,4.2))
		beam(scattered, "LooseBone", p, p + Vector3(rng.randf_range(-0.8,0.8),0.05,rng.randf_range(-0.4,0.4)), 0.06, BONE)
	var cart := group(mine_root, "J8_OverturnedBodyCart", Vector3(0,0.55,-1))
	box(cart, "BrokenCartBox", Vector3(0,0,0), Vector3(2.6,0.35,1.5), WOOD)
	for x in [-1.15,1.15]:
		var wheel := cylinder(cart, "Wheel", Vector3(x,-0.2,0.7), 0.48, 0.18, "3b332a", -1, 12)
		wheel.rotation.z = PI/2
	beam(cart, "Axle", Vector3(-1.4,-0.2,0.7), Vector3(1.4,-0.2,0.7), 0.08, WOOD)
	var supports := group(mine_root, "J12_TimberSupport")
	for x in [15,19,23,27]:
		box(supports, "Post", Vector3(x,1.5,-39), Vector3(0.22,3.0,0.22), WOOD)
		beam(supports, "Brace", Vector3(x-0.2,2.5,-39), Vector3(x+1.0,0.4,-39), 0.09, WOOD)
	var bridge := group(mine_root, "J11_SuspendedBoneBridge")
	for i in range(9):
		box(bridge, "BridgePlank", Vector3(36+i*1.0,0.15,-24 + sin(i*0.4)*0.35), Vector3(0.9,0.22,2.0), WOOD)
	for side in [-1,1]:
		beam(bridge, "BridgeRail", Vector3(35,1.2,-24 + side*0.8), Vector3(44,1.0,-24 + side*0.8), 0.07, WOOD)
	var entrance_props := group(life_root, "J0_LimeVats")
	for x in [-4.2,0,4.2]:
		cylinder(entrance_props, "CalciteVat", Vector3(x,0.5,27), 0.75, 0.9, "a6a28b", 0.62, 12)
		cylinder(entrance_props, "WhiteCrust", Vector3(x,0.97,27), 0.57, 0.06, WATER_EDGE, 0.45, 12)
	var marker := group(life_root, "J2_BrokenMarkers")
	for i in range(6):
		box(marker, "MarkerStone", Vector3(18+i*1.5,0.32,-7+rng.randf_range(-0.5,0.5)), Vector3(0.55,0.64,0.18), ROCK_LIGHT)
	var names := group(life_root, "J13_NameWallRoom", Vector3(49,0,-40))
	for i in range(7):
		box(names, "NameTablet", Vector3(-4.5+i*1.5,1.0,0), Vector3(0.95,1.35,0.18), "77776b")
	box(names, "EmptyNameTable", Vector3(0,0.55,1.6), Vector3(5.4,0.22,1.2), "806a50")
	var fissure := group(architecture_root, "J7_SealedFissure")
	box(fissure, "BlackCrack", Vector3(-52,-0.1,-39), Vector3(7,0.1,0.35), "171c1c")
	for i in range(6):
		ball(fissure, "CalciteSeal", Vector3(-55+i*1.1,0.16,-38.7), Vector3(0.42,0.24,0.28), WATER_EDGE)

func build_entry() -> void:
	entry_root = group(scene_root, "EntranceTransition")
	var portal := Area3D.new()
	portal.name = "ExitToNorthernRidge"
	portal.collision_layer = 0
	portal.collision_mask = 1
	portal.monitoring = true
	portal.monitorable = false
	portal.set_script(load("res://village/scene_portal.gd"))
	portal.set_meta("target_scene", "res://village/main.tscn")
	portal.set_meta("target_spawn", "root_cave_exit")
	portal.set_meta("door_link_id", "northern_root_cave_door")
	portal.set_meta("destination_id", "northern_ridge")
	entry_root.add_child(portal, true)
	portal.owner = scene_root
	add_collision(portal, "TriggerVolume", Vector3(0,1.0,32), Vector3(4.0,2.0,2.0))
	var enter := Marker3D.new()
	enter.name = "EntrySpawn"
	enter.position = Vector3(0,0.15,30.5)
	enter.set_meta("spawn_id", "root_cave_entry")
	entry_root.add_child(enter, true)
	enter.owner = scene_root
	var exit := Marker3D.new()
	exit.name = "ExitSpawn"
	exit.position = Vector3(0,0.15,30.5)
	exit.set_meta("spawn_id", "root_cave_exit")
	entry_root.add_child(exit, true)
	exit.owner = scene_root
	var sign := Label3D.new()
	sign.name = "CaveName"
	sign.text = "乱葬岭 · 左山洞"
	sign.font_size = 64
	sign.pixel_size = 0.004
	sign.modulate = Color("c3b894")
	sign.position = Vector3(0,3.2,33.0)
	entry_root.add_child(sign, true)
	sign.owner = scene_root

func build_lighting() -> void:
	lighting()
	var rig := scene_root.get_node("RenderRig")
	var env := rig.get_node("VillageEnvironment") as WorldEnvironment
	env.environment.background_color = Color("050708")
	env.environment.ambient_light_color = Color("90a3a3")
	env.environment.ambient_light_energy = 0.34
	var sun := rig.get_node("AfternoonSun") as DirectionalLight3D
	sun.light_energy = 0.42
	sun.light_color = Color("b6c8bd")
	var camera := rig.get_node("VillageCamera") as Camera3D
	camera.size = 92.0
	camera.position = Vector3(0,72,54)
	camera.rotation_degrees = Vector3(-53,0,0)
	camera.far = 240.0
