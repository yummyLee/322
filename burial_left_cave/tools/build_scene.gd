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
	scene_root.set_meta("layout_revision", 3)
	scene_root.set_meta("layout_scale", 1.0)
	make_v3_floor()
	make_v3_walls()
	make_v3_water()
	make_v3_objects()
	make_v3_entry()
	make_v3_lighting()
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

func sloped_strip(parent: Node, label: String, a: Vector3, b: Vector3, width: float, color: String) -> void:
	var direction := Vector2(b.x - a.x, b.z - a.z).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var mid := a.lerp(b, 0.5)
	var wobble := normal * sin((a.x + b.z) * 1.73) * width * 0.12
	var points := PackedVector3Array([
		Vector3(a.x + normal.x * width * 0.5, a.y, a.z + normal.y * width * 0.5),
		Vector3(a.x - normal.x * width * 0.5, a.y, a.z - normal.y * width * 0.5),
		Vector3(mid.x + wobble.x + normal.x * width * 0.58, mid.y + 0.025, mid.z + wobble.y + normal.y * width * 0.58),
		Vector3(mid.x + wobble.x - normal.x * width * 0.58, mid.y + 0.025, mid.z + wobble.y - normal.y * width * 0.58),
		Vector3(b.x - normal.x * width * 0.5, b.y, b.z - normal.y * width * 0.5),
		Vector3(b.x + normal.x * width * 0.5, b.y, b.z + normal.y * width * 0.5)
	])
	solid(parent, label, points, PackedInt32Array([0, 1, 2, 2, 1, 3, 2, 3, 4, 4, 3, 5]), color, Vector3.UP)

func faceted_rock(parent: Node, label: String, pos: Vector3, size: Vector3, color: String, segments: int = 7) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var rings := [Vector2(-1.0, 0.58), Vector2(-0.42, 1.0), Vector2(0.32, 0.86), Vector2(0.92, 0.24)]
	for ring in rings:
		for i in range(segments):
			var angle := TAU * float(i) / segments + sin(float(i) * 7.13 + pos.x * 0.31 + pos.z) * 0.08
			var jitter := 0.88 + 0.15 * sin(float(i) * 3.7 + pos.z * 0.27)
			vertices.append(Vector3(cos(angle) * size.x * ring.y * jitter, ring.x * size.y, sin(angle) * size.z * ring.y * jitter))
	var bottom := vertices.size()
	vertices.append(Vector3(0, -size.y, 0))
	var top := vertices.size()
	vertices.append(Vector3(0, size.y, 0))
	var indices := PackedInt32Array()
	for r in range(rings.size() - 1):
		for i in range(segments):
			var a := r * segments + i
			var b := r * segments + ((i + 1) % segments)
			var c := (r + 1) * segments + i
			var d := (r + 1) * segments + ((i + 1) % segments)
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	for i in range(segments):
		var a := i
		var b := (i + 1) % segments
		indices.append_array(PackedInt32Array([bottom, b, a]))
		var c := (rings.size() - 1) * segments + i
		var d := (rings.size() - 1) * segments + ((i + 1) % segments)
		indices.append_array(PackedInt32Array([top, c, d]))
	var node := solid(parent, label, vertices, indices, color)
	node.position = pos
	return node

func cave_wall_band(parent: Node, label: String, a: Vector2, b: Vector2, floor_y: float, height: float, thickness: float, color: String) -> void:
	# A continuous, scalloped wall surface gives each chamber a real boundary.
	# It is intentionally made from several uneven sections so the silhouette reads as limestone, not a box.
	var direction := (b - a).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var steps := maxi(3, ceili(a.distance_to(b) / 1.15))
	var vertices := PackedVector3Array()
	for i in range(steps + 1):
		var t := float(i) / steps
		var center := a.lerp(b, t)
		var wave := sin(float(i) * 2.17 + a.x * 0.41 + b.y * 0.17)
		var top_y := floor_y + height * (0.74 + 0.18 * wave + 0.05 * sin(float(i) * 4.7))
		var front := center + normal * thickness * 0.5
		var back := center - normal * thickness * 0.5
		vertices.append(Vector3(front.x, floor_y, front.y))
		vertices.append(Vector3(back.x, floor_y, back.y))
		vertices.append(Vector3(front.x, top_y, front.y))
		vertices.append(Vector3(back.x, top_y - 0.08 * (1.0 - t), back.y))
	var indices := PackedInt32Array()
	for i in range(steps):
		var base := i * 4
		var next := (i + 1) * 4
		indices.append_array(PackedInt32Array([base, next, next + 2, base, next + 2, base + 2]))
		indices.append_array(PackedInt32Array([base + 1, base + 3, next + 3, base + 1, next + 3, next + 1]))
		indices.append_array(PackedInt32Array([base + 2, next + 2, next + 3, base + 2, next + 3, base + 3]))
	indices.append_array(PackedInt32Array([0, 1, 3, 0, 3, 2]))
	var end_base := steps * 4
	indices.append_array(PackedInt32Array([end_base, end_base + 2, end_base + 3, end_base, end_base + 3, end_base + 1]))
	solid(parent, label, vertices, indices, color)
	# Vertical ribs break up the long wall and make the top profile easier to read at the orthographic scale.
	for i in range(1, steps, 2):
		var t := float(i) / steps
		var p := a.lerp(b, t)
		var rib_height := height * (0.60 + 0.12 * sin(float(i) * 2.3))
		faceted_rock(parent, "WallRib", Vector3(p.x + normal.x * thickness * 0.42, floor_y + rib_height * 0.50, p.y + normal.y * thickness * 0.42), Vector3(thickness * 0.38, rib_height * 0.55, thickness * 0.34), "4e5a53", 7)

func cave_stone_pillar(parent: Node, label: String, pos: Vector3, height: float, radius: float, color: String) -> MeshInstance3D:
	# Multi-ring limestone column: each ring changes radius and centre slightly, creating a carved natural profile.
	var segments := 8
	var ring_heights := [0.0, 0.13, 0.31, 0.53, 0.72, 0.90]
	var ring_radius := [1.12, 0.92, 1.02, 0.78, 0.66, 0.40]
	var vertices := PackedVector3Array()
	for r in range(ring_heights.size()):
		var sway := Vector2(sin(float(r) * 1.7 + pos.x), cos(float(r) * 1.35 + pos.z)) * radius * 0.10
		for i in range(segments):
			var angle := TAU * float(i) / segments + float(r % 2) * 0.16
			var jitter := 0.90 + 0.10 * sin(float(i) * 4.1 + float(r) * 2.2 + pos.z)
			var rr: float = radius * ring_radius[r] * jitter
			vertices.append(Vector3(sway.x + cos(angle) * rr, height * ring_heights[r], sway.y + sin(angle) * rr))
	var bottom := vertices.size()
	vertices.append(Vector3(0, -0.04, 0))
	var top := vertices.size()
	vertices.append(Vector3(0, height * 0.99, 0))
	var indices := PackedInt32Array()
	for r in range(ring_heights.size() - 1):
		for i in range(segments):
			var a := r * segments + i
			var b := r * segments + ((i + 1) % segments)
			var c := (r + 1) * segments + i
			var d := (r + 1) * segments + ((i + 1) % segments)
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	for i in range(segments):
		var a := i
		var b := (i + 1) % segments
		indices.append_array(PackedInt32Array([bottom, b, a]))
		var c := (ring_heights.size() - 1) * segments + i
		var d := (ring_heights.size() - 1) * segments + ((i + 1) % segments)
		indices.append_array(PackedInt32Array([top, c, d]))
	var node := solid(parent, label, vertices, indices, color)
	node.position = pos
	return node

