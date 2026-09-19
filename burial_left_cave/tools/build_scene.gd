extends "res://village/tools/build_village.gd"
## Offline authoring source for the editable 乱葬岭左山洞 interior.
const CAVE_OUTPUT := "res://burial_left_cave/world.tscn"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--bake" in args or (FileAccess.file_exists(CAVE_OUTPUT) and not "--overwrite" in args):
		push_error("Authoring requires -- --bake; replacing the saved cave additionally requires --overwrite.")
		quit(1)
		return
	shader = load("res://village/style.gdshader")
	rng.seed = 190919
	scene_root = Node3D.new()
	scene_root.name = "BurialLeftCave"
	scene_root.set_meta("reference_image", "E:/GameDev/openworldtest/resources/map/architecture乱葬岭左山洞/乱葬岭左山洞.png")
	scene_root.set_meta("player_height_reference", 1.86)
	scene_root.set_meta("scene_id", "northern_root_cave")
	scene_root.set_meta("layout_revision", 2)
	scene_root.set_meta("layout_scale", 2.8)
	make_floor()
	make_walls_and_ceiling()
	make_waterfalls_and_pools()
	make_burial_fields()
	make_mine_works()
	make_lower_pools()
	make_scene_details()
	make_entry_and_exit()
	enlarge_layout()
	make_lighting()
	var err := save_scene(CAVE_OUTPUT)
	scene_root.free()
	quit(err)

func collision_box(parent: Node, label: String, pos: Vector3, dimensions: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	shape.name = label
	var box_shape := BoxShape3D.new()
	box_shape.size = dimensions
	shape.shape = box_shape
	shape.position = pos
	parent.add_child(shape, true)
	shape.owner = scene_root
	return shape

func floor_patch(parent: Node, label: String, points: Array[Vector2], y: float, color: String) -> void:
	var verts := PackedVector3Array()
	for point in points:
		verts.append(Vector3(point.x, y, point.y))
	var ids := PackedInt32Array()
	for i in range(1, points.size() - 1):
		ids.append_array(PackedInt32Array([0, i, i + 1]))
	solid(parent, label, verts, ids, color, Vector3.UP)

func cave_platform(parent: Node, colliders: Node, label: String, points: Array[Vector2], y: float, color: String) -> void:
	var platform := group(parent, label)
	floor_patch(platform, "WalkableTop", points, y, color)
	# Broken lip stones make each island read as a raised ledge over the black void.
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var edge := beam(platform, "BrokenLedge", Vector3(a.x, y - 0.24, a.y), Vector3(b.x, y - 0.24, b.y), 0.16, ["59645a", "70776a", "4d5a53"][i % 3])
		edge.scale.y = 0.72
	var min_x := points[0].x
	var max_x := points[0].x
	var min_z := points[0].y
	var max_z := points[0].y
	for p in points:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.y)
		max_z = maxf(max_z, p.y)
	collision_box(colliders, label + "WalkSurface", Vector3((min_x + max_x) * 0.5, y - 0.25, (min_z + max_z) * 0.5), Vector3(max_x - min_x, 0.5, max_z - min_z))

func cave_walkway(parent: Node, colliders: Node, label: String, points: Array[Vector3], width: float, color: String) -> void:
	var road := group(parent, label)
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var mid := (a + b) * 0.5
		var plank := box(road, "NarrowStonePath", mid, Vector3(width, 0.18, a.distance_to(b) + 0.18), color)
		plank.rotation.y = atan2(b.x - a.x, b.z - a.z)
		collision_box(colliders, label + "Segment%02d" % i, Vector3(mid.x, mid.y - 0.12, mid.z), Vector3(width, 0.42, a.distance_to(b) + 0.18))
		for j in range(2):
			var side := -1.0 if j == 0 else 1.0
			var offset := Vector3(cos(plank.rotation.y), 0, -sin(plank.rotation.y)) * side * width * 0.42
			ball(road, "PathShoulderStone", mid + offset + Vector3(0, -0.03, 0), Vector3(0.18, 0.10, 0.26), "7d8274")

