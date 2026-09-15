@tool
extends Node3D
## All variants are saved scene instances; changing clothes only toggles visibility.
@export var outfit_nodes: Array[NodePath] = [NodePath("LinenRobe"),NodePath("IndigoRobe")]
## 0 .. outfit_nodes.size()-1 selects a garment; the final index shows the body.
@export var outfit: int = 0:
	set(value):
		outfit = clampi(value,0,outfit_nodes.size())
		apply_visibility()
@export var show_hair: bool = true:
	set(value):
		show_hair = value
		apply_visibility()

func _ready() -> void:
	apply_visibility()

func apply_visibility() -> void:
	if not is_inside_tree():
		return
	for i in range(outfit_nodes.size()):
		var garment := get_node_or_null(outfit_nodes[i]) as Node3D
		if garment:
			garment.visible = outfit == i
	if has_node("Hair"):
		$Hair.visible = show_hair

func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_C:
		outfit = (outfit+1)%(outfit_nodes.size()+1)
	if event.keycode == KEY_H:
		show_hair = not show_hair
