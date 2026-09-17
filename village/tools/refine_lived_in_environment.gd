extends "res://burial_ridge/tools/sculpt_saved_terrain.gd"
## Authoring only: modify the saved village and ridge, never rebuild their layout.
const VILLAGE := "res://village/yao_village.tscn"
var soil_boundary := PackedVector2Array()
var building_footprints: Array[Node3D] = []
var moved_trees := 0
var removed_trees := 0

func _initialize() -> void:
	if not "--apply" in OS.get_cmdline_user_args():
		quit(1)
		return
	shader = load("res://village/style.gdshader")
	natural_noise.seed = 917369
	natural_noise.frequency = 0.12
	rng.seed = 917417
	scene_root = load(VILLAGE).instantiate()
	if scene_root.has_meta("lived_in_revision"):
		push_error("Already applied. Edit the saved nodes instead.")
		quit(1)
		return
	move_north_courtyard()
	village_ground()
	for h in scene_root.get_node("Buildings").get_children():
		if h.has_node("PlasterWalls"):
			building_footprints.append(h)
			weather_house(h)
	village_ecology()
	scene_root.set_meta("lived_in_revision",1)
	scene_root.set_meta("north_courtyard_shift",5.0)
	scene_root.set_meta("northern_trees_relocated",moved_trees)
	scene_root.set_meta("northern_trees_removed",removed_trees)
	# Save changes to the existing collision resource, retaining the instance.
	var coll := scene_root.get_node("WalkCollisions")
	var packed := PackedScene.new()
	assert(packed.pack(coll)==OK)
	assert(ResourceSaver.save(packed,"res://village/hero/world_collisions.tscn")==OK)
	# Disable child overrides while packing; keep the west resource authoritative.
	scene_root.set_editable_instance(scene_root.get_node("WesternBurialRidge"),false)
	assert(save_scene(VILLAGE)==OK)
	var village_file:=FileAccess.open(VILLAGE,FileAccess.READ_WRITE)
	village_file.seek_end()
	village_file.store_string("\n[editable path=\"WesternBurialRidge\"]\n")
	village_file.close()
	scene_root.free()
	scene_root = load(OUTPUT).instantiate()
	if scene_root.has_meta("exploration_landmarks_revision"):
		push_error("Ridge revision already applied")
		quit(1)
		return
	new_landmarks()
	graveyard_weeds()
	scene_root.set_meta("exploration_landmarks_revision",1)
	assert(save_scene(OUTPUT)==OK)
	scene_root.free()
	print("LIVED IN REVISION SAVED; northern trees moved=",moved_trees," removed=",removed_trees)
	quit()

func move_north_courtyard() -> void:
	for n in scene_root.get_node("Buildings").get_children():
		if str(n.name).begins_with("North"):
			n.position.z -= 5
	for n in scene_root.get_node("VegetableGardens").get_children():
		if n.position.z < -9:
			n.position.z -= 5
	var coll := scene_root.get_node("WalkCollisions")
	for n in coll.get_children():
		if str(n.name).begins_with("North"):
			n.position.z -= 5
	var i := 0
	for t in scene_root.get_node("ForestBoundary").get_children():
		if t.position.z > -14.8: continue
		var shape: CollisionShape3D
		for c in coll.get_children():
			if "Trunk" in str(c.name) and Vector2(c.position.x,c.position.z).distance_to(Vector2(t.position.x,t.position.z))<0.02:
				shape=c
				break
		i += 1
		if i%4==0 and t.position.x>-20 and t.position.x<16:
			if shape: shape.free()
			t.free()
			removed_trees += 1
		else:
			var shift := Vector3(0,0,-5.5-rng.randf_range(0,1.5))
			t.position += shift
			if shape: shape.position += shift
			moved_trees += 1
	# The north end remains inside the original playable boundary.

func soil_distance(p: Vector2) -> float:
	var d := INF
	for i in soil_boundary.size():
		var a := soil_boundary[i]
		var b := soil_boundary[(i+1)%soil_boundary.size()]
		var t := clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
		d=minf(d,p.distance_to(a.lerp(b,t)))
	return d if Geometry2D.is_point_in_polygon(p,soil_boundary) else -d

