extends "scene_parts.gd"
const OUTPUT := "res://burial_left_cave/world.tscn"
const ROCK_PALETTE := ["25343d","30414a","3a4b52","46545a","526066"]
const TERRAIN_CELL := 0.60
var portal_points: Array[Vector3] = []

func _initialize() -> void:
	var args := OS.get_cmdline_args()
	if FileAccess.file_exists(OUTPUT) and not "--overwrite" in args:
		push_error("Saved editable cave exists. Remove it only for authoring revisions or pass --overwrite.")
		quit(1)
		return
	shader = load("res://burial_left_cave/style.gdshader")
	rng.seed = 19091926
	scene_root = Node3D.new()
	scene_root.name = "World"
	build_layout()
	lighting()
	var rig := scene_root.get_node("RenderRig")
	var env := rig.get_node("VillageEnvironment") as WorldEnvironment
	env.environment.background_color = Color("06090d")
	env.environment.ambient_light_energy = 0.72
	env.environment.ambient_light_color = Color("95a7b1")
	var sun := rig.get_node("AfternoonSun") as DirectionalLight3D
	sun.light_energy = 0.72
	sun.light_color = Color("b9c9d0")
	var camera := rig.get_node("VillageCamera") as Camera3D
	camera.size = 62
	camera.position = Vector3(0,52,46)
	camera.far = 180
	var err := save_scene(OUTPUT)
	scene_root.free()
	quit(err)

func tone(base: String, index: int) -> String:
	var c := Color(base)
	var delta: float = [-0.022,0.0,0.016,0.030][posmod(index,4)]
	return Color(clampf(c.r+delta,0.0,1.0),clampf(c.g+delta,0.0,1.0),clampf(c.b+delta,0.0,1.0),1.0).to_html(false)

func grid_jitter(ix: int, iz: int) -> Vector2:
	var seed := float(ix*9283+iz*6899)
	return Vector2(sin(seed*0.017)*0.28,cos(seed*0.013)*0.28)

func cell_height(ix: int, iz: int, base_y: float, water := false) -> float:
	if water:
		return base_y + sin(float(ix*17+iz*11))*0.008
	return base_y + sin(float(ix*17+iz*11))*0.085 + cos(float(ix*7-iz*13))*0.050

func patch(parent: Node, label: String, points: Array, y: float, color: String) -> Node3D:
	# A room is a stitched field of small irregular cells. The outline remains
	# editable as a region group, while no large fan or rectangle survives in
	# the baked scene.
	var g := group(parent,label)
	var polygon := PackedVector2Array()
	var min_x := INF; var max_x := -INF; var min_z := INF; var max_z := -INF
	for p in points:
		var q := Vector2(p.x,p.z)
		polygon.append(q)
		min_x = minf(min_x,q.x); max_x = maxf(max_x,q.x)
		min_z = minf(min_z,q.y); max_z = maxf(max_z,q.y)
	var ix0 := floori(min_x/TERRAIN_CELL)-1; var ix1 := ceili(max_x/TERRAIN_CELL)+1
	var iz0 := floori(min_z/TERRAIN_CELL)-1; var iz1 := ceili(max_z/TERRAIN_CELL)+1
	var water := color in ["2f6570","3b6266"]
	var cell_index := 0
	for ix in range(ix0,ix1):
		for iz in range(iz0,iz1):
			var x0 := ix*TERRAIN_CELL; var z0 := iz*TERRAIN_CELL
			var x1 := (ix+1)*TERRAIN_CELL; var z1 := (iz+1)*TERRAIN_CELL
			var v00 := Vector2(x0,z0)+grid_jitter(ix,iz)
			var v10 := Vector2(x1,z0)+grid_jitter(ix+1,iz)
			var v11 := Vector2(x1,z1)+grid_jitter(ix+1,iz+1)
			var v01 := Vector2(x0,z1)+grid_jitter(ix,iz+1)
			var inside := 0
			for v in [v00,v10,v11,v01]:
				if Geometry2D.is_point_in_polygon(v,polygon): inside += 1
			if inside < 2: continue
			var verts := PackedVector3Array([
				Vector3(v00.x,cell_height(ix,iz,y,water),v00.y),
				Vector3(v10.x,cell_height(ix+1,iz,y,water),v10.y),
				Vector3(v11.x,cell_height(ix+1,iz+1,y,water),v11.y),
				Vector3(v01.x,cell_height(ix,iz+1,y,water),v01.y)
			])
			var indices := PackedInt32Array([0,1,2,0,2,3] if posmod(ix+iz,2)==0 else [0,1,3,1,2,3])
			solid(g,"GroundCell_%03d"%cell_index,verts,indices,tone(color,cell_index))
			cell_index += 1
	return g

func rock(parent: Node, label: String, p: Vector3, s: Vector3, color := "") -> void:
	var c: String = color if color != "" else ROCK_PALETTE[rng.randi_range(0,ROCK_PALETTE.size()-1)]
	var n := ball(parent,label,p,s,c)
	n.rotation = Vector3(rng.randf_range(-0.18,0.18),rng.randf_range(0,TAU),rng.randf_range(-0.18,0.18))

func rim(parent: Node, points: Array, y: float, height: float, density: int = 2) -> void:
	for i in range(points.size()):
		var p: Vector3 = points[i]
		var next: Vector3 = points[(i+1)%points.size()]
		var edge := next-p
		var steps := maxi(1,int(edge.length()*density))
		for k in range(steps):
			var q := p.lerp(next,(k+0.35)/float(steps))
			var near_portal := false
			for portal in portal_points:
				if Vector2(q.x,q.z).distance_to(Vector2(portal.x,portal.z)) < 2.65:
					near_portal = true
					break
			if near_portal:
				continue
			var h_factor := rng.randf_range(0.28,1.18)
			var size := Vector3(rng.randf_range(0.30,0.78),height*h_factor,rng.randf_range(0.30,0.78))
			rock(parent,"RimRock",Vector3(q.x,y+size.y*0.38,q.z),size)