func make_floor() -> void:
	var floor_root := group(scene_root, "CaveTerrain")
	var floor_collision := StaticBody3D.new()
	floor_collision.name = "SavedWalkCollisions"
	floor_root.add_child(floor_collision, true)
	floor_collision.owner = scene_root
	var boundaries := group(floor_root, "MapBoundaries")
	# Invisible perimeter walls keep the player inside the authored cave footprint.
	collision_box(floor_collision, "WestBoundary", Vector3(-16.8, 1.0, -1.5), Vector3(0.8, 7.0, 29.0))
	collision_box(floor_collision, "EastBoundary", Vector3(16.8, 1.0, -1.5), Vector3(0.8, 7.0, 29.0))
	collision_box(floor_collision, "NorthBoundary", Vector3(0, 1.0, -15.6), Vector3(34.0, 7.0, 0.8))
	collision_box(floor_collision, "SouthBoundary", Vector3(0, 1.0, 12.2), Vector3(34.0, 7.0, 0.8))
	# A low catch plane stops an accidental fall into the black void from becoming an endless drop.
	collision_box(floor_collision, "VoidSafetyCatch", Vector3(0, -3.6, -1.5), Vector3(34.0, 0.5, 29.0))
	boundaries.set_meta("purpose", "player_bounds_and_void_safety")
	var platforms := group(floor_root, "DisconnectedPlatforms")
	cave_platform(platforms, floor_collision, "EntryShelf", [Vector2(-1.7, 9.6), Vector2(1.5, 9.6), Vector2(2.0, 7.1), Vector2(1.0, 6.2), Vector2(-1.8, 6.5), Vector2(-2.1, 8.2)], 0.05, "777868")
	cave_platform(platforms, floor_collision, "CentralBurialIsland", [Vector2(-4.3, 1.8), Vector2(-3.0, -2.5), Vector2(-0.7, -3.8), Vector2(3.4, -3.4), Vector2(5.1, -0.8), Vector2(4.0, 2.8), Vector2(0.7, 3.7), Vector2(-2.2, 3.0)], 0.82, "625d4e")
	cave_platform(platforms, floor_collision, "UpperLeftWaterShelf", [Vector2(-11.2, 1.8), Vector2(-10.7, -3.4), Vector2(-8.5, -5.0), Vector2(-5.5, -3.8), Vector2(-4.8, -0.3), Vector2(-6.2, 2.2), Vector2(-8.7, 3.0)], 1.12, "737b70")
	cave_platform(platforms, floor_collision, "LowerLeftPoolIsland", [Vector2(-11.2, 6.5), Vector2(-10.0, 2.9), Vector2(-6.4, 2.3), Vector2(-3.7, 4.1), Vector2(-4.4, 7.8), Vector2(-7.8, 9.0)], -0.62, "58665f")
	cave_platform(platforms, floor_collision, "RightMineShelf", [Vector2(5.4, 1.8), Vector2(6.4, -2.3), Vector2(9.5, -3.1), Vector2(12.0, -1.0), Vector2(11.5, 2.3), Vector2(8.0, 3.0)], 1.00, "737867")
	cave_platform(platforms, floor_collision, "RightTombShelf", [Vector2(6.6, 5.0), Vector2(8.2, 3.1), Vector2(11.6, 3.6), Vector2(12.1, 7.4), Vector2(9.2, 9.3), Vector2(6.9, 8.0)], 0.28, "676c61")
	cave_platform(platforms, floor_collision, "LowerCentralForkIsland", [Vector2(-2.5, 6.1), Vector2(-0.5, 5.5), Vector2(3.2, 6.0), Vector2(4.7, 8.0), Vector2(2.4, 9.5), Vector2(-1.0, 9.2), Vector2(-3.0, 7.8)], -0.28, "656c62")
	cave_platform(platforms, floor_collision, "BackTunnelLedge", [Vector2(-2.1, -6.0), Vector2(-1.7, -9.3), Vector2(1.8, -9.8), Vector2(2.5, -6.5), Vector2(1.2, -4.0), Vector2(-0.9, -4.2)], 1.42, "59645a")
	cave_platform(platforms, floor_collision, "NorthBoneHall", [Vector2(-5.5, -4.4), Vector2(-4.7, -8.1), Vector2(-1.8, -9.1), Vector2(3.8, -8.5), Vector2(5.7, -5.1), Vector2(3.4, -3.5), Vector2(-1.8, -3.6)], 1.55, "6b6555")
	cave_platform(platforms, floor_collision, "WestPillarForest", [Vector2(-13.5, -5.6), Vector2(-12.4, -9.8), Vector2(-9.5, -10.8), Vector2(-7.2, -8.2), Vector2(-7.6, -4.4), Vector2(-10.6, -3.0)], 0.36, "59645d")
	cave_platform(platforms, floor_collision, "WestPitWell", [Vector2(-14.4, -13.2), Vector2(-11.4, -14.4), Vector2(-9.2, -12.3), Vector2(-9.8, -9.6), Vector2(-12.6, -9.5), Vector2(-14.7, -11.0)], -0.10, "4f5b56")
	cave_platform(platforms, floor_collision, "EastQuarryGallery", [Vector2(9.3, -8.7), Vector2(12.4, -10.2), Vector2(15.5, -8.7), Vector2(15.8, -5.1), Vector2(13.0, -3.7), Vector2(9.8, -4.8)], 1.42, "5d655d")
	cave_platform(platforms, floor_collision, "NameWallChamber", [Vector2(14.0, -11.6), Vector2(16.8, -11.3), Vector2(17.3, -8.5), Vector2(15.3, -7.1), Vector2(13.5, -8.3)], 1.55, "625e53")
	var paths := group(floor_root, "BranchingStonePaths")
	cave_walkway(paths, floor_collision, "EntryToCenter", [Vector3(0, 0.08, 6.9), Vector3(0.0, 0.35, 5.6), Vector3(0.7, 0.58, 4.2), Vector3(0.4, 0.76, 3.1)], 1.25, "7f806e")
	cave_walkway(paths, floor_collision, "CenterToBurial", [Vector3(0.4, 0.76, 2.9), Vector3(0.2, 0.82, 1.8), Vector3(0.0, 0.82, 0.6)], 1.30, "777565")
	cave_walkway(paths, floor_collision, "CenterToWater", [Vector3(-2.8, 0.92, 0.4), Vector3(-4.2, 1.0, -0.2), Vector3(-5.5, 1.08, -1.0)], 1.0, "868979")
	cave_walkway(paths, floor_collision, "CenterToMine", [Vector3(3.3, 0.91, 0.4), Vector3(4.8, 0.94, 0.0), Vector3(6.1, 1.0, -0.2)], 1.10, "828573")
	cave_walkway(paths, floor_collision, "CenterToBackTunnel", [Vector3(0.0, 0.9, -2.4), Vector3(0.1, 1.12, -4.0), Vector3(0.2, 1.35, -6.0)], 1.0, "74796d")
	cave_walkway(paths, floor_collision, "CenterToLowerPools", [Vector3(-1.5, 0.58, 2.7), Vector3(-2.8, 0.25, 3.7), Vector3(-4.1, -0.15, 4.5)], 0.95, "707a70")
	cave_walkway(paths, floor_collision, "MineToTomb", [Vector3(8.2, 0.72, 2.3), Vector3(8.4, 0.48, 3.6), Vector3(8.8, 0.30, 5.0)], 0.95, "7d7d6d")
	cave_walkway(paths, floor_collision, "WindingLowerRoad", [Vector3(5.5, 0.52, 2.7), Vector3(4.7, 0.20, 4.4), Vector3(3.0, -0.08, 6.1), Vector3(1.2, -0.20, 7.1)], 1.35, "858778")
	cave_walkway(paths, floor_collision, "LowerRoadLeftFork", [Vector3(1.2, -0.20, 7.1), Vector3(-0.8, -0.25, 7.8), Vector3(-2.5, -0.42, 7.5)], 1.20, "7a8072")
	cave_walkway(paths, floor_collision, "LowerRoadRightFork", [Vector3(1.2, -0.20, 7.1), Vector3(4.2, -0.10, 7.7), Vector3(7.0, 0.12, 7.7)], 1.20, "7c8174")
	cave_walkway(paths, floor_collision, "CenterToPillarForest", [Vector3(-3.7, 0.86, -0.8), Vector3(-5.8, 0.56, -2.6), Vector3(-7.6, 0.42, -4.7)], 1.10, "6e796f")
	cave_walkway(paths, floor_collision, "PillarForestToPitWell", [Vector3(-9.7, 0.34, -6.2), Vector3(-11.4, 0.08, -8.7), Vector3(-12.1, -0.04, -10.0)], 0.95, "68736d")
	cave_walkway(paths, floor_collision, "PitWellToBoneHall", [Vector3(-11.8, 0.02, -9.5), Vector3(-8.8, 0.54, -7.5), Vector3(-5.0, 1.25, -6.0)], 1.0, "777a6e")
	cave_walkway(paths, floor_collision, "BoneHallToQuarry", [Vector3(3.2, 1.48, -6.0), Vector3(6.5, 1.40, -5.1), Vector3(9.4, 1.38, -6.3)], 1.05, "77796b")
	cave_walkway(paths, floor_collision, "QuarryToNameWall", [Vector3(12.5, 1.45, -7.2), Vector3(14.2, 1.52, -9.0), Vector3(15.2, 1.55, -10.0)], 0.90, "6f7165")
	var grit := group(floor_root, "ScatteredCaveGrit")
	for i in range(65):
		var p := Vector3(rng.randf_range(-10.5, 10.5), rng.randf_range(-0.35, 1.1), rng.randf_range(-8.5, 8.2))
		var flake := ball(grit, "HalfBuriedShale", p, Vector3(rng.randf_range(0.06, 0.22), rng.randf_range(0.025, 0.07), rng.randf_range(0.05, 0.18)), ["818378", "969886", "6b7167"][i % 3])
		flake.rotation.y = rng.randf() * TAU

