extends "res://hero_v2/tools/bake_helpers.gd"
## Authoring-only: replaces the saved character's visual assembly with editable skins.
var rig: Skeleton3D
var bone_ids: Dictionary = {}
var rest_world: Dictionary = {}
var shared_skin: Skin
var vertices := PackedVector3Array()
var indices := PackedInt32Array()
var bone_data := PackedInt32Array()
var weight_data := PackedFloat32Array()
var garment_color := "7c8174"
var trim_color := "b9af96"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--bake" not in args or "--overwrite" not in args:
		push_error("Requires --bake --overwrite. Never run to refresh hand-edited scenes.")
		quit(1)
		return
	build.call_deferred()

func add_bone(label: String, parent: String, local: Vector3) -> void:
	var index := rig.get_bone_count()
	rig.add_bone(label)
	bone_ids[label] = index
	var rest := Transform3D(Basis.IDENTITY,local)
	if parent!="":
		rig.set_bone_parent(index,bone_ids[parent])
		rest_world[label] = rest_world[parent]*rest
	else:
		rest_world[label] = rest
	rig.set_bone_rest(index,rest)

func make_rig() -> void:
	rig = Skeleton3D.new()
	rig.name = "Rig"
	scene_root = rig
	add_bone("Hips","",Vector3(0,0.91,0))
	add_bone("Spine","Hips",Vector3(0,0.18,0))
	add_bone("Chest","Spine",Vector3(0,0.18,0))
	add_bone("Neck","Chest",Vector3(0,0.22,0))
	add_bone("Head","Neck",Vector3(0,0.075,0))
	for side in [-1,1]:
		var s := "L" if side==-1 else "R"
		add_bone("Clavicle"+s,"Chest",Vector3(side*0.07,0.13,0))
		add_bone("UpperArm"+s,"Clavicle"+s,Vector3(side*0.095,-0.01,0))
		add_bone("Forearm"+s,"UpperArm"+s,Vector3(0,-0.28,0))
		add_bone("Hand"+s,"Forearm"+s,Vector3(0,-0.26,0))
		add_bone("Thigh"+s,"Hips",Vector3(side*0.086,-0.05,0))
		add_bone("Shin"+s,"Thigh"+s,Vector3(0,-0.41,0))
		add_bone("Foot"+s,"Shin"+s,Vector3(0,-0.365,0.015))
		add_bone("HemFront"+s,"Thigh"+s,Vector3(0,0.045,0.06))
		add_bone("HemBack"+s,"Thigh"+s,Vector3(0,0.045,-0.06))
		add_bone("Cuff"+s,"Forearm"+s,Vector3(0,-0.13,0))
		add_bone("HairFront"+s,"Head",Vector3(side*0.055,0.15,0.065))
		add_bone("HairSide"+s,"Head",Vector3(side*0.102,0.12,-0.01))
	add_bone("HairTail","Head",Vector3(0,0.17,-0.09))
	add_bone("SashTail","Hips",Vector3(0.13,0.09,0.10))
	rig.reset_bone_poses()
	shared_skin = Skin.new()
	for name in bone_ids:
		shared_skin.add_bind(bone_ids[name],rest_world[name].affine_inverse())

func begin_mesh() -> void:
	vertices.clear()
	indices.clear()
	bone_data.clear()
	weight_data.clear()

