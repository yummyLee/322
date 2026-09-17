extends "res://village/tools/refine_lived_in_environment.gd"
func _initialize() -> void:
	shader=load("res://village/style.gdshader")
	natural_noise.seed=917369
	natural_noise.frequency=0.12
	scene_root=load(OUTPUT).instantiate()
	if scene_root.has_meta("landmark_access_finished"):
		quit(1)
		return
	# Fix the dome's outer winding; each stone remains a separate editable mesh.
	for stone in scene_root.get_node("ExplorationLandmarks/DomeStoneTomb/StoneDome").get_children():
		if not str(stone.name).begins_with("DomeVoussoir"): continue
		var old: PackedVector3Array=stone.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var s:=SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0,old.size(),3):
			s.add_vertex(old[i]);s.add_vertex(old[i+2]);s.add_vertex(old[i+1])
		s.generate_normals()
		stone.mesh=s.commit()
	# Lift the nearer tree away from the tomb silhouette and doorway.
	for name in ["DeadTree_01","DeadTree_04"]:
		var t: Node3D=scene_root.get_node("BareRidgeTrees/"+name)
		var previous:=t.position
		t.position=Vector3(-85.0,0,-29.5) if name=="DeadTree_01" else Vector3(-57.5,0,-28.5)
		t.position.y=elevation(t.position.x,t.position.z)
		var c: CollisionShape3D=scene_root.get_node("SavedWalkCollisions/"+name+"_Trunk")
		c.position+=t.position-previous
	# Break the old continuous rock line at the new shrine's doorway.
	for stone in scene_root.get_node("BrokenRockTerraces").find_children("*","MeshInstance3D",true,false):
		var p: Vector3=stone.position
		if absf(p.x+62)<2.7 and p.z>-27.2 and p.z<-19.5:
			stone.position.x+=5.8
			stone.position.y+=elevation(stone.position.x,p.z)-elevation(p.x,p.z)
	for building in scene_root.get_node("ExplorationLandmarks").get_children():
		building.get_node("ReservedEntrance").collision_mask=1
	scene_root.set_meta("landmark_access_finished",true)
	assert(save_scene(OUTPUT)==OK)
	scene_root.free()
	# Avoid serializing thousands of accidental overrides on the external west scene.
	scene_root=load(VILLAGE).instantiate()
	var old_ridge:=scene_root.get_node("WesternBurialRidge")
	var original_transform: Transform3D=old_ridge.transform
	scene_root.set_editable_instance(old_ridge,false)
	old_ridge.free()
	var ridge: Node3D=load(OUTPUT).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	ridge.name="WesternBurialRidge"
	scene_root.add_child(ridge)
	ridge.owner=scene_root
	ridge.transform=original_transform
	scene_root.set_editable_instance(ridge,false)
	assert(save_scene(VILLAGE)==OK)
	var f:=FileAccess.open(VILLAGE,FileAccess.READ_WRITE)
	f.seek_end();f.store_string("\n[editable path=\"WesternBurialRidge\"]\n");f.close()
	scene_root.free()
	quit()