func make_walls_and_ceiling() -> void:
	var rock_root := group(scene_root, "CaveRockShell")
	# Back wall and side shelves keep the cave readable without blocking the orthographic view.
	for x in range(-12, 13, 2):
		var back := ball(rock_root, "BackWallRock", Vector3(x + rng.randf_range(-0.3, 0.3), 2.3 + rng.randf_range(-0.25, 0.35), -10.2 + rng.randf_range(-0.3, 0.3)), Vector3(rng.randf_range(1.0, 1.65), rng.randf_range(1.6, 3.2), rng.randf_range(0.8, 1.4)), ["58645b", "677064", "4c5953"][x % 3])
		back.rotation.z = rng.randf_range(-0.12, 0.12)
	for side in [-1, 1]:
		for i in range(8):
			var z := 7.5 - i * 2.4
			var wall := ball(rock_root, "SideCaveRock", Vector3(side * (12.2 + rng.randf_range(-0.4, 0.4)), 1.5 + rng.randf_range(0.0, 1.4), z), Vector3(rng.randf_range(1.0, 1.8), rng.randf_range(1.5, 3.4), rng.randf_range(1.0, 1.8)), ["5c675e", "6b7466", "4e5b53"][i % 3])
			wall.rotation.z = side * rng.randf_range(-0.12, 0.14)
	var ceiling := group(rock_root, "LowCeilingFragments")
	for p in [Vector3(-8, 5.0, -7.8), Vector3(-2, 5.4, -9.0), Vector3(4, 5.2, -8.0), Vector3(9, 4.7, -6.8), Vector3(-10, 4.5, -3.0), Vector3(11, 4.6, 1.0)]:
		ball(ceiling, "CeilingRockMass", p, Vector3(3.4, 0.8, 2.0), "3f4945")
	# Stalactites / stalagmites form broken silhouettes and leave the main path open.
	var spikes := group(rock_root, "StalactiteAndStalagmiteField")
	for i in range(28):
		var p := Vector2(rng.randf_range(-11, 11), rng.randf_range(-9.3, 7.8))
		if absf(p.x) < 3.0 and p.y > -7.0: continue
		var h := rng.randf_range(0.55, 1.8)
		cylinder(spikes, "Stalagmite", Vector3(p.x, h * 0.5, p.y), rng.randf_range(0.12, 0.32), h, ["768073", "879083", "657168"][i % 3], rng.randf_range(0.04, 0.12), 7)
		if i % 2 == 0:
			var top_h := rng.randf_range(0.7, 1.5)
			cylinder(spikes, "Stalactite", Vector3(p.x + 0.18, 4.6 - top_h * 0.5, p.y + 0.12), rng.randf_range(0.04, 0.11), top_h, "515d56", rng.randf_range(0.18, 0.28), 7)
	# A dark back aperture suggests a deeper tunnel.
	box(rock_root, "DeepTunnelMouth", Vector3(0, 2.0, -10.0), Vector3(3.8, 3.7, 0.22), "202823")
	collision_box(scene_root.get_node("CaveTerrain/SavedWalkCollisions"), "BackWall", Vector3(0, 2.0, -10.4), Vector3(25, 4.0, 0.7))

