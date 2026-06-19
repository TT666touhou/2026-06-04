# ponytail: rung=2 — CanvasLayer + Label, built-in nodes only
class_name DebugOverlay
extends CanvasLayer

var _player: Node = null  # Player script instance; untyped to allow script-method calls

@onready var _label: Label = $DebugPanel/DebugLabel

func _ready() -> void:
	_player = get_tree().current_scene.get_node_or_null("Player")
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible

func _process(_delta: float) -> void:
	if not visible or _player == null:
		return
	_label.text = _build_text()

func _build_text() -> String:
	var nm := _player.get_node_or_null("NeedleManager")
	var count: int = nm.needle_count() if nm != null else 0
	var tension: float = _player.get_wire_tension()
	var wire_len: float = _player.get_wire_length()
	var vel: Vector2 = _player.velocity
	var on_floor: bool = _player.is_on_floor()
	var state := "TAUT" if tension >= 0.95 else ("TENSE" if tension >= 0.5 else "SLACK")
	return "[Wire]\n  max_length: %.1f px\n  tension:    %.2f  %s\n\n[Player]\n  velocity:   (%.1f, %.1f)\n  on_floor:   %s\n\n[Needles]\n  count:      %d / 3" % [
		wire_len, tension, state, vel.x, vel.y, str(on_floor), count
	]