func influence(mode: String, p: Vector3) -> Dictionary:
	if bone_ids.has(mode):
		return {mode:1.0}
	if mode=="torso":
		if p.y<1.06:
			return mix_bones("Hips","Spine",clampf((p.y-0.96)/0.10,0,1))
		if p.y<1.30:
			return mix_bones("Spine","Chest",clampf((p.y-1.12)/0.18,0,1))
		return mix_bones("Chest","Neck",clampf((p.y-1.43)/0.10,0,1))
	if mode.begins_with("arm"):
		var s := mode.right(1)
		if p.y>1.36:
			return mix_bones("Chest","UpperArm"+s,clampf((absf(p.x)-0.105)/0.065,0,1))
		if p.y>1.20:
			return {"UpperArm"+s:1.0}
		if p.y>1.035:
			return mix_bones("Forearm"+s,"UpperArm"+s,clampf((p.y-1.055)/0.12,0,1))
		return mix_bones("Hand"+s,"Forearm"+s,clampf((p.y-0.825)/0.065,0,1))
	if mode.begins_with("leg"):
		var s := mode.right(1)
		if p.y>0.54:
			return {"Thigh"+s:1.0}
		if p.y>0.20:
			return mix_bones("Shin"+s,"Thigh"+s,clampf((p.y-0.39)/0.12,0,1))
		return mix_bones("Foot"+s,"Shin"+s,clampf((p.y-0.10)/0.10,0,1))
	return {"Hips":1.0}

func mix_bones(a: String,b: String,t: float) -> Dictionary:
	return {a:1.0-t,b:t}

func vertex(p: Vector3, weights: Dictionary) -> void:
	var head_bound := true
	for name in weights:
		if name!="Head" and not String(name).begins_with("Hair"):
			head_bound = false
	if head_bound:
		p.y -= 0.055
	vertices.append(p)
	var names := weights.keys()
	for i in range(4):
		bone_data.append(bone_ids[names[i]] if i<names.size() else 0)
		weight_data.append(weights[names[i]] if i<names.size() else 0.0)

func loft(rows: Array, mode: String, x: float=0.0, z: float=0.0, segments: int=24, folds: float=0.0) -> void:
	var start := vertices.size()
	for row in rows:
		for j in range(segments):
			var angle := TAU*j/segments
			var fold := folds*sin(angle*8.0+row[0]*17.0)
			var point := Vector3(x+(row[3] if row.size()>3 else 0.0)+sin(angle)*(row[1]+fold),row[0],z+cos(angle)*(row[2]+fold))
			vertex(point,influence(mode,point))
	for i in range(rows.size()-1):
		for j in range(segments):
			var a := start+i*segments+j
			var b := start+i*segments+(j+1)%segments
			var c := a+segments
			var d := b+segments
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))

func ellipsoid(center: Vector3, radii: Vector3, mode: String, rings: int=10, segments: int=20) -> void:
	var rows := []
	for i in range(rings+1):
		var angle := -PI/2+PI*i/rings
		rows.append([center.y+sin(angle)*radii.y,maxf(0.0001,cos(angle)*radii.x),maxf(0.0001,cos(angle)*radii.z)])
	loft(rows,mode,center.x,center.z,segments)

func sweep(points: Array, widths: Array, depth: float, mode: String, dynamic_bone: String="", segments: int=10) -> void:
	var start := vertices.size()
	for i in range(points.size()):
		var tangent: Vector3 = points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]
		tangent = tangent.normalized()
		var axis := Vector3.RIGHT
		if absf(tangent.dot(axis))>0.9:
			axis = Vector3.UP
		var side := tangent.cross(axis).normalized()
		var up := tangent.cross(side).normalized()
		for j in range(segments):
			var angle := TAU*j/segments
			var p: Vector3 = points[i]+up*sin(angle)*widths[i]+side*cos(angle)*widths[i]*depth
			var weights := influence(mode,p)
			if dynamic_bone!="":
				weights = mix_bones(mode,dynamic_bone,float(i)/(points.size()-1))
			vertex(p,weights)
	for i in range(points.size()-1):
		for j in range(segments):
			var a := start+i*segments+j
			var b := start+i*segments+(j+1)%segments
			var c := a+segments
			var d := b+segments
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))

