extends "res://burial_ridge/tools/sculpt_saved_terrain.gd"
## Offline authoring of this new extension only. Never attached to the game scene.
const NORTH_OUTPUT := "res://northern_ridge/world.tscn"
var routes: Array = []
var forest_positions: Array[Vector2] = []
var obstacle_root: StaticBody3D
var surface_mat: ShaderMaterial

func _initialize() -> void:
	if not "--bake" in OS.get_cmdline_user_args() or (FileAccess.file_exists(NORTH_OUTPUT) and not "--overwrite-new" in OS.get_cmdline_user_args()):
		push_error("Bake only the new extension with --bake. Never rebuild the saved village.")
		quit(1)
		return
	shader=load("res://village/style.gdshader")
	rng.seed=918260
	natural_noise.seed=917369
	natural_noise.frequency=0.12
	scene_root=Node3D.new()
	scene_root.name="NorthernRidge"
	obstacle_root=StaticBody3D.new()
	obstacle_root.name="SavedWalkCollisions"
	scene_root.add_child(obstacle_root)
	obstacle_root.owner=scene_root
	make_north_terrain()
	make_routes()
	root_gate()
	pavilion()
	ancient_tree()
	stone_terraces()
	herb_hollow()
	north_forest()
	ground_ecology()
	understory_details()
	collision_box(obstacle_root,"NorthernLimit",Vector3(-63,2,-77),Vector3(52,8,0.6))
	collision_box(obstacle_root,"WesternLimit",Vector3(-87,2,-54.5),Vector3(0.6,8,45))
	collision_box(obstacle_root,"EasternLimit",Vector3(-26,2,-54.5),Vector3(0.6,8,45))
	scene_root.set_meta("reference_image","地图草稿乙.png")
	scene_root.set_meta("player_height_reference",1.86)
	scene_root.set_meta("south_terrain_seam_z",-42.0)
	assert(save_scene(NORTH_OUTPUT)==OK)
	scene_root.free()
	quit()

func elevation(x: float,z: float) -> float:
	var blend:=1.0-smoothstep(-52,-42,z)
	var rise:=0.72+0.58*exp(-pow((x+78)/14,2)-pow((z+60)/17,2))
	var slope:=0.32*(1+natural_noise.get_noise_2d(x*0.8,z*0.8))
	var hollow:=0.31*exp(-pow((x+74)/5.5,2)-pow((z+43)/6,2))
	# The cave is a fold in the same terrain: a high northern shelf, a lower southern floor,
	# and a broad sloped fold between them. The doorway sits in that fold instead of on a prop slab.
	var gate_fade: float=0.0 if z>-42.25 else 1.0-smoothstep(-43.5,-42.25,z)
	var gate_width:=1.0-smoothstep(7.5,12.5,absf(x+55.0))
	var gate_terrace:=2.05*(1.0-smoothstep(-55.0,-48.5,z))*gate_width*gate_fade
	var gate_shoulder:=0.34*exp(-pow((x+55)/9.0,2)-pow((z+53)/7.5,2))*gate_fade
	var gate_cut:=0.26*exp(-pow((x+55)/2.8,2)-pow((z+48)/2.2,2))*gate_fade
	return super.elevation(x,z)+maxf(0,rise+slope-hollow)*blend+gate_terrace+gate_shoulder-gate_cut

func weights_at(x: float,z: float) -> Color:
	var old:=super.weights_at(x,z)
	var north:=1-smoothstep(-53,-42,z)
	var red:=1-smoothstep(-73,-61,x+natural_noise.get_noise_2d(x,z)*5)
	red*=0.77+0.23*smoothstep(-0.18,0.24,natural_noise.get_noise_2d(x*2.4,z*2.4))
	var trail:=maxf(0,natural_noise.get_noise_2d(x*2,z*2))*0.15
	var fresh:=Color(0.41*(1-red),0.12*(1-red),0.80*red+trail,0.47*(1-red)+0.20*red-trail)
	return old.lerp(fresh,north)

func ground(x: float,z: float) -> Vector3:
	return Vector3(x,0.07+elevation(x,z),z)

func make_north_terrain() -> void:
	terrain_group=group(scene_root,"ContinuousForestGround")
	terrain_material=ShaderMaterial.new()
	terrain_material.shader=load("res://northern_ridge/forest_ground.gdshader")
	terrain_material.set_shader_parameter("grass_color",Color("8f9c72"))
	terrain_material.set_shader_parameter("mineral_color",Color("a1a99b"))
	terrain_material.set_shader_parameter("loam_color",Color("a69d7e"))
	terrain_material.set_shader_parameter("litter_color",Color("7d8a6c"))
	terrain_material.set_meta("village_toon",true)
	for x in range(-112,-26,8):
		for z in range(-82,-42,8):
			make_chunk(x,z,minf(x+8,-26),minf(z+8,-42))
	box(terrain_group,"NorthernEarthUnderlay",Vector3(-69,-0.50,-62),Vector3(86,0.8,40),"77745b")

