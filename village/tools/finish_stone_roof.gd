extends "res://burial_ridge/tools/bake_helpers.gd"
func _initialize() -> void:
	shader=load("res://village/style.gdshader")
	rng.seed=917420
	scene_root=load("res://burial_ridge/world.tscn").instantiate()
	var building:=scene_root.get_node("ExplorationLandmarks/StoneAncestralShrine")
	var roof_node: Node3D=building.get_node("StoneGabledRoof")
	if roof_node.has_node("WeatheredStoneSlab"):
		push_error("Roof finish already saved; edit the saved slabs directly.")
		quit(1)
		return
	for c in roof_node.get_children(): c.free()
	roof_node.rotation=Vector3.ZERO
	var extent:=2.40
	var rise:=1.25
	var pitch:=atan2(rise,extent)
	var length:=sqrt(extent*extent+rise*rise)
	for side in [-1,1]:
		var under:=box(roof_node,"SlateRoofBed",Vector3(side*extent/2,2.52+rise/2,0),Vector3(length,0.12,5.22),"777f70")
		under.rotation.z=-side*pitch
		for row in range(6):
			var t: float=(row+0.5)/6
			for col in range(8):
				var slab:=box(roof_node,"WeatheredStoneSlab",Vector3(side*extent*t,2.52+rise*(1-t)+0.11,-2.3+col*0.66),Vector3(length/6+0.035,0.10,0.625),["909782","9da38c","858e7a","a1a590"][(col+row*2)%4])
				slab.rotation.z=-side*pitch
				slab.position.y+=rng.randf_range(-0.012,0.012)
		beam(roof_node,"OldStoneEave",Vector3(side*extent,2.53,-2.65),Vector3(side*extent,2.53,2.65),0.085,"919983")
	for side in [-1,1]:
		var z: float=side*2.33
		var vertices:=PackedVector3Array([Vector3(-2.05,2.50,z),Vector3(0,3.76,z),Vector3(2.05,2.50,z)])
		solid(roof_node,"StoneGable",vertices,PackedInt32Array([0,1,2] if side==1 else [2,1,0]),"929b85",Vector3(0,0,side))
		beam(roof_node,"GableStoneFrame",Vector3(-2.07,2.57,z+side*0.03),Vector3(0,3.78,z+side*0.03),0.075,"a3a990")
		beam(roof_node,"GableStoneFrame",Vector3(0,3.78,z+side*0.03),Vector3(2.07,2.57,z+side*0.03),0.075,"a3a990")
	for i in range(8):
		beam(roof_node,"SegmentedStoneRidge",Vector3(0,3.84,-2.6+i*0.65),Vector3(0,3.84,-1.97+i*0.65),0.13,"9aa28a")
	# Jambs are individual heavy blocks, with staggered mortar breaks.
	for b in scene_root.get_node("ExplorationLandmarks").get_children():
		var masonry:=b.get_node("HandLaidStonework")
		for block in masonry.get_children():
			if str(block.name).begins_with("DoorJambStone"):
				var m: BoxMesh=block.mesh.duplicate()
				m.size.x=0.548
				block.mesh=m
				var other:=block.duplicate()
				masonry.add_child(other,true)
				other.owner=scene_root
				block.position.x-=0.29
				other.position.x+=0.29
	assert(save_scene("res://burial_ridge/world.tscn")==OK)
	scene_root.free()
	quit()