func make_waterfalls_and_pools() -> void:
	var water_root := group(scene_root, "WaterfallsAndPools", Vector3(0, 0.92, 0))
	var falls := group(water_root, "TieredWaterfall")
	for i in range(4):
		var x := -9.6 + i * 0.85
		var z := 4.5 - i * 1.15
		box(falls, "LimestoneWaterStep", Vector3(x, 0.38 + i * 0.34, z), Vector3(2.6, 0.34, 2.0), ["8b9180", "9ca08d", "767d70"][i % 3])
		box(falls, "BlueGreenWaterTier", Vector3(x, 0.59 + i * 0.34, z + 0.24), Vector3(1.9, 0.045, 1.42), "3b6062")
		box(falls, "WaterfallRibbon", Vector3(x + 0.05, 0.34 + i * 0.34, z - 0.72), Vector3(0.56, 0.58, 0.12), "507477")
	for j in range(4):
		var pool := box(water_root, "ColdPool", Vector3(-8.4 + j * 1.15, 0.10, 0.7 - j * 0.72), Vector3(3.4 - j * 0.24, 0.06, 2.2 - j * 0.12), "31565b")
		pool.rotation.y = -0.08 + j * 0.04
	var glow := OmniLight3D.new()
	glow.name = "WaterfallColdGlow"
	glow.position = Vector3(-8.3, 2.1, 1.5)
	glow.light_color = Color("6fabb0")
	glow.light_energy = 1.6
	glow.omni_range = 7.0
	water_root.add_child(glow, true)
	glow.owner = scene_root