func make_routes() -> void:
	road_root=group(scene_root,"WindingTrails")
	add_route("CemeteryToPavilion",[Vector2(-71,-25),Vector2(-70.5,-29),Vector2(-68,-32.5),Vector2(-65,-35),Vector2(-61.5,-35.7)],1.50,true)
	add_route("PavilionToRootGate",[Vector2(-61.5,-35.7),Vector2(-57.8,-37.8),Vector2(-56,-42),Vector2(-55,-45.6),Vector2(-55,-47.3)],1.45,false)
	add_route("EasternWoodlandLink",[Vector2(-40,-18),Vector2(-40,-23),Vector2(-40,-28),Vector2(-41,-33),Vector2(-42,-38),Vector2(-44,-43),Vector2(-43,-48),Vector2(-39,-52),Vector2(-34,-55),Vector2(-31,-61),Vector2(-31,-69)],2.15,false)
	add_route("NorthernStoneCrossing",[Vector2(-79,-54),Vector2(-73,-53),Vector2(-67,-54.5),Vector2(-60,-56),Vector2(-52,-56),Vector2(-45,-55),Vector2(-39,-52)],1.85,false)
	add_route("RedEarthAscent",[Vector2(-69,-32.5),Vector2(-72,-36),Vector2(-78,-43),Vector2(-81,-48),Vector2(-79,-54),Vector2(-83,-61),Vector2(-83,-70)],1.45,false)
	conform(road_root)
	paint_paths(road_root)
	var paving:=group(scene_root,"BrokenForestPaving")
	for i in range(100):
		var p:=Vector2(rng.randf_range(-48,-37),rng.randf_range(-56,-51))
		if path_distance(p)>1.45: continue
		var stone:=ball(paving,"HalfBuriedOldPaver",ground(p.x,p.y)+Vector3(0,0.025,0),Vector3(rng.randf_range(0.14,0.32),0.05,rng.randf_range(0.12,0.26)),["929888","a6ab96","818b7c"][i%3])
		stone.rotation.y=rng.randf()*TAU

func add_route(label: String,points: Array,width: float,cold: bool) -> void:
	routes.append(points)
	detailed_road(label,points,width,cold)

func path_distance(p: Vector2) -> float:
	var closest:=INF
	for route in routes:
		for i in range(route.size()-1):
			var a: Vector2=route[i]
			var b: Vector2=route[i+1]
			var t:=clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
			closest=minf(closest,p.distance_to(a.lerp(b,t)))
	return closest

func paint_paths(node: Node) -> void:
	if node is MeshInstance3D and node.mesh is ArrayMesh and node.name!="BentBlades":
		var m:=ShaderMaterial.new()
		m.shader=load("res://burial_ridge/ground_paint.gdshader")
		m.set_shader_parameter("base_color",node.get_active_material(0).get_shader_parameter("base_color"))
		var v: Vector3=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
		m.render_priority=clampi(roundi((v.y-elevation(v.x,v.z)-0.13)*1000),0,60)
		m.set_meta("village_toon",true)
		node.material_override=m
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children(): paint_paths(c)

func tapered_root(parent: Node,label: String,points: Array,radius: float,color: String) -> void:
	var g:=group(parent,label)
	var curve:=Curve3D.new()
	for i in points.size():
		var prev: Vector3=points[maxi(i-1,0)]
		var next: Vector3=points[mini(i+1,points.size()-1)]
		var tangent: Vector3=(next-prev)*0.16
		curve.add_point(points[i],-tangent,tangent)
	curve.bake_interval=0.25
	var baked:=curve.get_baked_points()
	for i in range(baked.size()-1):
		var a:=baked[i]
		var b:=baked[i+1]
		var r0:=lerpf(radius,radius*0.08,float(i)/(baked.size()-1))
		var r1:=lerpf(radius,radius*0.08,float(i+1)/(baked.size()-1))
		var segment:=cylinder(g,"TaperingWood",(a+b)/2,r0,a.distance_to(b)+0.025,color,r1,7)
		segment.quaternion=Quaternion(Vector3.UP,(b-a).normalized())

