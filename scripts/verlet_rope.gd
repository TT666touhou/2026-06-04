# Verlet-integrated rope for natural 2D rope visuals (GAP-037).
# No class_name on purpose — preloaded by the player so adding it never requires
# a global class-cache rebuild (--import). Pure data: fill a Line2D from `points`.
# Endpoints are pinned each frame (anchor + player); interior points hang/swing
# under gravity with distance constraints, so the rope droops when slack and
# straightens when taut — no fake perpendicular sag.
extends RefCounted

var points: PackedVector2Array = PackedVector2Array()
var prev: PackedVector2Array = PackedVector2Array()
var num: int = 12
var gravity: Vector2 = Vector2(0.0, 980.0)
var damping: float = 0.98
var iterations: int = 10

func init(start: Vector2, end: Vector2, count: int = 12) -> void:
	num = maxi(2, count)
	points = PackedVector2Array()
	prev = PackedVector2Array()
	for i in num:
		var t := float(i) / float(num - 1)
		var p := start.lerp(end, t)
		points.append(p)
		prev.append(p)

func update(start: Vector2, end: Vector2, total_length: float, delta: float) -> void:
	if points.size() != num:
		init(start, end, num)
	var seg := total_length / float(num - 1)
	# Verlet-integrate the interior points (endpoints pinned just below)
	for i in range(1, num - 1):
		var cur := points[i]
		var vel := (cur - prev[i]) * damping
		prev[i] = cur
		points[i] = cur + vel + gravity * (delta * delta)
	points[0] = start
	points[num - 1] = end
	# Satisfy segment-length constraints (Jakobsen relaxation)
	for _it in iterations:
		points[0] = start
		points[num - 1] = end
		for i in range(num - 1):
			var a := points[i]
			var b := points[i + 1]
			var d := b - a
			var dist := d.length()
			if dist < 0.0001:
				continue
			var corr := d * (0.5 * (dist - seg) / dist)
			if i != 0:
				points[i] = a + corr
			if i + 1 != num - 1:
				points[i + 1] = b - corr
