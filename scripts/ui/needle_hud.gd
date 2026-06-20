extends CanvasLayer

@onready var _label: Label = $NeedleLabel

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var nm: Node = players[0].get_node_or_null("NeedleManager")
	if nm == null:
		return
	var total: int = nm.max_needles
	var in_use: int = clampi(nm.needle_count(), 0, total)
	var available: int = total - in_use
	_label.text = "●".repeat(available) + "○".repeat(in_use)