func cave_arch(parent: Node, label: String, pos: Vector3, opening_axis: Vector2, clear_width: float, height: float, color: String) -> void:
	var axis := opening_axis.normalized()
	for side in [-1.0, 1.0]:
		var p := pos + Vector3(axis.x * side * clear_width * 0.5, 0, axis.y * side * clear_width * 0.5)
		cave_stone_pillar(parent, label + "Pillar", p, height * (0.80 + 0.05 * side), clear_width * 0.17, color)
	for i in range(4):
		var t := float(i) / 3.0
		var p := pos + Vector3(axis.x * lerpf(-clear_width * 0.54, clear_width * 0.54, t), height * (0.78 + 0.06 * sin(float(i) * 2.1)), axis.y * lerpf(-clear_width * 0.54, clear_width * 0.54, t))
		faceted_rock(parent, label + "LintelStone", p, Vector3(clear_width * 0.18, height * 0.15, clear_width * 0.20), color, 7)

func cave_cliff_faces(parent: Node, label: String, points: Array[Vector2], y: float, depth: float, color: String) -> void:
	# Extruded island sides are the actual cliff faces visible from the isometric camera.
	# The lower ring is pulled outward and down unevenly, so each chamber has a broken limestone profile.
	var centre := Vector2.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	var vertices := PackedVector3Array()
	for p in points:
		vertices.append(Vector3(p.x, y, p.y))
	for i in range(points.size()):
		var p := points[i]
		var outward := (p - centre).normalized()
		var lower := p + outward * (0.12 + 0.10 * sin(float(i) * 3.1 + p.x))
		var lower_y := y - depth * (0.76 + 0.17 * sin(float(i) * 2.41 + p.y))
		vertices.append(Vector3(lower.x, lower_y, lower.y))
	var indices := PackedInt32Array()
	for i in range(points.size()):
		var n := (i + 1) % points.size()
		var top_a := i
		var top_b := n
		var bottom_a := points.size() + i
		var bottom_b := points.size() + n
		indices.append_array(PackedInt32Array([top_a, top_b, bottom_b, top_a, bottom_b, bottom_a]))
	solid(parent, label, vertices, indices, color)

func cave_platform(parent: Node, colliders: Node, label: String, points: Array[Vector2], y: float, color: String) -> void:
	var platform := group(parent, label)
	floor_patch(platform, "WalkableTop", points, y, color)
	var cliff_depth := 1.6 + maxf(0.0, 0.45 - y)
	cave_cliff_faces(platform, "LimestoneCliffFaces", points, y - 0.015, cliff_depth, ["4b5750", "59645a", "505b54"][platform.get_index() % 3])
	# Broken lip stones make each island read as a raised ledge over the black void.
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var edge_length := a.distance_to(b)
		var count := maxi(2, ceili(edge_length / 0.92))
		for j in range(count):
			var p := a.lerp(b, (float(j) + 0.5) / count)
			faceted_rock(platform, "BrokenLedgeRock", Vector3(p.x, y - 0.22 - rng.randf_range(0.0, 0.12), p.y), Vector3(rng.randf_range(0.22, 0.42), rng.randf_range(0.16, 0.28), rng.randf_range(0.22, 0.42)), ["59645a", "70776a", "4d5a53"][j % 3])
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

func v3_shell_band(parent: Node, label: String, top_points: Array[Vector2], bottom_points: Array[Vector2], top_y: float, bottom_y: float, color: String) -> void:
	var vertices := PackedVector3Array()
	for p in top_points:
		vertices.append(Vector3(p.x, top_y, p.y))
	for p in bottom_points:
		vertices.append(Vector3(p.x, bottom_y, p.y))
	var indices := PackedInt32Array()
	for i in range(top_points.size()):
		var n := (i + 1) % top_points.size()
		indices.append_array(PackedInt32Array([i, n, top_points.size() + n, i, top_points.size() + n, top_points.size() + i]))
	solid(parent, label, vertices, indices, color)

func v3_top_collision(parent: Node, label: String, points: Array[Vector2], y: float) -> void:
	var faces := PackedVector3Array()
	for i in range(1, points.size() - 1):
		faces.append(Vector3(points[0].x, y, points[0].y))
		faces.append(Vector3(points[i].x, y, points[i].y))
		faces.append(Vector3(points[i + 1].x, y, points[i + 1].y))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.name = label
	collision.shape = shape
	parent.add_child(collision, true)
	collision.owner = scene_root

func v3_zone_shell(parent: Node, colliders: Node, label: String, points: Array[Vector2], y: float, depth: float, color: String) -> void:
	var zone := group(parent, label)
	floor_patch(zone, "WalkableFloor", points, y, color)
	var centre := Vector2.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	var middle: Array[Vector2] = []
	var bottom: Array[Vector2] = []
	for i in range(points.size()):
		var outward := (points[i] - centre).normalized()
		middle.append(points[i] + outward * 0.05)
		bottom.append(points[i] + outward * (0.18 + 0.08 * sin(float(i) * 2.4 + points[i].x)))
	v3_shell_band(zone, "UpperLimestoneStrata", points, middle, y - 0.01, y - depth * 0.44, "667168")
	v3_shell_band(zone, "WetMiddleStrata", middle, bottom, y - depth * 0.44, y - depth, "4b5750")
	for i in range(points.size()):
		if i % 2 == 0:
			var p := points[i].lerp(points[(i + 1) % points.size()], 0.5)
			faceted_rock(zone, "CliffFootStone", Vector3(p.x, y - depth + 0.14, p.y), Vector3(0.30, 0.28, 0.38), ["394640", "515e55", "5d685e"][i % 3], 7)
	v3_top_collision(colliders, label + "WalkSurface", points, y - 0.02)

