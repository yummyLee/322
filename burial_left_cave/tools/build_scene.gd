extends "scene_parts.gd"
const OUTPUT := "res://burial_left_cave/world.tscn"
const ROCK_PALETTE := ["25343d","30414a","3a4b52","46545a","526066"]
var portal_points: Array[Vector3] = []
var boundary_collisions: Node3D
var route_registry: Array[String] = []
var rim_index := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
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

func surface_y(x: float, z: float, base_y: float, water := false) -> float:
	if water:
		return base_y + sin(x*0.37+z*0.21)*0.012
	return base_y + sin(x*0.23+z*0.17)*0.065 + cos(x*0.11-z*0.29)*0.045

func patch(parent: Node, label: String, points: Array, y: float, color: String) -> Node3D:
	# One continuous editable surface per region. The outline is irregular and
	# gently warped in height; stones, wear and wet marks remain separate nodes.
	var g := group(parent,label)
	var polygon := PackedVector2Array()
	for p in points:
		var q := Vector2(p.x,p.z)
		polygon.append(q)
	var tris := Geometry2D.triangulate_polygon(polygon)
	if tris.is_empty():
		push_error("Unable to triangulate region %s" % label)
		return g
	var boundary := PackedVector3Array()
	var is_water := color in ["2f6570","3b6266"]
	for q in polygon:
		boundary.append(Vector3(q.x,surface_y(q.x,q.y,y,is_water),q.y))
	var verts := PackedVector3Array()
	var refined := PackedInt32Array()
	for i in range(0,tris.size(),3):
		var a: Vector3 = boundary[tris[i]]
		var b: Vector3 = boundary[tris[i+1]]
		var c: Vector3 = boundary[tris[i+2]]
		append_surface_triangle(verts,refined,a,b,c,0,is_water)
	# Terrain keeps its saved height variation, but uses a shared upward normal
	# so the post-process does not outline every small triangulation cell.
	var surface := solid(g,"TerrainSurface_%s" % label,verts,refined,color,Vector3.UP)
	surface.set_meta("surface_kind","continuous_region")
	surface.set_meta("region_id",label)
	mesh_collision(g,surface,"GroundCollision")
	return g

func append_surface_triangle(verts: PackedVector3Array, indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, depth: int, water: bool) -> void:
	# Keep every saved terrain cell below half the player height. The recursive
	# split also removes the large exposed fan triangles that used to read as
	# simple polygon floors from the camera.
	var edge_max := maxf(a.distance_to(b),maxf(b.distance_to(c),c.distance_to(a)))
	if edge_max <= 0.82 or depth >= 5:
		var base := verts.size()
		verts.append(a); verts.append(b); verts.append(c)
		indices.append_array([base,base+1,base+2])
		return
	var ab := (a+b)*0.5
	var bc := (b+c)*0.5
	var ca := (c+a)*0.5
	# Keep midpoint heights shared by adjacent triangles. Independent random
	# lifts create microscopic cracks that become black dotted lines at 1080p;
	# the saved boundary heights and broad wear patches already provide the
	# cave's low-frequency relief.
	append_surface_triangle(verts,indices,a,ab,ca,depth+1,water)
	append_surface_triangle(verts,indices,ab,b,bc,depth+1,water)
	append_surface_triangle(verts,indices,ca,bc,c,depth+1,water)
	append_surface_triangle(verts,indices,ab,bc,ca,depth+1,water)

func mesh_collision(parent: Node, source: MeshInstance3D, label: String) -> void:
	if source.mesh == null:
		return
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 1
	parent.add_child(body,true)
	body.owner = scene_root
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = source.mesh.create_trimesh_shape()
	body.add_child(shape,true)
	shape.owner = scene_root
	body.set_meta("collision_kind","walkable_surface")

func rock(parent: Node, label: String, p: Vector3, s: Vector3, color := "") -> void:
	var c: String = color if color != "" else ROCK_PALETTE[rng.randi_range(0,ROCK_PALETTE.size()-1)]
	var n := ball(parent,label,p,s,c)
	n.rotation = Vector3(rng.randf_range(-0.18,0.18),rng.randf_range(0,TAU),rng.randf_range(-0.18,0.18))