func finish_mesh(label: String, color: String) -> MeshInstance3D:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,indices.size(),3):
		var a := indices[i]
		var b := indices[i+1]
		var c := indices[i+2]
		var n := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normals[a] += n
		normals[b] += n
		normals[c] += n
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_BONES] = bone_data
	arrays[Mesh.ARRAY_WEIGHTS] = weight_data
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := mesh_node(scene_root,label,mesh,Vector3.ZERO,color)
	node.skin = shared_skin
	node.skeleton = NodePath("..") if scene_root is Skeleton3D else NodePath("../../Rig")
	node.custom_aabb = AABB(Vector3(-1,-0.2,-1),Vector3(2,2.6,2))
	return node

func body_meshes() -> void:
	begin_mesh()
	loft([[0.84,0.075,0.072],[0.89,0.124,0.08],[0.95,0.128,0.088],[1.025,0.12,0.083],[1.09,0.114,0.078],[1.16,0.126,0.085],[1.24,0.144,0.092],[1.31,0.153,0.089],[1.37,0.146,0.082],[1.405,0.12,0.066],[1.44,0.07,0.047],[1.47,0.045,0.042]],"torso")
	finish_mesh("AnatomyTorso","c6a184")
	begin_mesh()
	loft([[1.42,0.047,0.044],[1.46,0.039,0.039],[1.51,0.039,0.038],[1.54,0.05,0.047]],"Neck",0,-0.005)
	finish_mesh("NeckAnatomy","c6a184")
	for side in [-1,1]:
		var s := "L" if side==-1 else "R"
		begin_mesh()
		loft([[0.827,0.026,0.025],[0.875,0.027,0.029],[0.94,0.039,0.035],[1.02,0.044,0.038],[1.09,0.033,0.034],[1.125,0.034,0.038],[1.19,0.045,0.042],[1.28,0.052,0.049],[1.35,0.051,0.049],[1.395,0.045,0.044],[1.417,0.033,0.036,-side*0.015],[1.433,0.022,0.025,-side*0.049],[1.445,0.002,0.01,-side*0.079]],"arm"+s,side*0.165)
		finish_mesh("ArmAnatomy"+s,"c6a184")
		begin_mesh()
		loft([[0.078,0.026,0.031],[0.16,0.027,0.032],[0.23,0.035,0.04],[0.31,0.046,0.045],[0.38,0.044,0.044],[0.43,0.039,0.044],[0.465,0.041,0.045],[0.53,0.048,0.052],[0.63,0.061,0.062],[0.75,0.069,0.070],[0.84,0.07,0.073],[0.91,0.063,0.067]],"leg"+s,side*0.086)
		finish_mesh("LegAnatomy"+s,"bc977c")
		begin_mesh()
		ellipsoid(Vector3(side*0.165,0.811,0.007),Vector3(0.033,0.052,0.021),"Hand"+s)
		for finger in range(4):
			var fx: float = side*0.165+(finger-1.5)*0.014
			var length: float = [0.054,0.066,0.062,0.046][finger]
			sweep([Vector3(fx,0.791,0.006),Vector3(fx,0.77,0.007),Vector3(fx,0.785-length,0.016),Vector3(fx,0.777-length,0.023)],[0.009,0.009,0.007,0.001],0.8,"Hand"+s)
		var tx: float = side*0.165-side*0.031
		sweep([Vector3(tx,0.83,0.003),Vector3(tx-side*0.01,0.804,0.012),Vector3(tx-side*0.009,0.788,0.026)],[0.012,0.011,0.003],0.9,"Hand"+s)
		finish_mesh("HandWithFingers"+s,"d0ad8f")
		begin_mesh()
		ellipsoid(Vector3(side*0.086,0.054,0.048),Vector3(0.044,0.043,0.103),"Foot"+s)
		finish_mesh("FootAnatomy"+s,"c2a085")
	# Modest neutral undergarment is a separate surface of the body study.
	begin_mesh()
	loft([[0.805,0.128,0.081],[0.87,0.137,0.089],[0.96,0.131,0.091]],"Hips",0,0,24)
	finish_mesh("BaseUndergarment","68665c")
	begin_mesh()
	loft([[1.585,0.028,0.041],[1.6,0.060,0.058],[1.628,0.083,0.074],[1.667,0.101,0.083],[1.71,0.106,0.089],[1.756,0.103,0.092],[1.797,0.099,0.089],[1.838,0.083,0.073],[1.865,0.052,0.042],[1.88,0.001,0.001]],"Head",0,0.003,32)
	finish_mesh("HeadSculpt","d0af93")
	begin_mesh()
	for side in [-1,1]:
		ellipsoid(Vector3(side*0.107,1.696,-0.002),Vector3(0.017,0.038,0.019),"Head")
	finish_mesh("Ears","be987e")
	begin_mesh()
	ellipsoid(Vector3(0,1.698,0.091),Vector3(0.012,0.04,0.018),"Head")
	ellipsoid(Vector3(0,1.676,0.104),Vector3(0.017,0.011,0.017),"Head")
	finish_mesh("NoseBridgeAndTip","cba488")
	for side in [-1,1]:
		begin_mesh()
		ellipsoid(Vector3(side*0.043,1.722,0.087),Vector3(0.020,0.010,0.006),"Head")
		finish_mesh("EyeWhite%d"%side,"d9d3bd")
		begin_mesh()
		ellipsoid(Vector3(side*0.042,1.722,0.094),Vector3(0.008,0.009,0.003),"Head")
		finish_mesh("Iris%d"%side,"303630")
		begin_mesh()
		sweep([Vector3(side*0.065,1.744,0.084),Vector3(side*0.045,1.749,0.091),Vector3(side*0.023,1.746,0.092)],[0.004,0.005,0.002],0.65,"Head")
		finish_mesh("Eyebrow%d"%side,"3e413a")
	begin_mesh()
	ellipsoid(Vector3(0,1.637,0.079),Vector3(0.024,0.004,0.003),"Head")
	finish_mesh("Lips","936e60")

