# velocity projection, ~30 lines, no Node inheritance
class_name WireConstraint
extends RefCounted

const MIN_LENGTH := 20.0

var anchor_pos: Vector2
var max_length: float           # rope rest (natural) length; player may stretch past it
var slack: float = 10.0
var stiffness: float = 80.0      # spring accel per px of stretch (1/s^2)
var damping: float = 9.0         # damping of velocity along the rope (1/s)

func setup(pos: Vector2, dist_to_anchor: float) -> void:
	anchor_pos = pos
	max_length = dist_to_anchor + slack

# Elastic spring-damper rope (GAP-034): slack rope = free fall; taut rope pulls
# back with a Hooke spring (elastic give) and damps along-rope oscillation while
# preserving the tangential swing component.
func apply(player_pos: Vector2, velocity: Vector2, delta: float) -> Vector2:
	var to_anchor := anchor_pos - player_pos
	var dist := to_anchor.length()
	if dist <= max_length or dist <= 0.001:
		return velocity
	var rope_dir := to_anchor / dist
	var stretch := dist - max_length
	# Spring pulls the player toward the anchor (proportional to stretch)
	velocity += rope_dir * (stiffness * stretch * delta)
	# Damp velocity along the rope (kills bounce) — tangential swing untouched
	var radial := velocity.dot(rope_dir)
	velocity -= rope_dir * (radial * clampf(damping * delta, 0.0, 1.0))
	return velocity

func reel_in(speed: float, delta: float) -> void:
	max_length = max(MIN_LENGTH, max_length - speed * delta)

func tension_ratio(player_pos: Vector2) -> float:
	if max_length <= 0.0:
		return 0.0
	return (anchor_pos - player_pos).length() / max_length
