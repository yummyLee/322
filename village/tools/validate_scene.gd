extends SceneTree

func _initialize() -> void:
	var scene := load("res://village/yao_village.tscn") as PackedScene
	assert(scene != null)
	var world := scene.instantiate()
	assert(world.get_script() == null, "Saved world must not rebuild itself at runtime")
	var nodes := world.find_children("*", "", true, false)
	var mesh_count := 0
	for node in nodes:
		assert(node.owner == world, "Unowned node: " + str(node.name))
		if node is MeshInstance3D:
			mesh_count += 1
			assert(node.mesh != null)
			assert(node.transform.is_finite())
	for path in ["Buildings/AncestralHall", "Buildings/NorthFarmhouse", "Buildings/KilnWorkshop", "VillageLife/VillageEntrance", "VillageLife/VillageWell", "VillageLife/StoneMill", "ForestBoundary", "VegetableGardens", "RenderRig/VillageCamera", "RenderRig/AfternoonSun"]:
		assert(world.has_node(path), "Missing landmark: " + path)
	var post := world.get_node("RenderRig/VillageCamera/PixelOutline") as MeshInstance3D
	assert(not post.visible, "Postprocess must not cover the editor")
	assert(post.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	# Confirm an editor-style transform edit survives packing and instantiation.
	var house := world.get_node("Buildings/NorthFarmhouse") as Node3D
	var edited_position := house.position + Vector3(0.5,0,0.25)
	house.position = edited_position
	var edited := PackedScene.new()
	assert(edited.pack(world) == OK)
	var restored := edited.instantiate()
	assert((restored.get_node("Buildings/NorthFarmhouse") as Node3D).position.is_equal_approx(edited_position))
	print("PASS: owned nodes=",nodes.size()," meshes=",mesh_count,"; landmarks, editor visibility, transform persistence")
	restored.free()
	world.free()
	quit()
