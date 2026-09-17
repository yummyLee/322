extends "bake_helpers.gd"
# Reusable authoring parts; no scene layout or runtime logic.
func roof(parent: Node3D, width: float, depth: float, height: float, straw: bool, fancy: bool = false) -> void:
	var r := group(parent, "Roof")
	var rise := 1.25 if not straw else 1.65
	var extent := depth / 2 + 0.45
	var length := sqrt(extent * extent + rise * rise)
	var color := "807047" if straw else ("46575b" if fancy else "514b40")
	for side in [-1, 1]:
		var slope := box(r, "ThatchSlope" if straw else "TileSlope", Vector3(0, height + rise/2, side * extent/2), Vector3(width+0.85, 0.18, length), color)
		slope.rotation.x = side * atan2(rise, extent)
		var count := int((width+0.8) / (0.18 if straw else 0.29))
		for i in range(count+1):
			var x := -width/2-0.4 + float(i)/count * (width+0.8)
			var tint: String = (["9c8857", "b19a63", "8e7a4d"][i%3] if straw else ["676356", "737064", "605f55"][i%3])
			if fancy:
				tint = ["708183", "627479", "839091"][i%3]
			if straw:
				for j in range(6):
					var t0 := j/6.0
					var t1 := (j+1.15)/6.0
					beam(r,"ThatchStrand",Vector3(x,height+rise*(1-t0)+0.12,side*extent*t0),Vector3(x+0.025,height+rise*(1-t1)+0.14,side*extent*t1),0.045,tint)
			else:
				for j in range(7):
					var t0 := j/7.0
					var t1 := (j+0.93)/7.0
					beam(r,"BarrelTile",Vector3(x,height+rise*(1-t0)+0.11,side*extent*t0),Vector3(x,height+rise*(1-t1)+0.11,side*extent*t1),0.115,tint)
		if not straw:
			for j in range(1, 8):
				var t := j / 8.0
				beam(r, "TileCourse", Vector3(-width/2-0.45,height+rise*(1-t)+0.09,side*extent*t), Vector3(width/2+0.45,height+rise*(1-t)+0.09,side*extent*t), 0.028, "393b36")
		beam(r, "Eave", Vector3(-width/2-0.5,height,side*extent), Vector3(width/2+0.5,height,side*extent), 0.1, color)
	beam(r, "Ridge", Vector3(-width/2-0.5,height+rise+0.17,0), Vector3(width/2+0.5,height+rise+0.17,0), 0.13, "b39a62" if straw else color)
	if fancy:
		for side in [-1,1]:
			beam(r, "RaisedRidge", Vector3(side*(width/2+0.4),height+rise+0.17,0), Vector3(side*(width/2+0.75),height+rise+0.62,0), 0.13, "829393")
			for z in [-extent,extent]:
				beam(r,"RaisedEave",Vector3(side*(width/2+0.4),height,z),Vector3(side*(width/2+0.8),height+0.4,z),0.09,"829393")
	# Closed triangular gables, with outward face winding.
	for x in [-width/2, width/2]:
		var v := PackedVector3Array([Vector3(x,height,-depth/2),Vector3(x,height+rise,0),Vector3(x,height,depth/2)])
		solid(r,"Gable",v,PackedInt32Array([0,1,2,2,1,0]),"a1936e" if straw else "8c8164")

func house(parent: Node, label: String, pos: Vector3, width: float, depth: float, height: float, straw: bool = false, color: String = "b49c6a", fancy: bool = false) -> Node3D:
	var h := group(parent, label, pos)
	box(h,"Foundation",Vector3(0,0.16,0),Vector3(width+0.3,0.32,depth+0.3),"85806b")
	box(h,"PlasterWalls",Vector3(0,height/2+0.16,0),Vector3(width,height,depth),color)
	for x in [-width/2+0.08,width/2-0.08]:
		for z in [-depth/2+0.03,depth/2+0.06]:
			box(h,"TimberPost",Vector3(x,height/2,z),Vector3(0.16,height,0.16),"63563e")
	var front := depth/2+0.04
	box(h,"DoorFrame",Vector3(0,1.03,front+0.04),Vector3(1.22,2.08,0.15),"726045")
	box(h,"DoorRecess",Vector3(0,0.98,front+0.13),Vector3(0.93,1.85,0.06),"302f27")
	box(h,"DoorPanel",Vector3(0.2,0.98,front+0.17),Vector3(0.45,1.8,0.08),"514331")
	box(h,"Threshold",Vector3(0,0.16,front+0.33),Vector3(1.6,0.25,0.65),"a39d84")
	for x in [-width*0.31,width*0.31]:
		box(h,"WindowFrame",Vector3(x,1.45,front+0.06),Vector3(0.92,0.98,0.12),"6d5a3e")
		box(h,"WindowShade",Vector3(x,1.45,front+0.14),Vector3(0.72,0.75,0.04),"353b30")
		for j in range(4):
			box(h,"WindowBar",Vector3(x-0.28+j*0.185,1.45,front+0.18),Vector3(0.045,0.75,0.06),"ab9970")
		box(h,"WindowCrossbar",Vector3(x,1.44,front+0.19),Vector3(0.74,0.05,0.05),"ab9970")
	roof(h,width,depth,height+0.17,straw,fancy)
	return h

