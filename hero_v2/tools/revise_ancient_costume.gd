extends "res://hero_v2/tools/build_traveler.gd"
## One-time targeted revision of the SAVED hero. Does not regenerate the world.
func _initialize() -> void:
	if "--bake" not in OS.get_cmdline_user_args() or "--overwrite" not in OS.get_cmdline_user_args():
		push_error("Requires explicit --bake --overwrite to revise saved scene")
		quit(1)
		return
	scene_root = load("res://hero_v2/traveler.tscn").instantiate()
	if scene_root.has_meta("ancient_costume_revision"):
		push_error("Revision already applied; edit the saved scene directly.")
		quit(1)
		return
	shader = load("res://hero_v2/cloth.gdshader")
	var body := scene_root.get_node("Facing/Visual/Body") as Node3D
	for label in ["Jacket","TunicHem","FrontOpening","LeftLapel","RightLapel","Undershirt","JacketPocket-1","JacketPocket1","PocketFlap-1","PocketFlap1","LeatherBelt","Buckle","BuckleInset","CrossBodyStrapFront","CrossBodyStrapBack","HipPouch","PouchFlap"]:
		body.get_node(label).free()
	body.get_node("Neck/ScarfCollar").free()
	for child in body.get_node("ScarfTails").get_children():
		child.free()
	# Keep the animated scarf joint, now supporting two narrow cloth collar ties.
	var ties := body.get_node("ScarfTails") as Node3D
	ties.position.x = -0.075
	var tie := box(ties,"CollarTie",Vector3(0,-0.095,-0.006),Vector3(0.034,0.19,0.02),"aba28a")
	tie.rotation.z = 0.15
	box(ties,"ShortTie",Vector3(0.047,-0.066,-0.01),Vector3(0.028,0.135,0.02),"8e8673")
	var head := body.get_node("Head") as Node3D
	head.scale = Vector3(0.82,0.95,0.91)
	head.position.y -= 0.015
	var robe := group(body,"CrossCollarRobe")
	tailored(robe,"LinenTorso",Vector3.ZERO,[[0.07,0.355,0.28],[0.24,0.345,0.252],[0.43,0.398,0.272],[0.545,0.358,0.24],[0.58,0.255,0.195]],"7c8174")
	# The diagonal panels form a crossed collar; the outer flap closes on wearer's right.
	ribbon(robe,"InnerCollar",Vector3(0.065,0.582,0.131),Vector3(-0.04,0.446,0.1465),0.054,"d0c2a1")
	ribbon(robe,"OuterRightLapel",Vector3(-0.075,0.585,0.155),Vector3(0.158,0.272,0.169),0.071,"c4b797")
	ribbon(robe,"OuterSeam",Vector3(0.153,0.27,0.157),Vector3(0.167,0.12,0.154),0.021,"646e61")
	tailored(robe,"InnerNeckline",Vector3(0,0.54,0.04),[[0.0,0.16,0.13],[0.07,0.17,0.15]],"c9bb9e")
	var sash := group(body,"ClothSash")
	tailored(sash,"WovenWaistBand",Vector3.ZERO,[[0.065,0.37,0.302],[0.155,0.36,0.286]],"60584b")
	tailored(sash,"UpperFold",Vector3.ZERO,[[0.135,0.365,0.291],[0.16,0.36,0.289]],"8c7d64")
	ball(sash,"ClothKnot",Vector3(0.157,0.11,0.158),Vector3(0.052,0.042,0.033),"9c8869")
	ribbon(sash,"LongSashEnd",Vector3(0.17,0.097,0.17),Vector3(0.13,-0.215,0.18),0.053,"8b785f")
	ribbon(sash,"ShortSashEnd",Vector3(0.163,0.09,0.182),Vector3(0.223,-0.11,0.176),0.045,"a08c6c")
	for side in [-1,1]:
		var label := "Left" if side==-1 else "Right"
		var arm := body.get_node(label+"Arm") as Node3D
		arm.position.x = side*0.212
		arm.get_node("Sleeve").free()
		arm.get_node("ShoulderSeam").free()
		tailored(arm,"PlainSleeve",Vector3.ZERO,[[-0.26,0.132,0.15],[-0.075,0.164,0.17],[0.023,0.133,0.15]],"7c8174")
		var elbow := arm.get_node("Elbow") as Node3D
		for name in ["ForearmSleeve","RolledCuff","WristWrap"]:
			elbow.get_node(name).free()
		tailored(elbow,"TaperedClothSleeve",Vector3.ZERO,[[-0.205,0.103,0.125],[-0.15,0.127,0.15],[0.025,0.14,0.155]],"777e70")
		tailored(elbow,"LinenCuff",Vector3.ZERO,[[-0.22,0.11,0.13],[-0.174,0.119,0.14]],"b6ab8c")
		var leg := body.get_node(label+"Leg") as Node3D
		leg.get_node("ThighPatch").free()
		var panels := group(leg,"SplitRobeHem")
		tailored(panels,"RobeSkirt",Vector3(0,0.01,0),[[-0.285,0.228,0.298],[-0.20,0.22,0.28],[-0.015,0.208,0.277],[0.065,0.205,0.27]],"777c6d")
		tailored(panels,"HemBinding",Vector3.ZERO,[[-0.283,0.232,0.30],[-0.252,0.23,0.298]],"aba083")
		ribbon(panels,"FrontPleat",Vector3(side*0.048,-0.025,0.141),Vector3(side*0.065,-0.241,0.151),0.018,"626d5e")
		var knee := leg.get_node("Knee") as Node3D
		knee.get_node("KneePatch").free()
		var ankle := knee.get_node("Ankle") as Node3D
		for name in ["Boot","BootSole","ToeCap"]:
			ankle.get_node(name).free()
		tailored(ankle,"ClothShoe",Vector3(0,-0.045,0.035),[[-0.054,0.14,0.24],[-0.02,0.147,0.25],[0.024,0.128,0.20],[0.05,0.105,0.125]],"414b43")
		box(ankle,"WovenSole",Vector3(0,-0.103,0.037),Vector3(0.149,0.023,0.247),"958569")
		box(ankle,"ShoeSeam",Vector3(0,-0.017,0.122),Vector3(0.02,0.02,0.055),"737b68")
	# A tied-up section makes the period silhouette legible from all directions.
	var hair := head.get_node("Hair") as Node3D
	ball(hair,"BoundTopknot",Vector3(0,0.29,-0.12),Vector3(0.125,0.115,0.115),"353d3d")
	box(hair,"HairTie",Vector3(0,0.265,-0.202),Vector3(0.175,0.031,0.04),"80745e")
	var pin := cylinder(hair,"WoodenHairpin",Vector3(0,0.305,-0.12),0.012,0.31,"a18e6e",-1,6)
	pin.rotation.z = PI/2
	scene_root.set_meta("ancient_costume_revision",1)
	save_scene("res://hero_v2/traveler.tscn")
	scene_root.free()
	quit()

func ribbon(parent: Node, label: String, a: Vector3, b: Vector3, width: float, color: String) -> void:
	var n := box(parent,label,(a+b)*0.5,Vector3(width,a.distance_to(b),0.024),color)
	n.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
