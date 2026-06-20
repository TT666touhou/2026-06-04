# velocity projection, ~30 lines, no Node inheritance
class_name WireConstraint
extends RefCounted

const MIN_LENGTH := 20.0

var anchor_pos: Vector2
var max_length: float
var slack: float = 10.0

func setup(pos: Vector2, dist_to_anchor: float) -> void:
	anchor_pos = pos
	max_length = dist_to_anchor + slack

func apply(player_pos: Vector2, velocity: Vector2) -> Vector2:
	var to_anchor := anchor_pos - player_pos
	var dist := to_anchor.length()
	if dist <= max_length:
		return velocity
	var rope_dir := to_anchor.normalized()
	var radial := velocity.dot(rope_dir)
	if radial < 0.0:
		velocity -= rope_dir * radial
	return velocity

func reel_in(speed: float, delta: float) -> void:
	max_length = max(MIN_LENGTH, max_length - speed * delta)

func tension_ratio(player_pos: Vector2) -> float:
	if max_length <= 0.0:
		return 0.0
	return (anchor_pos - player_pos).length() / max_length
