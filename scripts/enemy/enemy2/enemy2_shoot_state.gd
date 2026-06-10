extends "res://scripts/state_machine/state.gd"

var shoot_timer: float = 0.0
var line: Line2D
var line_inner: Line2D
var shot_fired: bool = false

func enter(_msg: Dictionary = {}) -> void:
	shoot_timer = 1.0 # 射擊硬直
	shot_fired = false
	
	# 建立雷射視覺
	line = Line2D.new()
	line.default_color = Color.RED
	line.width = 6.0
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2(400 * actor.direction, 0))
	actor.add_child(line)
	
	line_inner = Line2D.new()
	line_inner.default_color = Color.WHITE
	line_inner.width = 2.0
	line_inner.add_point(Vector2.ZERO)
	line_inner.add_point(Vector2(400 * actor.direction, 0))
	actor.add_child(line_inner)
	
	# 傷害判定
	var rc = RayCast2D.new()
	rc.target_position = Vector2(400 * actor.direction, 0)
	rc.collision_mask = 2
	rc.force_raycast_update()
	if rc.is_colliding():
		var col = rc.get_collider()
		if col and col.has_method("take_damage"):
			col.take_damage(1)
	rc.queue_free()

func physics_update(delta: float) -> void:
	shoot_timer -= delta
	if shoot_timer <= 0:
		state_machine.transition_to("PatrolState")

func exit() -> void:
	if is_instance_valid(line):
		line.queue_free()
	if is_instance_valid(line_inner):
		line_inner.queue_free()
