extends "res://scripts/state_machine/state.gd"

var charge_speed: float = 80.0
var max_charge_speed: float = 150.0

func enter(_msg: Dictionary = {}) -> void:
	if actor.stats and "speed" in actor.stats:
		charge_speed = actor.stats.speed * 2.5
	else:
		charge_speed = 150.0

func physics_update(delta: float) -> void:
	actor.velocity.x = actor.direction * charge_speed
	
	if not actor.is_on_floor():
		actor.velocity.y += actor.gravity * delta
		
	actor.move_and_slide()
	
	if actor.is_on_wall() or not actor.ledge_detector.is_colliding():
		state_machine.transition_to("PatrolState")