func add_bone(parent: Node, pos: Vector3, angle: float, length: float, color: String = "c4c0a5") -> void:
	var a := pos + Vector3(cos(angle), 0.015, sin(angle)) * length * 0.5
	var b := pos - Vector3(cos(angle), 0.015, sin(angle)) * length * 0.5
	beam(parent, "ScatteredBone", a, b, 0.045, color)

func add_skull(parent: Node, pos: Vector3, scale_value: float) -> void:
	var skull := group(parent, "SmallSkull", pos)
	ball(skull, "Skull", Vector3(0, 0.12, 0), Vector3(0.18, 0.15, 0.2) * scale_value, "c5c0a4")
	ball(skull, "EyeSocketL", Vector3(-0.07, 0.14, 0.14), Vector3(0.038, 0.035, 0.018) * scale_value, "47453d")
	ball(skull, "EyeSocketR", Vector3(0.07, 0.14, 0.14), Vector3(0.038, 0.035, 0.018) * scale_value, "47453d")

func make_burial_fields() -> void:
	var bones := group(scene_root, "BoneBurialFields")
	for row in range(5):
		for col in range(5):
			var p := Vector3(1.3 + col * 1.55 + rng.randf_range(-0.25, 0.25), 0.89, 1.9 - row * 1.38 + rng.randf_range(-0.22, 0.22))
			add_bone(bones, p, rng.randf_range(0, TAU), rng.randf_range(0.55, 1.2))
			if (row + col) % 2 == 0: add_skull(bones, p + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25)), rng.randf_range(0.8, 1.15))
	for i in range(22):
		var p := Vector3(rng.randf_range(-5.8, 5.8), 0.895, rng.randf_range(-3.8, 3.6))
		add_bone(bones, p, rng.randf_range(0, TAU), rng.randf_range(0.25, 0.85), ["b7b29a", "d0c7a8", "9f9c87"][i % 3])
	for p in [Vector3(-3.9, 0.1, 3.4), Vector3(-6.0, 0.1, 0.4), Vector3(4.4, 0.1, -3.9)]:
		add_skull(bones, p + Vector3(0, 0.02, 0), 1.15)
	var soil := group(bones, "BurialSoilMounds")
	for p in [Vector3(-1.8, 0.10, 3.0), Vector3(3.1, 0.10, 2.5), Vector3(-2.7, 0.10, -1.7), Vector3(1.6, 0.10, -3.5)]:
		ball(soil, "LooseBurialSoil", p + Vector3(0, 0.82, 0), Vector3(1.25, 0.10, 0.72), "514d42")