func v3_passage_tunnel(parent: Node, colliders: Node, label: String, points: Array[Vector3], width: float, color: String) -> void:
	var tunnel := group(parent, label)
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var direction := Vector2(b.x - a.x, b.z - a.z).normalized()
		var normal := Vector3(-direction.y, 0, direction.x)
		var mid := (a + b) * 0.5
		sloped_strip(tunnel, "ContinuousTunnelFloor", a, b, width, color)
		var left_a := a + normal * width * 0.54
		var left_b := b + normal * width * 0.54
		var right_a := a - normal * width * 0.54
		var right_b := b - normal * width * 0.54
		var bank_y := (a.y + b.y) * 0.5 - 0.03
		cave_wall_band(tunnel, "LeftTunnelBank", Vector2(left_a.x, left_a.z), Vector2(left_b.x, left_b.z), bank_y, 0.92, 0.34, "59655c")
		cave_wall_band(tunnel, "RightTunnelBank", Vector2(right_a.x, right_a.z), Vector2(right_b.x, right_b.z), bank_y, 0.92, 0.34, "59655c")
		var collision := collision_box(colliders, label + "Segment%02d" % i, mid + Vector3(0, -0.12, 0), Vector3(width, 0.42, a.distance_to(b) + 0.28))
		collision.rotation.y = atan2(b.x - a.x, b.z - a.z)

func make_v3_floor() -> void:
	var floor_root := group(scene_root, "CaveTerrain")
	var floor_collision := StaticBody3D.new()
	floor_collision.name = "SavedWalkCollisions"
	floor_root.add_child(floor_collision, true)
	floor_collision.owner = scene_root
	var boundaries := group(floor_root, "MapBoundaries")
	collision_box(floor_collision, "WestBoundary", Vector3(-68, 0, -3), Vector3(0.8, 10, 82))
	collision_box(floor_collision, "EastBoundary", Vector3(68, 0, -3), Vector3(0.8, 10, 82))
	collision_box(floor_collision, "NorthBoundary", Vector3(0, 0, -40), Vector3(128, 10, 0.8))
	collision_box(floor_collision, "SouthBoundary", Vector3(0, 0, 43), Vector3(136, 10, 0.8))
	collision_box(floor_collision, "VoidSafetyCatch", Vector3(0, -7.5, -1), Vector3(136, 0.5, 84))
	boundaries.set_meta("purpose", "v3_chamber_boundaries_and_void_safety")
	var platforms := group(floor_root, "DisconnectedPlatforms")
	# The floor polygons follow the black gaps in the reference instead of filling them with one terrain slab.
	v3_zone_shell(platforms, floor_collision, "J0_EntranceHall", [Vector2(-7, 34), Vector2(-10, 28), Vector2(-4, 25), Vector2(5, 26), Vector2(10, 31), Vector2(7, 38), Vector2(-1, 40)], 0.0, 2.8, "6e705f")
	v3_zone_shell(platforms, floor_collision, "J1_MainSCorridor", [Vector2(-8, 25), Vector2(-11, 21), Vector2(-10, 17), Vector2(-5, 15), Vector2(-1, 17), Vector2(-2, 21)], 0.30, 1.9, "68685b")
	v3_zone_shell(platforms, floor_collision, "J8_OldCartYard", [Vector2(-10, 12), Vector2(-14, 4), Vector2(-8, -3), Vector2(2, -4), Vector2(13, 0), Vector2(16, 8), Vector2(10, 15), Vector2(-1, 18)], 0.85, 3.0, "6b624f")
	v3_zone_shell(platforms, floor_collision, "J2_BoneShelf", [Vector2(16, 6), Vector2(18, -1), Vector2(25, -5), Vector2(36, -4), Vector2(43, 0), Vector2(41, 7), Vector2(32, 10), Vector2(22, 9)], 1.65, 3.2, "666456")
	v3_zone_shell(platforms, floor_collision, "J3_WetThroat", [Vector2(-40, 8), Vector2(-42, 1), Vector2(-38, -4), Vector2(-27, -5), Vector2(-22, 0), Vector2(-25, 8), Vector2(-32, 11)], -0.25, 2.4, "536965")
	v3_zone_shell(platforms, floor_collision, "J4_UpperFissure", [Vector2(5, -14), Vector2(10, -18), Vector2(22, -19), Vector2(28, -16), Vector2(26, -12), Vector2(14, -10)], 2.10, 3.4, "5b6258")
	v3_zone_shell(platforms, floor_collision, "J9_PillarForest", [Vector2(-43, 22), Vector2(-49, 16), Vector2(-48, 8), Vector2(-39, 5), Vector2(-29, 9), Vector2(-26, 17), Vector2(-33, 23)], 0.20, 2.8, "4f625e")
	v3_zone_shell(platforms, floor_collision, "J6_PitWell", [Vector2(-55, 4), Vector2(-59, -2), Vector2(-56, -9), Vector2(-47, -12), Vector2(-40, -7), Vector2(-41, 1), Vector2(-47, 6)], -0.75, 3.4, "4b5955")
	v3_zone_shell(platforms, floor_collision, "J11_SuspendedBoneBridge", [Vector2(25, -6), Vector2(29, -14), Vector2(38, -15), Vector2(41, -9), Vector2(36, -5), Vector2(30, -4)], 2.25, 3.8, "555d55")
	v3_zone_shell(platforms, floor_collision, "J5_BoneSortingHall", [Vector2(-22, -24), Vector2(-19, -33), Vector2(-10, -37), Vector2(3, -35), Vector2(9, -29), Vector2(5, -22), Vector2(-6, -19), Vector2(-15, -20)], 1.50, 3.8, "615d50")
	v3_zone_shell(platforms, floor_collision, "J10_GreyWaterTerraces", [Vector2(-54, -21), Vector2(-53, -30), Vector2(-46, -36), Vector2(-35, -36), Vector2(-26, -31), Vector2(-28, -23), Vector2(-37, -19), Vector2(-47, -18)], -0.20, 2.5, "6b746a")
	v3_zone_shell(platforms, floor_collision, "J7_SealedFissure", [Vector2(-58, -25), Vector2(-56, -30), Vector2(-51, -32), Vector2(-48, -28), Vector2(-50, -23), Vector2(-55, -22)], -0.10, 2.6, "3b4845")
	v3_zone_shell(platforms, floor_collision, "J12_CollapsedQuarry", [Vector2(24, -22), Vector2(28, -30), Vector2(39, -34), Vector2(49, -30), Vector2(48, -23), Vector2(41, -18), Vector2(31, -18)], 1.45, 3.6, "5d6259")
	v3_zone_shell(platforms, floor_collision, "J13_NameWallRoom", [Vector2(47, -16), Vector2(50, -23), Vector2(57, -26), Vector2(63, -22), Vector2(63, -16), Vector2(58, -12), Vector2(51, -12)], 1.55, 3.5, "5f5e54")
	var paths := group(floor_root, "BranchingStonePaths")
	v3_passage_tunnel(paths, floor_collision, "J0_to_J8_SCurve", [Vector3(1, 26, 0.1), Vector3(-3, 20, 0.25), Vector3(-1, 15, 0.45), Vector3(3, 11, 0.70), Vector3(3, 8, 0.82)], 3.2, "777766")
	v3_passage_tunnel(paths, floor_collision, "J8_to_J3_WetBranch", [Vector3(-9, 3, 0.82), Vector3(-17, 4, 0.35), Vector3(-25, 4, 0.0), Vector3(-30, 3, -0.2)], 2.8, "647875")
	v3_passage_tunnel(paths, floor_collision, "J3_to_J9_WaterLoop", [Vector3(-31, 7, -0.1), Vector3(-36, 11, 0.0), Vector3(-37, 16, 0.15)], 2.4, "5e7470")
	v3_passage_tunnel(paths, floor_collision, "J9_to_J6_PillarLoop", [Vector3(-40, 14, 0.12), Vector3(-45, 9, -0.1), Vector3(-47, 4, -0.55)], 2.5, "5f6d68")
	v3_passage_tunnel(paths, floor_collision, "J6_to_J5_DeepLoop", [Vector3(-45, -5, -0.7), Vector3(-38, -11, -0.2), Vector3(-28, -18, 0.35), Vector3(-18, -23, 1.0), Vector3(-12, -25, 1.38)], 2.6, "68655b")
	v3_passage_tunnel(paths, floor_collision, "J8_to_J2_EastRise", [Vector3(11, 1, 0.95), Vector3(16, 0, 1.15), Vector3(20, 0, 1.45)], 2.8, "777566")
	v3_passage_tunnel(paths, floor_collision, "J8_to_J11_BridgeRoad", [Vector3(11, -3, 0.9), Vector3(18, -7, 1.2), Vector3(25, -10, 2.05)], 2.55, "727368")
	v3_passage_tunnel(paths, floor_collision, "J11_to_J5_BoneRoad", [Vector3(27, -13, 2.10), Vector3(20, -17, 1.75), Vector3(12, -21, 1.55), Vector3(5, -25, 1.48)], 2.5, "6e6b5d")
	v3_passage_tunnel(paths, floor_collision, "J5_to_J10_WaterRoad", [Vector3(-18, -28, 1.40), Vector3(-25, -27, 0.85), Vector3(-33, -26, 0.15), Vector3(-38, -26, -0.05)], 2.7, "707a70")
	v3_passage_tunnel(paths, floor_collision, "J5_to_J12_QuarryRoad", [Vector3(4, -28, 1.45), Vector3(14, -27, 1.48), Vector3(25, -26, 1.45)], 2.8, "6c6d64")
	v3_passage_tunnel(paths, floor_collision, "J12_to_J13_NameRoad", [Vector3(39, -25, 1.5), Vector3(46, -20, 1.55), Vector3(51, -18, 1.55)], 2.5, "666860")
	v3_passage_tunnel(paths, floor_collision, "J2_to_J4_UpperShortcut", [Vector3(23, -4, 1.75), Vector3(20, -9, 1.95), Vector3(16, -13, 2.05)], 2.35, "686b61")
	v3_passage_tunnel(paths, floor_collision, "J4_to_J5_BackShortcut", [Vector3(10, -16, 1.9), Vector3(5, -21, 1.65), Vector3(-2, -24, 1.5)], 2.35, "67665b")

