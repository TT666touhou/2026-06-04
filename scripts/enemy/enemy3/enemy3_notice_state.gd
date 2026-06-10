extends "res://scripts/state_machine/state.gd"

var notice_timer: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	notice_timer = 0.5 
	
	if actor.appearance and "modulate" in actor.appearance:
		var tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(actor.appearance, "modulate", Color.RED, 0.1)
		tween.tween_property(actor.appearance, "modulate", Color.WHITE, 0.1)

func physics_update(delta: float) -> void:
	notice_timer -= delta
	if notice_timer <= 0:
		state_machine.transition_to("ShootState")
