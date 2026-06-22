# Natural pendulum length-constraint tether (GAP-040), no Node inheritance.
# Pure distance constraint — it NEVER injects velocity toward the anchor (GAP-039's
# elastic spring did, which felt like "specially-added" unnatural momentum). The
# player swings naturally under gravity; reeling (shrinking max_length) pulls the
# player in via the position clamp, and angular momentum is conserved naturally
# (swinging speeds up as the rope shortens, like a skater pulling in their arms).
# The Verlet rope (player.gd) handles the visual via `max_length`.
class_name WireConstraint
extends RefCounted

var anchor_pos: Vector2
var max_length: float                # rope length = swing radius (shrinks via reel)
var min_length: float = 24.0
var auto_reel_speed: float = 520.0   # fast auto-pull toward the anchor (px/s)
var snap_factor: float = 0.0         # pure pendulum: no energy injection when rope snaps taut (GAP-052)

func setup(pos: Vector2, dist_to_anchor: float) -> void:
	anchor_pos = pos
	max_length = dist_to_anchor

func auto_reel(delta: float) -> void:
	max_length = maxf(min_length, max_length - auto_reel_speed * delta)

func reel(speed: float, delta: float) -> void:
	max_length = maxf(min_length, max_length - speed * delta)

# Slack (dist <= length) → free fall. Taut → clamp the player onto the swing circle
# and cancel only the OUTWARD radial velocity (keeps tangential swing). No velocity
# is ever added toward the anchor → momentum stays natural. Returns { "pos", "vel" }.
func constrain(player_pos: Vector2, velocity: Vector2) -> Dictionary:
	var to_anchor := anchor_pos - player_pos
	var dist := to_anchor.length()
	if dist <= max_length or dist <= 0.001:
		return { "pos": player_pos, "vel": velocity }
	var dir := to_anchor / dist
	var new_pos := anchor_pos - dir * max_length
	var radial := velocity.dot(dir)   # >0 toward anchor, <0 stretching away
	if radial < 0.0:
		velocity -= dir * radial                        # remove outward component
		velocity += dir * (-radial) * snap_factor       # snap-back: reflect fraction inward (GAP-046)
	return { "pos": new_pos, "vel": velocity }

func tension_ratio(player_pos: Vector2) -> float:
	if max_length <= 0.0:
		return 0.0
	return clampf((anchor_pos - player_pos).length() / max_length, 0.0, 1.0)