func gate_local_point(x: float,z: float,lift: float=0.04) -> Vector3:
	var base:=elevation(-55,-48)
	return Vector3(x,elevation(-55+x,-48+z)-base+lift,z)

func root_gate() -> void:
	var hill:=group(scene_root,"RootWrappedStoneGate",ground(-55,-48))
	var body:=StaticBody3D.new()
	body.name="PassageCollisions"
	hill.add_child(body)
	body.owner=scene_root
	for side in [-1,1]:
		for j in range(5):
			box(hill,"WeatheredDoorJamb",Vector3(side*1.06,0.26+j*0.48,0.68),Vector3(0.48,0.45,0.68),["929c8b","a5ab97","87927f"][j%3])
		collision_box(body,"StoneJamb",Vector3(side*1.06,1.20,0.68),Vector3(0.48,2.4,0.68))
		box(hill,"RecessSide",Vector3(side*1.10,1.16,-0.30),Vector3(0.40,2.32,1.65),"737e6d")
		collision_box(body,"TunnelSide",Vector3(side*1.10,1.16,-0.30),Vector3(0.4,2.32,1.65))
	box(hill,"ChippedStoneLintel",Vector3(0,2.50,0.71),Vector3(2.88,0.38,0.94),"a7ae9a")
	collision_box(body,"LintelClearOfHead",Vector3(0,2.50,0.71),Vector3(2.88,0.38,0.94))
	box(hill,"DarkRecessBack",Vector3(0,1.16,-1.1),Vector3(2.0,2.32,0.08),"30382d")
	collision_box(body,"TunnelEnd",Vector3(0,1.16,-1.14),Vector3(2.0,2.32,0.10))
	var roots:=group(hill,"WrappingRoots")
	for side in [-1,1]:
		# Three short primaries with several bends read as roots pressed into the mound.
		var root_paths: Array = [
			[gate_local_point(side*0.82,-2.30,0.22),gate_local_point(side*1.35,-1.92,0.16),gate_local_point(side*1.18,-1.16,0.11),gate_local_point(side*1.62,-0.20,0.07),gate_local_point(side*2.72,0.72,0.045)],
			[gate_local_point(side*1.42,-2.62,0.20),gate_local_point(side*2.18,-2.42,0.15),gate_local_point(side*2.42,-1.72,0.10),gate_local_point(side*2.95,-1.56,0.065),gate_local_point(side*4.02,-2.05,0.04)],
			[gate_local_point(side*1.90,-1.50,0.18),gate_local_point(side*2.72,-1.15,0.13),gate_local_point(side*2.92,-0.42,0.09),gate_local_point(side*3.72,0.42,0.06),gate_local_point(side*4.76,1.40,0.04)]
		]
		for i in range(root_paths.size()):
			tapered_root(roots,"UnevenPrimaryRoot",root_paths[i],0.13+i*0.018,["706449","837257","635e45"][i%3])
			var branch_path: Array = [root_paths[i][1],root_paths[i][2]+Vector3(side*(0.42 if i%2==0 else -0.32),-0.10,0.28),root_paths[i][3]+Vector3(side*(0.40 if i==1 else -0.28),-0.08,0.44)]
			tapered_root(roots,"BrokenSideRoot",branch_path,0.065+i*0.012,"75684f")
	var distant_roots:=group(hill,"RootsFromAncientTree")
	for path in [
		[gate_local_point(-3.6,-3.0,0.11),gate_local_point(-4.4,-4.1,0.08),gate_local_point(-5.7,-4.7,0.06),gate_local_point(-7.0,-5.9,0.045),gate_local_point(-8.7,-6.2,0.035)],
		[gate_local_point(2.8,-3.4,0.11),gate_local_point(3.3,-4.4,0.08),gate_local_point(2.4,-5.4,0.06),gate_local_point(1.3,-6.3,0.045),gate_local_point(-0.4,-7.2,0.035)],
		[gate_local_point(-1.4,-3.8,0.10),gate_local_point(-2.4,-5.0,0.075),gate_local_point(-3.6,-5.7,0.055),gate_local_point(-4.7,-6.9,0.04),gate_local_point(-6.0,-7.6,0.03)]
	]:
		tapered_root(distant_roots,"DistantGiantTreeRoot",path,0.12,"705f49")
		tapered_root(distant_roots,"DistantFineFork",[path[1],path[2]+Vector3(0,0.02,0.35),path[3]+Vector3(0,0.02,0.52)],0.055,"665b45")
	# Small contour stones and moss tufts sit on the transition, never forming a new hard-edged slab.
	for i in range(30):
		var a:=rng.randf()*TAU
		var r:=rng.randf_range(2.5,6.3)
		var x:=cos(a)*r
		var z:=-1.5+sin(a)*3.8
		var y:=elevation(-55+x,-48+z)-elevation(-55,-48)
		ball(hill,"ApronContourStone",Vector3(x,y+0.05,z),Vector3(rng.randf_range(0.12,0.28),0.08,rng.randf_range(0.12,0.30)),["737b67","8f9279","66705c"][i%3])
	for p in [Vector3(-3.6,0,-2.0),Vector3(3.4,0,-2.4),Vector3(-4.8,0,-4.7),Vector3(4.8,0,-4.0)]:
		var tuft_root:=group(hill,"ApronMossTuft",Vector3(p.x,elevation(-55+p.x,-48+p.z)-elevation(-55,-48)+0.02,p.z))
		tuft(tuft_root,Vector3.ZERO,rng.randi_range(0,1)==0,p.x<0)
	# Canopies sit behind and beside the lintel, never directly over its silhouette.
	for base in [Vector2(-3.6,-2.0),Vector2(-1.1,-3.4),Vector2(2.3,-3.1),Vector2(4.1,-1.8)]:
		var local_y:=elevation(-55+base.x,-48+base.y)-elevation(-55,-48)
		conifer(hill,Vector3(base.x,local_y,base.y),0.78+rng.randf()*0.16,false)
	var portal:=Area3D.new()
	portal.name="ReservedEntrance"
	portal.collision_layer=0
	portal.collision_mask=1
	portal.monitoring=false
	portal.monitorable=false
	hill.add_child(portal)
	portal.owner=scene_root
	portal.set_meta("target_scene","")
	portal.set_meta("door_link_id","northern_root_cave_door")
	portal.set_meta("destination_id","northern_root_cave")
	collision_box(portal,"TriggerVolume",Vector3(0,1.0,0.15),Vector3(1.25,2,0.70))
	for label in ["EntryPoint","ExitSpawn"]:
		var marker:=Marker3D.new()
		marker.name=label
		hill.add_child(marker)
		marker.owner=scene_root
		var z:=0.0 if label=="EntryPoint" else 2.25
		marker.position=Vector3(0,0.015+elevation(-55,-48+z)-elevation(-55,-48),z)
		marker.set_meta("spawn_id","root_cave_entry" if label=="EntryPoint" else "root_cave_exit")

