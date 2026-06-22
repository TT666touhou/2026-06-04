## AimPreview — draws dashed preview lines during FROZEN state.
## Attach as child of Player with top_level = true (world coords).
## GAP-055
extends Node2D

enum Mode { NONE, SLINGSHOT, NEEDLE }

var mode: Mode = Mode.NONE
var points: PackedVector2Array  # path points (arc or straight line)
var reach_point: Vector2        # circle drawn here (720px reach marker)

const DASH_LEN: float = 8.0
const GAP_LEN: float = 6.0
const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.75)
const REACH_COLOR := Color(1.0, 0.9, 0.3, 0.9)
const REACH_RADIUS: float = 6.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 10

func _process(_delta: float) -> void:
	queue_redraw()

func set_slingshot(arc: PackedVector2Array) -> void:
	mode = Mode.SLINGSHOT
	points = arc
	reach_point = arc[-1] if arc.size() > 0 else Vector2.ZERO

func set_needle(from: Vector2, to: Vector2, reach: Vector2) -> void:
	mode = Mode.NEEDLE
	points = PackedVector2Array([from, to])
	reach_point = reach

func clear() -> void:
	mode = Mode.NONE
	points.clear()

func _draw() -> void:
	if mode == Mode.NONE or points.size() < 2:
		return
	_draw_dashed_path(points, LINE_COLOR)
	draw_circle(reach_point, REACH_RADIUS, REACH_COLOR)

func _draw_dashed_path(pts: PackedVector2Array, color: Color) -> void:
	var remaining_dash := DASH_LEN
	var drawing := true
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg_len := a.distance_to(b)
		var seg_dir := (b - a) / seg_len
		var traveled := 0.0
		while traveled < seg_len:
			var chunk := minf(remaining_dash, seg_len - traveled)
			if drawing:
				var p0 := a + seg_dir * traveled
				var p1 := a + seg_dir * (traveled + chunk)
				draw_line(p0, p1, color, 1.5)
			traveled += chunk
			remaining_dash -= chunk
			if remaining_dash <= 0.0:
				drawing = !drawing
				remaining_dash = DASH_LEN if drawing else GAP_LEN
