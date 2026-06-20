class_name WorldLabel
extends Node2D
# Reusable world-space text label that follows a world position.
# Generic on purpose — usable for pickup prompts, damage numbers, hints, etc.
# Polish (tween/colour/icons) lives in play_appear(); call sites never change.

@export var world_offset: Vector2 = Vector2(0.0, -22.0)

@onready var _label: Label = $Label

var _active: bool = false

func set_content(text: String, color: Color = Color.WHITE) -> void:
	if _label == null:
		_label = $Label
	_label.text = text
	_label.modulate = color

func follow(world_pos: Vector2) -> void:
	global_position = world_pos + world_offset

func show_prompt() -> void:
	if _active:
		return
	_active = true
	visible = true
	play_appear()

func hide_prompt() -> void:
	if not _active:
		return
	_active = false
	visible = false

# --- Polish hook (future-friendly) ---------------------------------------
# Swap the body for any fancier effect later; show_prompt() is the only caller.
func play_appear() -> void:
	scale = Vector2(0.7, 0.7)
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.12)
