extends "res://burial_ridge/tools/sculpt_saved_terrain.gd"
func _initialize() -> void:
	natural_noise.seed=917369
	natural_noise.frequency=0.12
	shader=load("res://village/style.gdshader")
	scene_root=load(OUTPUT).instantiate()
	for b in scene_root.get_node("ExplorationLandmarks").get_children():
		if b.has_node("TerrainFittedEntryFloor"): continue
		var old:=b.get_node_or_null("WallCollisions/ApronSurface")
		if old: old.free()
		b.get_node("WornEntryApron").free()
		b.get_node("InteriorFloor").free()
		b.get_node("HandLaidStonework/WornThreshold").free()
		var vs:=PackedVector3Array()
		var idx:=PackedInt32Array()
		var depth:=4.2 if b.name=="DomeStoneTomb" else 4.6
		for iz in range(13):
			for ix in range(3):
				var x: float=(ix-1)*0.77
				var z: float=-depth/2+0.3+iz*(depth+0.95)/12
				var y: float=0.079+elevation(b.position.x+x,b.position.z+z)-b.position.y
				vs.append(Vector3(x,y,z))
		for iz in range(12):
			for ix in range(2):
				var a:=iz*3+ix
				idx.append_array(PackedInt32Array([a,a+1,a+3,a+1,a+4,a+3]))
		var floor:=solid(b,"TerrainFittedEntryFloor",vs,idx,"8f9884",Vector3.UP)
		floor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for label in ["EntryPoint","ExitSpawn"]:
			var m: Marker3D=b.get_node(label)
			m.position.y=0.085+elevation(b.position.x,b.position.z+m.position.z)-b.position.y
	assert(save_scene(OUTPUT)==OK)
	scene_root.free()
	quit()
