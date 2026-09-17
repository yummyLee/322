extends SceneTree
var failures := 0

func _initialize() -> void:
	var scene := load("res://burial_ridge/world.tscn").instantiate() as Node3D
	var shortest := INF
	var tallest := 0.0
	for grave in scene.get_node("Graveyard").get_children():
		if str(grave.name).begins_with("Grave_"):
			var height := measure(grave,Transform3D.IDENTITY).size.y
			shortest = minf(shortest,height)
			tallest = maxf(tallest,height)
			if height>1.2:
				failures += 1
	print("ALL 22 GRAVES height range=",shortest," to ",tallest)
	for label in ["Graveyard/Grave_01","Graveyard/Grave_05","Graveyard/TallBoundaryStele","Graveyard/RidgeStoneShrine","Graveyard/AbandonedHandcart","ForestHomesteads/GraveKeeperCottage"]:
		var node := scene.get_node(label) as Node3D
		var bounds := measure(node,Transform3D.IDENTITY)
		print(label," bounds=",bounds.size)
		if label.begins_with("Graveyard/") and not label.ends_with("AbandonedHandcart"):
			if bounds.size.y >= 1.86:
				failures += 1
	var player := load("res://hero_v2/traveler.tscn").instantiate() as Node3D
	var capsule := player.get_node("BodyCollision").shape as CapsuleShape3D
	print("PLAYER collision height=",capsule.height)
	var walls := scene.get_node("ForestHomesteads/GraveKeeperCottage/DoorFrame") as MeshInstance3D
	print("Retained door frame height=",walls.mesh.get_aabb().size.y*walls.scale.y)
	if walls.mesh.get_aabb().size.y*walls.scale.y < capsule.height:
		failures += 1
	print("HUMAN SCALE CHECK / failures=",failures)
	player.free()
	scene.free()
	quit(failures)

func measure(node: Node3D, inherited: Transform3D) -> AABB:
	var t := inherited*node.transform
	var result := AABB()
	var populated := false
	if node is MeshInstance3D and node.mesh:
		result = t*node.mesh.get_aabb()
		populated = true
	for child in node.get_children():
		if child is Node3D:
			var other := measure(child,t)
			if other.size.length()>0:
				result = result.merge(other) if populated else other
				populated = true
	return result