func village_weights(p: Vector2) -> Color:
	var noise := natural_noise.get_noise_2d(p.x*1.7,p.y*1.7)
	var soil := smoothstep(-1.3,1.8,soil_distance(p)+noise*1.6)
	# A narrow shared green edge exactly matches the west expansion.
	soil *= smoothstep(-26,-24.5,p.x)
	var loam := soil*(0.12+maxf(0,noise)*0.42)
	var litter := (1-soil)*0.13*smoothstep(-26,-22,p.x)
	return Color(1-soil-litter,soil-loam,loam,litter)

func village_ground() -> void:
	var ground := scene_root.get_node("Terrain")
	var old: MeshInstance3D = ground.get_node("VillageSoil")
	var verts: PackedVector3Array = old.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var points: Array[Vector2] = []
	for v in verts:
		var p := Vector2(v.x,v.z)
		if p.length()>0.1 and not p in points: points.append(p)
	points.sort_custom(func(a: Vector2,b: Vector2): return a.angle()<b.angle())
	for p in points:
		if p.y<-14: p.y-=5
		soil_boundary.append(p)
	old.free()
	ground.get_node("ForestFloor").free()
	for c in ground.get_children():
		if str(c.name).begins_with("MossPatch"): c.free()
	var mat_ground := ShaderMaterial.new()
	mat_ground.shader=load("res://burial_ridge/terrain_blend.gdshader")
	mat_ground.set_shader_parameter("grass_color",Color("8f9c72"))
	mat_ground.set_shader_parameter("mineral_color",Color("d5c69b"))
	mat_ground.set_shader_parameter("loam_color",Color("b4a17b"))
	mat_ground.set_shader_parameter("litter_color",Color("7d8968"))
	mat_ground.set_shader_parameter("variation_strength",0.38)
	mat_ground.set_shader_parameter("seam_direction",-1.0)
	mat_ground.set_meta("village_toon",true)
	var chunks := group(ground,"BlendedVillageGround")
	for x in range(-26,40,6):
		for z in range(-32,32,8):
			var nx := mini(12,(40-x)*2)
			var nv := PackedVector3Array()
			var normals := PackedVector3Array()
			var colors := PackedColorArray()
			var idx := PackedInt32Array()
			for iz in range(17):
				for ix in range(nx+1):
					var p := Vector2(x+ix*0.5,z+iz*0.5)
					nv.append(Vector3(ix*0.5,0.07,iz*0.5))
					normals.append(Vector3.UP)
					colors.append(village_weights(p))
			for iz in range(16):
				for ix in range(nx):
					var a := iz*(nx+1)+ix
					idx.append_array(PackedInt32Array([a,a+1,a+nx+1,a+1,a+nx+2,a+nx+1]))
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=nv
			arrays[Mesh.ARRAY_NORMAL]=normals
			arrays[Mesh.ARRAY_COLOR]=colors
			arrays[Mesh.ARRAY_INDEX]=idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var node := mesh_node(chunks,"Soil_%d_%d"%[x,z],mesh,Vector3(x,0,z),"d5c69b")
			node.material_override=mat_ground