func garments() -> void:
	begin_mesh()
	loft([[0.935,0.144,0.103],[0.98,0.131,0.099],[1.04,0.126,0.095],[1.11,0.131,0.095],[1.19,0.145,0.104],[1.28,0.158,0.106],[1.35,0.155,0.094],[1.398,0.127,0.077],[1.44,0.07,0.057],[1.468,0.049,0.047]],"torso",0,0,32,0.0025)
	finish_mesh("CrossCollarTorso",garment_color)
	begin_mesh()
	sweep([Vector3(-0.035,1.476,0.047),Vector3(-0.051,1.409,0.082),Vector3(0,1.339,0.109),Vector3(0.074,1.26,0.105),Vector3(0.123,1.205,0.087)],[0.016,0.02,0.021,0.019,0.009],0.22,"torso", "",12)
	sweep([Vector3(0.035,1.476,0.047),Vector3(0.046,1.411,0.087),Vector3(0.001,1.345,0.108)],[0.014,0.016,0.014],0.22,"torso","",12)
	finish_mesh("FoldedLinenCollar",trim_color)
	begin_mesh()
	loft([[0.977,0.138,0.104],[0.995,0.138,0.105],[1.03,0.134,0.102],[1.051,0.131,0.102]],"torso",0,0,32,0.001)
	finish_mesh("WovenSash","625c50")
	begin_mesh()
	ellipsoid(Vector3(0.121,1.01,0.07),Vector3(0.029,0.024,0.023),"Hips")
	sweep([Vector3(0.127,1.005,0.089),Vector3(0.139,0.93,0.104),Vector3(0.155,0.835,0.115),Vector3(0.151,0.742,0.12)],[0.018,0.022,0.023,0.02],0.18,"Hips","SashTail",12)
	finish_mesh("KnotAndSoftSashEnd","96836a")
	for side in [-1,1]:
		var s := "L" if side==-1 else "R"
		begin_mesh()
		loft([[0.85,0.035,0.038],[0.90,0.042,0.044],[0.97,0.053,0.046],[1.06,0.052,0.047],[1.115,0.045,0.045],[1.18,0.052,0.049],[1.27,0.059,0.055],[1.345,0.058,0.056],[1.395,0.055,0.054],[1.425,0.043,0.044,-side*0.018],[1.445,0.029,0.031,-side*0.054],[1.46,0.003,0.012,-side*0.085]],"arm"+s,side*0.165,0,24,0.0025)
		finish_mesh("ContinuousSleeve"+s,garment_color)
		begin_mesh()
		loft([[0.842,0.037,0.039],[0.865,0.039,0.041],[0.889,0.044,0.044]],"Cuff"+s,side*0.165,0,24,0.001)
		finish_mesh("SoftCuff"+s,trim_color)
		begin_mesh()
		loft([[0.095,0.031,0.038],[0.17,0.033,0.038],[0.26,0.046,0.047],[0.36,0.052,0.051],[0.45,0.049,0.049],[0.54,0.056,0.059],[0.65,0.071,0.072],[0.78,0.075,0.078],[0.895,0.075,0.079]],"leg"+s,side*0.086,0,24,0.002)
		finish_mesh("Trousers"+s,"5e685d")
		for front in [true,false]:
			var bone := ("HemFront" if front else "HemBack")+s
			var zsign := 1.0 if front else -1.0
			begin_mesh()
			# Curved subdivided cloth patch, with a soft gradient into its hem bone.
			var start := vertices.size()
			for row in range(9):
				var t := row/8.0
				for column in range(9):
					var u := column/8.0
					var x: float = side*(0.005+u*(0.139+0.035*t))
					var y := 0.983-t*(0.377+0.015*cos(u*PI))
					var z := zsign*(0.104+0.014*t-0.045*pow(u,2)+0.004*sin(u*TAU*2+t*1.8))
					vertex(Vector3(x,y,z),mix_bones("Hips",bone,t))
			for row in range(8):
				for column in range(8):
					var a := start+row*9+column
					var b := a+1
					var c := a+9
					var d := c+1
					if side*zsign>0:
						indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
					else:
						indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
			var panel := finish_mesh(bone+"Panel",garment_color)
			var cloth_material := panel.material_override.duplicate() as ShaderMaterial
			cloth_material.shader = load("res://hero_v2/model/fabric_double_sided.gdshader")
			panel.material_override = cloth_material
		begin_mesh()
		for band in range(7):
			var y := 0.112+band*0.033
			var r := 0.034+band*0.0025
			loft([[y,r,r+0.003],[y+0.012,r+0.001,r+0.004]],"leg"+s,side*0.086,0,24)
		finish_mesh("WovenLegWraps"+s,"a9a086")
		begin_mesh()
		ellipsoid(Vector3(side*0.086,0.054,0.051),Vector3(0.05,0.047,0.112),"Foot"+s)
		finish_mesh("RoundedClothShoe"+s,"414c44")
		begin_mesh()
		ellipsoid(Vector3(side*0.086,0.021,0.048),Vector3(0.051,0.012,0.113),"Foot"+s)
		finish_mesh("LayeredSole"+s,"9d8c6d")