func pavilion() -> void:
	var p:=group(scene_root,"WeatheredWaysidePavilion",ground(-63,-36.5))
	box(p,"SunkenStonePlinth",Vector3(0,0.01,0),Vector3(3.35,0.10,3.1),"8b9580")
	for x in [-1.18,1.18]:
		for z in [-1.08,1.08]:
			cylinder(p,"OldTimberPillar",Vector3(x,1.37,z),0.13,2.68,"796348",0.105,8)
			cylinder(p,"RoughStoneFoot",Vector3(x,0.14,z),0.24,0.26,"a0a38c",-1,7)
			collision_box(obstacle_root,"PavilionPost",p.position+Vector3(x,1.30,z),Vector3(0.26,2.6,0.26))
	for z in [-1.08,1.08]: beam(p,"MortisedLintel",Vector3(-1.37,2.53,z),Vector3(1.37,2.53,z),0.11,"6b5b43")
	for x in [-1.18,1.18]: beam(p,"SideLintel",Vector3(x,2.53,-1.25),Vector3(x,2.53,1.25),0.11,"6b5b43")
	var roof_group:=group(p,"OldHippedTileRoof")
	var corners: Array[Vector3]=[Vector3(-1.72,2.68,-1.62),Vector3(1.72,2.68,-1.62),Vector3(1.72,2.68,1.62),Vector3(-1.72,2.68,1.62)]
	var peak:=Vector3(0,3.78,0)
	for side in range(4):
		var a: Vector3=corners[side]
		var b: Vector3=corners[(side+1)%4]
		solid(roof_group,"WeatheredHipPlane",PackedVector3Array([peak,a,b]),PackedInt32Array([0,1,2,2,1,0]),"716d57",Vector3.UP)
		for i in range(13):
			var edge:=a.lerp(b,(i+0.5)/13.0)
			for row in range(5):
				var t0:=0.12+row*0.17
				var t1:=t0+0.17
				beam(roof_group,"UnevenBarrelTile",peak.lerp(edge,t0)+Vector3.UP*0.055,peak.lerp(edge,t1)+Vector3.UP*0.055,0.050,["8d8773","a09980","797565"][(i+row)%3])
		beam(roof_group,"WornEave",a,b,0.095,"6e6049")
		tapered_root(roof_group,"CornerRidge",[peak+Vector3.UP*0.10,peak.lerp(a,0.6)+Vector3.UP*0.10,a+Vector3.UP*0.20],0.085,"a2926c")
	cylinder(roof_group,"StoneRoofFinial",Vector3(0,3.95,0),0.17,0.32,"a39776",0.11,8)
	var altar:=group(p,"WornStoneOfferingStand",Vector3(0,0,0.08))
	box(altar,"StoneSlab",Vector3(0,0.60,0),Vector3(0.80,0.18,0.67),"9ba18c")
	for side in [-1,1]:box(altar,"StoneLeg",Vector3(side*0.25,0.30,0),Vector3(0.20,0.60,0.36),"818a77")
	pot(altar,Vector3(0,0.70,0),0.13)
	for side in [-1,1]:
		var plank:=box(p,"FadedInscriptionBoard",Vector3(side*1.18,1.60,1.19),Vector3(0.16,1.54,0.035),"9a825f")
		for i in range(7): box(p,"WornInkMark",plank.position+Vector3(0,0.53-i*0.17,0.022),Vector3(0.06+rng.randf()*0.04,0.025,0.012),"544f3c")