func weather_house(h: Node3D) -> void:
	var wall: MeshInstance3D = h.get_node("PlasterWalls")
	var dims: Vector3 = wall.mesh.size
	var weather := ShaderMaterial.new()
	weather.shader=load("res://village/weathered_plaster.gdshader")
	weather.set_shader_parameter("base_color",wall.get_active_material(0).get_shader_parameter("base_color"))
	weather.set_shader_parameter("wear_strength",0.43 if h.name=="AncestralHall" else 0.83)
	weather.set_meta("village_toon",true)
	wall.material_override=weather
	var detail := group(h,"AgeAndRepairs")
	for side in [0,1,2]:
		var face := group(detail,["FrontWallWear","LeftWallWear","RightWallWear"][side])
		var width := dims.x if side==0 else dims.z
		face.position=Vector3(0,0,dims.z/2+0.008) if side==0 else Vector3((-1 if side==1 else 1)*(dims.x/2+0.008),0,0)
		if side>0: face.rotation.y=-PI/2 if side==1 else PI/2
		for j in range(9):
			var x := rng.randf_range(-width/2+0.20,width/2-0.20)
			if side==0 and absf(x)<0.88: continue
			var y := rng.randf_range(0.28,0.75) if j<6 else rng.randf_range(1.95,dims.y)
			wall_patch(face,Vector2(x,y),Vector2(rng.randf_range(0.16,0.40),rng.randf_range(0.12,0.32)),"968467" if j%2==0 else "a39370")
			if j<4:
				for k in range(3):
					box(face,"ExposedOldBrick",Vector3(x+(k%2)*0.18-0.08,y+(k/2)*0.12,0.018),Vector3(0.23,0.10,0.028),["807965","94866d","887c63"][k])
		for j in range(3):
			var x := (-0.34+j*0.30)*width
			if side==0 and absf(x)<0.85: continue
			var y := dims.y-rng.randf_range(0.3,0.65)
			for k in range(3):
				var to := Vector3(x+rng.randf_range(-0.085,0.085),y-rng.randf_range(0.10,0.22),0.014)
				beam(face,"FinePlasterCrack",Vector3(x,y,0.014),to,0.009,"7e755d")
				x=to.x
				y=to.y
	# Slightly shifted, unevenly weathered individual tiles and straw ends.
	for tile in h.get_node("Roof").get_children():
		if str(tile.name).begins_with("BarrelTile") or str(tile.name).begins_with("ThatchStrand"):
			if rng.randf()<0.22:
				tile.position+=Vector3(rng.randf_range(-0.027,0.027),rng.randf_range(-0.025,0.04),rng.randf_range(-0.04,0.04))
				tile.scale.y*=rng.randf_range(0.80,1.04)
				tile.material_override=mat(["655f4e","7b765c","85816a"][rng.randi_range(0,2)] if "Barrel" in str(tile.name) else ["847348","a28b58","746748"][rng.randi_range(0,2)])
	var front := dims.z/2+0.25
	box(detail,"OldWindowRepairSlat",Vector3(dims.x*0.31,1.2,front),Vector3(0.75,0.095,0.055),"7c694c").rotation.z=0.09
	for side in [-1,1]:
		for j in range(4):
			ball(detail,"FoundationMoss",Vector3(side*(dims.x/2-0.35)+rng.randf_range(-0.16,0.16),0.20,front-0.10+j*0.035),Vector3(0.14,0.075,0.035),"737d56")
	var supplies := group(detail,"HouseholdRepairs",Vector3(-dims.x/2+0.4,0,front+0.15))
	for j in range(3):
		var board := box(supplies,"SalvagedTimber",Vector3(j*0.15,0.59,0.18),Vector3(0.11,1.10+j*0.12,0.07),["786448","8c7955","695a43"][j])
		board.rotation.x=-0.20
	pot(detail,Vector3(dims.x/2-0.4,0.08,front+0.35),0.22)

func wall_patch(parent: Node,pos: Vector2,size: Vector2,color: String) -> void:
	var vs := PackedVector3Array([Vector3(pos.x,pos.y,0.012)])
	var idx := PackedInt32Array()
	for i in range(9):
		var a := i*TAU/9
		var r := rng.randf_range(0.68,1.15)
		vs.append(Vector3(pos.x+cos(a)*size.x*r,pos.y+sin(a)*size.y*r,0.012))
	for i in range(9): idx.append_array(PackedInt32Array([0,(i+1)%9+1,i+1,0,i+1,(i+1)%9+1]))
	solid(parent,"FlakedPlaster",vs,idx,color)

func near_house(p: Vector2) -> bool:
	for h in building_footprints:
		var local: Vector3 = h.transform.affine_inverse()*Vector3(p.x,0,p.y)
		var dims: Vector3 = h.get_node("PlasterWalls").mesh.size
		if absf(local.x)<dims.x/2+0.35 and absf(local.z)<dims.z/2+0.45: return true
	return false

