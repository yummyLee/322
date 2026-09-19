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
	make_floor()
	make_walls_and_ceiling()
	make_waterfalls_and_pools()
	make_burial_fields()
	make_mine_works()
	make_lower_pools()
	make_entry_and_exit()
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

func make_floor() -> void:
	var floor_root := group(scene_root, "CaveTerrain")
	box(floor_root, "CaveFloorSolid", Vector3(0, -0.38, -0.5), Vector3(29, 0.76, 24), "313a35")
	var floor_collision := StaticBody3D.new()
	floor_collision.name = "SavedWalkCollisions"
	floor_root.add_child(floor_collision, true)
	floor_collision.owner = scene_root
	collision_box(floor_collision, "CaveFloor", Vector3(0, -0.38, -0.5), Vector3(29, 0.76, 24))
	floor_patch(floor_root, "MainWornStoneFloor", [Vector2(-12, 8.7), Vector2(-6, 8.1), Vector2(-3, 5.1), Vector2(4, 5.0), Vector2(10, 7.0), Vector2(12, 3), Vector2(11, -7), Vector2(6, -10), Vector2(-2, -9), Vector2(-10, -7), Vector2(-12, -2)], 0.02, "6f7568")
	floor_patch(floor_root, "BurialLoamPatch", [Vector2(-5.2, 4.4), Vector2(2.8, 4.0), Vector2(5.5, 1.0), Vector2(3.4, -4.0), Vector2(-4.0, -4.5), Vector2(-8.2, -1.5)], 0.035, "625d4e")
	floor_patch(floor_root, "EntryWornRamp", [Vector2(-1.15, 9.4), Vector2(1.15, 9.4), Vector2(1.4, 5.1), Vector2(-1.5, 5.1)], 0.045, "777868")
	floor_patch(floor_root, "RightWorkShelf", [Vector2(6.2, 3.7), Vector2(11.4, 3.8), Vector2(11.8, -0.4), Vector2(7.0, -1.8), Vector2(5.8, 0.5)], 0.08, "777867")
	var grit := group(floor_root, "ScatteredCaveGrit")
	for i in range(95):
		var p := Vector2(rng.randf_range(-10.5, 10.5), rng.randf_range(-7.8, 7.5))
		if p.x < -4.0 and p.y > 1.0: continue
		var flake := ball(grit, "HalfBuriedShale", Vector3(p.x, 0.08 + rng.randf_range(0, 0.035), p.y), Vector3(rng.randf_range(0.06, 0.22), rng.randf_range(0.025, 0.07), rng.randf_range(0.05, 0.18)), ["818378", "969886", "6b7167"][i % 3])
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
	collision_box(scene_root.get_node("CaveTerrain/SavedWalkCollisions"), "LeftWall", Vector3(-12.4, 2.0, -1.0), Vector3(0.7, 4.0, 18))
	collision_box(scene_root.get_node("CaveTerrain/SavedWalkCollisions"), "RightWall", Vector3(12.4, 2.0, -1.0), Vector3(0.7, 4.0, 18))

func make_waterfalls_and_pools() -> void:
	var water_root := group(scene_root, "WaterfallsAndPools")
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
			var p := Vector3(1.3 + col * 1.55 + rng.randf_range(-0.25, 0.25), 0.07, 1.9 - row * 1.38 + rng.randf_range(-0.22, 0.22))
			add_bone(bones, p, rng.randf_range(0, TAU), rng.randf_range(0.55, 1.2))
			if (row + col) % 2 == 0: add_skull(bones, p + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25)), rng.randf_range(0.8, 1.15))
	for i in range(22):
		var p := Vector3(rng.randf_range(-5.8, 5.8), 0.075, rng.randf_range(-3.8, 3.6))
		add_bone(bones, p, rng.randf_range(0, TAU), rng.randf_range(0.25, 0.85), ["b7b29a", "d0c7a8", "9f9c87"][i % 3])
	for p in [Vector3(-3.9, 0.1, 3.4), Vector3(-6.0, 0.1, 0.4), Vector3(4.4, 0.1, -3.9)]:
		add_skull(bones, p, 1.15)
	var soil := group(bones, "BurialSoilMounds")
	for p in [Vector3(-1.8, 0.10, 3.0), Vector3(3.1, 0.10, 2.5), Vector3(-2.7, 0.10, -1.7), Vector3(1.6, 0.10, -3.5)]:
		ball(soil, "LooseBurialSoil", p, Vector3(1.25, 0.10, 0.72), "514d42")

func make_mine_works() -> void:
	var mine := group(scene_root, "MineWorks")
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
	var lower := group(scene_root, "LowerStalactitePools")
	box(lower, "LowerPoolWater", Vector3(-7.1, 0.075, -5.4), Vector3(7.2, 0.05, 5.0), "294e56")
	for i in range(26):
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.8, 5.5)
		var h := rng.randf_range(0.35, 1.55)
		cylinder(lower, "PoolStalagmite", Vector3(-7.0 + cos(a) * r, h * 0.5, -5.2 + sin(a) * r * 0.55), rng.randf_range(0.08, 0.25), h, ["5d6b63", "758077", "8b8e7e"][i % 3], rng.randf_range(0.025, 0.08), 7)
	for i in range(8):
		var bridge_x := -0.4 + i * 0.28
		var plank := box(lower, "BrokenBridgePlank", Vector3(bridge_x, 0.72 + rng.randf_range(-0.06, 0.06), -4.0), Vector3(0.22, 0.12, 2.2), ["795d42", "896948", "66513d"][i % 3])
		plank.rotation.y = rng.randf_range(-0.08, 0.08)
	var pit := box(lower, "DarkRavine", Vector3(1.1, -0.03, -4.0), Vector3(2.5, 0.06, 3.4), "1e2927")
	pit.rotation.y = -0.15

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
	env.environment.background_color = Color("17201e")
	env.environment.ambient_light_color = Color("b7c5bd")
	env.environment.ambient_light_energy = 0.48
	var sun := rig.get_node("AfternoonSun") as DirectionalLight3D
	sun.light_energy = 0.82
	sun.light_color = Color("d9e0d1")
	var camera := rig.get_node("VillageCamera") as Camera3D
	camera.size = 28.0
	camera.position = Vector3(0, 33, 29)
	camera.rotation_degrees = Vector3(-49, 0, 0)
	camera.far = 120.0