func make_mine_works() -> void:
	var mine := group(scene_root, "MineWorks", Vector3(0, 0.93, 0))
	var frame := group(mine, "OldTimberSupport", Vector3(8.4, 0, 3.6))
	for x in [-1.45, 1.45]:
		beam(frame, "TimberPost", Vector3(x, 0.15, 0), Vector3(x, 2.75, 0), 0.13, "66533e")
	beam(frame, "TimberHeader", Vector3(-1.6, 2.62, 0), Vector3(1.6, 2.62, 0), 0.15, "755c43")
	beam(frame, "TimberBackBeam", Vector3(-1.45, 1.55, -0.55), Vector3(1.45, 1.55, -0.55), 0.11, "5b4b3a")
	for x in [-1.15, -0.4, 0.4, 1.15]:
		beam(frame, "RoofSlat", Vector3(x, 2.7, -0.65), Vector3(x, 2.7, 0.75), 0.065, ["806548", "715943", "8b6b4e"][int((x + 1.2) * 2) % 3])
	var cart := group(mine, "AbandonedHandcart", Vector3(7.0, 0.12, 0.1))
	box(cart, "CartBed", Vector3(0, 0.35, 0), Vector3(1.3, 0.16, 2.0), "6d543b")
	for x in [-0.62, 0.62]:
		var wheel := cylinder(cart, "CartWheel", Vector3(x, 0.36, 0.25), 0.40, 0.12, "4f4337", -1, 12)
		wheel.rotation.z = PI / 2
	beam(cart, "CartHandle", Vector3(0, 0.45, 0.7), Vector3(0, 0.65, 2.05), 0.065, "805f3f")
	for i in range(12):
		ball(mine, "MineRockPile", Vector3(10.1 + rng.randf_range(-1.1, 1.1), 0.15 + rng.randf_range(0, 0.3), 1.5 + rng.randf_range(-1.0, 1.0)), Vector3(rng.randf_range(0.18, 0.45), rng.randf_range(0.14, 0.38), rng.randf_range(0.18, 0.42)), ["777b70", "929286", "646b62"][i % 3])
	var amber := OmniLight3D.new()
	amber.name = "MineLanternGlow"
	amber.position = Vector3(8.4, 2.0, 3.2)
	amber.light_color = Color("d59b5f")
	amber.light_energy = 1.4
	amber.omni_range = 5.5
	mine.add_child(amber, true)
	amber.owner = scene_root

func make_lower_pools() -> void:
	var lower := group(scene_root, "LowerStalactitePools", Vector3(0, -0.60, 0))
	box(lower, "LowerPoolWater", Vector3(-7.1, 0.075, 5.8), Vector3(5.7, 0.05, 4.3), "294e56")
	for i in range(26):
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.4, 4.4)
		var h := rng.randf_range(0.35, 1.55)
		cylinder(lower, "PoolStalagmite", Vector3(-7.0 + cos(a) * r, h * 0.5, 5.8 + sin(a) * r * 0.55), rng.randf_range(0.08, 0.25), h, ["5d6b63", "758077", "8b8e7e"][i % 3], rng.randf_range(0.025, 0.08), 7)
	for i in range(8):
		var bridge_x := -0.4 + i * 0.28
		var plank := box(lower, "BrokenBridgePlank", Vector3(bridge_x + 4.0, 0.72 + rng.randf_range(-0.06, 0.06), 3.0), Vector3(0.22, 0.12, 2.2), ["795d42", "896948", "66513d"][i % 3])
		plank.rotation.y = rng.randf_range(-0.08, 0.08)
	var pit := box(lower, "DarkRavine", Vector3(5.1, -0.03, 3.0), Vector3(2.5, 0.06, 3.4), "1e2927")
	pit.rotation.y = -0.15

