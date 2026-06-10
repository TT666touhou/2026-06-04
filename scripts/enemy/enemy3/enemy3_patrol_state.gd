extends "res://scripts/state_machine/state.gd"

@export var move_speed: float = 30.0
@export var patrol_distance: float = 100.0
var distance_moved: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	if actor.stats and "speed" in actor.stats:
		move_speed = actor.stats.speed
	distance_moved = 0.0

func physics_update(delta: float) -> void:
	var step = actor.direction * move_speed * delta
	actor.position.x += step
	distance_moved += abs(step)
	
	if distance_moved >= patrol_distance:
		actor.turn_around()
		distance_moved = 0.0
		
	if actor.player_detector.is_colliding():
		var collider = actor.player_detector.get_collider()
		if collider and collider.name == "Player1":
			state_machine.transition_to("NoticeState")