func smooth_route(points: Array) -> Array:
	var out: Array = []
	if points.size() < 2: return points
	for i in range(points.size()-1):
		var p0: Vector3 = points[maxi(0,i-1)]
		var p1: Vector3 = points[i]
		var p2: Vector3 = points[i+1]
		var p3: Vector3 = points[mini(points.size()-1,i+2)]
		var steps := maxi(4,ceili(p1.distance_to(p2)/0.65))
		for j in range(steps):
			var t := j/float(steps)
			var t2 := t*t
			var t3 := t2*t
			var q: Vector3 = 0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t2+(-p0+3.0*p1-3.0*p2+p3)*t3)
			out.append(q)
	out.append(points[points.size()-1])
	return out

func path_wall_edge(parent: Node, label: String, a: Vector3, b: Vector3, width: float) -> void:
	var g := group(parent,label)
	var dir := Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var side := Vector3(-dir.z,0,dir.x)
	var steps := maxi(3,int(a.distance_to(b)/0.96))
	for k in range(steps+1):
		var t := clampf(k/float(steps)+rng.randf_range(-0.08,0.08),0.0,1.0)
		var p := a.lerp(b,t)
		for sign in [-1,1]:
			if rng.randf() < 0.36: continue
			var q: Vector3 = p+side*(width*0.5*rng.randf_range(0.90,1.10)*sign)+side*rng.randf_range(-0.10,0.10)
			var h := rng.randf_range(0.28,0.66)
			rock(g,"RoadsideWallStone",Vector3(q.x,p.y+h*0.36,q.z),Vector3(rng.randf_range(0.28,0.56),h,rng.randf_range(0.28,0.60)),["59615f","6d6b5e","4e5758"][rng.randi_range(0,2)])

func slope_quad(parent: Node, label: String, a: Vector3, b: Vector3, width: float, color: String) -> void:
	var dir := Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var side := Vector3(-dir.z,0,dir.x)
	var length := a.distance_to(b)
	var steps := maxi(5,ceili(length/0.48))
	var lanes := maxi(3,ceili(width/0.72))
	for i in range(steps):
		var t0 := i/float(steps); var t1 := (i+1)/float(steps)
		var center0 := a.lerp(b,t0)+side*rng.randf_range(-0.18,0.18)+Vector3(0,0.06,0)
		var center1 := a.lerp(b,t1)+side*rng.randf_range(-0.18,0.18)+Vector3(0,0.06,0)
		for lane in range(lanes):
			var u0 := -0.5+lane/float(lanes)
			var u1 := -0.5+(lane+1)/float(lanes)
			var lateral0 := side*rng.randf_range(-0.08,0.08)
			var lateral1 := side*rng.randf_range(-0.08,0.08)
			# Four corners are ordered around one small cell; this prevents diagonal
			# gaps and the apparent pair of floating wall lines from the old mesh.
			var v0 := center0+side*(u0*width)+lateral0+Vector3(0,rng.randf_range(-0.015,0.02),0)
			var v1 := center1+side*(u0*width)+lateral1+Vector3(0,rng.randf_range(-0.015,0.02),0)
			var v2 := center1+side*(u1*width)+lateral1+Vector3(0,rng.randf_range(-0.015,0.02),0)
			var v3 := center0+side*(u1*width)+lateral0+Vector3(0,rng.randf_range(-0.015,0.02),0)
			var verts := PackedVector3Array([v0,v1,v2,v3])
			var indices := PackedInt32Array([0,1,2,0,2,3] if (i+lane)%2==0 else [0,1,3,1,2,3])
			solid(parent,"%s_Cell_%03d_%02d"%[label,i,lane],verts,indices,tone(color,i+lane))

func corridor_edges(parent: Node, label: String, points: Array, width: float) -> void:
	var g := group(parent,label)
	for i in range(points.size()-1):
		path_wall_edge(g,"SegmentWall_%02d"%i,points[i],points[i+1],width)

func carve_opening(parent: Node, p: Vector3, radius: float = 2.7) -> void:
	var stones := parent.find_children("RimRock","MeshInstance3D",true,false)
	for node in stones:
		var local_pos: Vector3 = node.position
		if Vector2(local_pos.x,local_pos.z).distance_to(Vector2(p.x,p.z)) < radius:
			node.free()

func stalagmite(parent: Node, label: String, p: Vector3, h: float, r: float, color := "46545a") -> void:
	var lower := cylinder(parent,label+"_Lower",Vector3(p.x,p.y+h*0.30,p.z),r*1.08,h*0.58,color, r*0.76,7)
	lower.rotation.z = rng.randf_range(-0.12,0.12); lower.rotation.x = rng.randf_range(-0.08,0.08)
	var upper := cylinder(parent,label+"_Upper",Vector3(p.x+rng.randf_range(-0.08,0.08),p.y+h*0.72,p.z+rng.randf_range(-0.08,0.08)),r*0.72,h*0.42,color,r*0.20,7)
	upper.rotation.z = rng.randf_range(-0.16,0.16); upper.rotation.x = rng.randf_range(-0.10,0.10)
	rock(parent,"BrokenTip",Vector3(p.x,p.y+h+0.04,p.z),Vector3(r*0.42,0.16,r*0.42),color)

func stalactite(parent: Node, label: String, p: Vector3, h: float, r: float, color := "33434b") -> void:
	var s := cylinder(parent,label,Vector3(p.x,p.y-h/2,p.z),r,h,color,0.05,7)
	s.rotation.z = rng.randf_range(-0.12,0.12); s.rotation.x = rng.randf_range(-0.08,0.08)

func torch(parent: Node, label: String, p: Vector3, warm := true) -> void:
	var t := group(parent,label,p)
	beam(t,"IronStake",Vector3(0,0.15,0),Vector3(0,1.18,0),0.07,"3b3026")
	box(t,"Brazier",Vector3(0,1.18,0),Vector3(0.32,0.13,0.32),"725039")
	cylinder(t,"BrazierRim",Vector3(0,1.27,0),0.19,0.06,"8b6842",0.14,7)
	beam(t,"WrapBand",Vector3(-0.06,0.32,0),Vector3(0.06,0.32,0),0.035,"9b754d")
	ball(t,"Ember",Vector3(0,1.31,0),Vector3(0.16,0.20,0.16),"d98a45")
	var light := OmniLight3D.new()
	light.name = "WarmLight"; light.omni_range = 5.2; light.light_energy = 2.0 if warm else 1.2
	light.light_color = Color("f0a65d") if warm else Color("9bc1d0")
	t.add_child(light,true); light.owner = scene_root; light.position = Vector3(0,1.4,0)