func rim(parent: Node, points: Array, y: float, height: float, density: int = 2, region_label: String = "") -> void:
	# A region gets a rounded, layered rock rim instead of a line of identical
	# pillars. Every span is short enough to remain editable and to avoid a
	# straight polygon edge in the player view.
	var rim_group := group(parent,region_label if region_label != "" else "RegionRim_%02d" % rim_index)
	rim_index += 1
	for i in range(points.size()):
		var p: Vector3 = points[i]
		var next: Vector3 = points[(i+1)%points.size()]
		var edge := next-p
		# Fewer, wider spans read as a continuous eroded wall instead of a
		# picket fence of identical spikes.
		var steps := maxi(3,int(edge.length()*0.92))
		for k in range(steps):
			var t0 := k/float(steps)
			var t1 := (k+1)/float(steps)
			var dir := Vector3(edge.x,0,edge.z).normalized()
			var side := Vector3(-dir.z,0,dir.x)
			var a := p.lerp(next,t0)+side*rng.randf_range(-0.16,0.16)
			var b := p.lerp(next,t1)+side*rng.randf_range(-0.16,0.16)
			var mid := a.lerp(b,0.5)
			var near_portal := false
			for portal in portal_points:
				if Vector2(mid.x,mid.z).distance_to(Vector2(portal.x,portal.z)) < 5.2:
					near_portal = true
					break
			if near_portal:
				continue
			var span_height := height*rng.randf_range(0.52,0.96)
			rock_wall_span(rim_group,"RockWallSpan_%02d_%02d" % [i,k],a,b,y,span_height)
			if rng.randf() < 0.42:
				var h_factor := rng.randf_range(0.24,0.62)
				var size := Vector3(rng.randf_range(0.46,0.94),height*h_factor,rng.randf_range(0.46,0.90))
				rock(rim_group,"RimFootBoulder",Vector3(mid.x,y+size.y*0.38,mid.z),size)
			collision_wall(boundary_collisions,"Rim_%02d_%02d"%[i,k],a,b,span_height*0.80)

func rock_wall_span(parent: Node, label: String, a: Vector3, b: Vector3, y: float, height: float) -> void:
	var dir := Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var side := Vector3(-dir.z,0,dir.x)
	var inner_a := a+side*0.14
	var inner_b := b+side*0.14
	var outer_a := a-side*0.48
	var outer_b := b-side*0.48
	var h0 := height*rng.randf_range(0.78,1.12)
	var h1 := height*rng.randf_range(0.72,1.16)
	var hm := height*rng.randf_range(0.86,1.24)
	var mid_a := inner_a.lerp(inner_b,0.46)+side*rng.randf_range(-0.10,0.10)
	var mid_b := outer_a.lerp(outer_b,0.54)+side*rng.randf_range(-0.10,0.10)
	var verts := PackedVector3Array([
		inner_a+Vector3(0,0.04,0), mid_a+Vector3(0,0.04,0), inner_b+Vector3(0,0.04,0),
		inner_a+Vector3(0,h0,0), mid_a+Vector3(0,hm,0), inner_b+Vector3(0,h1,0),
		outer_a+Vector3(0,0.01,0), mid_b+Vector3(0,0.01,0), outer_b+Vector3(0,0.01,0),
		outer_a+Vector3(0,h0*0.84,0), mid_b+Vector3(0,hm*0.86,0), outer_b+Vector3(0,h1*0.84,0)
	])
	var indices := PackedInt32Array([
		0,1,4,0,4,3, 1,2,5,1,5,4,
		8,7,10,8,10,6, 7,9,11,7,11,10,
		3,4,9,3,9,8, 4,5,11,4,11,9,
		0,6,7,0,7,1, 2,5,11,2,11,10
	])
	var face := solid(parent,label,verts,indices,["3d4a50","46555a","53605f"][rng.randi_range(0,2)])
	face.set_meta("wall_kind","layered_rock_face")
	# Broken sediment ledges provide rock texture without parallel rails.
	if height > 1.0 and rng.randf() < 0.58:
		var ledge_a := a.lerp(b,0.16)+side*0.05+Vector3(0,height*0.58,0)
		var ledge_b := a.lerp(b,0.52)+side*0.08+Vector3(0,height*0.58,0)
		beam(parent,label+"_LedgeA",ledge_a,ledge_b,0.11,"65706b")
	if rng.randf() < 0.34:
		var cap := a.lerp(b,rng.randf_range(0.30,0.72))+side*rng.randf_range(-0.08,0.08)
		rock(parent,label+"_CapRock",cap+Vector3(0,height*0.88,0),Vector3(rng.randf_range(0.34,0.62),rng.randf_range(0.18,0.34),rng.randf_range(0.40,0.70)),"65706b")

