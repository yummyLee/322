extends "res://northern_ridge/tools/extend_north.gd"
## Local offline edit of the saved scene. Never rebuild the forest/village.
var gate_base: float

func _initialize() -> void:
	if not "--apply" in OS.get_cmdline_user_args():
		quit(1)
		return
	apply_edit.call_deferred()

func rise_at(x: float,z: float) -> float:
	var width:=1.0-smoothstep(1.5,5.6,absf(x+55.0))
	var front:=1.0-smoothstep(-48.0,-47.0,z)
	var back:=smoothstep(-55.0,-51.0,z)
	return maxf(0.0,gate_base+2.72-(0.07+super.elevation(x,z)))*width*front*back

func raised_normal(x: float,z: float,old: Vector3) -> Vector3:
	var grad_x: float=-old.x/maxf(old.y,0.01)+(rise_at(x+0.1,z)-rise_at(x-0.1,z))/0.2
	var grad_z: float=-old.z/maxf(old.y,0.01)+(rise_at(x,z+0.1)-rise_at(x,z-0.1))/0.2
	return Vector3(-grad_x,1,-grad_z).normalized()

func apply_edit() -> void:
	shader=load("res://village/style.gdshader")
	natural_noise.seed=917369
	natural_noise.frequency=0.12
	rng.seed=919331
	var source_path:=NORTH_OUTPUT
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):source_path=arg.trim_prefix("--source=")
	scene_root=load(source_path).instantiate()
	if scene_root.get_meta("embedded_cave_revision",0)>=1:
		print("Saved cave is already embedded; preserving editor changes.")
		scene_root.free()
		quit()
		return
	root.add_child(scene_root)
	var gate: Node3D=scene_root.get_node("RootWrappedStoneGate")
	gate_base=gate.position.y
	for chunk in scene_root.get_node("ContinuousForestGround").get_children():
		if not chunk.has_node("BlendedTerrain"):continue
		var visual: MeshInstance3D=chunk.get_node("BlendedTerrain")
		var arrays: Array=visual.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var touched:=false
		for i in vertices.size():
			var p: Vector3=vertices[i]+chunk.position
			var lift:=rise_at(p.x,p.z)
			if lift<=0.000001:continue
			touched=true
			vertices[i].y+=lift
			normals[i]=raised_normal(p.x,p.z,normals[i])
		if not touched:continue
		var kept:=PackedInt32Array()
		var ids: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for i in range(0,ids.size(),3):
			var center: Vector3=(vertices[ids[i]]+vertices[ids[i+1]]+vertices[ids[i+2]])/3.0+chunk.position
			# Open only the steep face in front of the roof. Retain terrain above the tunnel.
			if absf(center.x+55)<1.0 and center.z>-48.0 and center.z<-47.0:continue
			kept.append_array(PackedInt32Array([ids[i],ids[i+1],ids[i+2]]))
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_INDEX]=kept
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		visual.mesh=mesh
		var shape:=mesh.create_trimesh_shape()
		shape.backface_collision=true
		chunk.get_node("GroundCollision/MatchingSurface").shape=shape
	for child in scene_root.get_children():
		if child==gate or child.name=="ContinuousForestGround":continue
		lift_saved_objects(child)
	for child in gate.get_children():
		if str(child.name).begins_with("OldPine") or str(child.name).begins_with("Apron"):
			var p: Vector3=child.global_position
			child.position.y+=rise_at(p.x,p.z)
	for branch_group in [gate.get_node("WrappingRoots"),gate.get_node("RootsFromAncientTree")]:
		for segment in branch_group.find_children("*","MeshInstance3D",true,false):
			if not segment.mesh is CylinderMesh:continue
			var old_mesh: CylinderMesh=segment.mesh
			var a: Vector3=segment.global_transform*Vector3(0,-old_mesh.height/2,0)
			var b: Vector3=segment.global_transform*Vector3(0,old_mesh.height/2,0)
			a.y+=rise_at(a.x,a.z)
			b.y+=rise_at(b.x,b.z)
			segment.mesh=old_mesh.duplicate()
			segment.mesh.height=a.distance_to(b)
			segment.global_position=(a+b)*0.5
			segment.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	var passage: Node3D=gate.get_node("PassageCollisions")
	box(gate,"BuriedPassageCeiling",Vector3(0,2.43,-0.35),Vector3(2.35,0.24,2.4),"6b7561")
	collision_box(passage,"PassageCeiling",Vector3(0,2.43,-0.35),Vector3(2.35,0.24,2.4))
	# A flush entry ramp avoids a box floor's vertical lip catching the player capsule.
	var floor_vertices:=PackedVector3Array()
	var floor_normals:=PackedVector3Array()
	var floor_ids:=PackedInt32Array()
	var front_y:=0.07+super.elevation(-55,-46.5)+0.015
	for i in range(13):
		var z: float=-46.5-i*0.25
		var y:=lerpf(front_y,gate_base+0.08,smoothstep(0.0,1.5,-46.5-z))
		for x in [-0.85,0.85]:
			floor_vertices.append(Vector3(x,y-gate_base,z+48))
			floor_normals.append(Vector3.UP)
		if i<12:
			var a:=i*2
			floor_ids.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))
	var floor_arrays:=[]
	floor_arrays.resize(Mesh.ARRAY_MAX)
	floor_arrays[Mesh.ARRAY_VERTEX]=floor_vertices
	floor_arrays[Mesh.ARRAY_NORMAL]=floor_normals
	floor_arrays[Mesh.ARRAY_INDEX]=floor_ids
	var floor_mesh:=ArrayMesh.new()
	floor_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,floor_arrays)
	mesh_node(gate,"RecessedWornFloor",floor_mesh,Vector3.ZERO,"8f8869")
	var floor_shape:=CollisionShape3D.new()
	floor_shape.name="FlushTunnelFloor"
	floor_shape.shape=floor_mesh.create_trimesh_shape()
	floor_shape.shape.backface_collision=true
	passage.add_child(floor_shape)
	floor_shape.owner=scene_root
	gate.get_node("EntryPoint").position.y=0.095
	scene_root.set_meta("embedded_cave_revision",1)
	assert(save_scene(NORTH_OUTPUT)==OK)
	print("LOCAL CAVE EDIT SAVED")
	quit()

func lift_saved_objects(node: Node) -> void:
	if node is Node3D and Vector2(node.position.x,node.position.z).length()>0.15:
		var p: Vector3=node.global_position
		node.position.y+=rise_at(p.x,p.z)
		return
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		var arrays: Array=node.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var changed:=false
		for i in vs.size():
			var p: Vector3=node.global_transform*vs[i]
			var lift:=rise_at(p.x,p.z)
			if lift>0.000001:
				p.y+=lift
				vs[i]=node.global_transform.affine_inverse()*p
				changed=true
		if changed:
			arrays[Mesh.ARRAY_VERTEX]=vs
			var mesh:=ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			node.mesh=mesh
	for child in node.get_children():lift_saved_objects(child)