func portal_mouth(parent: Node, label: String, p: Vector3, facing: Vector3) -> void:
	# A readable threshold: low side stones leave a clear walkable mouth between regions.
	var g := group(parent,label,p)
	var dir := Vector3(facing.x,0,facing.z).normalized()
	if dir.length() < 0.1: dir = Vector3(0,0,1)
	var side := Vector3(-dir.z,0,dir.x)
	for sign in [-1,1]:
		var q: Vector3 = side*sign*1.55 + dir*0.15
		rock(g,"MouthStone",q+Vector3(0,0.22,0),Vector3(0.46,0.44,0.62),"4b5555")
		rock(g,"MouthStoneSmall",q+side*sign*0.38+dir*0.34+Vector3(0,0.12,0),Vector3(0.28,0.24,0.38),"62645c")
	for i in range(3):
		var q: Vector3 = dir*(i*0.62-0.62)+side*rng.randf_range(-0.75,0.75)
		rock(g,"ThresholdCobbles",q+Vector3(0,0.09,0),Vector3(0.22,0.18,0.28),"777362")

func bridge_path(parent: Node, label: String, points: Array) -> void:
	var g := group(parent,label)
	var route := smooth_route(points)
	for i in range(route.size()-1):
		var a: Vector3 = route[i]
		var b: Vector3 = route[i+1]
		beam(g,"BridgeBeamA_%02d"%i,a+Vector3(0,0.0,0),b+Vector3(0,0.0,0),0.14,"6b513b")
		beam(g,"BridgeBeamB_%02d"%i,a+Vector3(0,0.18,-0.7),b+Vector3(0,0.18,-0.7),0.14,"6b513b")
		var steps := maxi(2,ceili(a.distance_to(b)/0.9))
		for k in range(steps):
			var t := (k+0.5)/float(steps)
			var p := a.lerp(b,t)
			var dir := Vector3(b.x-a.x,0,b.z-a.z).normalized()
			var plank := box(g,"BridgePlank",p+Vector3(0,0.05,0),Vector3(0.78,0.12,1.45),"806447")
			plank.rotation.y = atan2(dir.x,dir.z)
			for side in [-1,1]:
				var rail_p := p+Vector3(0,0.15,side*0.82)
				beam(g,"RopeRail",rail_p,rail_p+Vector3(0,0.72,0),0.045,"a08a5e")

func path_wear(parent: Node, label: String, route: Array, width: float, color: String) -> void:
	var g := group(parent,label)
	for i in range(1,route.size()-1,3):
		var p: Vector3 = route[i]
		var dir := Vector3(route[i+1].x-route[i-1].x,0,route[i+1].z-route[i-1].z).normalized()
		var side := Vector3(-dir.z,0,dir.x)
		for j in range(rng.randi_range(1,3)):
			var q := p+side*rng.randf_range(-width*0.38,width*0.38)+dir*rng.randf_range(-0.40,0.40)
			rock(g,"PathWearStone",Vector3(q.x,p.y+0.08,q.z),Vector3(rng.randf_range(0.12,0.30),0.08,rng.randf_range(0.12,0.28)),tone(color,i+j))
		if rng.randf() < 0.65:
			var q0 := p+side*rng.randf_range(-width*0.28,width*0.28)-dir*0.30
			var q1 := q0+dir*rng.randf_range(0.28,0.62)+side*rng.randf_range(-0.16,0.16)
			beam(g,"BrokenWearGroove",q0+Vector3(0,0.07,0),q1+Vector3(0,0.07,0),0.018,"4d4a43")

func corridor(parent: Node, label: String, points: Array, width: float, y: float, color := "57534a") -> void:
	var g := group(parent,label)
	var route := smooth_route(points)
	for i in range(route.size()-1):
		var a: Vector3 = route[i]; var b: Vector3 = route[i+1]
		slope_quad(g,"Segment_%03d"%i,a,b,width*(0.84+rng.randf_range(-0.08,0.18)),color)
	corridor_edges(g,"StonePathBoundary",route,width*(0.90+rng.randf_range(-0.05,0.12)))
	path_wear(g,"SurfaceWear",route,width,color)

func crate(parent: Node, label: String, p: Vector3, scale := Vector3.ONE) -> void:
	var c := group(parent,label,p)
	# Short boards keep every component below the player half-height scale.
	for x in [-0.30,0.30]:
		box(c,"BodyBoard",Vector3(x,0.42,0),Vector3(0.52,0.78,0.72)*scale,"624d3b")
	for z in [-0.31,0.31]:
		box(c,"SideBoard",Vector3(0,0.42,z),Vector3(0.72,0.78,0.12)*scale,"6e5740")
	for x in [-0.34,0.34]:
		for z in [-0.34,0.34]:
			beam(c,"CornerPeg",Vector3(x,0.08,z),Vector3(x,0.82,z),0.055,"9b7b50")
	box(c,"LidSlatA",Vector3(-0.22,0.85,0),Vector3(0.42,0.08,0.76)*scale,"806447")
	box(c,"LidSlatB",Vector3(0.22,0.86,0),Vector3(0.42,0.08,0.76)*scale,"75583f")
	c.rotation.y = rng.randf_range(-0.35,0.35)