func collision_wall(parent: Node, label: String, a: Vector3, b: Vector3, height: float) -> void:
	if boundary_collisions == null: return
	var body := StaticBody3D.new()
	body.name = "BoundaryCollision_%s" % label
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("boundary_segment",label)
	boundary_collisions.add_child(body,true); body.owner = scene_root
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.58,height,maxf(0.55,a.distance_to(b)))
	shape.shape = box_shape
	body.add_child(shape,true); shape.owner = scene_root
	body.position = (a+b)*0.5 + Vector3(0,height*0.5,0)
	body.rotation.y = atan2(b.x-a.x,b.z-a.z)

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
		# One broken shoulder at a time; alternating sides prevents a second
		# straight road from emerging beside the actual road surface.
		if rng.randf() < 0.52: continue
		var sign := -1 if ((k + int(width*10.0)) % 3 == 0) else 1
		var q: Vector3 = p+side*(width*0.5*rng.randf_range(0.94,1.18)*sign)+side*rng.randf_range(-0.18,0.18)
		var h := rng.randf_range(0.22,0.52)
		rock(g,"RoadShoulderStone",Vector3(q.x,p.y+h*0.36,q.z),Vector3(rng.randf_range(0.34,0.68),h,rng.randf_range(0.34,0.74)),["59615f","6d6b5e","4e5758"][rng.randi_range(0,2)])

func route_ribbon(parent: Node, label: String, route: Array, width: float, color: String) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var across := maxi(6,ceili(width/0.72))
	for i in range(route.size()):
		var p: Vector3 = route[i]
		var prev: Vector3 = route[maxi(0,i-1)]
		var next: Vector3 = route[mini(route.size()-1,i+1)]
		var tangent := Vector3(next.x-prev.x,0,next.z-prev.z).normalized()
		var side := Vector3(-tangent.z,0,tangent.x)
		var local_width := width*(0.90+0.10*sin(float(i)*0.71+0.3))
		for j in range(across+1):
			var u := j/float(across)
			var shoulder := 0.05*sin(float(i)*0.43+u*2.1)
			var offset := lerpf(-local_width*0.5,local_width*0.5,u)+shoulder
			# The road sits just above the shared terrain datum; its edge is
			# blended by broken shoulders rather than a second raised strip.
			verts.append(p+side*offset+Vector3(0,0.024+0.008*sin(i*0.7+j*1.2),0))
	for i in range(route.size()-1):
		for j in range(across):
			var a := i*(across+1)+j
			var b := a+1
			var c := (i+1)*(across+1)+j
			var d := c+1
			indices.append_array([a,c,d,a,d,b])
	var node := solid(parent,label,verts,indices,color,Vector3.UP)
	node.set_meta("surface_kind","continuous_road")
	node.set_meta("route_control_points",route.size())
	return node

func road_marker(parent: Node, label: String, p: Vector3, facing: Vector3, kind: String) -> void:
	var g := group(parent,"RoadMarker_%s_%s" % [kind,label],p)
	g.set_meta("connection_id",label); g.set_meta("marker_kind",kind)
	var dir := Vector3(facing.x,0,facing.z).normalized()
	var side := Vector3(-dir.z,0,dir.x)
	for sign in [-1,1]:
		rock(g,"MarkerStone",side*sign*0.82+Vector3(0,0.13,0),Vector3(0.22,0.26,0.28),"7c7664")
	beam(g,"MarkerStake",-side*0.42+Vector3(0,0.05,0),-side*0.42+Vector3(0,0.52,0),0.035,"8d744f")

