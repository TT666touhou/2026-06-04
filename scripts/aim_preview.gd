## AimPreview — comprehensive trajectory preview during FROZEN state.
## GAP-056: Full trajectory for slingshot (arc+ghost), needle (reach+continuation), swing (pendulum arc).
extends Node2D

enum Mode { NONE, SLINGSHOT, NEEDLE, SWING }

var mode: Mode = Mode.NONE

# Shared path points (arc, line, swing arc)
var points: PackedVector2Array
# For SLINGSHOT: ghost rectangle at landing spot
var ghost_pos: Vector2
var ghost_size: Vector2 = Vector2(32, 64)
# For NEEDLE: reach point (720px) and optional continuation to actual target
var reach_point: Vector2
var beyond_point: Vector2   # actual mouse target if beyond 720px; zero = no continuation
var beyond_active: bool = false

const DASH_LEN: float = 10.0
const GAP_LEN: float = 7.0

const COLOR_SLING  := Color(0.4, 0.8, 1.0, 0.85)   # light blue arc
const COLOR_NEEDLE := Color(1.0, 0.85, 0.3, 0.90)   # yellow needle
const COLOR_BEYOND := Color(1.0, 0.6, 0.2, 0.40)    # orange faded (multi-turn)
const COLOR_SWING  := Color(0.5, 1.0, 0.6, 0.80)    # green swing arc
const COLOR_GHOST  := Color(0.4, 0.8, 1.0, 0.30)    # ghost player fill
const COLOR_REACH  := Color(1.0, 0.9, 0.2, 1.00)    # reach circle border
const COLOR_SWING_DOT := Color(0.5, 1.0, 0.6, 0.50) # swing endpoint circle

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 10

func _process(_delta: float) -> void:
	queue_redraw()

# ── Setters ────────────────────────────────────────────────────────────────────

func set_slingshot(arc: PackedVector2Array, landing: Vector2) -> void:
	mode = Mode.SLINGSHOT
	points = arc
	ghost_pos = landing

func set_needle(from: Vector2, reach: Vector2, target: Vector2) -> void:
	## reach = 720px endpoint.  target = actual mouse (may == reach if within 720px).
	mode = Mode.NEEDLE
	points = PackedVector2Array([from, reach])
	reach_point = reach
	beyond_active = target.distance_to(reach) > 4.0
	beyond_point = target

func set_swing(arc: PackedVector2Array) -> void:
	mode = Mode.SWING
	points = arc

func clear() -> void:
	mode = Mode.NONE
	points.clear()
	beyond_active = false

# ── Draw ───────────────────────────────────────────────────────────────────────

func _draw() -> void:
	match mode:
		Mode.SLINGSHOT: _draw_slingshot()
		Mode.NEEDLE:    _draw_needle()
		Mode.SWING:     _draw_swing()

func _draw_slingshot() -> void:
	if points.size() < 2:
		return
	_draw_dashed_path(points, COLOR_SLING, 2.0)
	# Ghost player rectangle at landing
	var half := ghost_size * 0.5
	var rect := Rect2(ghost_pos - half, ghost_size)
	draw_rect(rect, COLOR_GHOST)
	draw_rect(rect, COLOR_SLING * Color(1, 1, 1, 0.9), false, 1.5)  # outline
	# Landing cross
	draw_line(ghost_pos + Vector2(-6, 0), ghost_pos + Vector2(6, 0), COLOR_SLING, 1.5)
	draw_line(ghost_pos + Vector2(0, -6), ghost_pos + Vector2(0, 6), COLOR_SLING, 1.5)

func _draw_needle() -> void:
	if points.size() < 2:
		return
	# Main reach line (dashed)
	_draw_dashed_path(points, COLOR_NEEDLE, 2.0)
	# Reach circle (solid border)
	draw_arc(reach_point, 7.0, 0.0, TAU, 16, COLOR_REACH, 2.0)
	# Optional continuation beyond 720px (faded dots)
	if beyond_active:
		var cont := PackedVector2Array([reach_point, beyond_point])
		_draw_dashed_path(cont, COLOR_BEYOND, 1.5, 5.0, 8.0)
		draw_circle(beyond_point, 4.0, COLOR_BEYOND)

func _draw_swing() -> void:
	if points.size() < 2:
		return
	_draw_dashed_path(points, COLOR_SWING, 2.0)
	# Endpoint circle
	var end_pt := points[-1]
	draw_circle(end_pt, 5.0, COLOR_SWING_DOT)
	draw_arc(end_pt, 5.0, 0.0, TAU, 12, COLOR_SWING, 1.5)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _draw_dashed_path(
	pts: PackedVector2Array, color: Color, width: float,
	dash: float = DASH_LEN, gap: float = GAP_LEN
) -> void:
	var remaining := dash
	var drawing := true
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg_len := a.distance_to(b)
		if seg_len < 0.001:
			continue
		var seg_dir := (b - a) / seg_len
		var traveled := 0.0
		while traveled < seg_len:
			var chunk := minf(remaining, seg_len - traveled)
			if drawing:
				var p0 := a + seg_dir * traveled
				var p1 := a + seg_dir * (traveled + chunk)
				draw_line(p0, p1, color, width)
			traveled += chunk
			remaining -= chunk
			if remaining <= 0.0:
				drawing = !drawing
				remaining = dash if drawing else gap
