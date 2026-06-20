# Elastic reel tether (GAP-039), no Node inheritance.
# Fast auto-reel + a springy pull toward the anchor → reeling builds velocity, so
# shooting upward flings the player up (momentum carries onto a platform formed by
# a 2nd anchor). Low damping keeps the "彈力" bounce/momentum. The Verlet rope
# (player.gd) handles the visual; this is pure physics on `max_length` (rest length).
class_name WireConstraint
extends RefCounted

var anchor_pos: Vector2
var max_length: float                # rope rest length (shrinks via reel); Verlet visual length
var min_length: float = 24.0
var auto_reel_speed: float = 320.0   # fast auto-pull toward the anchor (px/s)
var stiffness: float = 40.0          # elastic pull per px of stretch beyond rest length
var damping: float = 4.0             # low → springy, preserves fling momentum
var max_accel: float = 5000.0        # cap on pull accel (avoid teleport-fling)

func setup(pos: Vector2, dist_to_anchor: float) -> void:
	anchor_pos = pos
	max_length = dist_to_anchor

func auto_reel(delta: float) -> void:
	max_length = maxf(min_length, max_length - auto_reel_speed * delta)

func reel(speed: float, delta: float) -> void:
	max_length = maxf(min_length, max_length - speed * delta)

# Slack (dist <= rest) → free fall. Taut (dist > rest) → elastic spring pulls the
# player toward the anchor (capped) with along-rope damping. As auto_reel shrinks
# rest length, stretch grows → stronger pull → the player is reeled/flung in.
func apply(player_pos: Vector2, velocity: Vector2, delta: float) -> Vector2:
	var to_anchor := anchor_pos - player_pos
	var dist := to_anchor.length()
	if dist <= 0.001:
		return velocity
	var dir := to_anchor / dist
	if dist > max_length:
		var stretch := dist - max_length
		var pull := minf(stiffness * stretch, max_accel)
		velocity += dir * (pull * delta)
		var radial := velocity.dot(dir)
		velocity -= dir * (radial * clampf(damping * delta, 0.0, 1.0))
	return velocity

func tension_ratio(player_pos: Vector2) -> float:
	if max_length <= 0.0:
		return 0.0
	return clampf((anchor_pos - player_pos).length() / max_length, 0.0, 1.0)