func v3_stalactite(parent: Node, label: String, pos: Vector3, height: float, radius: float, color: String) -> void:
	var spike := cave_stone_pillar(parent, label, pos, height, radius, color)
	spike.scale.y = -1.0

func make_v3_walls() -> void:
	var shell := group(scene_root, "CaveRockShell")
	var walls := group(shell, "ContinuousChamberWalls")
	# Outer wall runs follow the large gray silhouettes in the reference and leave the black gaps exposed.
	cave_wall_band(walls, "SouthEntryWestWall", Vector2(-22, 37), Vector2(-16, 29), 0.0, 4.0, 1.25, "4b5750")
	cave_wall_band(walls, "SouthEntryEastWall", Vector2(9, 37), Vector2(10, 30), 0.0, 3.7, 1.25, "4e5951")
	cave_wall_band(walls, "WestWetWall", Vector2(-41, 8), Vector2(-47, 15), -0.2, 4.4, 1.3, "4c5e58")
	cave_wall_band(walls, "WestPillarWall", Vector2(-50, 14), Vector2(-52, 3), -0.7, 4.0, 1.35, "455650")
	cave_wall_band(walls, "PitWellWall", Vector2(-58, 2), Vector2(-57, -8), -0.75, 4.6, 1.45, "3d4b48")
	cave_wall_band(walls, "GreyTerraceNorthWall", Vector2(-56, -21), Vector2(-49, -17), -0.2, 3.6, 1.2, "667268")
	cave_wall_band(walls, "BoneHallNorthWall", Vector2(-22, -34), Vector2(7, -35), 1.45, 4.8, 1.4, "48534d")
	cave_wall_band(walls, "BoneHallEastWall", Vector2(8, -34), Vector2(12, -26), 1.45, 4.0, 1.2, "4b564f")
	cave_wall_band(walls, "QuarryNorthWall", Vector2(25, -31), Vector2(47, -29), 1.35, 4.2, 1.35, "4b5750")
	cave_wall_band(walls, "NameRoomEastWall", Vector2(62, -25), Vector2(63, -13), 1.5, 3.8, 1.25, "4d5851")
	cave_wall_band(walls, "UpperFissureWall", Vector2(8, -19), Vector2(27, -19), 2.0, 3.5, 1.15, "4c5750")
	var architecture := group(scene_root, "CaveArchitecture")
	var divider := group(architecture, "ChamberDividers")
	cave_wall_band(divider, "CartToWaterDivider", Vector2(-16, 1), Vector2(-16, 7), 0.4, 2.6, 0.8, "56645d")
	cave_wall_band(divider, "BridgePitNorthLip", Vector2(22, -8), Vector2(27, -7), 1.95, 2.2, 0.9, "515d55")
	cave_wall_band(divider, "BridgePitSouthLip", Vector2(38, -8), Vector2(41, -12), 1.95, 2.5, 0.9, "4a5650")
	var pillars := group(architecture, "FineStonePillars")
	var pillar_data := [
		[Vector3(-45, -0.2, 18), 3.6, 0.75], [Vector3(-41, -0.2, 14), 2.4, 0.52], [Vector3(-35, -0.2, 17), 4.2, 0.66],
		[Vector3(-31, -0.2, 13), 2.9, 0.48], [Vector3(-28, -0.2, 18), 3.8, 0.62], [Vector3(-39, -0.2, 9), 2.2, 0.58],
		[Vector3(-34, -0.2, 8), 3.1, 0.50], [Vector3(-47, -0.2, 10), 2.7, 0.56], [Vector3(-43, -0.2, 6), 3.4, 0.64],
		[Vector3(-51, -0.2, 11), 2.0, 0.44], [Vector3(-36, -0.2, 22), 2.6, 0.46], [Vector3(-30, -0.2, 20), 3.0, 0.54],
		[Vector3(-49, -0.2, 20), 2.3, 0.48], [Vector3(-27, -0.2, 11), 2.0, 0.42], [Vector3(-40, -0.2, 20), 3.6, 0.57],
		[Vector3(-46, -0.2, 15), 2.8, 0.45], [Vector3(-33, -0.2, 10), 2.4, 0.43], [Vector3(-52, -0.2, 17), 3.1, 0.51]
	]
	for data in pillar_data:
		cave_stone_pillar(pillars, "PillarForestColumn", data[0], data[1], data[2], ["5c6b63", "708077", "879086"][pillars.get_child_count() % 3])
	var mouths := group(architecture, "ChamberMouths")
	cave_arch(mouths, "EntryMouth", Vector3(1, 0.0, 25.5), Vector2(1, 0), 3.4, 4.0, "56635a")
	cave_arch(mouths, "WaterMouth", Vector3(-25, 0.0, 4.0), Vector2(0, 1), 3.0, 3.4, "53665f")
	cave_arch(mouths, "PillarMouth", Vector3(-39, 0.0, 14.5), Vector2(1, 0), 2.7, 3.6, "4b5c56")
	cave_arch(mouths, "BoneMouth", Vector3(3, 1.5, -25), Vector2(0, 1), 3.0, 4.0, "4b564e")
	cave_arch(mouths, "QuarryMouth", Vector3(28, 1.45, -26), Vector2(1, 0), 2.8, 3.7, "505a52")
	var ceiling := group(shell, "CeilingStalactites")
	for item in [
		[Vector3(-51, 5.1, -20), 2.5, 0.32], [Vector3(-44, 5.4, -18), 3.0, 0.38], [Vector3(-33, 5.8, -22), 2.4, 0.30],
		[Vector3(-18, 6.0, -31), 2.8, 0.34], [Vector3(-4, 6.2, -32), 3.5, 0.42], [Vector3(12, 5.8, -30), 2.7, 0.32],
		[Vector3(27, 5.9, -27), 2.9, 0.34], [Vector3(44, 5.4, -25), 2.3, 0.28], [Vector3(-54, 4.8, 4), 2.7, 0.35],
		[Vector3(-48, 4.5, 16), 2.2, 0.30], [Vector3(38, 5.6, -12), 2.5, 0.29]
	]:
		v3_stalactite(ceiling, "CeilingLimestoneTooth", item[0], item[1], item[2], "4d5b54")

