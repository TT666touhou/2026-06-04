# Rope-length constraint for wire grapple.
# Split into pre/post move_and_slide passes to avoid velocity-injection oscillation.
# pre_constrain: removes outward radial velocity (pendulum arc, no bounce).
# post_constrain: hard-clamps position onto rope circle + projects velocity to tangent.
class_name WireConstraint
extends RefCounted

var anchor_pos: Vector2
var length: float
var min_length: float = 24.0
var reel_speed: float = 180.0
var snap_factor: float = 0.12  # tiny inward bounce when rope snaps taut

func setup(pos: Vector2, initial_length: float) -> void:
	anchor_pos = pos
	length = initial_length

func reel(delta: float) -> void:
	length = maxf(min_length, length - reel_speed * delta)

# Call BEFORE move_and_slide.
# Removes outward radial velocity so the player can't stretch the rope further.
# Adds a tiny inward bounce (snap_factor) for rope-snap elasticity feel.
func pre_constrain(player_pos: Vector2, vel: Vector2) -> Vector2:
	var to_anchor := anchor_pos - player_pos
	var dist := to_anchor.length()
	if dist <= length or dist < 0.001:
		return vel
	var dir := to_anchor / dist
	var radial := vel.dot(dir)  # +toward anchor, -away
	if radial < 0.0:
		vel -= dir * radial                    # cancel outward
		vel += dir * (-radial) * snap_factor   # tiny elastic bounce
	return vel

# Call AFTER move_and_slide.
# Hard-clamps player onto rope circle and removes any remaining outward radial velocity.
# Direct position assignment (not velocity injection) avoids the overshoot cycle.
func post_constrain(player_pos: Vector2, vel: Vector2) -> Dictionary:
	var to_anchor := anchor_pos - player_pos
	var dist := to_anchor.length()
	if dist <= length or dist < 0.001:
		return {"pos": player_pos, "vel": vel}
	var dir := to_anchor / dist
	var new_pos := anchor_pos - dir * length
	var radial := vel.dot(dir)
	if radial < 0.0:
		vel -= dir * radial  # remove any residual outward velocity
	return {"pos": new_pos, "vel": vel}

func tension_ratio(player_pos: Vector2) -> float:
	if length <= 0.0:
		return 0.0
	return clampf((anchor_pos - player_pos).length() / length, 0.0, 1.0)