func hair_meshes() -> void:
	begin_mesh()
	loft([[1.756,0.102,0.083],[1.795,0.118,0.101],[1.836,0.116,0.099],[1.875,0.092,0.081],[1.903,0.054,0.052],[1.914,0.002,0.002]],"Head",0,-0.014,32)
	finish_mesh("FittedHairCap","303a3d")
	begin_mesh()
	ellipsoid(Vector3(0,1.918,-0.065),Vector3(0.053,0.064,0.051),"Head",12,24)
	finish_mesh("BoundBun","30383a")
	begin_mesh()
	sweep([Vector3(-0.072,1.914,-0.07),Vector3(0.072,1.914,-0.07)],[0.005,0.005],1.0,"Head")
	finish_mesh("WoodHairpin","ac9474")
	for side in [-1,1]:
		var s := "L" if side==-1 else "R"
		for j in range(3):
			begin_mesh()
			var x: float = side*(0.019+j*0.031)
			sweep([Vector3(x*0.6,1.881,0.052),Vector3(x,1.828,0.085),Vector3(x+side*0.014,1.78,0.10),Vector3(x+side*0.023,1.747+j*0.007,0.091)],[0.024,0.025,0.016,0.001],0.38,"Head","HairFront"+s,12)
			finish_mesh("SweptFringe%s%d"%[s,j],["374347","414b4d","323d40"][j])
		begin_mesh()
		sweep([Vector3(side*0.096,1.83,-0.002),Vector3(side*0.12,1.777,0.008),Vector3(side*0.118,1.714,0.014),Vector3(side*0.111,1.666,0.022)],[0.026,0.024,0.018,0.002],0.48,"Head","HairSide"+s,12)
		finish_mesh("TempleLock"+s,"303b3d")
		begin_mesh()
		sweep([Vector3(side*0.065,1.82,-0.096),Vector3(side*0.075,1.768,-0.108),Vector3(side*0.063,1.704,-0.098)],[0.032,0.028,0.001],0.42,"Head","HairTail",12)
		finish_mesh("NapeLock"+s,"344044")

