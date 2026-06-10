extends "res://scripts/state_machine/state.gd"

var move_speed: float = 30.0

func enter(_msg: Dictionary = {}) -> void:
	if actor.stats and "speed" in actor.stats:
		move_speed = actor.stats.speed

func physics_update(delta: float) -> void:
	if not actor.is_on_floor():
		actor.velocity.y += actor.gravity * delta
		
	actor.velocity.x = actor.direction * move_speed
	actor.move_and_slide()
	
	if actor.is_on_wall() or not actor.ledge_detector.is_colliding():
		actor.turn_around()
		
	if actor.player_detector.is_colliding():
		var collider = actor.player_detector.get_collider()
		if collider and collider.name == "Player1":
			state_machine.transition_to("NoticeState")
