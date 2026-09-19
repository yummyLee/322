extends SceneTree

const WORLD := "res://burial_left_cave/world.tscn"
const BUILDER := "res://burial_left_cave/tools/build_scene.gd"
const STYLE := "res://burial_left_cave/style.gdshader"

func _initialize() -> void:
	var failures: Array[String] = []
	var world := FileAccess.get_file_as_string(WORLD)
	var builder := FileAccess.get_file_as_string(BUILDER)
	var style := FileAccess.get_file_as_string(STYLE)
	for forbidden in ["GroundCell_", "Segment_", "LowStoneKerb", "ColdLightStone", "J10_CalcifiedStep", "J13_NameBox", "Footprint", "WheelRut", "BoneDragMark", "BrokenWearGroove", "ErosionCrack"]:
		if world.find(forbidden) >= 0: failures.append("fragmented legacy geometry remains: %s" % forbidden)
	if style.find("floor(world_position*13.0") >= 0 or style.find("hash3") >= 0:
		failures.append("high-frequency point texture remains in cave shader")
	for region in ["J0_EntranceHall","J8_OldCartYard","J2_BoneSortingLedge","J4_UpperFissureWalk","J5_BoneCairnHall","J6_SunkenPit","J3_SeepingThroat","J9_StonePillarForest","J10_GreyWaterTerraces","J7_SealedWestFissure","J12_CollapseQuarry","J13_NameWallChamber"]:
		if world.find("node name=\"%s\"" % region) < 0: failures.append("missing preserved region: %s" % region)
	for required in ["RegionEntrances","SavedWallCollisions","J0_J1_Entrance","J12_J13_Entrance","J1_AbandonedCoffin","J5_BrokenCoffin","OverturnedCorpseCart","StonePillar","RoadShoulderStone","GroundCollision"]:
		if world.find(required) < 0: failures.append("missing editable group/asset: %s" % required)
	if builder.find("func mesh_collision") < 0 or builder.find("surface_kind\",\"continuous_region") < 0 or builder.find("surface_kind\",\"continuous_road") < 0:
		failures.append("continuous surface policy is missing")
	if builder.find("func smooth_route") < 0 or builder.find("var route := smooth_route(points)") < 0:
		failures.append("corridors are not generated from smooth routes")
	if builder.find("func broad_wear_patch") < 0 or builder.find("func debris_cluster") < 0:
		failures.append("ground variation still uses point-only detail")
	if world.count("metadata/surface_kind = \"continuous_region\"") < 12: failures.append("preserved regions are not continuous surfaces")
	if world.count("metadata/surface_kind = \"continuous_road\"") < 10: failures.append("continuous marked roads are missing")
	if world.count("BoundaryCollision_") < 8: failures.append("enclosed region wall collisions are missing")
	if world.count("metadata/detail_kind = \"broad_wear_patch\"") < 10: failures.append("continuous ground wear patches are missing")
	if failures.is_empty():
		print("PASS: preserved J0-J13 region structure, enclosed walls, continuous surfaces, marked routes and collisions")
		quit(0)
	for failure in failures: push_error(failure)
	quit(1)