func coffin(parent: Node, label: String, p: Vector3, scale := Vector3.ONE) -> void:
	var c := group(parent,label,p)
	# A broken coffin is assembled from short boards, never a single long box.
	for x in [-0.62,-0.20,0.22,0.64]:
		var board := box(c,"BaseBoard",Vector3(x,0.16,0),Vector3(0.38,0.20,0.72)*scale,["4c4036","574638","463b34"][int(abs(x*10))%3])
		board.rotation.y = rng.randf_range(-0.05,0.05)
	for z in [-0.39,0.39]:
		beam(c,"CoffinSide",Vector3(-0.68,0.38,z),Vector3(0.68,0.38,z),0.10,"5a4839")
	for x in [-0.63,0.63]:
		beam(c,"EndRail",Vector3(x,0.34,-0.34),Vector3(x,0.34,0.34),0.08,"6f5742")
	box(c,"BrokenLidA",Vector3(-0.25,0.54,-0.02),Vector3(0.70,0.10,0.72)*scale,"67513d")
	box(c,"BrokenLidB",Vector3(0.43,0.50,0.04),Vector3(0.46,0.08,0.62)*scale,"4b4036")
	beam(c,"LidStrap",Vector3(-0.56,0.60,-0.42),Vector3(-0.56,0.60,0.42),0.035,"8a6f4b")
	for x in [-0.60,0.60]:
		ball(c,"Nail",Vector3(x,0.62,0),Vector3(0.055,0.055,0.055),"b08a58")
	c.rotation.y = rng.randf_range(-0.22,0.22)

func cart(parent: Node, p: Vector3) -> void:
	var c := group(parent,"OverturnedCorpseCart",p)
	for x in [-0.78,0,0.78]:
		box(c,"BedPlank",Vector3(x,0.62,0),Vector3(0.68,0.22,1.05),["5a4938","634b38","4b4034"][int(x+1)%3])
	for z in [-0.54,0.54]:
		for x in [-0.72,0,0.72]:
			beam(c,"SideRailSegment",Vector3(x,0.98,z),Vector3(x+0.62,0.98,z),0.08,"6e5740")
	beam(c,"Axle",Vector3(-1.05,0.34,0),Vector3(1.05,0.34,0),0.10,"46392e")
	for x in [-1.1,1.1]:
		var w := cylinder(c,"WoodWheel",Vector3(x,0.47,0),0.52,0.16,"6b513b",0.52,10)
		w.rotation.z = PI/2
		for a in range(4):
			beam(c,"WheelSpoke",Vector3(x,0.47,0)+Vector3(0,cos(a*PI/2)*0.42,sin(a*PI/2)*0.42),Vector3(x,0.47,0)+Vector3(0,cos(a*PI/2+PI)*0.42,sin(a*PI/2+PI)*0.42),0.035,"a08058")
	c.rotation = Vector3(0.18,0.22,-0.24)

func bone_pile(parent: Node, label: String, p: Vector3, amount: int) -> void:
	var g := group(parent,label,p)
	for i in range(amount):
		var a := rng.randf()*TAU; var r := rng.randf_range(0.15,0.85)
		var q := Vector3(cos(a)*r,0.08+rng.randf_range(0,0.18),sin(a)*r)
		beam(g,"Bone",q,q+Vector3(rng.randf_range(-0.35,0.35),rng.randf_range(0.12,0.28),rng.randf_range(-0.35,0.35)),0.045,"b3aa8f")

func wall_marker(parent: Node, p: Vector3, h := 1.8) -> void:
	var m := group(parent,"NameMarker",p)
	box(m,"StoneSlab",Vector3(0,h/2,0),Vector3(0.42,h,0.22),"7c7b6d")
	box(m,"DarkCarving",Vector3(0,h*0.64,0.12),Vector3(0.23,0.055,0.03),"3c3a35")

func ground_detail(parent: Node, label: String, center: Vector3, extent: Vector2, wet := false, count := 14) -> void:
	var g := group(parent,label)
	var stone_colors := ["777362","625f55","85806e","514f49"] if not wet else ["6b7b78","536b6c","82908a"]
	var soil_colors := ["6d6658","80745f","554f47"] if not wet else ["3d5b5e","42696a","536f6c"]
	for i in range(count):
		var p := Vector3(center.x+rng.randf_range(-extent.x,extent.x),center.y+0.035,center.z+rng.randf_range(-extent.y,extent.y))
		var s := Vector3(rng.randf_range(0.12,0.42),rng.randf_range(0.035,0.10),rng.randf_range(0.10,0.32))
		rock(g,"LooseCaveStone",p,s,stone_colors[i%stone_colors.size()])
	for i in range(8):
		var p := Vector3(center.x+rng.randf_range(-extent.x*0.8,extent.x*0.8),center.y+0.018,center.z+rng.randf_range(-extent.y*0.8,extent.y*0.8))
		var patch_stone := ball(g,"SoilVariation",p,Vector3(rng.randf_range(0.22,0.62),0.020,rng.randf_range(0.12,0.36)),soil_colors[i%soil_colors.size()])
		patch_stone.rotation.y = rng.randf_range(0,TAU)
	for i in range(5):
		var p := Vector3(center.x+rng.randf_range(-extent.x*0.75,extent.x*0.75),center.y+0.075,center.z+rng.randf_range(-extent.y*0.75,extent.y*0.75))
		var footprint := cylinder(g,"Footprint",p,rng.randf_range(0.07,0.12),0.025,"403f3a",rng.randf_range(0.03,0.07),7)
		footprint.rotation.x = rng.randf_range(-0.12,0.12); footprint.rotation.z = rng.randf_range(-0.12,0.12)
	for i in range(3):
		var a := Vector3(center.x+rng.randf_range(-extent.x*0.6,extent.x*0.6),center.y+0.08,center.z+rng.randf_range(-extent.y*0.6,extent.y*0.6))
		beam(g,"ErosionCrack",a,a+Vector3(rng.randf_range(-0.8,0.8),0,rng.randf_range(-0.4,0.4)),0.018,"3f4140")

func spider_web(parent: Node, label: String, p: Vector3, size: float) -> void:
	var g := group(parent,label,p)
	for i in range(4):
		var a := i*TAU/4.0
		beam(g,"WebRadial",Vector3.ZERO,Vector3(cos(a)*size,0,sin(a)*size),0.012,"8a9390")
	for i in range(3):
		var r := size*(0.35+i*0.22)
		var pts := []
		for j in range(9):
			var a := j*TAU/8.0
			pts.append(Vector3(cos(a)*r,0.01,sin(a)*r))
		for j in range(8): beam(g,"WebArc",pts[j],pts[j+1],0.009,"717a78")