func stone_wall(parent: Node, label: String, a: Vector3, b: Vector3, height: float = 0.85) -> void:
	var wall := group(parent,label)
	var distance := a.distance_to(b)
	var count := maxi(1,int(distance/0.64))
	for row in range(2):
		for i in range(count):
			var p := a.lerp(b,(i+0.5)/count)
			p.y += height*(0.25+row*0.5)
			var stone := box(wall,"Stone",p,Vector3(distance/count-0.045,height/2-0.025,0.48),["8b8970","9b967a","777d65"][(i+row)%3])
			stone.rotation.y = -atan2(b.z-a.z,b.x-a.x)

func fence(parent: Node, a: Vector3, b: Vector3) -> void:
	var f := group(parent,"BambooFence")
	var count := int(a.distance_to(b)/0.46)+1
	for i in range(count+1):
		var p := a.lerp(b,float(i)/count)
		beam(f,"Upright",p,p+Vector3(0,1.0+rng.randf_range(-0.1,0.1),0),0.055,"716240")
	for y in [0.35,0.75]:
		beam(f,"Rail",a+Vector3.UP*y,b+Vector3.UP*y,0.045,"948056")

func pot(parent: Node, pos: Vector3, radius: float = 0.32) -> void:
	var p := group(parent,"Pot",pos)
	ball(p,"Body",Vector3(0,radius,0),Vector3(radius,radius*1.15,radius),"8d6650")
	cylinder(p,"Rim",Vector3(0,radius*1.85,0),radius*0.76,0.11,"b48b64")
	cylinder(p,"DarkOpening",Vector3(0,radius*1.85+0.061,0),radius*0.58,0.013,"3e3b2e")

func tree(parent: Node, pos: Vector3, scale_value: float, ancient: bool = false) -> void:
	var t := group(parent,"AncientTree" if ancient else "BroadleafTree",pos)
	var height := 3.0 if not ancient else 4.0
	cylinder(t,"Trunk",Vector3(0,height/2,0),0.32 if not ancient else 0.65,height,"655c40",0.17 if not ancient else 0.3)
	for j in range(5):
		var a := j*TAU/5+0.3
		var end := Vector3(cos(a)*1.3,height+0.3,sin(a)*1.1)
		beam(t,"Branch",Vector3(0,height*0.6,0),end,0.13 if not ancient else 0.2,"6c6346")
		beam(t,"Root",Vector3.ZERO,Vector3(cos(a)*0.9,0.06,sin(a)*0.9),0.12,"756c49")
	var colors := ["405e40","526e45","6b8050","4e6947","728851"]
	for j in range(17 if ancient else 10):
		var a := j*2.4
		var rad := sqrt(float(j)/16.0)*2.6 if ancient else sqrt(float(j)/10.0)*1.7
		var p := Vector3(cos(a)*rad,height+0.6+cos(rad*0.5)*0.6+rng.randf_range(-0.3,0.3),sin(a)*rad)
		ball(t,"LeafCluster",p,Vector3(1.15,0.65,0.95) if ancient else Vector3(0.9,0.7,0.85),colors[j%5])
		for k in range(4):
			var offset := Vector3(cos(k*1.57)*0.65,0.25+rng.randf_range(-0.15,0.15),sin(k*1.57)*0.55)
			ball(t,"LeafSpray",p+offset,Vector3(0.43,0.38,0.4),colors[(j+k)%5])
	t.scale = Vector3.ONE*scale_value


