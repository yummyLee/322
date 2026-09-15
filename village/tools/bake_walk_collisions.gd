extends SceneTree

func _initialize() -> void:
	if "--bake" not in OS.get_cmdline_user_args() or (FileAccess.file_exists("res://village/hero/world_collisions.tscn") and "--overwrite" not in OS.get_cmdline_user_args()):
		quit(1)
		return
	var world := load("res://village/yao_village.tscn").instantiate() as Node3D
	root.add_child(world)
	var body := StaticBody3D.new()
	body.name = "WalkCollisions"
	var ground := CollisionShape3D.new()
	ground.name = "Ground"
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(80,0.4,64)
	ground.shape = floor_shape
	ground.position.y = -0.13
	body.add_child(ground)
	ground.owner = body
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		if not (str(mesh.name).begins_with("PlasterWalls") or str(mesh.name).begins_with("Trunk") or str(mesh.name).begins_with("WallBody")):
			continue
		var collision := CollisionShape3D.new()
		collision.name = str(mesh.get_parent().name)+"_"+str(mesh.name)
		collision.shape = mesh.mesh.create_convex_shape()
		body.add_child(collision,true)
		collision.owner = body
		collision.transform = mesh.transform
		var ancestor: Node = mesh.get_parent()
		while ancestor != world:
			if ancestor is Node3D:
				collision.transform = ancestor.transform * collision.transform
			ancestor = ancestor.get_parent()
	for side in [-1,1]:
		for axis in [0,2]:
			var fence := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1,8,64) if axis == 0 else Vector3(80,8,1)
			fence.shape = box
			body.add_child(fence,true)
			fence.owner = body
			fence.position[axis] = side * (40 if axis == 0 else 32)
	var packed := PackedScene.new()
	packed.pack(body)
	ResourceSaver.save(packed,"res://village/hero/world_collisions.tscn")
	print("Baked collision shapes: ",body.get_child_count())
	body.free()
	world.free()
	quit()