func corridor_edges(parent: Node, label: String, points: Array, width: float) -> void:
	var g := group(parent,label)
	for i in range(points.size()-1):
		path_wall_edge(g,"RoadShoulderSpan_%02d"%i,points[i],points[i+1],width)

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
	for i in range(2,route.size()-2,5):
		var p: Vector3 = route[i]
		var dir := Vector3(route[i+1].x-route[i-1].x,0,route[i+1].z-route[i-1].z).normalized()
		# Use a few broad worn areas instead of repeated pebbles and dark line
		# grooves, which previously formed a dotted/striped road texture.
		broad_wear_patch(g,"RoadWearBand_%02d"%i,p,Vector2(width*0.34,width*0.12),p.y+0.028,tone(color,i),atan2(dir.x,dir.z))
		if rng.randf() < 0.38:
			var side := Vector3(-dir.z,0,dir.x)
			var q := p+side*rng.randf_range(-width*0.34,width*0.34)
			rock(g,"PathWearStone",Vector3(q.x,p.y+0.08,q.z),Vector3(rng.randf_range(0.22,0.42),0.08,rng.randf_range(0.20,0.38)),tone(color,i))

func corridor(parent: Node, label: String, points: Array, width: float, y: float, color := "57534a") -> void:
	var g := group(parent,label)
	var route := smooth_route(points)
	for i in range(route.size()):
		var q: Vector3 = route[i]
		# Keep the road on the same low-frequency terrain undulation as the
		# region it crosses. This removes coplanar overlays and visible floating
		# strips at the entrances while preserving the intended slope.
		q.y = lerpf(q.y,surface_y(q.x,q.z,q.y),0.58)
		route[i] = q
	var road := route_ribbon(g,"RoadSurface",route,width,color)
	road.set_meta("connection_id",label)
	road.set_meta("route_control_points",points.size())
	road.set_meta("road_role","continuous marked route")
	mesh_collision(g,road,"RoadCollision")
	corridor_edges(g,"StonePathBoundary",route,width*(0.90+rng.randf_range(-0.05,0.12)))
	path_wear(g,"SurfaceWear",route,width,color)
	route_registry.append(label)
	road_marker(g,label+"_Start",points[0],points[1]-points[0],"start")
	road_marker(g,label+"_End",points[points.size()-1],points[points.size()-1]-points[points.size()-2],"end")

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

func broad_wear_patch(parent: Node, label: String, center: Vector3, extent: Vector2, y: float, color: String, angle: float) -> void:
	# A low-poly, broad stain breaks up a large floor without becoming a
	# collection of dots. The irregular perimeter is intentionally soft and
	# each patch is large enough to survive the final pixel scale.
	var ring := PackedVector2Array()
	for i in range(8):
		var a := i*TAU/8.0
		var radius := 0.76 + 0.24*sin(i*2.17+center.x*0.13+center.z*0.09)
		ring.append(Vector2(cos(a)*extent.x*radius,sin(a)*extent.y*radius))
	var verts := PackedVector3Array([Vector3.ZERO])
	for q in ring:
		verts.append(Vector3(q.x,0.012*sin(q.x*0.5),q.y))
	var indices := PackedInt32Array()
	for i in range(8):
		indices.append_array([0,1+i,1+((i+1)%8)])
	var patch := solid(parent,label,verts,indices,color,Vector3.UP)
	patch.position = Vector3(center.x,y,center.z)
	patch.rotation.y = angle
	patch.set_meta("detail_kind","broad_wear_patch")

func debris_cluster(parent: Node, label: String, center: Vector3, wet := false) -> void:
	var g := group(parent,label,center)
	var colors := ["777362","625f55","85806e"] if not wet else ["6b7b78","536b6c","82908a"]
	for i in range(3):
		var p := Vector3(rng.randf_range(-0.55,0.55),0.06+rng.randf_range(0,0.06),rng.randf_range(-0.42,0.42))
		var s := Vector3(rng.randf_range(0.28,0.58),rng.randf_range(0.08,0.18),rng.randf_range(0.24,0.52))
		rock(g,"EmbeddedRock",p,s,colors[i%colors.size()])

