extends SceneTree

const SOURCE := "res://northern_ridge/world.tscn"

func _initialize() -> void:
	if not "--apply" in OS.get_cmdline_user_args():
		quit(1)
		return
	var root: Node3D = load(SOURCE).instantiate()
	var portal := root.get_node("RootWrappedStoneGate/ReservedEntrance") as Area3D
	portal.monitoring = true
	portal.monitorable = false
	portal.set_script(load("res://village/scene_portal.gd"))
	portal.set_meta("target_scene", "res://burial_left_cave/main.tscn")
	portal.set_meta("target_spawn", "root_cave_entry")
	portal.set_meta("door_link_id", "northern_root_cave_door")
	portal.set_meta("destination_id", "northern_root_cave")
	portal.set_meta("portal_enabled", true)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, SOURCE)
	print("NORTHERN CAVE PORTAL SAVED ", err)
	root.free()
	quit(err)