func village_ecology() -> void:
	var g := group(scene_root,"LivedInGroundDetails")
	var grass := group(g,"WallVergeAndMeadowGrass")
	var gravel := group(g,"ScatteredGravelAndPotteryChips")
	for i in range(1800):
		var p := Vector2(rng.randf_range(-25,29),rng.randf_range(-25,21))
		if near_house(p): continue
		var soil := village_weights(p).g
		if i%3==0 and soil<0.67:
			for j in range(rng.randi_range(2,4)):
				tuft(grass,Vector3(p.x+rng.randf_range(-0.45,0.45),0.075,p.y+rng.randf_range(-0.45,0.45)),false,false)
		elif natural_noise.get_noise_2d(p.x*3,p.y*3)>0.05:
			var cluster := group(gravel,"GritPocket",Vector3(p.x,0.075,p.y))
			for j in range(3):
				ball(cluster,"PartlyBuriedChip",Vector3(rng.randf_range(-0.18,0.18),0.01,rng.randf_range(-0.18,0.18)),Vector3(rng.randf_range(0.025,0.09),0.02,rng.randf_range(0.025,0.06)),["b4ad8f","9e9579","a59070"][j])
	for h in building_footprints:
		var dims: Vector3=h.get_node("PlasterWalls").mesh.size
		for side in [-1,1]:
			for j in range(5):
				var local:=Vector3(side*(dims.x/2+0.15),0.08,-dims.z/2+j*dims.z/5)
				tuft(grass,h.transform*local,false,false)

func new_landmarks() -> void:
	var landmarks := group(scene_root,"ExplorationLandmarks")
	var positions := [Vector2(-80,-28),Vector2(-62,-24.5)]
	# Keep approach lanes clear of old decorative trees and rocks.
	for section in ["BareRidgeTrees","BrokenRockTerraces"]:
		for n in scene_root.get_node(section).get_children():
			for p in positions:
				if Vector2(n.position.x,n.position.z).distance_to(p)<3.7:
					var old: Vector3=n.position
					n.position.x-=4.5
					n.position.y=elevation(n.position.x,n.position.z)
					for c in scene_root.get_node("SavedWalkCollisions").get_children():
						if Vector2(c.position.x,c.position.z).distance_to(Vector2(old.x,old.z))<0.1:
							c.position+=n.position-old
					break
	for i in range(2):
		var p: Vector2=positions[i]
		var building := group(landmarks,"DomeStoneTomb" if i==0 else "StoneAncestralShrine",Vector3(p.x,0.07+elevation(p.x,p.y+2.2),p.y))
		building.set_meta("display_name","圆顶石墓" if i==0 else "石祠小庙")
		building.set_meta("reference_project","openworldtest")
		stone_building(building,i==0)
		portal_reservation(building,"burial_dome_tomb" if i==0 else "burial_shici")
	# Short branching paths connect both new entrances to the saved north path.
	road_root=group(scene_root.get_node("TerrainAndPaths/HandWorkedRoads"),"ExplorationApproaches")
	detailed_road("TombApproach",[Vector2(-71,-25),Vector2(-74,-25.4),Vector2(-77,-24.5),Vector2(-80,-23),Vector2(-80,-25.4)],1.3,true)
	detailed_road("ShrineApproach",[Vector2(-70,-18),Vector2(-68,-19.7),Vector2(-64,-20.3),Vector2(-62,-21.6)],1.35,true)
	conform(road_root)
	paint_new_paths(road_root)