func v3_water_patch(parent: Node, label: String, centre: Vector2, sx: float, sz: float, y: float) -> void:
	var pts: Array[Vector2] = [centre + Vector2(-sx, -sz * 0.15), centre + Vector2(-sx * 0.55, -sz), centre + Vector2(sx * 0.55, -sz * 0.82), centre + Vector2(sx, -sz * 0.10), centre + Vector2(sx * 0.55, sz * 0.82), centre + Vector2(-sx * 0.60, sz)]
	floor_patch(parent, label, pts, y, "294e56")

func v3_water_sheet(parent: Node, label: String, x: float, z: float, top_y: float, height: float, width: float) -> void:
	var verts := PackedVector3Array([Vector3(x - width * 0.5, top_y, z), Vector3(x + width * 0.5, top_y, z), Vector3(x + width * 0.38, top_y - height, z), Vector3(x - width * 0.42, top_y - height * 0.86, z)])
	solid(parent, label, verts, PackedInt32Array([0, 1, 2, 0, 2, 3]), "507477", Vector3.FORWARD)

func make_v3_water() -> void:
	var water := group(scene_root, "WaterfallsAndPools")
	var tiers := group(water, "J10_GreyWaterTerraces")
	var tier_centres := [Vector2(-48, -21), Vector2(-45, -24), Vector2(-42, -27), Vector2(-39, -30)]
	for i in range(tier_centres.size()):
		var c: Vector2 = tier_centres[i]
		var points: Array[Vector2] = [c + Vector2(-5.4, -2.0), c + Vector2(-3.1, -3.0), c + Vector2(3.8, -2.4), c + Vector2(5.0, 0.8), c + Vector2(2.8, 2.8), c + Vector2(-3.6, 2.3), c + Vector2(-5.0, 0.5)]
		floor_patch(tiers, "LimestoneTerrace%02d" % i, points, 0.15 + i * 0.33, ["a7aa98", "949989", "8a9185"][i % 3])
		cave_cliff_faces(tiers, "WhiteCalciteDrop%02d" % i, points, 0.12 + i * 0.33, 0.38, "a9ab98")
		var water_points: Array[Vector2] = [c + Vector2(-3.8, -1.2), c + Vector2(-2.1, -1.9), c + Vector2(3.2, -1.4), c + Vector2(3.7, 0.6), c + Vector2(1.6, 1.7), c + Vector2(-2.5, 1.4), c + Vector2(-3.5, 0.3)]
		floor_patch(tiers, "BlueGreenPool%02d" % i, water_points, 0.36 + i * 0.33, "315b5e")
		v3_water_sheet(tiers, "NarrowWaterfall%02d" % i, c.x + 0.1, c.y - 2.1, 0.38 + i * 0.33, 0.42, 0.8)
	v3_water_patch(water, "J10_LowerColdPool", Vector2(-42, -19), 5.8, 3.6, -0.05)
	var wet := group(water, "J3_WetThroatPools")
	v3_water_patch(wet, "WetThroatPoolA", Vector2(-34, 1), 4.3, 2.4, -0.04)
	v3_water_patch(wet, "WetThroatPoolB", Vector2(-29, 5), 3.0, 2.0, -0.02)
	var lower := group(scene_root, "LowerStalactitePools")
	v3_water_patch(lower, "J9_PillarForestWater", Vector2(-37, 15), 8.0, 4.8, -0.12)
	v3_water_patch(lower, "J6_PitBlackWater", Vector2(-49, -3), 4.0, 3.8, -1.55)
	var glow := OmniLight3D.new()
	glow.name = "ColdWaterGlow"
	glow.position = Vector3(-42, 2.5, -24)
	glow.light_color = Color("6fabb0")
	glow.light_energy = 2.1
	glow.omni_range = 12.0
	water.add_child(glow, true)
	glow.owner = scene_root

