extends SceneTree

const WORLD := "res://burial_left_cave/world.tscn"
const BUILDER := "res://burial_left_cave/tools/build_scene.gd"

func _initialize() -> void:
	var failures: Array[String] = []
	var world := FileAccess.get_file_as_string(WORLD)
	var builder := FileAccess.get_file_as_string(BUILDER)
	for forbidden in ["LowStoneKerb", "SlopeMarker", "ColdLightStone", "J10_CalcifiedStep", "J13_NameBox"]:
		if world.find(forbidden) >= 0:
			failures.append("forbidden legacy geometry: %s" % forbidden)
	for required in ["RegionEntrances", "J0_J1_Entrance", "J12_J13_Entrance", "J1_AbandonedCoffin", "J5_BrokenCoffin", "OverturnedCorpseCart", "StonePillar", "RoadsideWallStone"]:
		if world.find(required) < 0:
			failures.append("missing editable asset/group: %s" % required)
	if builder.find("const TERRAIN_CELL := 0.60") < 0:
		failures.append("terrain cell is not locked below half-player proxy")
	if builder.find("func smooth_route") < 0 or builder.find("var route := smooth_route(points)") < 0:
		failures.append("corridors are not generated from smooth routes")
	var ground_cells := world.count("GroundCell_")
	var path_cells := world.count("Segment_%03d")
	if ground_cells < 1000:
		failures.append("too few saved terrain cells: %d" % ground_cells)
	if path_cells < 100:
		failures.append("too few saved path cells: %d" % path_cells)
	if failures.is_empty():
		print("PASS: scene specification, editable assets, entrances, smooth routes, and fine cells")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