func stone_pillar_cluster(parent: Node, label: String, p: Vector3, y: float) -> void:
	var g := group(parent,label,p)
	for i in range(3):
		var q := Vector3(rng.randf_range(-1.0,1.0),0,rng.randf_range(-0.8,0.8))
		var pillar := group(g,"StonePillar_%02d"%i,q)
		stalagmite(pillar,"PillarBody",Vector3(0,y,0),rng.randf_range(1.0,2.2),rng.randf_range(0.28,0.52),["465960","52636a","3d5058"][i])
		rock(pillar,"PillarFoot",Vector3(0,y+0.12,0),Vector3(rng.randf_range(0.45,0.8),0.24,rng.randf_range(0.42,0.72)),"59666a")
		cylinder(pillar,"PillarCollar",Vector3(0,y+0.72,0),rng.randf_range(0.30,0.50),0.10,["59666a","697379"][i%2],rng.randf_range(0.18,0.28),7)

func broken_rail(parent: Node, label: String, a: Vector3, b: Vector3, y: float) -> void:
	var g := group(parent,label)
	beam(g,"LowRail",a+Vector3(0,y,0),b+Vector3(0,y+0.12,0),0.06,"6c5943")
	var mid := a.lerp(b,0.5)
	beam(g,"PostA",a+Vector3(0,0,0),a+Vector3(0,0.8,0),0.065,"574938")
	beam(g,"PostB",b+Vector3(0,0,0),b+Vector3(0,0.8,0),0.065,"574938")
	beam(g,"BrokenPost",mid+Vector3(0,0,0),mid+Vector3(0,0.42,0),0.05,"78634c")

