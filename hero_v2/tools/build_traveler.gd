extends "res://hero_v2/tools/bake_helpers.gd"
## One-time authoring tool. Never referenced by a runtime scene.
const DEST := "res://hero_v2/"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--bake" not in args:
		push_error("Authoring requires --bake. Saved scenes are the source of truth.")
		quit(1)
		return
	if (FileAccess.file_exists(DEST + "traveler.tscn") or FileAccess.file_exists(DEST + "world.tscn")) and "--overwrite" not in args:
		push_error("Refusing to overwrite editable scenes without --overwrite.")
		quit(1)
		return
	shader = load(DEST + "cloth.gdshader")
	make_hero()
	make_world()
	quit()

func own(parent: Node, child: Node, label: String) -> Node:
	child.name = label
	parent.add_child(child)
	child.owner = scene_root
	return child

# Octagonal cross sections with clipped corners: every garment is real 3D geometry.
func tailored(parent: Node, label: String, pos: Vector3, sections: Array, color: String) -> MeshInstance3D:
	var verts: Array[Vector3] = []
	for row in sections:
		var y: float = row[0]
		var x: float = row[1] * 0.5
		var z: float = row[2] * 0.5
		for p in [Vector2(-0.68,-1),Vector2(0.68,-1),Vector2(1,-0.68),Vector2(1,0.68),Vector2(0.68,1),Vector2(-0.68,1),Vector2(-1,0.68),Vector2(-1,-0.68)]:
			verts.append(Vector3(p.x*x,y,p.y*z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(sections.size()-1):
		for i in range(8):
			var a := r*8+i
			var b := r*8+(i+1)%8
			var c := (r+1)*8+i
			var d := (r+1)*8+(i+1)%8
			for index in [a,b,c,b,d,c]:
				st.add_vertex(verts[index])
	for i in range(1,7):
		for index in [0,i+1,i]:
			st.add_vertex(verts[index])
		var top := (sections.size()-1)*8
		for index in [top,top+i,top+i+1]:
			st.add_vertex(verts[index])
	st.generate_normals()
	return mesh_node(parent,label,st.commit(),pos,color)

func lock(parent: Node, label: String, start: Vector3, tip: Vector3, width: float, color: String) -> void:
	var center := (start+tip)*0.5
	var node := cylinder(parent,label,center,width,start.distance_to(tip),color,0.015,5)
	node.quaternion = Quaternion(Vector3.UP,(tip-start).normalized())

func make_hero() -> void:
	scene_root = CharacterBody3D.new()
	scene_root.name = "Traveler"
	scene_root.set_script(load(DEST+"hero_controller.gd"))
	scene_root.set("floor_snap_length",0.25)
	scene_root.set("floor_max_angle",deg_to_rad(46.0))
	scene_root.add_to_group("player",true)
	var collision := own(scene_root,CollisionShape3D.new(),"BodyCollision") as CollisionShape3D
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	var facing := group(scene_root,"Facing")
	var visual := group(facing,"Visual")
	var body := group(visual,"Body",Vector3(0,0.82,0))
	tailored(body,"TunicHem",Vector3.ZERO,[[0.0,0.42,0.30],[0.12,0.39,0.29],[0.20,0.35,0.27]],"59564a")
	tailored(body,"Jacket",Vector3.ZERO,[[0.15,0.35,0.25],[0.40,0.47,0.29],[0.54,0.44,0.27],[0.58,0.30,0.23]],"817e6e")
	box(body,"FrontOpening",Vector3(0,0.33,0.152),Vector3(0.035,0.30,0.021),"484a43")
	var lapel_l := box(body,"LeftLapel",Vector3(-0.071,0.45,0.157),Vector3(0.073,0.23,0.028),"a5a08b")
	lapel_l.rotation.z = 0.26
	var lapel_r := box(body,"RightLapel",Vector3(0.071,0.45,0.157),Vector3(0.073,0.23,0.028),"979580")
	lapel_r.rotation.z = -0.26
	box(body,"Undershirt",Vector3(0,0.53,0.136),Vector3(0.09,0.16,0.022),"363d39")
	for side in [-1,1]:
		box(body,"JacketPocket%d" % side,Vector3(side*0.125,0.28,0.153),Vector3(0.115,0.105,0.028),"6b6b5e")
		box(body,"PocketFlap%d" % side,Vector3(side*0.125,0.325,0.172),Vector3(0.12,0.028,0.018),"96907b")
	tailored(body,"LeatherBelt",Vector3.ZERO,[[0.09,0.417,0.315],[0.158,0.402,0.31]],"343b36")
	box(body,"Buckle",Vector3(0,0.122,0.168),Vector3(0.09,0.066,0.03),"a69d7e")
	box(body,"BuckleInset",Vector3(0,0.122,0.188),Vector3(0.047,0.033,0.015),"42463c")
	var strap := box(body,"CrossBodyStrapFront",Vector3(0.015,0.365,0.184),Vector3(0.053,0.49,0.026),"444940")
	strap.rotation.z = -0.59
	var back_strap := box(body,"CrossBodyStrapBack",Vector3(0.015,0.365,-0.164),Vector3(0.055,0.49,0.025),"41453d")
	back_strap.rotation.z = 0.59
	tailored(body,"HipPouch",Vector3(-0.26,0.04,0.015),[[0.0,0.13,0.19],[0.15,0.15,0.20],[0.19,0.13,0.19]],"555749")
	box(body,"PouchFlap",Vector3(-0.26,0.175,0.11),Vector3(0.15,0.055,0.025),"89816b")
	var neck := group(body,"Neck",Vector3(0,0.58,0))
	cylinder(neck,"Skin",Vector3(0,0.025,0),0.083,0.15,"c4a489",-1,8)
	tailored(neck,"ScarfCollar",Vector3.ZERO,[[-0.026,0.235,0.24],[0.033,0.24,0.24],[0.075,0.19,0.19]],"555d55")
	var scarf := group(body,"ScarfTails",Vector3(0,0.57,-0.135))
	var tail_a := box(scarf,"LongTail",Vector3(-0.055,-0.155,-0.035),Vector3(0.078,0.33,0.026),"454b45")
	tail_a.rotation.z = -0.16
	box(scarf,"LightTip",Vector3(-0.08,-0.30,-0.034),Vector3(0.079,0.045,0.031),"b2afa0")
	var tail_b := box(scarf,"ShortTail",Vector3(0.06,-0.10,-0.05),Vector3(0.06,0.21,0.025),"73766a")
	tail_b.rotation.z = 0.23
	var head := group(body,"Head",Vector3(0,0.84,0.016))
	tailored(head,"Face",Vector3.ZERO,[[-0.215,0.24,0.25],[-0.16,0.37,0.33],[0.04,0.425,0.365],[0.19,0.36,0.32]],"d2b194")
	for side in [-1,1]:
		tailored(head,"Ear%d" % side,Vector3(side*0.224,-0.055,0.006),[[-0.065,0.055,0.078],[0.05,0.075,0.09]],"b9967c")
		box(head,"EyeSocket%d" % side,Vector3(side*0.091,-0.043,0.184),Vector3(0.082,0.066,0.014),"ad8c74")
		box(head,"EyeWhite%d" % side,Vector3(side*0.091,-0.033,0.197),Vector3(0.061,0.039,0.012),"cfcbbb")
		box(head,"Eye%d" % side,Vector3(side*0.082,-0.036,0.207),Vector3(0.03,0.043,0.012),"252c2c")
		box(head,"EyeGlint%d" % side,Vector3(side*0.082-0.006,-0.023,0.215),Vector3(0.009,0.011,0.008),"e2d2b3")
		var brow := box(head,"Brow%d" % side,Vector3(side*0.091,0.005,0.203),Vector3(0.077,0.022,0.016),"343838")
		brow.rotation.z = side*0.08
	tailored(head,"Nose",Vector3(0,-0.074,0.186),[[-0.02,0.043,0.035],[0.044,0.027,0.021]],"bd967a")
	box(head,"Mouth",Vector3(0,-0.145,0.173),Vector3(0.058,0.014,0.012),"92705e")
	var hair := group(head,"Hair")
	ball(hair,"Crown",Vector3(0,0.105,-0.04),Vector3(0.282,0.235,0.243),"373d40")
	ball(hair,"BackVolume",Vector3(0,0.025,-0.10),Vector3(0.257,0.25,0.194),"2c3233")
	# Broad asymmetric locks, with smaller graphite highlights, match the reference silhouette.
	var locks := [
		[Vector3(-0.18,0.23,0.10),Vector3(-0.245,-0.105,0.15),0.093,"303637"],
		[Vector3(-0.095,0.255,0.12),Vector3(-0.15,0.035,0.21),0.085,"4b5254"],
		[Vector3(0.01,0.27,0.12),Vector3(-0.035,0.053,0.216),0.077,"3c4446"],
		[Vector3(0.08,0.25,0.13),Vector3(0.146,0.026,0.216),0.071,"464d50"],
		[Vector3(0.18,0.21,0.085),Vector3(0.247,-0.11,0.115),0.094,"303738"],
		[Vector3(-0.21,0.115,-0.035),Vector3(-0.25,-0.175,-0.01),0.074,"292f30"],
		[Vector3(0.21,0.115,-0.035),Vector3(0.24,-0.17,-0.015),0.075,"303637"],
		[Vector3(-0.12,0.04,-0.21),Vector3(-0.11,-0.22,-0.17),0.076,"303638"],
		[Vector3(0.075,0.035,-0.22),Vector3(0.11,-0.215,-0.18),0.084,"363c3d"]]
	for i in range(locks.size()):
		lock(hair,"Lock%02d"%i,locks[i][0],locks[i][1],locks[i][2],locks[i][3])
	for side in [-1,1]:
		var label := "Left" if side == -1 else "Right"
		var arm := group(body,label+"Arm",Vector3(side*0.265,0.485,0))
		tailored(arm,"Sleeve",Vector3.ZERO,[[-0.26,0.14,0.155],[-0.07,0.195,0.19],[0.035,0.155,0.17]],"777767")
		box(arm,"ShoulderSeam",Vector3(side*0.085,-0.04,0),Vector3(0.025,0.065,0.18),"9b9580")
		var elbow := group(arm,"Elbow",Vector3(0,-0.27,0))
		tailored(elbow,"ForearmSleeve",Vector3.ZERO,[[-0.175,0.105,0.13],[-0.02,0.145,0.145],[0.025,0.14,0.14]],"6e7163")
		tailored(elbow,"RolledCuff",Vector3.ZERO,[[-0.19,0.13,0.148],[-0.125,0.145,0.16]],"a49b84")
		tailored(elbow,"WristWrap",Vector3.ZERO,[[-0.225,0.09,0.108],[-0.19,0.095,0.11]],"484f47")
		tailored(elbow,"Hand",Vector3(0,-0.23,0.012),[[-0.09,0.088,0.10],[-0.025,0.115,0.13],[0.015,0.092,0.106]],"d0aa8a")
		var leg := group(body,label+"Leg",Vector3(side*0.12,0,0))
		tailored(leg,"TrouserThigh",Vector3.ZERO,[[-0.34,0.156,0.17],[-0.18,0.186,0.203],[0.005,0.19,0.215]],"595e52")
		box(leg,"ThighPatch",Vector3(side*0.065,-0.18,0.085),Vector3(0.065,0.103,0.023),"8b826b")
		var knee := group(leg,"Knee",Vector3(0,-0.355,0))
		tailored(knee,"Shin",Vector3.ZERO,[[-0.27,0.115,0.13],[-0.065,0.142,0.157],[0.023,0.15,0.16]],"4b534a")
		box(knee,"KneePatch",Vector3(0,-0.023,0.078),Vector3(0.12,0.078,0.03),"797b69")
		for k in range(3):
			tailored(knee,"LegBinding%d" % k,Vector3.ZERO,[[-0.12-k*0.055,0.139-k*0.007,0.155-k*0.005],[-0.095-k*0.055,0.14-k*0.007,0.156-k*0.005]],"aaa087" if k==1 else "88846f")
		var ankle := group(knee,"Ankle",Vector3(0,-0.335,0))
		tailored(ankle,"Boot",Vector3(0,-0.042,0.034),[[-0.065,0.15,0.25],[-0.033,0.165,0.26],[0.022,0.146,0.22],[0.07,0.11,0.13]],"736651")
		box(ankle,"BootSole",Vector3(0,-0.102,0.036),Vector3(0.159,0.027,0.257),"363d36")
		box(ankle,"ToeCap",Vector3(0,-0.045,0.15),Vector3(0.13,0.059,0.022),"9b8870")
	var animation_player := own(scene_root,AnimationPlayer.new(),"AnimationPlayer") as AnimationPlayer
	var library := AnimationLibrary.new()
	for state in ["RESET","idle","walk","run"]:
		library.add_animation(state,make_animation(state))
	animation_player.add_animation_library("",library)
	animation_player.autoplay = "idle"
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	var attach := group(body,"BackAttachment",Vector3(0,0.37,-0.20))
	attach.set_meta("description","Optional equipment attachment. Local +Z is character front.")
	save_scene(DEST+"traveler.tscn")
	scene_root.free()

func track(animation: Animation, path: String, samples: Array) -> void:
	var index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index,NodePath(path))
	animation.track_set_interpolation_type(index,Animation.INTERPOLATION_LINEAR)
	for sample in samples:
		animation.track_insert_key(index,sample[0],sample[1])

func make_animation(state: String) -> Animation:
	var animation := Animation.new()
	animation.resource_name = state
	animation.length = 0.1 if state=="RESET" else (2.4 if state=="idle" else (0.86 if state=="walk" else 0.58))
	animation.loop_mode = Animation.LOOP_NONE if state=="RESET" else Animation.LOOP_LINEAR
	var paths := {}
	var n := 1 if state=="RESET" else 24
	for i in range(n+1):
		var t := animation.length*float(i)/n
		var phase := TAU*float(i)/n
		var idle := state=="idle"
		var moving := state=="walk" or state=="run"
		var run := state=="run"
		var bob := (0.007*(1.0-cos(phase))) if idle else ((0.032 if run else 0.015)*(1.0-cos(phase*2.0)) if moving else 0.0)
		var values := {
			"Facing/Visual:position":Vector3(0,bob,0),
			"Facing/Visual/Body:rotation":Vector3(0.12 if run else (0.025 if moving else 0.0),0.045*sin(phase) if moving else 0.0,0.018*sin(phase) if moving else 0.0),
			"Facing/Visual/Body/Head:rotation":Vector3(-0.07 if run else 0.012*sin(phase),-0.025*sin(phase) if moving else 0.0,0),
			"Facing/Visual/Body/ScarfTails:rotation":Vector3((0.5 if run else 0.12)+0.08*sin(phase),0,0.04*sin(phase)) if state!="RESET" else Vector3.ZERO
		}
		for side in [-1,1]:
			var prefix := "Facing/Visual/Body/"+("Left" if side==-1 else "Right")
			var wave := sin(phase+(PI if side==1 else 0.0)) if moving else 0.0
			var lift := maxf(0.0,wave)
			values[prefix+"Arm:rotation"] = Vector3(wave*(0.84 if run else 0.48),0,side*(0.06 if moving else 0.045))
			values[prefix+"Arm/Elbow:rotation"] = Vector3((-1.12+0.20*wave) if run else (-0.19-0.1*wave if moving else -0.13-0.018*sin(phase)),0,0)
			values[prefix+"Leg:rotation"] = Vector3(-wave*(0.94 if run else 0.51)-(0.13 if run else 0),0,0)
			values[prefix+"Leg/Knee:rotation"] = Vector3((0.13+lift*1.45) if run else (0.055+lift*0.78 if moving else 0.025),0,0)
			values[prefix+"Leg/Knee/Ankle:rotation"] = Vector3(-lift*(0.52 if run else 0.29),0,0)
		for path in values:
			if not paths.has(path):
				paths[path] = []
			paths[path].append([t,values[path] if state!="RESET" else Vector3.ZERO])
	for path in paths:
		track(animation,path,paths[path])
	return animation

func obstacle(parent: Node, label: String, pos: Vector3, dimensions: Vector3, color: String) -> Node3D:
	var node := group(parent,label,pos)
	box(node,"Mesh",Vector3.ZERO,dimensions,color)
	var solid_body := own(node,StaticBody3D.new(),"Solid") as StaticBody3D
	var collision := own(solid_body,CollisionShape3D.new(),"Shape") as CollisionShape3D
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	return node

func make_world() -> void:
	scene_root = Node3D.new()
	scene_root.name = "TravelerWorld"
	var env_node := own(scene_root,WorldEnvironment.new(),"Environment") as WorldEnvironment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("202e2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b3bdb2")
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	var sun := own(scene_root,DirectionalLight3D.new(),"AfternoonSun") as DirectionalLight3D
	sun.rotation_degrees = Vector3(-52,-38,0)
	sun.light_color = Color("ffe2b7")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55
	var ground := group(scene_root,"Ground")
	obstacle(ground,"Earth",Vector3(0,-0.18,0),Vector3(32,0.35,32),"777b61")
	box(ground,"CrossingEastWest",Vector3(0,0.001,0),Vector3(30,0.02,3.4),"a69a7c")
	box(ground,"CrossingNorthSouth",Vector3(0,0.002,0),Vector3(3.5,0.022,30),"a69a7c")
	rng.seed = 48291
	var paving := group(scene_root,"Paving")
	for z in range(-5,6):
		for x in range(-6,7):
			if rng.randf()<0.17:
				continue
			var p := Vector3(x*0.50+(0.23 if z%2 else 0.0),0.024,z*0.41)
			box(paving,"Stone_%d_%d"%[x,z],p,Vector3(rng.randf_range(0.36,0.46),0.033,rng.randf_range(0.27,0.34)),["b1a58a","a4977c","bbae92","9d947d"][rng.randi()%4])
	var props := group(scene_root,"CourtyardProps")
	for side in [-1,1]:
		for i in range(5):
			var p := Vector3(side*(4.2+i*0.75),0.23,-3.8)
			obstacle(props,"LowWall_%d_%d"%[side,i],p,Vector3(0.72,0.46,0.6),"74796a")
			box(props,"WallCap_%d_%d"%[side,i],p+Vector3(0,0.27,0),Vector3(0.78,0.13,0.70),"aaa38b")
	for p in [Vector3(-4.4,0,1.5),Vector3(4.8,0,-1.6)]:
		var well := group(props,"Planter",p)
		obstacle(well,"StoneBase",Vector3(0,0.26,0),Vector3(1.2,0.5,1.15),"767e6c")
		box(well,"Soil",Vector3(0,0.52,0),Vector3(1.02,0.05,0.97),"505e47")
		for j in range(6):
			ball(well,"Leaves%d"%j,Vector3(rng.randf_range(-0.35,0.35),rng.randf_range(0.65,0.91),rng.randf_range(-0.3,0.3)),Vector3(0.42,0.35,0.38),["576c50","647d57","859066"][j%3])
	for p in [Vector3(-3.8,0,-5.1),Vector3(5.9,0,4.5),Vector3(-7.5,0,4.0),Vector3(7.0,0,-6.2)]:
		var tree := group(props,"Tree",p)
		cylinder(tree,"Trunk",Vector3(0,1.1,0),0.20,2.2,"636653",0.13,7)
		var tree_body := own(tree,StaticBody3D.new(),"TrunkCollision") as StaticBody3D
		var tree_shape := own(tree_body,CollisionShape3D.new(),"Shape") as CollisionShape3D
		var trunk_shape := CylinderShape3D.new()
		trunk_shape.radius = 0.23
		trunk_shape.height = 2.2
		tree_shape.shape = trunk_shape
		tree_shape.position.y = 1.1
		for j in range(5):
			ball(tree,"Canopy%d"%j,Vector3(sin(j*2.4)*0.5,2.2+j*0.12,cos(j*2.4)*0.45),Vector3(0.95,0.72,0.90),["647553","7d8961","89966b"][j%3])
	var details := group(scene_root,"GroundDetails")
	for i in range(90):
		var x := rng.randf_range(-12,12)
		var z := rng.randf_range(-12,12)
		if absf(x)<3.4 or absf(z)<2.7:
			continue
		var tuft := group(details,"Grass%02d"%i,Vector3(x,0,z))
		for j in range(3):
			var blade := box(tuft,"Blade%d"%j,Vector3(j*0.055,0.095,0),Vector3(0.042,0.19,0.038),"9b9c70" if j==0 else "626f50")
			blade.rotation.z = (j-1)*0.24
	# Invisible safety boundaries have explicit, editable collider nodes.
	var boundary := group(scene_root,"Bounds")
	for p in [Vector3(-15.5,1,0),Vector3(15.5,1,0),Vector3(0,1,-15.5),Vector3(0,1,15.5)]:
		var b := obstacle(boundary,"Boundary",p,Vector3(0.3,2,32) if p.x!=0 else Vector3(32,2,0.3),"777b61")
		b.get_node("Mesh").visible = false
	var hero := load(DEST+"traveler.tscn").instantiate() as CharacterBody3D
	own(scene_root,hero,"Traveler")
	var camera := own(scene_root,Camera3D.new(),"FollowCamera") as Camera3D
	camera.set_script(load(DEST+"follow_camera.gd"))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 7.0
	camera.position = Vector3(5.5,9.6,14.5)
	camera.transform = camera.transform.looking_at(Vector3(0,0.9,0))
	camera.current = true
	camera.near = 0.1
	camera.far = 100.0
	camera.set("target",hero)
	hero.set("movement_camera",camera)
	save_scene(DEST+"world.tscn")
	scene_root.free()
