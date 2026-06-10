extends "res://scripts/state_machine/state.gd"

var notice_timer: float = 0.0
var line: Line2D

func enter(_msg: Dictionary = {}) -> void:
	notice_timer = 0.5
	
	if actor.appearance and "modulate" in actor.appearance:
		var tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(actor.appearance, "modulate", Color.RED, 0.1)
		tween.tween_property(actor.appearance, "modulate", Color.WHITE, 0.1)
		
	line = Line2D.new()
	line.default_color = Color(1, 0, 0, 0.3)
	line.width = 2.0
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2(200 * actor.direction, 0))
	actor.add_child(line)

func exit() -> void:
	if is_instance_valid(line):
		line.queue_free()

func physics_update(delta: float) -> void:
	notice_timer -= delta
	if notice_timer <= 0:
		state_machine.transition_to("ShootState")