func rotation_track(animation: Animation, bone: String, values: Array) -> void:
	var i := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(i,NodePath("Facing/Visual/Rig:"+bone))
	for entry in values:
		animation.rotation_track_insert_key(i,entry[0],Quaternion.from_euler(entry[1]))

func clip(state: String) -> Animation:
	var anim := Animation.new()
	anim.resource_name = state
	anim.length = 0.1 if state=="RESET" else (2.4 if state=="idle" else (0.9 if state=="walk" else 0.62))
	anim.loop_mode = Animation.LOOP_NONE if state=="RESET" else Animation.LOOP_LINEAR
	var values := {}
	var bob := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(bob,NodePath("Facing/Visual:position"))
	for i in range(33):
		var t := anim.length*i/32.0
		var phase := TAU*i/32.0
		var move := state=="walk" or state=="run"
		var running := state=="run"
		# Walk/run uses heel-strike, toe-off, pelvic sway and counter-rotation.
		var stride := sin(phase)
		var step_contact := (cos(phase)+1.0)*0.5
		var poses := {"Hips":Vector3(0.095 if running else 0.0,0.014*sin(phase*2.0) if move else 0,0.018*sin(phase) if move else 0),"Spine":Vector3(0.025 if running else 0.008, -0.015*sin(phase) if move else 0, -0.012*sin(phase) if move else 0),"Chest":Vector3(0, -0.022*sin(phase) if move else 0,0.016*sin(phase) if move else 0),"Neck":Vector3.ZERO,"Head":Vector3(-0.065 if running else 0,0.008*sin(phase) if move else 0,0)}
		for side in [-1,1]:
			var s := "L" if side==-1 else "R"
			var wave := sin(phase+(PI if side==1 else 0.0)) if move else 0.0
			poses["Clavicle"+s] = Vector3.ZERO
			poses["UpperArm"+s] = Vector3(wave*(0.75 if running else 0.41),0,side*(0.055+0.014*absf(wave)))
			poses["Forearm"+s] = Vector3((-1.03+0.15*wave) if running else -0.13-0.11*wave,0,0)
			poses["Hand"+s] = Vector3(0,0,side*0.03)
			poses["Thigh"+s] = Vector3(-wave*(0.79 if running else 0.43)-(0.06 if running else 0),0,0)
			poses["Shin"+s] = Vector3((0.10+maxf(0,wave)*1.26) if running else (0.028+maxf(0,wave)*0.72 if move else 0),0,0)
			poses["Foot"+s] = Vector3((-0.22*step_contact-maxf(0,wave)*(0.47 if running else 0.25)) if move else 0,0,0)
		for name in poses:
			if not values.has(name):
				values[name] = []
			values[name].append([t,poses[name] if state!="RESET" else Vector3.ZERO])
		var lift := (0.003*(1-cos(phase))) if state=="idle" else ((0.025 if running else 0.012)*(1-cos(phase*2)) if move else 0.0)
		anim.track_insert_key(bob,t,Vector3(0,lift,0))
	for name in values:
		rotation_track(anim,name,values[name])
	return anim

