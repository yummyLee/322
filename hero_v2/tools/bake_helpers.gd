extends SceneTree
# Authoring-only helpers. Nodes are owned and baked; no runtime dependency.
var scene_root: Node3D
var palette: Dictionary = {}
var meshes: Dictionary = {}
var shader: Shader
var rng := RandomNumberGenerator.new()

func group(parent: Node, label: String, pos := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node, true)
	node.owner = scene_root
	node.position = pos
	return node

func mat(hex: String) -> Material:
	if not palette.has(hex):
		if shader:
			var value := ShaderMaterial.new()
			value.shader = shader
			value.set_shader_parameter("base_color", Color(hex))
			palette[hex] = value
		else:
			var value := StandardMaterial3D.new()
			value.albedo_color = Color(hex)
			value.roughness = 1
			palette[hex] = value
	return palette[hex]

func mesh_node(parent: Node, label: String, mesh: Mesh, pos: Vector3, hex: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat(hex)
	parent.add_child(node, true)
	node.owner = scene_root
	node.position = pos
	return node

func box(parent: Node, label: String, pos: Vector3, dimensions: Vector3, hex: String) -> MeshInstance3D:
	var key := "box" + str(dimensions)
	if not meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = dimensions
		meshes[key] = mesh
	return mesh_node(parent, label, meshes[key], pos, hex)

func cylinder(parent: Node, label: String, pos: Vector3, radius: float, height: float, hex: String, top: float = -1, segments: int = 8) -> MeshInstance3D:
	var key := "cyl%s,%s,%s,%s" % [radius, height, top, segments]
	if not meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = radius
		mesh.top_radius = radius if top < 0 else top
		mesh.height = height
		mesh.radial_segments = segments
		mesh.rings = 1
		meshes[key] = mesh
	return mesh_node(parent, label, meshes[key], pos, hex)

func ball(parent: Node, label: String, pos: Vector3, scale_value: Vector3, hex: String) -> MeshInstance3D:
	if not meshes.has("ball"):
		var mesh := SphereMesh.new()
		mesh.radius = 1
		mesh.height = 2
		mesh.radial_segments = 7
		mesh.rings = 3
		meshes["ball"] = mesh
	var node := mesh_node(parent, label, meshes["ball"], pos, hex)
	node.scale = scale_value
	return node

func beam(parent: Node, label: String, a: Vector3, b: Vector3, radius: float, hex: String) -> MeshInstance3D:
	var node := cylinder(parent, label, (a+b)/2, radius, a.distance_to(b), hex)
	var direction := (b-a).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		node.quaternion = Quaternion(Vector3.UP, direction)
	return node

func solid(parent: Node, label: String, vertices: PackedVector3Array, indices: PackedInt32Array, hex: String, normal_override := Vector3.ZERO) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices:
		if normal_override != Vector3.ZERO:
			surface.set_normal(normal_override)
		surface.add_vertex(vertices[i])
	if normal_override == Vector3.ZERO:
		surface.generate_normals()
	return mesh_node(parent, label, surface.commit(), Vector3.ZERO, hex)

func save_scene(path: String) -> int:
	var packed := PackedScene.new()
	var err := packed.pack(scene_root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("Saved ", path, " result=", err, " nodes=", scene_root.find_children("*", "", true, false).size())
	return err


