extends SceneTree

var failures := 0

func _initialize() -> void:
	var world := load("res://burial_left_cave/world.tscn").instantiate() as Node3D
	check(world != null, "saved cave scene instantiates")
	check(world.scene_file_path == "res://burial_left_cave/world.tscn", "cave is a saved editable scene")
	for path in ["CaveTerrain", "CaveRockShell", "WaterfallsAndPools", "BoneBurialFields", "MineWorks", "LowerStalactitePools", "EntranceTransition", "RenderRig/VillageCamera"]:
		check(world.get_node_or_null(path) != null, path + " is present as an editable group")
	var portal := world.get_node_or_null("EntranceTransition/ExitToNorthernRidge") as Area3D
	check(portal != null and portal.monitoring and portal.get_meta("target_scene") == "res://village/main.tscn", "cave exit portal is linked to the outdoor entry")
	check(world.find_children("*", "MeshInstance3D", true, false).size() > 250, "cave has substantial saved geometry")
	check(world.find_children("*", "CollisionShape3D", true, false).size() >= 5, "floor, walls and portal collisions are saved")
	check(world.get_node("CaveTerrain").get_node_or_null("DisconnectedPlatforms") != null and world.get_node("CaveTerrain/DisconnectedPlatforms").get_child_count() >= 7, "cave uses multiple disconnected platforms")
	check(world.get_node("CaveTerrain/BranchingStonePaths").get_child_count() >= 6, "cave has branching narrow paths")
	check(world.get_meta("layout_revision", 0) == 2, "branched cave layout revision is saved")
	check(is_equal_approx(world.get_meta("layout_scale", 0.0), 2.8), "cave layout is enlarged for the wider reference composition")
	check(world.get_node_or_null("CaveLifeAndRemains/BoneDisplayRacks") != null and world.get_node_or_null("CaveLifeAndRemains/MineToolsAndCrates") != null, "cave detail groups are saved")
	check(world.get_node_or_null("CaveTerrain/MapBoundaries") != null and world.get_node_or_null("CaveTerrain/SavedWalkCollisions/VoidSafetyCatch") != null, "map perimeter and void safety boundaries are saved")
	var main_text := FileAccess.get_file_as_string("res://burial_left_cave/main.tscn")
	check(main_text.contains("res://burial_left_cave/world.tscn"), "cave main entry uses the saved cave world")
	world.free()
	print("BURIAL LEFT CAVE VALIDATION FINISHED / failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		print("FAIL: ", label)
