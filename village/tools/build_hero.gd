extends "res://village/tools/bake_helpers.gd"

func _initialize() -> void:
	if "--bake" not in OS.get_cmdline_user_args():
		quit(1)
		return
	if FileAccess.file_exists("res://village/hero/hero.tscn") and "--overwrite" not in OS.get_cmdline_user_args():
		push_error("Refusing to overwrite an edited hero. Explicit --overwrite required.")
		quit(1)
		return
	scene_root = CharacterBody3D.new()
	scene_root.name = "Hero"
	scene_root.set_script(load("res://village/hero/hero_controller.gd"))
	var shape := CollisionShape3D.new()
	shape.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.75
	shape.shape = capsule
	scene_root.add_child(shape)
	shape.owner = scene_root
	shape.position.y = 0.875
	var visual := group(scene_root, "Visual")
	var hips := group(visual, "Hips", Vector3(0, 0.86, 0))
	box(hips,"Trousers",Vector3.ZERO,Vector3(0.43,0.24,0.29),"48483f")
	var torso := group(hips,"Torso",Vector3(0,0.12,0))
	box(torso,"Tunic",Vector3(0,0.23,0),Vector3(0.49,0.46,0.3),"777569")
	box(torso,"Hem",Vector3(0,0.03,0),Vector3(0.53,0.15,0.34),"5d5d51")
	box(torso,"Belt",Vector3(0,0.08,0.015),Vector3(0.54,0.09,0.36),"302f29")
	box(torso,"Buckle",Vector3(0,0.08,0.206),Vector3(0.1,0.07,0.025),"a6946a")
	box(torso,"FrontSeam",Vector3(0,0.29,0.155),Vector3(0.035,0.32,0.018),"42473e")
	for side in [-1,1]:
		var collar := box(torso,"Collar",Vector3(side*0.07,0.43,0.155),Vector3(0.09,0.19,0.045),"a3a08c")
		collar.rotation.z = side * -0.4
	var strap := box(torso,"DiagonalSatchelStrap",Vector3(0,0.28,0.18),Vector3(0.07,0.51,0.035),"3e4038")
	strap.rotation.z = -0.6
	box(torso,"HipPouch",Vector3(0.29,0.03,0),Vector3(0.15,0.21,0.24),"655947")
	var head := group(torso,"Head",Vector3(0,0.53,0))
	cylinder(head,"Neck",Vector3(0,-0.015,0),0.1,0.15,"bc9d7f")
	box(head,"Face",Vector3(0,0.23,0.045),Vector3(0.39,0.4,0.34),"c8ad8f")
	box(head,"Jaw",Vector3(0,0.055,0.055),Vector3(0.29,0.12,0.29),"ba997c")
	ball(head,"HairCrown",Vector3(0,0.38,-0.025),Vector3(0.3,0.29,0.26),"292d2d")
	box(head,"HairBack",Vector3(0,0.25,-0.14),Vector3(0.43,0.36,0.16),"25292a")
	for i in range(7):
		var x := (i-3)*0.071
		var fringe := box(head,"Fringe%02d"%i,Vector3(x,0.35-0.035*(i%3),0.205),Vector3(0.095,0.2+0.03*(i%2),0.075),"363b3c" if i%2 else "25292b")
		fringe.rotation.z = -0.22 + i*0.07
	for side in [-1,1]:
		box(head,"Ear",Vector3(side*0.22,0.19,0.03),Vector3(0.075,0.12,0.09),"b99a7d")
		box(head,"Sideburn",Vector3(side*0.21,0.29,0.12),Vector3(0.065,0.22,0.09),"292d2e")
		box(head,"Eye",Vector3(side*0.085,0.21,0.219),Vector3(0.042,0.055,0.018),"252a28")
		box(head,"Brow",Vector3(side*0.085,0.265,0.22),Vector3(0.071,0.022,0.02),"41413a")
	box(head,"Nose",Vector3(0,0.153,0.231),Vector3(0.042,0.055,0.037),"d6b899")
	box(head,"Mouth",Vector3(0,0.092,0.219),Vector3(0.06,0.015,0.013),"8b6f59")
	var tail := group(head,"Ponytail",Vector3(0,0.19,-0.24))
	box(tail,"HairTie",Vector3(0,-0.02,0),Vector3(0.105,0.07,0.11),"a4a28c")
	box(tail,"Tail",Vector3(0,-0.16,-0.015),Vector3(0.1,0.25,0.11),"252b2c")
	for side in [-1,1]:
		var label := "Left" if side < 0 else "Right"
		var arm := group(torso,label+"Arm",Vector3(side*0.31,0.38,0))
		box(arm,"Sleeve",Vector3(0,-0.13,0),Vector3(0.19,0.31,0.23),"737469")
		var elbow := group(arm,"Elbow",Vector3(0,-0.27,0))
		box(elbow,"Forearm",Vector3(0,-0.095,0),Vector3(0.145,0.21,0.17),"858375")
		box(elbow,"WristWrap",Vector3(0,-0.19,0),Vector3(0.15,0.07,0.18),"464a41")
		box(elbow,"Hand",Vector3(0,-0.26,0.015),Vector3(0.145,0.14,0.16),"c9ab8b")
		var leg := group(hips,label+"Leg",Vector3(side*0.13,-0.07,0))
		box(leg,"Thigh",Vector3(0,-0.17,0),Vector3(0.185,0.34,0.24),"52564a")
		var knee := group(leg,"Knee",Vector3(0,-0.34,0))
		box(knee,"Shin",Vector3(0,-0.155,0),Vector3(0.15,0.31,0.18),"646354")
		for j in range(3):
			box(knee,"LegWrap%d"%j,Vector3(0,-0.075-j*0.08,0),Vector3(0.165,0.04,0.195),"98917a")
		box(knee,"Boot",Vector3(0,-0.375,0.055),Vector3(0.19,0.15,0.32),"665440")
		box(knee,"Sole",Vector3(0,-0.435,0.055),Vector3(0.2,0.035,0.33),"34372f")
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	scene_root.add_child(player)
	player.owner = scene_root
	var library := AnimationLibrary.new()
	for clip in ["idle","walk","run"]:
		var anim := Animation.new()
		anim.length = 2.4 if clip == "idle" else (0.88 if clip == "walk" else 0.56)
		anim.loop_mode = Animation.LOOP_LINEAR
		var moving: bool = clip != "idle"
		var running: bool = clip == "run"
		track(anim,"Visual/Hips:position",[Vector3(0,0.86,0),Vector3(0,0.86+(0.075 if running else 0.035 if moving else 0.018),0),Vector3(0,0.86,0),Vector3(0,0.86+(0.075 if running else 0.035 if moving else 0.018),0),Vector3(0,0.86,0)])
		track(anim,"Visual/Hips/Torso:rotation",[Vector3(-0.15 if running else 0,0,0),Vector3(-0.18 if running else 0.015,0,0),Vector3(-0.15 if running else 0,0,0),Vector3(-0.18 if running else 0.015,0,0),Vector3(-0.15 if running else 0,0,0)])
		for side in [-1,1]:
			var label := "Left" if side < 0 else "Right"
			var swing := (0.85 if running else 0.45) if moving else 0.025
			track(anim,"Visual/Hips/"+label+"Leg:rotation",[Vector3(side*swing,0,0),Vector3.ZERO,Vector3(-side*swing,0,0),Vector3.ZERO,Vector3(side*swing,0,0)])
			var bend := -1.35 if running else -0.65 if moving else 0.0
			track(anim,"Visual/Hips/"+label+"Leg/Knee:rotation",[Vector3.ZERO,Vector3(bend if side < 0 else 0,0,0),Vector3.ZERO,Vector3(bend if side > 0 else 0,0,0),Vector3.ZERO])
			track(anim,"Visual/Hips/Torso/"+label+"Arm:rotation",[Vector3(-side*swing,0,side*0.06),Vector3(0,0,side*0.06),Vector3(side*swing,0,side*0.06),Vector3(0,0,side*0.06),Vector3(-side*swing,0,side*0.06)])
			var elbow_bend := 1.25 if running else 0.35 if moving else 0.1
			track(anim,"Visual/Hips/Torso/"+label+"Arm/Elbow:rotation",[Vector3(elbow_bend,0,0),Vector3(elbow_bend+0.1,0,0),Vector3(elbow_bend,0,0),Vector3(elbow_bend+0.1,0,0),Vector3(elbow_bend,0,0)])
		track(anim,"Visual/Hips/Torso/Head/Ponytail:rotation",[Vector3(-0.1,0,-0.08),Vector3(0.2,0,0),Vector3(-0.1,0,0.08),Vector3(0.2,0,0),Vector3(-0.1,0,-0.08)])
		library.add_animation(clip,anim)
	player.add_animation_library("",library)
	player.autoplay = "idle"
	var result := save_scene("res://village/hero/hero.tscn")
	scene_root.free()
	quit(result)

func track(anim: Animation, path: String, values: Array) -> void:
	var index := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(index,NodePath(path))
	for i in range(values.size()):
		anim.track_insert_key(index,anim.length*i/float(values.size()-1),values[i])


