# velocity projection, ~30 lines, no Node inheritance
class_name WireConstraint
extends RefCounted

var anchor_pos: Vector2
var max_length: float            # visual reference (initial attach distance); physics is always-pull
var stiffness: float = 14.0      # elastic pull toward anchor (1/s^2); hang dist ~ gravity/stiffness
var damping: float = 6.0         # along-rope velocity damping (bounce control)
var max_accel: float = 3500.0    # cap on pull accel to avoid violent yank

func setup(pos: Vector2, dist_to_anchor: float) -> void:
	anchor_pos = pos
	max_length = dist_to_anchor

# Bungee / elastic tether (GAP-035): always pulls the player toward the anchor
# (auto-reel) with an elastic, low-damped force, so the player gets yanked in,
# overshoots and bounces. Damping acts only along the rope; swing is preserved.
func apply(player_pos: Vector2, velocity: Vector2, delta: float) -> Vector2:
	var to_anchor := anchor_pos - player_pos
	var dist := to_anchor.length()
	if dist <= 0.001:
		return velocity
	var rope_dir := to_anchor / dist
	var pull := minf(stiffness * dist, max_accel)
	velocity += rope_dir * (pull * delta)
	var radial := velocity.dot(rope_dir)
	velocity -= rope_dir * (radial * clampf(damping * delta, 0.0, 1.0))
	return velocity

func tension_ratio(player_pos: Vector2) -> float:
	if max_length <= 0.0:
		return 0.0
	return (anchor_pos - player_pos).length() / max_length