func make_scene_details() -> void:
	var details := group(scene_root, "CaveLifeAndRemains")
	var bone_racks := group(details, "BoneDisplayRacks")
	for x in [-2.8, -1.0, 1.0, 2.8]:
		beam(bone_racks, "RackPost", Vector3(x, 0.92, -1.9), Vector3(x, 2.05, -1.9), 0.07, "66533e")
		beam(bone_racks, "RackCrossbar", Vector3(x - 0.34, 1.60, -1.9), Vector3(x + 0.34, 1.60, -1.9), 0.05, "795d42")
		add_bone(bone_racks, Vector3(x, 1.78, -1.82), PI * 0.5, 0.62, "d0c7a8")
	var hanging := group(details, "HangingRopesAndHooks")
	for i in range(5):
		var x := -9.4 + i * 0.85
		beam(hanging, "WetRope", Vector3(x, 3.0 - (i % 2) * 0.22, -2.8), Vector3(x + 0.12, 1.25, -2.45), 0.035, "51483a")
		cylinder(hanging, "IronHook", Vector3(x + 0.12, 1.18, -2.43), 0.055, 0.22, "4c5149", 0.035, 6)
	var mine_props := group(details, "MineToolsAndCrates")
	for p in [Vector3(7.0, 1.10, -1.2), Vector3(9.1, 1.10, 0.8), Vector3(10.3, 1.10, -1.0)]:
		box(mine_props, "RoughWoodCrate", p, Vector3(0.72, 0.62, 0.72), "76583e")
		beam(mine_props, "CrateBand", p + Vector3(-0.36, 0.04, 0), p + Vector3(0.36, 0.04, 0), 0.035, "9a7950")
	var pickaxe := group(mine_props, "LeaningPickaxe", Vector3(10.3, 1.04, 0.3))
	beam(pickaxe, "Handle", Vector3(0, 0, 0), Vector3(-0.12, 1.25, 0.10), 0.045, "8b6845")
	beam(pickaxe, "IronHead", Vector3(-0.42, 1.25, 0.10), Vector3(0.25, 1.25, 0.10), 0.07, "5d625b")
	var tomb := group(details, "LowerTombMarkers")
	box(tomb, "SunkenTombSlab", Vector3(9.3, 0.48, 6.3), Vector3(1.55, 0.20, 0.82), "8e907d")
	box(tomb, "WeatheredTombstone", Vector3(9.3, 1.05, 6.05), Vector3(0.42, 1.1, 0.18), "9b9b83")
	box(tomb, "TombstoneCrown", Vector3(9.3, 1.62, 6.05), Vector3(0.28, 0.12, 0.20), "858778")
	add_skull(tomb, Vector3(8.4, 0.42, 6.8), 0.9)
	add_bone(tomb, Vector3(10.2, 0.44, 6.85), 0.2, 0.8, "c0b99e")
	var moss := group(details, "EdgeMossAndFungi")
	for i in range(30):
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * rng.randf_range(5.2, 11.5), rng.randf_range(0.18, 1.4), rng.randf_range(-7.5, 7.5))
		ball(moss, "MossLump", p, Vector3(rng.randf_range(0.12, 0.30), rng.randf_range(0.08, 0.20), rng.randf_range(0.12, 0.28)), ["64775d", "788665", "526653"][i % 3])
		if i % 3 == 0:
			cylinder(moss, "PaleFungus", p + Vector3(0, 0.18, 0), 0.045, 0.34, "a9a57d", 0.02, 6)
	var rear_altar := group(details, "RearTunnelAltar", Vector3(0, 0, -7.4))
	box(rear_altar, "StoneOfferingBase", Vector3(0, 1.48, 0), Vector3(1.35, 0.20, 0.72), "858878")
	box(rear_altar, "DarkOfferingBowl", Vector3(0, 1.68, 0), Vector3(0.42, 0.18, 0.34), "3f4540")
	var bridge_detail := group(details, "BridgeRailsAndRope")
	for x in [4.25, 5.95]:
		beam(bridge_detail, "BridgePost", Vector3(x, 0.20, 2.2), Vector3(x, 1.15, 2.2), 0.07, "6b543d")
	beam(bridge_detail, "BridgeHandrail", Vector3(4.25, 1.12, 2.2), Vector3(5.95, 1.12, 2.2), 0.055, "7d6043")
	var central_cart := group(details, "TurnedBodyCart", Vector3(-0.4, 0.94, 1.6))
	box(central_cart, "CartBed", Vector3(0, 0.38, 0), Vector3(1.45, 0.16, 2.0), "6e543c")
	for x in [-0.68, 0.68]:
		var wheel := cylinder(central_cart, "BrokenWheel", Vector3(x, 0.38, -0.15), 0.38, 0.12, "4d4236", -1, 12)
		wheel.rotation.z = PI / 2
	beam(central_cart, "SplitCartHandle", Vector3(0, 0.45, 0.72), Vector3(-0.25, 0.62, 1.8), 0.055, "805f3f")
	var lime_vats := group(details, "EntryLimeVats", Vector3(0, 0, 7.8))
	for x in [-0.9, 0, 0.9]:
		cylinder(lime_vats, "WhiteCakedVat", Vector3(x, 0.30, 0), 0.28, 0.50, "a7a28d", 0.22, 8)
		cylinder(lime_vats, "PowderedLime", Vector3(x, 0.57, 0), 0.19, 0.035, "d0c8aa", -1, 8)
	var name_wall := group(details, "CarvedNameWall", Vector3(15.0, 0, -9.4))
	box(name_wall, "NumberedWallSlab", Vector3(0, 1.8, 0), Vector3(2.6, 2.7, 0.25), "4d514b")
	for i in range(6):
		box(name_wall, "EmptyNameTablet", Vector3(-0.8 + (i % 3) * 0.8, 1.25 + (i / 3) * 0.75, 0.18), Vector3(0.42, 0.28, 0.035), "9b947b")
	var pit_frame := group(details, "PitWellRopeFrame", Vector3(-12.0, 0, -11.2))
	for x in [-0.8, 0.8]:
		beam(pit_frame, "PitPost", Vector3(x, 0.0, 0), Vector3(x, 2.0, 0), 0.08, "5c4d3c")
	beam(pit_frame, "PitCrossbar", Vector3(-0.9, 1.85, 0), Vector3(0.9, 1.85, 0), 0.08, "725942")
	beam(pit_frame, "PitRope", Vector3(0, 1.82, 0), Vector3(0, 0.15, 0.12), 0.035, "4e4438")