func make_v3_objects() -> void:
	var details := group(scene_root, "CaveLifeAndRemains")
	var bones := group(details, "BoneBurialFields")
	# J5 is split into an orderly eastern rack and a disturbed western scatter, as in the reference.
	for row in range(4):
		for col in range(4):
			var p := Vector3(-5.5 + col * 2.8, 1.92, -24.0 - row * 2.5)
			add_skull(bones, p, 0.95)
			add_bone(bones, p + Vector3(0.7, 0.0, 0.25), 0.18, 1.15, "d1c9aa")
	for i in range(30):
		var p := Vector3(-18.0 + fmod(float(i) * 2.13, 14.0), 1.92, -22.0 - fmod(float(i) * 3.17, 11.0))
		add_bone(bones, p, float(i) * 0.73, 0.45 + fmod(float(i), 3.0) * 0.20, ["b8b39c", "d0c6a6", "9d9c89"][i % 3])
		if i % 5 == 0:
			add_skull(bones, p + Vector3(0.35, 0.0, 0.15), 0.78)
	var racks := group(bones, "J5_BoneRackFrames")
	for x in [-14.5, -10.5, -6.5, -2.5]:
		beam(racks, "RackPost", Vector3(x, 1.55, -24.0), Vector3(x, 3.1, -24.0), 0.08, "66523b")
		beam(racks, "RackCrossbar", Vector3(x - 0.7, 2.5, -24.0), Vector3(x + 0.7, 2.5, -24.0), 0.06, "795d42")
	var cart := group(details, "J8_TurnedFuneralCart", Vector3(1.0, 1.0, 3.0))
	box(cart, "CartBed", Vector3(0, 0.45, 0), Vector3(1.9, 0.18, 2.8), "6d543b")
	box(cart, "CartSide", Vector3(0, 0.72, -1.15), Vector3(1.9, 0.38, 0.12), "765b40")
	for x in [-1.0, 1.0]:
		var wheel := cylinder(cart, "CartWheel", Vector3(x, 0.44, 0.45), 0.52, 0.14, "4f4337", -1, 12)
		wheel.rotation.z = PI / 2
	beam(cart, "CartHandle", Vector3(0, 0.5, 1.2), Vector3(0, 0.75, 2.6), 0.07, "805f3f")
	var mine := group(scene_root, "MineWorks")
	var support := group(mine, "J12_TimberSupport", Vector3(35, 1.45, -25.5))
	for x in [-2.0, 2.0]:
		beam(support, "SupportPost", Vector3(x, 0.0, 0), Vector3(x, 3.6, 0), 0.16, "66503b")
	beam(support, "SupportHeader", Vector3(-2.2, 3.45, 0), Vector3(2.2, 3.45, 0), 0.19, "755b40")
	for x in [-1.6, -0.8, 0, 0.8, 1.6]:
		beam(support, "RoofSlat", Vector3(x, 3.45, -0.8), Vector3(x, 3.45, 0.8), 0.08, ["806548", "715943", "8b6b4e"][int(absf(x) * 2.0) % 3])
	for i in range(14):
		faceted_rock(mine, "QuarryLooseStone", Vector3(40 + sin(float(i) * 1.7) * 4.0, 1.55 + fmod(float(i), 3.0) * 0.12, -28 + cos(float(i) * 1.3) * 3.0), Vector3(0.35, 0.30, 0.42), ["666b63", "85877a", "555e58"][i % 3], 7)
	var bridge := group(details, "J11_SuspendedBoneBridge")
	var pit_points: Array[Vector2] = [Vector2(25, -12), Vector2(29, -16), Vector2(39, -15), Vector2(42, -9), Vector2(37, -7), Vector2(29, -8)]
	floor_patch(bridge, "BridgeDeepRavine", pit_points, -1.9, "1d2927")
	for i in range(6):
		var plank := box(bridge, "MisalignedBridgePlank", Vector3(27.5 + i * 1.65, 2.45 + sin(float(i) * 1.2) * 0.08, -10.5 + sin(float(i) * 0.7) * 0.15), Vector3(1.7, 0.18, 2.2), ["795d42", "896948", "66513d"][i % 3])
		plank.rotation.y = -0.08 + sin(float(i) * 1.9) * 0.04
	for x in [26.7, 38.5]:
		beam(bridge, "BridgePost", Vector3(x, 2.35, -10.5), Vector3(x, 3.7, -10.5), 0.08, "6b543d")
	beam(bridge, "BridgeHandrail", Vector3(26.7, 3.7, -10.5), Vector3(38.5, 3.7, -10.5), 0.06, "7d6043")
	var tomb := group(details, "J13_NameWallRoom")
	var name_wall := group(tomb, "CarvedNameWall", Vector3(57.2, 0, -23.7))
	cave_wall_band(name_wall, "NameWallRockFace", Vector2(-4.8, 0), Vector2(4.8, 0), 1.55, 3.4, 0.7, "4d514b")
	for i in range(6):
		var tablet := box(name_wall, "IndependentNameTablet", Vector3(-3.7 + (i % 3) * 3.5, 2.0 + (i / 3) * 1.0, -0.38), Vector3(1.4, 0.65, 0.12), "9b947b")
		tablet.rotation.z = sin(float(i) * 1.4) * 0.05
	var tombstone := group(tomb, "J13_TombMarker", Vector3(54.0, 1.7, -19.0))
	box(tombstone, "TombSlab", Vector3(0, -0.1, 0), Vector3(3.0, 0.25, 1.6), "8e907d")
	var stone := faceted_rock(tombstone, "WeatheredTombstone", Vector3(0, 1.0, 0), Vector3(0.55, 1.15, 0.22), "9b9b83", 7)
	stone.rotation.z = -0.08
	var pit_frame := group(details, "J6_PitWellRopeFrame", Vector3(-50, -0.72, -4))
	for x in [-1.2, 1.2]:
		beam(pit_frame, "PitPost", Vector3(x, 0.0, 0), Vector3(x, 3.0, 0), 0.10, "5c4d3c")
	beam(pit_frame, "PitCrossbar", Vector3(-1.4, 2.8, 0), Vector3(1.4, 2.8, 0), 0.10, "725942")
	beam(pit_frame, "PitRope", Vector3(0, 2.75, 0), Vector3(0, -0.5, 0.2), 0.04, "4e4438")
	var vats := group(details, "J0_EntryLimeVats", Vector3(2, 0, 32))
	for x in [-1.4, 0, 1.4]:
		cylinder(vats, "CakedLimeVat", Vector3(x, 0.35, 0), 0.38, 0.65, "a7a28d", 0.28, 8)
		cylinder(vats, "PowderedLime", Vector3(x, 0.70, 0), 0.27, 0.04, "d0c8aa", -1, 8)
	var moss := group(details, "CaveMossAndFungi")
	for i in range(70):
		var p := Vector3(-58 + fmod(float(i) * 7.73, 116.0), 0.15 + fmod(float(i), 4.0) * 0.08, -35 + fmod(float(i) * 5.17, 66.0))
		if i % 3 == 0:
			ball(moss, "MossLump", p, Vector3(0.18, 0.12, 0.22), ["526653", "64775d", "788665"][i % 3])
		else:
			cylinder(moss, "PaleFungus", p + Vector3(0, 0.16, 0), 0.05, 0.30, "a9a57d", 0.025, 6)