func ground_detail(parent: Node, label: String, center: Vector3, extent: Vector2, wet := false, count := 14) -> void:
	var g := group(parent,label)
	var soil_colors := ["6d6658","80745f","554f47"] if not wet else ["3d5b5e","42696a","536f6c"]
	var patch_count := maxi(2,mini(4,ceili(float(count)/10.0)))
	for i in range(patch_count):
		var p := Vector3(center.x+rng.randf_range(-extent.x*0.48,extent.x*0.48),center.y,center.z+rng.randf_range(-extent.y*0.48,extent.y*0.48))
		var e := Vector2(rng.randf_range(extent.x*0.22,extent.x*0.48),rng.randf_range(extent.y*0.12,extent.y*0.30))
		broad_wear_patch(g,"ContinuousWear_%02d"%i,p,e,center.y+0.022,soil_colors[i%soil_colors.size()],rng.randf_range(0,TAU))
	var clusters := maxi(1,mini(4,ceili(float(count)/8.0)))
	for i in range(clusters):
		var p := Vector3(center.x+rng.randf_range(-extent.x*0.55,extent.x*0.55),center.y+0.04,center.z+rng.randf_range(-extent.y*0.55,extent.y*0.55))
		debris_cluster(g,"DebrisCluster_%02d"%i,p,wet)

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
	boundary_collisions = group(scene_root,"SavedWallCollisions")
	portal_points = [
		Vector3(0,0,22),Vector3(0,0,16),Vector3(-1,0,1),Vector3(9,0,4),
		Vector3(18,1.8,-3),Vector3(24,3.8,-12),Vector3(30,3.8,-18),
		Vector3(19,2.4,-20),Vector3(-17,-2,-16),Vector3(1,2.4,-23),
		Vector3(-10,-0.2,4),Vector3(-21,-0.8,-3),Vector3(-22,-1.4,-15),
		Vector3(4,2.4,-26),Vector3(-12,0.8,-28),Vector3(-9,0.8,-29),
		Vector3(19,3,-29),Vector3(34,3,-29)
	]

	var j0_points=[Vector3(-6,0,25),Vector3(4,0,27),Vector3(8,0,23),Vector3(6,0,17),Vector3(1,0,14),Vector3(-5,0,16),Vector3(-9,0,21)]
	patch(terrain,"J0_EntranceHall",j0_points,0.0,"625e52"); rim(rock_shell,j0_points,0.0,1.4,2,"RegionRockRim_J0")
	corridor(terrain,"J0_J1_J8_MainCorridor",[Vector3(0,0,25.4),Vector3(-2.5,0,22.3),Vector3(1.2,0,18.5),Vector3(-2.0,0,14.6),Vector3(1.4,0,10.5),Vector3(-2.6,0,6.5),Vector3(-1.2,0,2.2)],4.1,0.0,"625d51")
	var j8_points=[Vector3(-12,0,6),Vector3(-8,0,12),Vector3(3,0,13),Vector3(12,0,8),Vector3(12,0,-2),Vector3(6,0,-7),Vector3(-6,0,-7),Vector3(-13,0,-2)]
	patch(terrain,"J8_OldCartYard",j8_points,0.0,"6c6252"); rim(rock_shell,j8_points,0.0,2.6,2,"RegionRockRim_J8")

	var j2_points=[Vector3(12,0,7),Vector3(19,0,8),Vector3(23,0,4),Vector3(22,0,-1),Vector3(17,0,-4),Vector3(12,0,-2)]
	patch(terrain,"J2_BoneSortingLedge",j2_points,1.8,"575650"); rim(rock_shell,j2_points,1.75,1.1,2,"RegionRockRim_J2")
	corridor(terrain,"J8_to_J2",[Vector3(9.0,0,4.0),Vector3(10.0,0.35,5.7),Vector3(12.0,0.8,5.9),Vector3(13.7,1.35,4.4),Vector3(14.5,1.8,2.2)],3.2,1.0,"625f54")
	corridor(terrain,"J2_to_J4",[Vector3(18.0,1.8,-2.4),Vector3(20.2,2.2,-4.2),Vector3(21.4,2.7,-6.0),Vector3(19.8,3.2,-7.6),Vector3(20.0,3.8,-9.0)],3.0,2.4,"565957")
	var j4_points=[Vector3(12,0,-9),Vector3(18,0,-10),Vector3(25,0,-8),Vector3(29,0,-11),Vector3(27,0,-15),Vector3(18,0,-16),Vector3(13,0,-13)]
	patch(terrain,"J4_UpperFissureWalk",j4_points,3.8,"454d52"); rim(rock_shell,j4_points,3.75,3.1,2,"RegionRockRim_J4")
	corridor(terrain,"J4_to_J11",[Vector3(25.0,3.8,-12.0),Vector3(26.2,3.8,-13.0),Vector3(27.4,3.7,-14.2),Vector3(26.8,3.8,-15.4),Vector3(29.0,4.0,-16.6)],2.5,3.7,"4e5558")

	bridge_path(terrain,"J11_SuspendedBoneBridge",[Vector3(27.0,4.0,-15.6),Vector3(28.0,4.0,-16.4),Vector3(29.2,4.0,-16.3),Vector3(30.2,4.0,-17.2),Vector3(31,4.0,-18)])
	corridor(terrain,"J11_to_J5",[Vector3(29.4,4.0,-17.4),Vector3(27.4,3.5,-18.6),Vector3(24.4,3.0,-19.2),Vector3(22.0,2.6,-20.7),Vector3(19.4,2.4,-20.8)],2.7,3.0,"56564f")
	var j5_points=[Vector3(6,0,-22),Vector3(15,0,-20),Vector3(21,0,-21),Vector3(23,0,-27),Vector3(18,0,-31),Vector3(7,0,-31),Vector3(1,0,-27),Vector3(1,0,-24)]
	patch(terrain,"J5_BoneCairnHall",j5_points,2.4,"5b5449"); rim(rock_shell,j5_points,2.35,2.4,2,"RegionRockRim_J5")
	var j6_points=[Vector3(-27,0,-12),Vector3(-19,0,-10),Vector3(-15,0,-14),Vector3(-16,0,-21),Vector3(-23,0,-23),Vector3(-29,0,-19)]
	patch(terrain,"J6_SunkenPit",j6_points,-2.2,"3d4b50"); rim(rock_shell,j6_points,-2.1,3.8,2,"RegionRockRim_J6")
	corridor(terrain,"J6_to_J5_OneWay",[Vector3(-17,-2,-16),Vector3(-15.3,-1.7,-17.8),Vector3(-12.2,-0.9,-18.4),Vector3(-8.5,0.0,-19.8),Vector3(-4.8,1.2,-20.8),Vector3(1.0,2.4,-23.0)],2.5,0.0,"545550")

	var j3_points=[Vector3(-28,0,7),Vector3(-20,0,11),Vector3(-13,0,8),Vector3(-12,0,1),Vector3(-17,0,-4),Vector3(-26,0,-4),Vector3(-32,0,1)]
	patch(terrain,"J3_SeepingThroat",j3_points,-0.8,"2f5b61"); rim(rock_shell,j3_points,-0.65,2.0,2,"RegionRockRim_J3")
	corridor(terrain,"J8_to_J3",[Vector3(-9.0,0,4),Vector3(-11.2,-0.1,5.8),Vector3(-14.0,-0.35,5.4),Vector3(-16.0,-0.6,4.0)],3.2,-0.4,"416068")
	var j9_points=[Vector3(-30,0,-4),Vector3(-25,0,-7),Vector3(-16,0,-7),Vector3(-11,0,-12),Vector3(-15,0,-18),Vector3(-24,0,-18),Vector3(-31,0,-14)]
	patch(terrain,"J9_StonePillarForest",j9_points,-1.4,"3d5055"); rim(rock_shell,j9_points,-1.3,3.4,2,"RegionRockRim_J9")
	corridor(terrain,"J3_to_J9",[Vector3(-21,-0.8,-3),Vector3(-23.0,-0.95,-4.4),Vector3(-24.0,-1.1,-6.2),Vector3(-22.0,-1.25,-8.0)],2.9,-1.0,"416068")
	corridor(terrain,"J9_to_J6",[Vector3(-22.0,-1.4,-15),Vector3(-23.5,-1.55,-16.0),Vector3(-24.5,-1.8,-17.2),Vector3(-22.0,-2.0,-18.0)],2.5,-1.6,"465b5c")

	var j10_points=[Vector3(-28,0,-22),Vector3(-20,0,-24),Vector3(-12,0,-23),Vector3(-9,0,-27),Vector3(-13,0,-33),Vector3(-22,0,-34),Vector3(-29,0,-30)]
	patch(terrain,"J10_GreyWaterTerraces",j10_points,0.8,"565852"); rim(rock_shell,j10_points,0.75,2.2,2,"RegionRockRim_J10")
	corridor(terrain,"J5_to_J10",[Vector3(4.0,2.4,-26),Vector3(1.2,2.1,-26.4),Vector3(-2.0,1.8,-26.7),Vector3(-5.0,1.45,-27.0),Vector3(-7.2,1.0,-28.0),Vector3(-9.0,0.8,-29.0)],3.2,1.6,"5a5a51")
	var j7_points=[Vector3(-33,0,-24),Vector3(-29,0,-24),Vector3(-29,0,-29),Vector3(-34,0,-31)]
	patch(terrain,"J7_SealedWestFissure",j7_points,0.9,"252d32"); rim(rock_shell,j7_points,0.8,3.5,2,"RegionRockRim_J7")
	var j12_points=[Vector3(21,0,-24),Vector3(28,0,-23),Vector3(34,0,-25),Vector3(36,0,-30),Vector3(31,0,-34),Vector3(22,0,-33),Vector3(18,0,-28)]
	patch(terrain,"J12_CollapseQuarry",j12_points,3.0,"50504c"); rim(rock_shell,j12_points,2.95,1.7,2,"RegionRockRim_J12")
	corridor(terrain,"J10_to_J12",[Vector3(-9.0,0.8,-29),Vector3(-6.6,1.0,-30.6),Vector3(-3.0,1.45,-31.2),Vector3(0.8,1.8,-30.7),Vector3(4.0,2.1,-29.0),Vector3(8.6,2.35,-29.7),Vector3(13.4,2.7,-29.4),Vector3(19.0,3.0,-29)],2.8,2.0,"56574f")
	var j13_points=[Vector3(35,0,-25),Vector3(42,0,-25),Vector3(45,0,-29),Vector3(43,0,-34),Vector3(36,0,-34),Vector3(33,0,-30)]
	patch(terrain,"J13_NameWallChamber",j13_points,3.0,"494b49"); rim(rock_shell,j13_points,2.95,2.6,2,"RegionRockRim_J13")
	corridor(terrain,"J12_to_J13",[Vector3(34.0,3,-29),Vector3(34.2,3,-27.5),Vector3(36.0,3,-26.7),Vector3(38.0,3,-28.0),Vector3(38.0,3,-29.0)],2.2,3.0,"52554e")

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
		carve_opening(rock_shell,opening,4.5)

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
	# Wheel and drag wear is now represented by broad broken stains in the
	# relevant floor groups; long beams here used to read as unexplained roads.
	broad_wear_patch(props,"J8_BrokenWheelWear",Vector3(-1,0.06,6),Vector2(2.4,0.62),0.08,"514f49",0.18)
	broad_wear_patch(props,"J5_BoneDragWear",Vector3(11,2.46,-27),Vector2(2.8,0.55),2.48,"514f49",-0.32)

	var scale_ref := group(scene_root,"ScaleReference")
	cylinder(scale_ref,"PlayerHeightMarker",Vector3(-7,1.0,22),0.06,2.0,"c6b08a",0.06,6)
