extends "res://burial_ridge/tools/sculpt_saved_terrain.gd"
func _initialize() -> void:
	if not "--apply" in OS.get_cmdline_user_args(): quit(1);return
	scene_root=load(OUTPUT).instantiate()
	if scene_root.has_meta("northern_connection_revision"):
		push_error("Northern connection already saved")
		quit(1);return
	natural_noise.seed=917369
	natural_noise.frequency=0.12
	scene_root.get_node("SavedWalkCollisions/NorthLimit").disabled=true
	var shifted:=0
	for t in scene_root.get_node("LivingForest").get_children():
		if not str(t.name).begins_with("BroadleafTree"):continue
		if t.position.x>-42.4 and t.position.x<-37.6 and t.position.z<-19:
			var previous: Vector3=t.position
			t.position.x+=-3.5 if t.position.x<-40 else 3.5
			t.position.y=elevation(t.position.x,t.position.z)
			for c in scene_root.get_node("SavedWalkCollisions").get_children():
				if Vector2(c.position.x,c.position.z).distance_to(Vector2(previous.x,previous.z))<0.02:
					c.position+=t.position-previous
			shifted+=1
	scene_root.set_meta("northern_connection_revision",1)
	assert(save_scene(OUTPUT)==OK)
	scene_root.free()
	print("Opened old north boundary; moved ",shifted," trees and their collisions to open the eastern link")
	quit()