func make_v3_entry() -> void:
	var entry := group(scene_root, "EntranceTransition")
	for p in [Vector3(-6, 1.3, 31), Vector3(-5, 2.8, 30), Vector3(8, 1.2, 31), Vector3(7, 2.7, 30), Vector3(-1.8, 3.5, 30), Vector3(2.0, 3.5, 30)]:
		faceted_rock(entry, "EntranceRimRock", p, Vector3(1.3, 1.4, 1.0), "59645a", 8)
	var darkness := PackedVector3Array([Vector3(-4, 0.2, 34.2), Vector3(-3, 3.7, 34.2), Vector3(5, 3.7, 34.2), Vector3(6, 0.2, 34.2)])
	solid(entry, "EntranceDarkness", darkness, PackedInt32Array([0, 1, 2, 0, 2, 3]), "202823", Vector3.FORWARD)
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
	collision_box(portal, "TriggerVolume", Vector3(2, 1.2, 34.0), Vector3(8.0, 3.0, 1.8))
	var enter_marker := Marker3D.new()
	enter_marker.name = "EntrySpawn"
	enter_marker.position = Vector3(2, 0.06, 30.5)
	enter_marker.set_meta("spawn_id", "root_cave_entry")
	entry.add_child(enter_marker, true)
	enter_marker.owner = scene_root
	var exit_marker := Marker3D.new()
	exit_marker.name = "ExitSpawn"
	exit_marker.position = Vector3(2, 0.06, 30.5)
	exit_marker.set_meta("spawn_id", "root_cave_exit")
	entry.add_child(exit_marker, true)
	exit_marker.owner = scene_root
	var sign := Label3D.new()
	sign.name = "CaveName"
	sign.text = "乱葬岭 · 左山洞"
	sign.font_size = 64
	sign.pixel_size = 0.004
	sign.modulate = Color("c3b894")
	sign.position = Vector3(2, 4.5, 31)
	entry.add_child(sign, true)
	sign.owner = scene_root

func make_v3_lighting() -> void:
	lighting()
	var rig := scene_root.get_node("RenderRig")
	var env := rig.get_node("VillageEnvironment") as WorldEnvironment
	env.environment.background_color = Color("050707")
	env.environment.ambient_light_color = Color("aebdb4")
	env.environment.ambient_light_energy = 0.42
	var sun := rig.get_node("AfternoonSun") as DirectionalLight3D
	sun.light_energy = 0.76
	sun.light_color = Color("d5ded3")
	var camera := rig.get_node("VillageCamera") as Camera3D
	camera.size = 82.0
	camera.position = Vector3(0, 54, 53)
	camera.rotation_degrees = Vector3(-49, 0, 0)
	camera.far = 260.0

func cave_walkway(parent: Node, colliders: Node, label: String, points: Array[Vector3], width: float, color: String) -> void:
	var road := group(parent, label)
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var mid := (a + b) * 0.5
		sloped_strip(road, "NarrowStonePath", a, b, width, color)
		collision_box(colliders, label + "Segment%02d" % i, Vector3(mid.x, mid.y - 0.12, mid.z), Vector3(width, 0.42, a.distance_to(b) + 0.18))
		for j in range(2):
			var side := -1.0 if j == 0 else 1.0
			var direction := Vector2(b.x - a.x, b.z - a.z).normalized()
			var offset := Vector3(-direction.y, 0, direction.x) * side * width * 0.42
			faceted_rock(road, "PathShoulderStone", mid + offset + Vector3(0, -0.03, 0), Vector3(0.18, 0.10, 0.26), "7d8274", 6)

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
	# A dark, irregular back aperture suggests a deeper tunnel without another rectangular wall.
	var mouth_points: Array[Vector2] = [Vector2(-2.0, -10.28), Vector2(-1.35, -10.62), Vector2(-0.45, -10.74), Vector2(0.65, -10.58), Vector2(1.75, -10.24), Vector2(1.55, -9.88), Vector2(0.55, -9.58), Vector2(-0.65, -9.62), Vector2(-1.65, -9.88)]
	floor_patch(rock_root, "DeepTunnelShadow", mouth_points, 0.18, "202823")
	for p in [Vector3(-1.65, 1.2, -10.0), Vector3(-0.75, 2.7, -10.08), Vector3(0.75, 2.55, -10.02), Vector3(1.65, 1.15, -10.0)]:
		faceted_rock(rock_root, "TunnelMouthRim", p, Vector3(0.55, 1.35, 0.52), "4f5b53", 8)
	collision_box(scene_root.get_node("CaveTerrain/SavedWalkCollisions"), "BackWall", Vector3(0, 2.0, -10.4), Vector3(25, 4.0, 0.7))

func make_zone_architecture() -> void:
	var architecture := group(scene_root, "CaveArchitecture")
	var walls := group(architecture, "ChamberWallBands")
	# J0 entrance throat and J1 central hall are bounded by broken wall runs, with openings left at each route.
	cave_wall_band(walls, "WestWaterWall", Vector2(-11.0, -8.0), Vector2(-11.0, -3.2), 0.48, 3.7, 0.75, "526057")
	cave_wall_band(walls, "WestWaterWallLower", Vector2(-11.0, -2.2), Vector2(-10.7, 2.4), 0.92, 3.1, 0.70, "5a675f")
	cave_wall_band(walls, "LowerPoolOuterWall", Vector2(-10.9, 3.1), Vector2(-10.6, 8.0), -0.35, 2.8, 0.76, "4e5b55")
	cave_wall_band(walls, "EastMineWall", Vector2(11.9, -3.0), Vector2(12.2, -0.8), 0.76, 3.3, 0.70, "59645a")
	cave_wall_band(walls, "EastMineWallSouth", Vector2(12.1, 0.8), Vector2(12.0, 2.5), 0.76, 2.8, 0.70, "59645a")
	cave_wall_band(walls, "EastTombOuterWall", Vector2(12.2, 4.0), Vector2(12.7, 8.1), 0.06, 3.0, 0.82, "505c55")
	cave_wall_band(walls, "NorthBoneWallLeft", Vector2(-10.0, -9.4), Vector2(-4.6, -9.7), 1.12, 3.0, 0.85, "4c5952")
	cave_wall_band(walls, "NorthBoneWallCentre", Vector2(-3.3, -9.8), Vector2(4.0, -9.5), 1.30, 3.35, 0.88, "4b5750")
	cave_wall_band(walls, "NorthQuarryWall", Vector2(8.5, -9.0), Vector2(14.8, -8.7), 1.18, 3.1, 0.82, "4c5951")
	# Short divider walls create alcoves and force the player through the intended narrow mouths.
	cave_wall_band(walls, "WaterToBurialDivider", Vector2(-5.0, -3.5), Vector2(-4.6, -1.15), 0.86, 2.5, 0.64, "59645b")
	cave_wall_band(walls, "BurialToMineDivider", Vector2(5.1, -2.6), Vector2(5.25, -0.85), 0.88, 2.6, 0.66, "59645b")
	cave_wall_band(walls, "RavineNorthLip", Vector2(5.1, 2.8), Vector2(7.0, 3.0), 0.32, 2.0, 0.64, "505e56")
	cave_wall_band(walls, "RavineSouthLip", Vector2(4.3, 4.2), Vector2(6.9, 4.15), 0.12, 2.2, 0.64, "505e56")
	var pillars := group(architecture, "FineStonePillars")
	for item in [
		[Vector3(-9.7, -0.34, 5.0), 2.15, 0.46], [Vector3(-7.9, -0.34, 6.2), 2.7, 0.58],
		[Vector3(-6.0, -0.34, 7.1), 2.25, 0.42], [Vector3(-9.8, 0.48, -6.0), 3.3, 0.52],
		[Vector3(-11.8, 0.08, -8.5), 2.7, 0.43], [Vector3(5.6, 0.30, 3.6), 2.1, 0.40],
		[Vector3(10.8, 0.06, 6.4), 2.55, 0.48], [Vector3(13.6, 1.2, -6.2), 2.6, 0.44]
	]:
		cave_stone_pillar(pillars, "LimestoneColumn", item[0], item[1], item[2], ["657168", "707b70", "59665e"][pillars.get_child_count() % 3])
	# Rock arches mark the change from one chamber to the next; the openings remain wider than the hero capsule.
	var arches := group(architecture, "ChamberMouths")
	cave_arch(arches, "WaterMouth", Vector3(-4.8, 0.88, -0.35), Vector2(1, 0), 1.45, 2.7, "59665d")
	cave_arch(arches, "MineMouth", Vector3(4.9, 0.90, -0.05), Vector2(0, 1), 1.55, 2.75, "5c665c")
	cave_arch(arches, "LowerForkMouth", Vector3(2.3, 0.05, 5.85), Vector2(0, 1), 1.35, 2.35, "59645b")
	cave_arch(arches, "BoneHallMouth", Vector3(0.0, 1.30, -4.1), Vector2(1, 0), 1.55, 2.85, "4f5b53")
	cave_arch(arches, "NameWallMouth", Vector3(13.0, 1.40, -8.8), Vector2(0, 1), 1.25, 2.6, "505b53")

