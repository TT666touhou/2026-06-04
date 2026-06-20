class_name PickupPromptUI
extends Node2D
# Floats a WorldLabel above each currently-retrievable needle and highlights
# the one F will actually grab (the priority target). Pools labels for reuse.
# Fed each frame by the player via update_prompts(); see needle_manager.get_retrieve_info().

const WorldLabelScene = preload("res://scenes/ui/world_label.tscn")

@export var target_color: Color = Color(1.0, 0.95, 0.4, 1.0)    # what F will grab
@export var other_color: Color = Color(0.85, 0.85, 0.85, 0.65)  # also retrievable

var _pool: Array[WorldLabel] = []

# candidates: Array of { "anchor": Node, "label": String }
# target: the anchor F would retrieve (highlighted), may be null
func update_prompts(candidates: Array, target: Node) -> void:
	_ensure_pool(candidates.size())
	for i in _pool.size():
		var wl: WorldLabel = _pool[i]
		if i < candidates.size():
			var info: Dictionary = candidates[i]
			var anchor: Node = info["anchor"]
			var is_target: bool = anchor == target
			wl.set_content(info["label"], target_color if is_target else other_color)
			wl.follow(anchor.global_position)
			wl.show_prompt()
		else:
			wl.hide_prompt()

func _ensure_pool(n: int) -> void:
	while _pool.size() < n:
		var wl := WorldLabelScene.instantiate() as WorldLabel
		add_child(wl)
		wl.hide_prompt()
		_pool.append(wl)