func mount(parent: Node, path: String, label: String) -> Node:
	var instance: Node = load(path).instantiate()
	instance.name = label
	parent.add_child(instance)
	instance.owner = scene_root
	return instance

func build() -> void:
	shader = load("res://hero_v2/cloth.gdshader")
	make_rig()
	body_meshes()
	save_scene("res://hero_v2/model/body_rig.tscn")
	scene_root.free()
	for name in ["linen","indigo"]:
		scene_root = Node3D.new()
		scene_root.name = "LinenRobe" if name=="linen" else "IndigoRobe"
		garment_color = "7c8174" if name=="linen" else "586e7a"
		trim_color = "b9af96" if name=="linen" else "a4b0ac"
		garments()
		save_scene("res://hero_v2/outfits/"+name+"_robe.tscn")
		scene_root.free()
	scene_root = Node3D.new()
	scene_root.name = "Hair"
	hair_meshes()
	save_scene("res://hero_v2/hair/tied_hair.tscn")
	scene_root.free()
	scene_root = load("res://hero_v2/traveler.tscn").instantiate()
	var visual := scene_root.get_node("Facing/Visual") as Node3D
	for child in visual.get_children():
		child.free()
	visual.set_script(load("res://hero_v2/wardrobe.gd"))
	mount(visual,"res://hero_v2/model/body_rig.tscn","Rig")
	mount(visual,"res://hero_v2/outfits/linen_robe.tscn","LinenRobe")
	(mount(visual,"res://hero_v2/outfits/indigo_robe.tscn","IndigoRobe") as Node3D).visible = false
	mount(visual,"res://hero_v2/hair/tied_hair.tscn","Hair")
	var animator := scene_root.get_node("AnimationPlayer") as AnimationPlayer
	for library in animator.get_animation_library_list():
		animator.remove_animation_library(library)
	var lib := AnimationLibrary.new()
	for state in ["RESET","idle","walk","run"]:
		lib.add_animation(state,clip(state))
	animator.add_animation_library("",lib)
	if scene_root.has_node("SecondaryMotion"):
		scene_root.get_node("SecondaryMotion").free()
	var motion := Node.new()
	motion.name = "SecondaryMotion"
	motion.set_script(load("res://hero_v2/secondary_motion.gd"))
	scene_root.add_child(motion)
	motion.owner = scene_root
	var collision := scene_root.get_node("BodyCollision") as CollisionShape3D
	collision.shape = collision.shape.duplicate()
	collision.shape.radius = 0.18
	collision.shape.height = 1.86
	collision.position.y = 0.93
	scene_root.set_meta("skinned_model_revision",1)
	save_scene("res://hero_v2/traveler.tscn")
	# Interoperable editable mesh/rig source, exported from the saved assembly.
	visual.get_node("IndigoRobe").free()
	for mesh in scene_root.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is ShaderMaterial:
			var export_material := StandardMaterial3D.new()
			export_material.albedo_color = mesh.material_override.get_shader_parameter("base_color")
			export_material.roughness = 1.0
			mesh.material_override = export_material
	root.add_child(scene_root)
	var doc := GLTFDocument.new()
	var gltf := GLTFState.new()
	var error := doc.append_from_scene(scene_root,gltf)
	if error==OK:
		error = doc.write_to_filesystem(gltf,"res://hero_v2/model/traveler_editable.glb")
	print("Editable GLB export result=",error)
	scene_root.free()
	quit(error)