func stone_building(b: Node3D,dome: bool) -> void:
	var w:=4.2 if dome else 4.1
	var d:=4.2 if dome else 4.6
	var masonry:=group(b,"HandLaidStonework")
	for side in [-1,1]:
		for row in range(6):
			for j in range(6):
				box(masonry,"SideStone",Vector3(side*(w/2-0.23),0.22+row*0.39,-d/2+0.36+j*(d-0.1)/6),Vector3(0.48,0.37,(d-0.1)/6-0.028),["909382","a0a18c","858b7c","969984"][(j+row)%4])
		for row in range(6):
			box(masonry,"DoorJambStone",Vector3(side*1.40,0.22+row*0.39,d/2),Vector3(1.15,0.37,0.52),["9a9e8b","868e7e","a3a58e"][row%3])
	for row in range(6):
		for j in range(6):
			box(masonry,"BackStone",Vector3(-w/2+0.35+j*w/6,0.22+row*0.39,-d/2),Vector3(w/6-0.025,0.37,0.48),["909382","a0a18c","858b7c"][(j+row)%3])
	box(masonry,"DoorLintel",Vector3(0,2.36,d/2),Vector3(w+0.12,0.28,0.65),"a5a68e")
	box(masonry,"WornThreshold",Vector3(0,0.04,d/2+0.18),Vector3(1.60,0.08,0.68),"999e89")
	box(b,"InteriorShadowBack",Vector3(0,1.1,-d/2+0.28),Vector3(w-0.7,2.0,0.025),"333b32")
	box(b,"InteriorFloor",Vector3(0,0.025,0),Vector3(w-0.5,0.05,d),"777f6e")
	if dome:
		var r:=group(b,"StoneDome")
		for row in range(5):
			var a0:=row*PI/10
			var a1:=(row+1)*PI/10-0.012
			for j in range(16):
				var t0:=(j+0.5*(row%2))*TAU/16+0.006
				var t1:=t0+TAU/16-0.012
				var vs:=PackedVector3Array()
				for inner in [false,true]:
					for a in [a0,a1]:
						for t in [t0,t1]:
							var rad:=maxf(0.02,cos(a)*2.22-(0.28 if inner else 0))
							vs.append(Vector3(cos(t)*rad,2.48+sin(a)*1.55,sin(t)*rad))
				var ids:=PackedInt32Array([0,2,1,1,2,3,4,5,6,5,7,6,0,1,4,1,5,4,2,6,3,3,6,7,0,4,2,2,4,6,1,3,5,3,7,5])
				solid(r,"DomeVoussoir",vs,ids,["999e8b","a8ac96","8a9383","9fa38e"][(row+j)%4])
		cylinder(r,"LotusFinialBase",Vector3(0,4.10,0),0.30,0.16,"9da38e",0.22,8)
		ball(r,"WeatheredStoneFinial",Vector3(0,4.26,0),Vector3(0.19,0.24,0.19),"a4a993")
	else:
		# Ridge runs front-to-back like the reference stone shrine.
		var r:=group(b,"StoneGabledRoof")
		r.rotation.y=PI/2
		roof(r,d+0.08,w,2.52,false,false)
		for n in r.find_children("*","MeshInstance3D",true,false):
			n.material_override=mat(["858b78","969983","a3a58d"][rng.randi_range(0,2)])
		box(b,"FadedStonePlaque",Vector3(0,2.27,d/2+0.36),Vector3(0.8,0.18,0.035),"717a68")
		for side in [-1,1]:
			var door:=group(b,"OpenTimberDoor",Vector3(side*0.81,0,d/2-0.08))
			door.rotation.y=side*1.18
			for j in range(4): box(door,"OldDoorPlank",Vector3(-side*(0.09+j*0.17),1.08,0),Vector3(0.155,2.04,0.075),["635c46","746a4f","6b624a"][j%3])
	var body:=StaticBody3D.new()
	body.name="WallCollisions"
	b.add_child(body)
	body.owner=scene_root
	for side in [-1,1]:
		collision_box(body,"SideWall",Vector3(side*(w/2-0.23),1.24,0),Vector3(0.48,2.48,d))
		collision_box(body,"DoorPier",Vector3(side*1.40,1.12,d/2),Vector3(1.15,2.24,0.52))
	collision_box(body,"BackWall",Vector3(0,1.24,-d/2),Vector3(w,2.48,0.48))
	collision_box(body,"LintelAbovePassage",Vector3(0,2.36,d/2),Vector3(w,0.28,0.65))
	for side in [-1,1]:
		for j in range(7):
			ball(masonry,"StoneFootMoss",Vector3(side*(w/2-0.1),0.15+rng.randf()*0.2,rng.randf_range(-d/2,d/2)),Vector3(0.18,0.09,0.16),"738269")
	# A shallow approach apron follows the actual ground, without a blocking step.
	var zfront:=d/2+0.35
	var verts:=PackedVector3Array([Vector3(-0.79,0.075,zfront),Vector3(0.79,0.075,zfront),Vector3(-0.88,-0.03,zfront+1),Vector3(0.88,-0.03,zfront+1)])
	var apron:=solid(b,"WornEntryApron",verts,PackedInt32Array([0,1,2,1,3,2]),"a0a48f",Vector3.UP)
	var floor_shape:=CollisionShape3D.new()
	floor_shape.name="ApronSurface"
	floor_shape.shape=apron.mesh.create_trimesh_shape()
	body.add_child(floor_shape)
	floor_shape.owner=scene_root

