extends "res://scripts/state_machine/state.gd"

var BulletClass = preload("res://scripts/enemy/bullet.gd")
var post_shoot_timer: float = 0.0
var shot_fired: bool = false

func enter(_msg: Dictionary = {}) -> void:
	shot_fired = false
	post_shoot_timer = 0.5 
	
	var bullet = BulletClass.new()
	bullet.direction = Vector2(actor.direction, 0)
	bullet.global_position = actor.global_position + Vector2(20 * actor.direction, 0)
	
	var root = actor.get_parent()
	if root:
		root.add_child(bullet)
	else:
		actor.add_child(bullet)
	shot_fired = true

func physics_update(delta: float) -> void:
	if shot_fired:
		post_shoot_timer -= delta
		if post_shoot_timer <= 0:
			state_machine.transition_to("PatrolState")