func ancient_tree() -> void:
	var t:=group(scene_root,"AncientRootTree",ground(-77,-68))
	cylinder(t,"ButtressedOldTrunk",Vector3(0,3.6,0),1.0,7.2,"6c624d",0.55,9)
	for j in range(9):
		var a:=j*TAU/9+rng.randf_range(-0.20,0.20)
		var end:=Vector3(cos(a)*rng.randf_range(5.0,7),0.04,sin(a)*rng.randf_range(4.5,6))
		var sideways:=Vector3(-sin(a),0,cos(a))*rng.randf_range(-0.65,0.65)
		var points: Array=[Vector3(cos(a)*0.40,2.4,sin(a)*0.40),Vector3(cos(a)*1.2,0.5,sin(a)*1.2),end*0.40+sideways+Vector3.UP*0.14,end*0.73-sideways*0.5+Vector3.UP*0.08,end]
		tapered_root(t,"AncientButtressRoot",points,0.35,"776c51")
		var fork:=end*0.58
		tapered_root(t,"FineRootFork",[fork+Vector3.UP*0.15,end*0.82+Vector3(-sin(a)*0.55,0.05,cos(a)*0.55),end+Vector3(-sin(a)*1.15,0.02,cos(a)*1.15)],0.11,"6e644c")
		var branch:=Vector3(cos(a)*2.4,7.0+rng.randf(),sin(a)*2.2)
		beam(t,"OldCrownBranch",Vector3(0,4.8,0),branch,0.27,"756a50")
		for k in range(4):
			ball(t,"IrregularCrown",branch+Vector3(rng.randf_range(-0.8,0.8),rng.randf_range(-0.2,0.7),rng.randf_range(-0.8,0.8)),Vector3(1.35,0.90,1.28),["536345","69774b","798052","485b42"][(j+k)%4])
	collision_box(obstacle_root,"AncientTreeTrunk",t.position+Vector3(0,3.2,0),Vector3(1.55,6.4,1.55))

func stone_terraces() -> void:
	var rocks:=group(scene_root,"BrokenRedSlopeTerraces")
	for route in [[Vector2(-86,-46),Vector2(-81,-44),Vector2(-77,-45)], [Vector2(-82,-57),Vector2(-75,-59),Vector2(-69,-62)], [Vector2(-85,-73),Vector2(-80,-75),Vector2(-73,-76)]]:
		for k in range(route.size()-1):
			var a: Vector2=route[k]
			var b: Vector2=route[k+1]
			for j in range(7):
				var pt:=a.lerp(b,float(j)/7)
				if path_distance(pt)<1.2: continue
				var stone:=ball(rocks,"BrokenSlateLedge",ground(pt.x,pt.y)+Vector3(0,0.08,0),Vector3(0.57,0.17+rng.randf()*0.10,0.47),["9ba392","a9b09a","838e7f"][j%3])
				stone.rotation.y=rng.randf()*TAU
	for p in [Vector2(-79,-47),Vector2(-75,-55),Vector2(-70,-38),Vector2(-79,-39)]:
		var sign:=group(scene_root,"OldWarningStone",ground(p.x,p.y))
		var stone:=box(sign,"ChippedUprightStone",Vector3(0,0.61,0),Vector3(0.50,1.2,0.26),"969e8c")
		stone.rotation.z=-0.06
		ball(sign,"RoundedStoneCrown",Vector3(-0.03,1.17,0),Vector3(0.25,0.16,0.13),"969e8c")
		var text:=Label3D.new()
		text.name="WornWarningInscription"
		text.text="勿\n入"
		text.font_size=40
		text.pixel_size=0.005
		text.modulate=Color("515b4b")
		text.outline_size=0
		sign.add_child(text)
		text.owner=scene_root
		text.position=Vector3(0,0.72,0.14)

