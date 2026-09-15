extends SceneTree
# One-shot editor operation on the saved scene, never a runtime dependency.
var hero: Node3D

func _initialize() -> void:
	if "--bake" not in OS.get_cmdline_user_args() or "--overwrite" not in OS.get_cmdline_user_args():
		quit(1)
		return
	hero = load("res://village/hero/hero.tscn").instantiate()
	if hero.get_node("Visual/Hips/Torso/Tunic").mesh is ArrayMesh:
		push_error("Refinement already applied. Edit the saved scene directly.")
		hero.free()
		quit(1)
		return
	for node in hero.find_children("*", "MeshInstance3D", true, false):
		if not node.mesh is BoxMesh:
			continue
		var size: Vector3 = node.mesh.size
		var label := str(node.name)
		if label.begins_with("Fringe") or label.begins_with("Sideburn") or label == "Tail":
			node.mesh = rings(size, [0.05,0.85,1.0,0.6], [-0.5,-0.18,0.28,0.5], 7)
		elif label in ["Tunic", "Hem", "Trousers", "Sleeve", "Forearm", "Thigh", "Shin", "Hand", "Face", "Jaw", "HairBack", "HipPouch", "Boot", "Sole"] or label.begins_with("LegWrap") or label == "WristWrap" or label == "Belt":
			var widths := [0.78,1.0,1.0,0.78]
			if label == "Tunic": widths = [0.78,0.88,1.0,0.66]
			if label in ["Sleeve","Thigh"]: widths = [0.72,0.84,1.0,0.8]
			if label == "Face": widths = [0.57,0.85,1.0,0.83]
			node.mesh = rings(size,widths,[-0.5,-0.3,0.28,0.5],12)
	# Round shoulders and hands instead of square blocks. Saved pivots stay intact.
	for side in ["Left", "Right"]:
		var arm: Node3D = hero.get_node("Visual/Hips/Torso/"+side+"Arm")
		arm.position.x *= 0.91
		add_ellipsoid(arm,"Shoulder",Vector3(0,-0.035,0),Vector3(0.105,0.115,0.115),"737469")
		var elbow: Node3D = arm.get_node("Elbow")
		add_ellipsoid(elbow,"ElbowJoint",Vector3.ZERO,Vector3(0.074,0.085,0.088),"78796b")
		var head: Node3D = hero.get_node("Visual/Hips/Torso/Head")
		var sign_value := -1.0 if side == "Left" else 1.0
		add_ellipsoid(head,side+"Cheek",Vector3(sign_value*0.123,0.14,0.155),Vector3(0.064,0.071,0.056),"c8ad8f")
	var head: Node3D = hero.get_node("Visual/Hips/Torso/Head")
	head.get_node("HairCrown").position = Vector3(0,0.37,-0.008)
	for i in range(9):
		var angle := TAU*i/9.0
		var tuft := add_ellipsoid(head,"LayeredHair%02d"%i,Vector3(sin(angle)*0.21,0.40+0.025*sin(i*2.1),cos(angle)*0.17),Vector3(0.095,0.145,0.09),"303638" if i%2 else "272d30")
		tuft.rotation.z = -sin(angle)*0.35
	var animator: AnimationPlayer = hero.get_node("AnimationPlayer")
	for clip in ["idle","walk","run"]:
		var anim := animator.get_animation(clip)
		for t in range(anim.get_track_count()):
			if not str(anim.track_get_path(t)).ends_with(":rotation"):
				continue
			for k in range(anim.track_get_key_count(t)):
				var value: Vector3 = anim.track_get_key_value(t,k)
				value.x = -value.x
				anim.track_set_key_value(t,k,value)
	var packed := PackedScene.new()
	packed.pack(hero)
	var err := ResourceSaver.save(packed,"res://village/hero/hero.tscn")
	print("Refined saved meshes and corrected +Z gait: ",err)
	hero.free()
	quit(err)

func add_ellipsoid(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 1.0
	node.material_override = mat
	parent.add_child(node)
	node.owner = hero
	node.position = pos
	node.scale = size
	return node

func rings(size: Vector3, widths: Array, heights: Array, segments: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	for row in range(heights.size()):
		for j in range(segments):
			var a := TAU*j/segments
			points.append(Vector3(cos(a)*size.x*0.5*widths[row],size.y*heights[row],sin(a)*size.z*0.5*widths[row]))
	for row in range(heights.size()-1):
		for j in range(segments):
			var a := row*segments+j
			var b := row*segments+(j+1)%segments
			for index in [a,a+segments,b,b,a+segments,b+segments]: surface.add_vertex(points[index])
	for j in range(segments):
		for point in [Vector3(0,-size.y*0.5,0),points[j],points[(j+1)%segments]]: surface.add_vertex(point)
		var top := (heights.size()-1)*segments
		for point in [Vector3(0,size.y*0.5,0),points[top+(j+1)%segments],points[top+j]]: surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()
