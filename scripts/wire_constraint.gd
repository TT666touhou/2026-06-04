# Pendulum length-constraint tether (GAP-037), no Node inheritance.
class_name WireConstraint
extends RefCounted

var anchor_pos: Vector2
var max_length: float                # current rope length = swing radius
var min_length: float = 24.0
var auto_reel_speed: float = 110.0   # auto-pull toward the anchor (px/s)

func setup(pos: Vector2, dist_to_anchor: float) -> void:
	anchor_pos = pos
	max_length = dist_to_anchor

func auto_reel(delta: float) -> void:
	max_length = maxf(min_length, max_length - auto_reel_speed * delta)

func reel(speed: float, delta: float) -> void:
	max_length = maxf(min_length, max_length - speed * delta)

# Slack rope (dist <= length) → free fall. Taut rope → clamp the player onto the
# swing circle and cancel the outward (radial) velocity, leaving only tangential
# swing = a real pendulum. Returns { "pos": Vector2, "vel": Vector2 }.
func constrain(player_pos: Vector2, velocity: Vector2) -> Dictionary:
	var to_anchor := anchor_pos - player_pos
	var dist := to_anchor.length()
	if dist <= max_length or dist <= 0.001:
		return { "pos": player_pos, "vel": velocity }
	var dir := to_anchor / dist
	var new_pos := anchor_pos - dir * max_length
	var radial := velocity.dot(dir)   # >0 toward anchor, <0 stretching away
	if radial < 0.0:
		velocity -= dir * radial
	return { "pos": new_pos, "vel": velocity }

func tension_ratio(player_pos: Vector2) -> float:
	if max_length <= 0.0:
		return 0.0
	return clampf((anchor_pos - player_pos).length() / max_length, 0.0, 1.0)
