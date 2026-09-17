extends "sculpt_saved_terrain.gd"
func _initialize() -> void:
	var world := load("res://burial_ridge/world.tscn").instantiate() as Node3D
	natural_noise.seed = 917369
	natural_noise.frequency = 0.12
	var materials: Dictionary = {}
	for mesh in world.get_node("TerrainAndPaths/HandWorkedRoads").find_children("*","MeshInstance3D",true,false):
		if mesh.mesh is ArrayMesh and mesh.name != "BentBlades":
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var p: Vector3 = vertices[0]
			var original_height := p.y-elevation(p.x,p.z)
			var order := clampi(roundi((original_height-0.13)*1000),0,60)
			var color: Color = mesh.material_override.get_shader_parameter("base_color")
			var key := str(color)+":"+str(order)
			if not materials.has(key):
				var paint := ShaderMaterial.new()
				paint.shader = load("res://burial_ridge/ground_paint.gdshader")
				paint.set_shader_parameter("base_color",color)
				paint.set_meta("village_toon",true)
				paint.render_priority = order
				materials[key] = paint
			mesh.material_override = materials[key]
		if str(mesh.name).begins_with("InterruptedCartRut"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var packed := PackedScene.new()
	packed.pack(world)
	var err := ResourceSaver.save(packed,"res://burial_ridge/world.tscn")
	world.free()
	print("Ground paint no longer casts duplicate shadows: ",err)
	quit(err)