func herb_hollow() -> void:
	var bed:=group(scene_root,"DampHerbHollow",ground(-72,-42))
	# A feathered mossy depression with several tall, untended medicinal plants.
	soft_patch(bed,"DampMossBasin",Vector2(3.5,2.7),"7e9785")
	for i in range(15):
		var x:=rng.randf_range(-2.2,1.9)
		var z:=rng.randf_range(-1.6,1.4)
		var plant:=group(bed,"WildHerb",Vector3(x,elevation(-72+x,-42+z)-elevation(-72,-42),z))
		var height:=rng.randf_range(0.6,1.05)
		beam(plant,"BentStalk",Vector3.ZERO,Vector3(0.04,height,0),0.019,"637650")
		for j in range(4):
			for side in [-1,1]:
				var leaf:=ball(plant,"PointedHerbLeaf",Vector3(side*(0.10+0.03*j),0.18+j*0.17,0),Vector3(0.15,0.036,0.067),["72894e","869952","a2a25e"][j%3])
				leaf.rotation.z=side*0.6
		if i%3==0:ball(plant,"DrySeedHead",Vector3(0.04,height+0.02,0),Vector3(0.065,0.10,0.065),"b0aa77")
	var spade:=group(bed,"LeaningWoodenSpade",Vector3(2.1,0,0.3))
	spade.rotation.z=-0.30
	beam(spade,"OldHandle",Vector3(0,0.12,0),Vector3(0,1.10,0),0.033,"796b50")
	box(spade,"WornIronBlade",Vector3(0,0.13,0),Vector3(0.22,0.26,0.05),"7f8a7c")