func make_waterfalls_and_pools() -> void:
	var water_root := group(scene_root, "WaterfallsAndPools", Vector3(0, 0.92, 0))
	var falls := group(water_root, "TieredWaterfall")
	for i in range(4):
		var x := -9.6 + i * 0.85
		var z := 4.5 - i * 1.15
		var shelf_points: Array[Vector2] = [Vector2(x - 1.35, z - 0.92), Vector2(x - 0.48, z - 1.12), Vector2(x + 1.17, z - 0.88), Vector2(x + 1.38, z + 0.18), Vector2(x + 0.78, z + 0.98), Vector2(x - 0.95, z + 1.02), Vector2(x - 1.48, z + 0.24)]
		floor_patch(falls, "LimestoneWaterStep", shelf_points, 0.38 + i * 0.34, ["8b9180", "9ca08d", "767d70"][i % 3])
		var water_points: Array[Vector2] = [Vector2(x - 1.0, z - 0.58), Vector2(x - 0.24, z - 0.82), Vector2(x + 0.94, z - 0.55), Vector2(x + 1.02, z + 0.14), Vector2(x + 0.44, z + 0.65), Vector2(x - 0.78, z + 0.60), Vector2(x - 1.12, z + 0.12)]
		floor_patch(falls, "BlueGreenWaterTier", water_points, 0.59 + i * 0.34, "3b6062")
		for k in range(5):
			var stone_angle := -0.9 + float(k) * 0.46 + i * 0.18
			var stone_pos := Vector3(x + cos(stone_angle) * 1.12, 0.32 + i * 0.34, z + sin(stone_angle) * 0.82)
			faceted_rock(falls, "CalcifiedShelfStone", stone_pos, Vector3(0.22 + (k % 2) * 0.08, 0.16, 0.26), ["737b70", "899084", "68736d"][k % 3], 7)
		var ribbon_points: Array[Vector2] = [Vector2(x - 0.30, z - 0.98), Vector2(x + 0.22, z - 1.00), Vector2(x + 0.28, z - 0.18), Vector2(x - 0.22, z - 0.12)]
		floor_patch(falls, "WaterfallRibbon", ribbon_points, 0.32 + i * 0.34, "507477")
	for j in range(4):
		var px := -8.4 + j * 1.15
		var pz := 0.7 - j * 0.72
		var pool_points: Array[Vector2] = [Vector2(px - 1.7 + j * 0.08, pz - 1.02), Vector2(px - 0.55, pz - 1.22), Vector2(px + 1.52 - j * 0.12, pz - 0.68), Vector2(px + 1.68 - j * 0.12, pz + 0.48), Vector2(px + 0.48, pz + 1.03), Vector2(px - 1.42, pz + 0.72)]
		floor_patch(water_root, "ColdPool", pool_points, 0.10, "31565b")
		faceted_rock(water_root, "PoolEdgeRock", Vector3(px - 1.42, 0.02, pz - 0.35), Vector3(0.32, 0.18, 0.42), "66736b", 7)
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
	var lower_pool_points: Array[Vector2] = [Vector2(-10.2, 5.5), Vector2(-9.0, 4.25), Vector2(-6.8, 4.05), Vector2(-4.55, 5.0), Vector2(-4.0, 6.5), Vector2(-5.2, 7.75), Vector2(-7.8, 8.18), Vector2(-9.75, 7.25)]
	floor_patch(lower, "LowerPoolWater", lower_pool_points, 0.075, "294e56")
	for p in [Vector3(-9.35, 0.02, 5.75), Vector3(-5.25, 0.02, 5.1), Vector3(-4.75, 0.02, 7.25), Vector3(-8.6, 0.02, 7.85)]:
		faceted_rock(lower, "LowerPoolEdgeRock", p, Vector3(0.42, 0.18, 0.55), "5f6d64", 7)
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
	for path in ["CaveTerrain", "CaveRockShell", "CaveArchitecture", "WaterfallsAndPools", "BoneBurialFields", "MineWorks", "LowerStalactitePools", "CaveLifeAndRemains", "EntranceTransition"]:
		var section := scene_root.get_node_or_null(path) as Node3D
		if section:
			section.scale = factor

func make_entry_and_exit() -> void:
	var entry := group(scene_root, "EntranceTransition")
	for p in [Vector3(-1.65, 1.25, 8.7), Vector3(-1.35, 2.65, 8.72), Vector3(1.65, 1.25, 8.7), Vector3(1.35, 2.7, 8.72), Vector3(-0.7, 3.08, 8.72), Vector3(0.7, 3.08, 8.72)]:
		faceted_rock(entry, "EntryRimRock", p, Vector3(0.52, 0.85, 0.58), "59645a", 8)
	var entry_shadow := PackedVector3Array([Vector3(-1.03, 0.34, 9.16), Vector3(-0.74, 2.68, 9.16), Vector3(0.74, 2.68, 9.16), Vector3(1.03, 0.34, 9.16), Vector3(-0.75, 0.18, 9.16), Vector3(0.75, 0.18, 9.16)])
	solid(entry, "EntryDarkness", entry_shadow, PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 0, 3, 4, 3, 5]), "202823", Vector3.FORWARD)
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

