extends Area3D

var _transitioning := false

func _ready() -> void:
	if monitoring:
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _transitioning or not body is CharacterBody3D:
		return
	var target := str(get_meta("target_scene", ""))
	if target.is_empty():
		return
	_transitioning = true
	var spawn := str(get_meta("target_spawn", ""))
	get_tree().root.set_meta("scene_spawn_id", spawn)
	get_tree().change_scene_to_file(target)