func soft_patch(parent: Node3D,label: String,size: Vector2,color: String) -> void:
	var vs:=PackedVector3Array([Vector3(0,0.016,0)])
	var colors:=PackedColorArray([Color(1,1,1,0.76)])
	var ids:=PackedInt32Array()
	for ring in [0.68,1.0]:
		for i in range(24):
			var a:=i*TAU/24
			var x: float=cos(a)*size.x*ring
			var z: float=sin(a)*size.y*ring
			vs.append(Vector3(x,0.016+elevation(parent.position.x+x,parent.position.z+z)-elevation(parent.position.x,parent.position.z),z))
			colors.append(Color(1,1,1,0.64 if ring<0.9 else 0))
	for i in range(24):
		var a:=i+1
		var b:=(i+1)%24+1
		ids.append_array(PackedInt32Array([0,a,b,a,a+24,b,b,a+24,b+24]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vs
	arrays[Mesh.ARRAY_COLOR]=colors
	var ns:=PackedVector3Array()
	ns.resize(vs.size());ns.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL]=ns
	arrays[Mesh.ARRAY_INDEX]=ids
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var n:=mesh_node(parent,label,mesh,Vector3.ZERO,color)
	var material:=ShaderMaterial.new()
	material.shader=load("res://northern_ridge/soft_ground_patch.gdshader")
	material.set_shader_parameter("base_color",Color(color))
	material.set_meta("village_toon",true)
	material.render_priority=1
	n.material_override=material
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func conifer(parent: Node,p: Vector3,scale_value: float,with_collision: bool=true) -> void:
	var t:=group(parent,"OldPine",p)
	cylinder(t,"WeatheredTrunk",Vector3(0,2.5,0),0.19,5,"685f47",0.085,7)
	var colors: Array=["4c6147","5f714c","788251"] if rng.randf()>0.28 else ["787b4d","919056","a09a5c"]
	for tier in range(5):
		var height:=1.0+tier*0.78
		var radius:=1.23-tier*0.19
		var verts:=PackedVector3Array([Vector3(0,height+1.48,0)])
		for i in range(20):
			var a:=i*TAU/20+tier*0.28
			var r:=radius*rng.randf_range(1.08,1.35) if i%2==0 else radius*rng.randf_range(0.66,0.88)
			verts.append(Vector3(cos(a)*r,height+rng.randf_range(-0.08,0.18),sin(a)*r))
		var ids:=PackedInt32Array()
		for i in range(20): ids.append_array(PackedInt32Array([0,i+1,(i+1)%20+1]))
		solid(t,"IrregularNeedleTier",verts,ids,colors[tier%3])
		for j in range(5):
			var angle:=j*TAU/5+tier*0.7
			ball(t,"NeedleSpray",Vector3(cos(angle)*radius*0.69,height+0.20,sin(angle)*radius*0.69),Vector3(radius*0.31,0.22,radius*0.31),colors[(tier+j)%3])
	for j in range(4):
		var a:=j*TAU/4
		beam(t,"LowRoot",Vector3(0,0.10,0),Vector3(cos(a)*0.7,0.025,sin(a)*0.7),0.055,"75694d")
	t.scale=Vector3.ONE*scale_value
	if with_collision:
		collision_box(obstacle_root,"PineTrunk",p+Vector3(0,1.6*scale_value,0),Vector3(0.30,3.2,0.30)*scale_value)

func north_forest() -> void:
	var forest:=group(scene_root,"MixedNorthernForest")
	for i in range(1000):
		var p:=Vector2(rng.randf_range(-94,-27.5),rng.randf_range(-80,-37))
		var edge:=p.x<-85 or p.y<-69 or (p.x>-70 and p.y<-59) or (p.x>-45 and p.y>-49)
		if not edge or path_distance(p)<2.35: continue
		if p.distance_to(Vector2(-55,-48))<7.0 or p.distance_to(Vector2(-63,-36.5))<4.6 or p.distance_to(Vector2(-77,-68))<4.4:continue
		var near:=false
		for old in forest_positions:
			if p.distance_to(old)<2.0:near=true;break
		if near:continue
		forest_positions.append(p)
		if i%3==0:
			tree(forest,ground(p.x,p.y),rng.randf_range(0.83,1.13))
			collision_box(obstacle_root,"BroadleafTrunk",ground(p.x,p.y)+Vector3.UP*1.5,Vector3(0.40,3,0.40))
		else:conifer(forest,ground(p.x,p.y),rng.randf_range(0.73,1.15))
	# Flank the root gate with uneven conifers without screening its doorway.
	for p in [Vector2(-60.5,-47),Vector2(-61.5,-51),Vector2(-58.8,-52),Vector2(-50,-48.5),Vector2(-49,-52),Vector2(-66,-50.5)]:
		conifer(forest,ground(p.x,p.y),rng.randf_range(0.76,1.0))

func ground_ecology() -> void:
	var ecology:=group(scene_root,"ForestFloorEcology")
	var grass:=group(ecology,"UnevenGrassAndFerns")
	var litter:=group(ecology,"LeafLitterAndShale")
	for i in range(3000):
		var p:=Vector2(rng.randf_range(-86,-28),rng.randf_range(-76,-34))
		if path_distance(p)<1.1 or p.distance_to(Vector2(-63,-36.5))<2.6 or p.distance_to(Vector2(-55,-48))<5.7:continue
		var density:=natural_noise.get_noise_2d(p.x*2,p.y*2)
		if density<-0.03:continue
		if i%3!=0:
			tuft(grass,ground(p.x,p.y),i%7==0,p.x<-70)
			grass.get_child(grass.get_child_count()-1).scale=Vector3.ONE*(0.60 if i%7==0 else 0.95)
		else:
			var pocket:=group(litter,"ShaleAndLitterPocket",ground(p.x,p.y))
			for j in range(3):
				var leaf:=box(pocket,"LeafFragment",Vector3(rng.randf_range(-0.18,0.18),0.015,rng.randf_range(-0.18,0.18)),Vector3(0.055+rng.randf()*0.07,0.016,0.08),["9b8d64","aaa17a","7c8060"][j])
				leaf.rotation.y=rng.randf()*TAU
	var moss:=group(ecology,"NaturalMossAndClayPatches")
	for i in range(150):
		var p:=Vector2(rng.randf_range(-86,-45),rng.randf_range(-76,-38))
		if path_distance(p)<1.45 or p.distance_to(Vector2(-55,-48))<5.5:continue
		var patch_root:=group(moss,"SoftMossIsland",ground(p.x,p.y))
		soft_patch(patch_root,"BlendedPatch",Vector2(rng.randf_range(0.5,1.4),rng.randf_range(0.4,1.05)),["96a18b","8a987d","8c9478"][i%3])
	# Branching roots spread over the red shoulder beside the route.
	var roots:=group(ecology,"ExposedRedSlopeRoots",ground(-68,-48))
	var root_origins: Array[Vector3]=[Vector3(-0.15,0.24,-2.10),Vector3(-0.48,0.18,-1.55),Vector3(0.22,0.20,-1.18),Vector3(-0.82,0.16,-0.78)]
	var root_tips: Array[Vector3]=[Vector3(-5.25,0.04,-0.55),Vector3(-4.25,0.05,0.85),Vector3(-5.70,0.04,1.70),Vector3(-3.65,0.05,2.45)]
	for i in range(4):
		var o:=root_origins[i]
		var t:=root_tips[i]
		var mid:=Vector3(-1.35-rng.randf()*0.45,0.16,-1.62+i*0.72)
		var low:=Vector3(-2.65+rng.randf_range(-0.35,0.25),0.10,-0.80+i*0.76)
		tapered_root(roots,"IrregularSlopePrimaryRoot",[o,mid,low,t],0.16+i*0.025,["76694f","6d624b","84704f"][i%3])
		if i%2==0:
			tapered_root(roots,"SlopeRootFork",[mid,Vector3(-2.0,0.12,-1.05+i*0.65),Vector3(-3.25,0.06,0.15+i*0.85)],0.075,"665b45")

func understory_details() -> void:
	# Fill the open middle ground with low, readable layers while preserving clear routes.
	var under:=group(scene_root,"MidgroundUnderstory")
	var shrubs:=group(under,"LowShrubClusters")
	var stones:=group(under,"WeatheredStonePockets")
	var deadfall:=group(under,"FallenBranchesAndDeadfall")
	var shrub_positions: Array[Vector2]=[]
	for i in range(180):
		var p:=Vector2(rng.randf_range(-86,-29),rng.randf_range(-76,-36))
		if path_distance(p)<2.05:continue
		if p.distance_to(Vector2(-55,-48))<7.0 or p.distance_to(Vector2(-63,-36.5))<5.0 or p.distance_to(Vector2(-77,-68))<5.0:continue
		var near:=false
		for old in shrub_positions:
			if p.distance_to(old)<1.35:near=true;break
		if near:continue
		shrub_positions.append(p)
		var clump:=group(shrubs,"MossyShrubClump",ground(p.x,p.y))
		var scale_value:=rng.randf_range(0.72,1.12)
		for j in range(3+rng.randi_range(0,2)):
			var a:=rng.randf()*TAU
			var offset:=Vector3(cos(a)*rng.randf_range(0.15,0.52),rng.randf_range(0.28,0.48),sin(a)*rng.randf_range(0.15,0.52))
			ball(clump,"RoundedShrubLeaf",offset,Vector3(0.42,0.30,0.40)*scale_value,["566a4b","66774e","788259","4e634a"][rng.randi_range(0,3)])
		if i%4==0:
			var stem:=cylinder(clump,"DryShrubStem",Vector3(0,0.30,0),0.045,0.60,"655c45",0.025,6)
			stem.rotation.y=rng.randf()*TAU
	for i in range(115):
		var p:=Vector2(rng.randf_range(-88,-29),rng.randf_range(-78,-35))
		if path_distance(p)<1.55 or p.distance_to(Vector2(-55,-48))<6.0:continue
		var pocket:=group(stones,"BrokenStonePocket",ground(p.x,p.y))
		var count:=2+rng.randi_range(0,3)
		for j in range(count):
			var a:=rng.randf()*TAU
			var r:=rng.randf_range(0.15,0.75)
			ball(pocket,"HalfBuriedStone",Vector3(cos(a)*r,0.06+rng.randf_range(0,0.04),sin(a)*r),Vector3(rng.randf_range(0.16,0.38),rng.randf_range(0.08,0.18),rng.randf_range(0.14,0.34)),["858b7c","989b87","747d70"][j%3])
	for i in range(42):
		var p:=Vector2(rng.randf_range(-86,-31),rng.randf_range(-75,-37))
		if path_distance(p)<2.6 or p.distance_to(Vector2(-55,-48))<7.0:continue
		var log:=group(deadfall,"WeatheredFallenBranch",ground(p.x,p.y))
		var length:=rng.randf_range(1.2,2.8)
		var angle:=rng.randf()*TAU
		var end:=Vector3(cos(angle)*length,0.16,sin(angle)*length)
		beam(log,"FallenTrunk",Vector3(-end.x*0.5,0.16,-end.z*0.5),Vector3(end.x*0.5,0.16,end.z*0.5),rng.randf_range(0.07,0.13),["6b6049","76684d","5b5744"][i%3])
		if i%2==0:
			beam(log,"BrokenTwig",end*0.35+Vector3(0,0.08,0),end*0.75+Vector3(0,0.10,0),0.045,"665b45")
