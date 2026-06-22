## AimPreview — multi-layer trajectory preview during FROZEN state.
## GAP-056b: All action types drawn simultaneously; disconnect wire button.
extends Node2D

# ── Per-layer data ─────────────────────────────────────────────────────────────
var _needle_from: Vector2
var _needle_reach: Vector2
var _needle_beyond: Vector2
var _needle_active: bool = false
var _needle_beyond_active: bool = false

var _sling_arc: PackedVector2Array
var _sling_ghost: Vector2
var _sling_active: bool = false

var _swing_arc: PackedVector2Array
var _swing_active: bool = false

var _btn_rect: Rect2 = Rect2()  # disconnect button, world coords

# ── Colors ─────────────────────────────────────────────────────────────────────
const C_NEEDLE    := Color(1.0, 0.88, 0.30, 0.95)
const C_BEYOND    := Color(1.0, 0.55, 0.15, 0.38)
const C_SLING     := Color(0.35, 0.75, 1.00, 0.85)
const C_GHOST_F   := Color(0.35, 0.75, 1.00, 0.22)
const C_GHOST_L   := Color(0.35, 0.75, 1.00, 0.80)
const C_SWING     := Color(0.45, 1.00, 0.55, 0.80)
const C_SWING_END := Color(0.45, 1.00, 0.55, 0.50)
const C_BTN_BG    := Color(0.15, 0.15, 0.15, 0.85)
const C_BTN_BORD  := Color(1.00, 0.38, 0.22, 1.00)
const C_BTN_TEXT  := Color(1.00, 1.00, 1.00, 1.00)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 10

func _process(_delta: float) -> void:
	queue_redraw()

# ── Public setters ─────────────────────────────────────────────────────────────

func set_needle(from: Vector2, reach: Vector2, target: Vector2) -> void:
	_needle_from = from
	_needle_reach = reach
	_needle_beyond = target
	_needle_active = true
	_needle_beyond_active = target.distance_squared_to(reach) > 16.0

func set_slingshot(arc: PackedVector2Array, ghost: Vector2) -> void:
	_sling_arc = arc
	_sling_ghost = ghost
	_sling_active = true

func set_swing(arc: PackedVector2Array) -> void:
	_swing_arc = arc
	_swing_active = true

func set_disconnect_button(rect: Rect2) -> void:
	_btn_rect = rect

func clear_needle() -> void:
	_needle_active = false

func clear_slingshot() -> void:
	_sling_active = false

func clear_swing() -> void:
	_swing_active = false

## Clears everything (called during PLAYING turns)
func clear_all() -> void:
	_needle_active = false
	_sling_active = false
	_swing_active = false
	_btn_rect = Rect2()

## Legacy compat
func clear() -> void:
	clear_all()

# ── Draw ───────────────────────────────────────────────────────────────────────

func _draw() -> void:
	# Layer 1: needle (always on top for readability)
	if _needle_active:
		_draw_dashed_line(_needle_from, _needle_reach, C_NEEDLE, 2.0)
		draw_arc(_needle_reach, 7.0, 0.0, TAU, 16, C_NEEDLE, 2.0)
		if _needle_beyond_active:
			_draw_dashed_line(_needle_reach, _needle_beyond, C_BEYOND, 1.5, 5.0, 9.0)
			draw_circle(_needle_beyond, 3.5, C_BEYOND)

	# Layer 2: slingshot arc + ghost player
	if _sling_active and _sling_arc.size() >= 2:
		_draw_dashed_path(_sling_arc, C_SLING, 2.0)
		var ghost_half := Vector2(16, 32)
		draw_rect(Rect2(_sling_ghost - ghost_half, ghost_half * 2), C_GHOST_F)
		draw_rect(Rect2(_sling_ghost - ghost_half, ghost_half * 2), C_GHOST_L, false, 1.5)
		draw_line(_sling_ghost + Vector2(-7, 0), _sling_ghost + Vector2(7, 0), C_SLING, 1.5)
		draw_line(_sling_ghost + Vector2(0, -7), _sling_ghost + Vector2(0, 7), C_SLING, 1.5)

	# Layer 3: swing arc
	if _swing_active and _swing_arc.size() >= 2:
		_draw_dashed_path(_swing_arc, C_SWING, 2.0)
		var end_pt := _swing_arc[-1]
		draw_circle(end_pt, 5.0, C_SWING_END)
		draw_arc(end_pt, 5.0, 0.0, TAU, 12, C_SWING, 1.5)

	# Layer 4: disconnect wire button
	if _btn_rect.has_area():
		draw_rect(_btn_rect, C_BTN_BG)
		draw_rect(_btn_rect, C_BTN_BORD, false, 2.0)
		# Draw "✂ 斷開" text placeholder as two lines (no font available in _draw)
		# Use a simple X mark as button icon
		var cx := _btn_rect.get_center()
		var hw := 8.0
		draw_line(cx + Vector2(-hw, -hw * 0.5), cx + Vector2(hw, hw * 0.5), C_BTN_TEXT, 2.0)
		draw_line(cx + Vector2(-hw, hw * 0.5), cx + Vector2(hw, -hw * 0.5), C_BTN_TEXT, 2.0)
		draw_circle(cx + Vector2(-hw - 4, 0), 2.5, C_BTN_BORD)  # scissors left
		draw_circle(cx + Vector2(hw + 4, 0), 2.5, C_BTN_BORD)   # scissors right

# ── Helpers ────────────────────────────────────────────────────────────────────

func _draw_dashed_line(
	a: Vector2, b: Vector2, color: Color, width: float,
	dash: float = 10.0, gap: float = 7.0
) -> void:
	_draw_dashed_path(PackedVector2Array([a, b]), color, width, dash, gap)

func _draw_dashed_path(
	pts: PackedVector2Array, color: Color, width: float,
	dash: float = 10.0, gap: float = 7.0
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
				draw_line(a + seg_dir * traveled, a + seg_dir * (traveled + chunk), color, width)
			traveled += chunk
			remaining -= chunk
			if remaining <= 0.0:
				drawing = !drawing
				remaining = dash if drawing else gap