func enlarge_layout() -> void:
	var factor := Vector3(2.8, 1.0, 2.8)
	for path in ["CaveTerrain", "CaveRockShell", "WaterfallsAndPools", "BoneBurialFields", "MineWorks", "LowerStalactitePools", "CaveLifeAndRemains", "EntranceTransition"]:
		var section := scene_root.get_node_or_null(path) as Node3D
		if section:
			section.scale = factor

func make_entry_and_exit() -> void:
	var entry := group(scene_root, "EntranceTransition")
	box(entry, "EntryRockLeft", Vector3(-1.65, 1.6, 8.7), Vector3(1.1, 3.3, 1.2), "59645a")
	box(entry, "EntryRockRight", Vector3(1.65, 1.6, 8.7), Vector3(1.1, 3.3, 1.2), "59645a")
	box(entry, "EntryRockTop", Vector3(0, 3.05, 8.7), Vector3(3.8, 0.75, 1.2), "4b574f")
	box(entry, "EntryDarkness", Vector3(0, 1.55, 9.16), Vector3(2.1, 2.5, 0.08), "202823")
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
	entry.add_child(portal, true)
	portal.owner = scene_root
	collision_box(portal, "TriggerVolume", Vector3(0, 1.1, 9.0), Vector3(1.9, 2.2, 1.2))
	var enter_marker := Marker3D.new()
	enter_marker.name = "EntrySpawn"
	enter_marker.position = Vector3(0, 0.06, 7.15)
	enter_marker.set_meta("spawn_id", "root_cave_entry")
	entry.add_child(enter_marker, true)
	enter_marker.owner = scene_root
	var exit_marker := Marker3D.new()
	exit_marker.name = "ExitSpawn"
	exit_marker.position = Vector3(0, 0.06, 7.15)
	exit_marker.set_meta("spawn_id", "root_cave_exit")
	entry.add_child(exit_marker, true)
	exit_marker.owner = scene_root
	var sign := Label3D.new()
	sign.name = "CaveName"
	sign.text = "乱葬岭 · 左山洞"
	sign.font_size = 64
	sign.pixel_size = 0.004
	sign.modulate = Color("c3b894")
	sign.position = Vector3(0, 3.9, 8.1)
	entry.add_child(sign, true)
	sign.owner = scene_root

func make_lighting() -> void:
	lighting()
	var rig := scene_root.get_node("RenderRig")
	var env := rig.get_node("VillageEnvironment") as WorldEnvironment
	env.environment.background_color = Color("070909")
	env.environment.ambient_light_color = Color("b7c5bd")
	env.environment.ambient_light_energy = 0.48
	var sun := rig.get_node("AfternoonSun") as DirectionalLight3D
	sun.light_energy = 0.82
	sun.light_color = Color("d9e0d1")
	var camera := rig.get_node("VillageCamera") as Camera3D
	camera.size = 72.0
	camera.position = Vector3(0, 60, 62)
	camera.rotation_degrees = Vector3(-49, 0, 0)
	camera.far = 260.0