func build_layout() -> void:
	var terrain := group(scene_root,"CaveTerrain")
	var rock_shell := group(scene_root,"CaveRockShell")
	var props := group(scene_root,"ExplorationProps")
	var lights := group(scene_root,"Lanterns")
	portal_points = [
		Vector3(0,0,22),Vector3(0,0,16),Vector3(-1,0,1),Vector3(9,0,4),
		Vector3(18,1.8,-3),Vector3(24,3.8,-12),Vector3(30,3.8,-18),
		Vector3(19,2.4,-20),Vector3(-17,-2,-16),Vector3(1,2.4,-23),
		Vector3(-10,-0.2,4),Vector3(-21,-0.8,-3),Vector3(-22,-1.4,-15),
		Vector3(4,2.4,-26),Vector3(-12,0.8,-28),Vector3(-9,0.8,-29),
		Vector3(19,3,-29),Vector3(34,3,-29)
	]

	var j0_points=[Vector3(-6,0,25),Vector3(4,0,27),Vector3(8,0,23),Vector3(6,0,17),Vector3(1,0,14),Vector3(-5,0,16),Vector3(-9,0,21)]
	patch(terrain,"J0_EntranceHall",j0_points,0.0,"625e52"); rim(rock_shell,j0_points,0.0,1.4)
	corridor(terrain,"J0_J1_J8_MainCorridor",[Vector3(0,0,22),Vector3(-1.8,0,19.5),Vector3(1.8,0,15.5),Vector3(-2.0,0,11),Vector3(2.1,0,6.2),Vector3(-1.4,0,2.4),Vector3(-1,0,-2)],4.6,0.0,"625d51")
	var j8_points=[Vector3(-12,0,6),Vector3(-8,0,12),Vector3(3,0,13),Vector3(12,0,8),Vector3(12,0,-2),Vector3(6,0,-7),Vector3(-6,0,-7),Vector3(-13,0,-2)]
	patch(terrain,"J8_OldCartYard",j8_points,0.0,"6c6252"); rim(rock_shell,j8_points,0.0,2.6)

	var j2_points=[Vector3(12,0,7),Vector3(19,0,8),Vector3(23,0,4),Vector3(22,0,-1),Vector3(17,0,-4),Vector3(12,0,-2)]
	patch(terrain,"J2_BoneSortingLedge",j2_points,1.8,"575650"); rim(rock_shell,j2_points,1.75,1.1)
	corridor(terrain,"J8_to_J2",[Vector3(8,0,4),Vector3(9.4,0.45,5.4),Vector3(11.4,0.9,5.2),Vector3(13.1,1.35,4.5),Vector3(14,1.8,3)],3.8,1.0,"625f54")
	corridor(terrain,"J2_to_J4",[Vector3(18,1.8,-3),Vector3(16.7,2.0,-4.0),Vector3(19.4,2.5,-5.4),Vector3(17.7,2.8,-6.8),Vector3(19,3,-8)],3.4,2.4,"565957")
	var j4_points=[Vector3(12,0,-9),Vector3(18,0,-10),Vector3(25,0,-8),Vector3(29,0,-11),Vector3(27,0,-15),Vector3(18,0,-16),Vector3(13,0,-13)]
	patch(terrain,"J4_UpperFissureWalk",j4_points,3.8,"454d52"); rim(rock_shell,j4_points,3.75,3.1)
	corridor(terrain,"J4_to_J11",[Vector3(24,3.8,-12),Vector3(25,3.8,-13.2),Vector3(27.2,3.7,-14.4),Vector3(28,3.6,-16)],2.8,3.7,"4e5558")

	bridge_path(terrain,"J11_SuspendedBoneBridge",[Vector3(27.0,4.0,-15.6),Vector3(28.0,4.0,-16.4),Vector3(29.2,4.0,-16.3),Vector3(30.2,4.0,-17.2),Vector3(31,4.0,-18)])
	corridor(terrain,"J11_to_J5",[Vector3(30,3.8,-18),Vector3(28.3,3.4,-18.6),Vector3(25.5,2.9,-19.6),Vector3(22.5,2.5,-20.2),Vector3(19,2.4,-20)],3.0,3.0,"56564f")
	var j5_points=[Vector3(6,0,-22),Vector3(15,0,-20),Vector3(21,0,-21),Vector3(23,0,-27),Vector3(18,0,-31),Vector3(7,0,-31),Vector3(1,0,-27),Vector3(1,0,-24)]
	patch(terrain,"J5_BoneCairnHall",j5_points,2.4,"5b5449"); rim(rock_shell,j5_points,2.35,2.4)
	var j6_points=[Vector3(-27,0,-12),Vector3(-19,0,-10),Vector3(-15,0,-14),Vector3(-16,0,-21),Vector3(-23,0,-23),Vector3(-29,0,-19)]
	patch(terrain,"J6_SunkenPit",j6_points,-2.2,"3d4b50"); rim(rock_shell,j6_points,-2.1,3.8)
	corridor(terrain,"J6_to_J5_OneWay",[Vector3(-17,-2,-16),Vector3(-16.0,-1.8,-17.0),Vector3(-13.4,-0.8,-18.0),Vector3(-10,0,-19),Vector3(-5.0,1.2,-21),Vector3(1,2.4,-23)],2.8,0.0,"545550")

	var j3_points=[Vector3(-28,0,7),Vector3(-20,0,11),Vector3(-13,0,8),Vector3(-12,0,1),Vector3(-17,0,-4),Vector3(-26,0,-4),Vector3(-32,0,1)]
	patch(terrain,"J3_SeepingThroat",j3_points,-0.8,"2f5b61"); rim(rock_shell,j3_points,-0.65,2.0)
	corridor(terrain,"J8_to_J3",[Vector3(-9.0,0,4),Vector3(-10.7,-0.1,5.0),Vector3(-13.0,-0.3,4.4),Vector3(-16,-0.6,4)],3.6,-0.4,"416068")
	var j9_points=[Vector3(-30,0,-4),Vector3(-25,0,-7),Vector3(-16,0,-7),Vector3(-11,0,-12),Vector3(-15,0,-18),Vector3(-24,0,-18),Vector3(-31,0,-14)]
	patch(terrain,"J9_StonePillarForest",j9_points,-1.4,"3d5055"); rim(rock_shell,j9_points,-1.3,3.4)
	corridor(terrain,"J3_to_J9",[Vector3(-21,-0.8,-3),Vector3(-21.6,-0.95,-4.4),Vector3(-21.2,-1.1,-6.2),Vector3(-22,-1.2,-8)],3.3,-1.0,"416068")
	corridor(terrain,"J9_to_J6",[Vector3(-22,-1.4,-15),Vector3(-22.3,-1.55,-16.0),Vector3(-22.6,-1.8,-17.0),Vector3(-23,-2,-18)],2.8,-1.6,"465b5c")

	var j10_points=[Vector3(-28,0,-22),Vector3(-20,0,-24),Vector3(-12,0,-23),Vector3(-9,0,-27),Vector3(-13,0,-33),Vector3(-22,0,-34),Vector3(-29,0,-30)]
	patch(terrain,"J10_GreyWaterTerraces",j10_points,0.8,"565852"); rim(rock_shell,j10_points,0.75,2.2)
	corridor(terrain,"J5_to_J10",[Vector3(4,2.4,-26),Vector3(2.1,2.1,-26.8),Vector3(-1.0,1.8,-26.2),Vector3(-5,1.4,-27),Vector3(-8.5,1.0,-27.5),Vector3(-12,0.8,-28)],3.8,1.6,"5a5a51")
	var j7_points=[Vector3(-33,0,-24),Vector3(-29,0,-24),Vector3(-29,0,-29),Vector3(-34,0,-31)]
	patch(terrain,"J7_SealedWestFissure",j7_points,0.9,"252d32"); rim(rock_shell,j7_points,0.8,3.5)
	var j12_points=[Vector3(21,0,-24),Vector3(28,0,-23),Vector3(34,0,-25),Vector3(36,0,-30),Vector3(31,0,-34),Vector3(22,0,-33),Vector3(18,0,-28)]
	patch(terrain,"J12_CollapseQuarry",j12_points,3.0,"50504c"); rim(rock_shell,j12_points,2.95,1.7)
	corridor(terrain,"J10_to_J12",[Vector3(-9,0.8,-29),Vector3(-5.0,1.0,-30.0),Vector3(0.0,1.5,-30.5),Vector3(5.0,2.0,-30.0),Vector3(11.0,2.5,-29.2),Vector3(19,3,-29)],3.2,2.0,"56574f")
	var j13_points=[Vector3(35,0,-25),Vector3(42,0,-25),Vector3(45,0,-29),Vector3(43,0,-34),Vector3(36,0,-34),Vector3(33,0,-30)]
	patch(terrain,"J13_NameWallChamber",j13_points,3.0,"494b49"); rim(rock_shell,j13_points,2.95,2.6)
	corridor(terrain,"J12_to_J13",[Vector3(34,3,-29),Vector3(34.8,3,-27.9),Vector3(36.2,3,-28.5),Vector3(36.4,3,-29.6),Vector3(37,3,-29)],2.5,3.0,"52554e")

	# The open-top presentation uses the rim and side walls as the cave ceiling
	# cue; detached stalactites are intentionally omitted from the playable view.
	var ceiling := group(scene_root,"CeilingFormations")

	var water := group(scene_root,"WaterFeatures")
	patch(water,"J3_ReflectingPool",[Vector3(-29,-0.15,4),Vector3(-24,-0.15,7),Vector3(-17,-0.15,5),Vector3(-16,-0.15,0),Vector3(-22,-0.15,-2),Vector3(-29,-0.15,0)],-0.22,"2f6570")
	patch(water,"J10_ShallowCascade",[Vector3(-26,0,-27),Vector3(-20,0,-29),Vector3(-13,0,-28),Vector3(-12,0,-32),Vector3(-21,0,-33),Vector3(-27,0,-31)],0.12,"3b6266")
	for p in [Vector3(-25,-0.05,3),Vector3(-20,-0.05,5),Vector3(-18,-0.05,1),Vector3(-21,0,-30),Vector3(-16,0,-31)]:
		rock(water,"WaterWornStone",p,Vector3(0.35,0.22,0.35),"708084")

	var entrance := group(props,"J0_EntranceDetails")
	for x in [-2.2,2.2]: beam(entrance,"DoorPost",Vector3(x,0.1,27.1),Vector3(x,2.7,27.1),0.16,"4e4035")
	beam(entrance,"DoorHeader",Vector3(-2.35,2.65,27.1),Vector3(2.35,2.65,27.1),0.18,"544335")
	for z in [26.2,26.8]: beam(entrance,"DoorBar",Vector3(-2.1,0.5,z),Vector3(2.1,0.5,z),0.07,"8d704b")
	for x in [-3.1,0,3.1]: pot(entrance,Vector3(x,0.05,23.1),0.42)
	for i in range(5):
		var q := Vector3(-1.6+i*0.72,0.07,27.30+rng.randf_range(-0.22,0.22))
		rock(entrance,"ColdLightPebble",q,Vector3(rng.randf_range(0.18,0.34),0.06,rng.randf_range(0.16,0.28)),"9db7c0")
	torch(lights,"J0_LanternWest",Vector3(-4.6,0.0,23.0),false); torch(lights,"J0_LanternEast",Vector3(4.6,0.0,23.0),false)

	cart(props,Vector3(-1.0,0.0,3.6)); coffin(props,"J1_AbandonedCoffin",Vector3(-4.0,0.0,8.0),Vector3(0.85,0.85,0.85)); crate(props,"J8_LimePallet",Vector3(4.7,0.0,0.9),Vector3(1.1,1.0,1.0)); crate(props,"J8_BrokenCrate",Vector3(-5.0,0.0,-1.0),Vector3(0.8,0.8,0.8))
	for p in [Vector3(-8,0,7),Vector3(8,0,5),Vector3(0,0,9)]: torch(lights,"J8_WorkLantern",p)
	for p in [Vector3(15,1.8,3),Vector3(19,1.8,1),Vector3(16,1.8,-1)]: bone_pile(props,"J2_ScatteredBones",p,6)
	wall_marker(props,Vector3(21,1.8,0.2),1.2)

	coffin(props,"J5_BrokenCoffin",Vector3(16.0,2.4,-25.5),Vector3(0.90,0.90,0.90))
	for p in [Vector3(6,2.4,-25),Vector3(10,2.4,-27),Vector3(14,2.4,-24)]: bone_pile(props,"J5_OrderedBoneRack",p,12)
	for p in [Vector3(4,2.4,-29),Vector3(16,2.4,-29),Vector3(18,2.4,-27)]: bone_pile(props,"J5_DisturbedDragPile",p,10)
	for p in [Vector3(5,2.4,-24),Vector3(18,2.4,-25),Vector3(12,2.4,-29)]: wall_marker(props,p,1.1)
	torch(lights,"J5_WarmLantern",Vector3(10,2.4,-22),true); torch(lights,"J5_WarmLantern2",Vector3(19,2.4,-27),true)
	var pit := group(props,"J6_PitEvidence",Vector3(-22,-2.15,-16))
	beam(pit,"RopeFrameA",Vector3(-2,0,-1),Vector3(0,2.4,0),0.10,"66533b"); beam(pit,"RopeFrameB",Vector3(2,0,1),Vector3(0,2.4,0),0.10,"66533b"); beam(pit,"Crossbar",Vector3(-2,2.1,-1),Vector3(2,2.1,1),0.10,"66533b")
	cylinder(pit,"RustBell",Vector3(0,0.4,0),0.16,0.34,"89644a",0.10,8); torch(lights,"J6_BottomLantern",Vector3(-22,-2.1,-16),false)
	for p in [Vector3(27,3.8,-16),Vector3(31,3.8,-18)]: torch(lights,"J11_BridgeLantern",p,true)

	for i in range(4):
		var step := group(props,"J10_CalcifiedTerrace_%02d"%i,Vector3(-20+i*1.5,0.30+i*0.20,-27.0-i*0.65))
		for j in range(5):
			rock(step,"CalcifiedRock",Vector3((j-2)*0.62+rng.randf_range(-0.18,0.18),0.08,rng.randf_range(-0.28,0.28)),Vector3(rng.randf_range(0.22,0.42),0.16,rng.randf_range(0.24,0.44)),["a6a18b","918f7d","b0aa91"][j%3])
	for p in [Vector3(-14,0.8,-30),Vector3(-23,0.8,-31)]: torch(lights,"J10_WaterLantern",p,false)
	var quarry := group(props,"J12_QuarrySupports")
	for z in [-26.0,-30.5,-33.0]:
		beam(quarry,"OldSupport",Vector3(23,3,z),Vector3(23,5.4,z),0.12,"6b5540")
		for x in [22.0,24.1,26.2,28.3,30.4]:
			var a := Vector3(x,5.15+rng.randf_range(-0.08,0.08),z+rng.randf_range(-0.08,0.08))
			var b := Vector3(x+1.55,5.15+rng.randf_range(-0.08,0.08),z+rng.randf_range(-0.08,0.08))
			beam(quarry,"OldCrossbeamSegment",a,b,0.10,"6b5540")
	crate(props,"J12_ToolCrate",Vector3(27,3,-27),Vector3(0.9,0.9,0.9)); crate(props,"J12_ToolCrate2",Vector3(30,3,-31),Vector3(0.65,0.65,0.65))
	for p in [Vector3(37,3,-27),Vector3(41,3,-31),Vector3(37,3,-32)]: wall_marker(props,p,1.55)
	torch(lights,"J12_WorkLight",Vector3(27,3,-25),true); torch(lights,"J13_QuietLantern",Vector3(39,3,-29),true)
	for i in range(5):
		var plaque := group(props,"J13_NamePlaque_%02d"%i,Vector3(36.0+i*1.05,3.2,-32.6+rng.randf_range(-0.14,0.14)))
		rock(plaque,"CarvedStone",Vector3(0,0.30,0),Vector3(0.38,0.30,0.24),"725a43")
		beam(plaque,"NameCut",Vector3(-0.14,0.39,0.23),Vector3(0.14,0.39,0.23),0.018,"b9a27b")

	# Carve deliberate openings after the natural wall rims are built. These are
	# the actual visual thresholds used by the future collision/portal pass.
	for opening in [
		Vector3(0,0,22),Vector3(0,0,16),Vector3(-1,0,1),Vector3(9,0,4),
		Vector3(18,1.8,-3),Vector3(24,3.8,-12),Vector3(30,3.8,-18),
		Vector3(19,2.4,-20),Vector3(-17,-2,-16),Vector3(1,2.4,-23),
		Vector3(-10,-0.2,4),Vector3(-21,-0.8,-3),Vector3(-22,-1.4,-15),
		Vector3(4,2.4,-26),Vector3(-12,0.8,-28),Vector3(-9,0.8,-29),
		Vector3(19,3,-29),Vector3(34,3,-29)
	]:
		carve_opening(rock_shell,opening,2.7)

	var mouths := group(props,"RegionEntrances")
	portal_mouth(mouths,"J0_J1_Entrance",Vector3(0,0,22),Vector3(0,0,-1))
	portal_mouth(mouths,"J1_J8_Entrance",Vector3(-1,0,1),Vector3(0,0,-1))
	portal_mouth(mouths,"J8_J2_Entrance",Vector3(9,0,4),Vector3(1,0,0))
	portal_mouth(mouths,"J2_J4_Entrance",Vector3(18,1.8,-3),Vector3(0,0,-1))
	portal_mouth(mouths,"J4_J11_Entrance",Vector3(24,3.8,-12),Vector3(1,0,-1))
	portal_mouth(mouths,"J11_J5_Entrance",Vector3(30,3.8,-18),Vector3(-1,0,0))
	portal_mouth(mouths,"J6_J5_Entrance",Vector3(-17,-2,-16),Vector3(1,0,-1))
	portal_mouth(mouths,"J8_J3_Entrance",Vector3(-10,-0.2,4),Vector3(-1,0,0))
	portal_mouth(mouths,"J3_J9_Entrance",Vector3(-21,-0.8,-3),Vector3(0,0,-1))
	portal_mouth(mouths,"J9_J6_Entrance",Vector3(-22,-1.4,-15),Vector3(0,0,-1))
	portal_mouth(mouths,"J5_J10_Entrance",Vector3(4,2.4,-26),Vector3(-1,0,0))
	portal_mouth(mouths,"J10_J12_Entrance",Vector3(-9,0.8,-29),Vector3(1,0,0))
	portal_mouth(mouths,"J12_J13_Entrance",Vector3(34,3,-29),Vector3(1,0,0))

	# Surface language is shared across zones but tuned by use: dry cart wear,
	# wet silt, bone-room drag marks, and quarry rubble.
	ground_detail(props,"J0_FloorWear",Vector3(0,0.0,21),Vector2(5.4,3.8),false,18)
	ground_detail(props,"J1_SiltAndWheelWear",Vector3(-1,0.0,8),Vector2(2.8,7.0),false,20)
	ground_detail(props,"J8_CartYardSurface",Vector3(0,0.0,4),Vector2(8.0,5.4),false,26)
	ground_detail(props,"J2_SortingSurface",Vector3(17,1.8,2),Vector2(4.8,3.8),false,16)
	ground_detail(props,"J4_FissureSurface",Vector3(20,3.8,-12),Vector2(5.0,2.4),false,14)
	ground_detail(props,"J11_BridgeLandingSurface",Vector3(25,3.7,-17),Vector2(3.2,2.0),false,10)
	ground_detail(props,"J5_BoneRoomSurface",Vector3(12,2.4,-26),Vector2(8.0,4.2),false,24)
	ground_detail(props,"J6_PitFloorSurface",Vector3(-22,-2.2,-16),Vector2(3.6,3.4),true,12)
	ground_detail(props,"J3_WetSiltSurface",Vector3(-22,-0.8,4),Vector2(7.2,4.5),true,20)
	ground_detail(props,"J9_PillarForestSurface",Vector3(-22,-1.4,-12),Vector2(7.0,4.2),true,20)
	ground_detail(props,"J10_CalcifiedSurface",Vector3(-19,0.8,-28),Vector2(7.0,4.0),true,18)
	ground_detail(props,"J12_QuarrySurface",Vector3(27,3.0,-29),Vector2(7.2,4.0),false,20)
	ground_detail(props,"J13_NameRoomSurface",Vector3(39,3.0,-30),Vector2(4.2,3.0),false,12)

	# Region-specific formations and edge language.
	stone_pillar_cluster(props,"J3_StalagmiteCluster",Vector3(-25,0,4),-0.8)
	stone_pillar_cluster(props,"J9_StalagmiteClusterA",Vector3(-25,0,-11),-1.4)
	stone_pillar_cluster(props,"J9_StalagmiteClusterB",Vector3(-17,0,-15),-1.4)
	spider_web(props,"J9_Web",Vector3(-28,-0.9,-14),1.2)
	spider_web(props,"J7_Web",Vector3(-31,0.95,-27),1.0)
	broken_rail(props,"J8_EastEdgeRail",Vector3(6,0,7),Vector3(10,0,5),0.18)
	broken_rail(props,"J8_WetEdgeRail",Vector3(-7,0,5),Vector3(-10,0,3),0.16)
	broken_rail(props,"J12_CollapseRail",Vector3(19,3,-27),Vector3(23,3,-31),0.20)
	for p in [Vector3(-4,0.08,8),Vector3(0,0.08,5),Vector3(3,0.08,2)]:
		beam(props,"WheelRut",p,p+Vector3(0,0,3.2),0.045,"3f403d")
		beam(props,"WheelRut2",p+Vector3(0.72,0,0),p+Vector3(0.72,0,3.2),0.045,"3f403d")
	for p in [Vector3(8,2.5,-26),Vector3(15,2.5,-28),Vector3(6,2.5,-29)]:
		beam(props,"BoneDragMark",p,p+Vector3(1.4,0,-0.5),0.035,"3c3936")

	var scale_ref := group(scene_root,"ScaleReference")
	cylinder(scale_ref,"PlayerHeightMarker",Vector3(-7,1.0,22),0.06,2.0,"c6b08a",0.06,6)