func portal_reservation(b: Node3D,id: String) -> void:
	var depth:=4.2 if id=="burial_dome_tomb" else 4.6
	var portal:=Area3D.new()
	portal.name="ReservedEntrance"
	portal.collision_layer=0
	portal.collision_mask=1
	portal.monitoring=false
	portal.monitorable=false
	b.add_child(portal)
	portal.owner=scene_root
	portal.position=Vector3(0,0,depth/2-0.25)
	portal.set_meta("door_link_id",id+"_door")
	portal.set_meta("destination_id",id+"_room")
	portal.set_meta("target_scene","")
	portal.set_meta("implementation_status","Reserved: connect to a future 3D interior scene")
	collision_box(portal,"TriggerVolume",Vector3(0,1.05,0),Vector3(1.30,2.1,0.75))
	for label in ["EntryPoint","ExitSpawn"]:
		var marker:=Marker3D.new()
		marker.name=label
		b.add_child(marker)
		marker.owner=scene_root
		marker.position=Vector3(0,0.10,depth/2+(-0.65 if label=="EntryPoint" else 1.25))
		marker.set_meta("spawn_id","world_to_room" if label=="EntryPoint" else id+"_room_exit")

func paint_new_paths(node: Node) -> void:
	if node is MeshInstance3D and node.mesh is ArrayMesh and node.name!="BentBlades":
		var m:=ShaderMaterial.new()
		m.shader=load("res://burial_ridge/ground_paint.gdshader")
		m.set_shader_parameter("base_color",node.get_active_material(0).get_shader_parameter("base_color"))
		var v: Vector3=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
		m.render_priority=clampi(roundi((v.y-elevation(v.x,v.z)-0.13)*1000),0,60)
		m.set_meta("village_toon",true)
		node.material_override=m
	for c in node.get_children(): paint_new_paths(c)

func graveyard_weeds() -> void:
	var g:=group(scene_root,"GraveyardWildGrass")
	for i in range(1050):
		var p:=Vector2(rng.randf_range(-86,-59),rng.randf_range(-30,-3))
		if near_path(p): continue
		if p.distance_to(Vector2(-80,-28))<3.6 or p.distance_to(Vector2(-62,-24.5))<3.8: continue
		var around_grave:=false
		for grave in scene_root.get_node("Graveyard").get_children():
			var distance:=p.distance_to(Vector2(grave.position.x,grave.position.z))
			if distance<0.63: around_grave=false; break
			if distance<2.0: around_grave=true
		if not around_grave and natural_noise.get_noise_2d(p.x*2,p.y*2)<0.02: continue
		var clump:=group(g,"DryGrassIsland",Vector3(p.x,0.08+elevation(p.x,p.y),p.y))
		for j in range(rng.randi_range(2,4)):
			var offset:=Vector3(rng.randf_range(-0.28,0.28),0,rng.randf_range(-0.28,0.28))
			offset.y=elevation(p.x+offset.x,p.y+offset.z)-elevation(p.x,p.y)
			tuft(clump,offset,i%6==0,true)
			clump.get_child(clump.get_child_count()-1).scale=Vector3.ONE*(rng.randf_range(0.55,0.85) if i%6==0 else rng.randf_range(0.85,1.35))
