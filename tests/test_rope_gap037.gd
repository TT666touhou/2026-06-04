# Headless unit test for GAP-037 rope rewrite (VerletRope + WireConstraint).
# Run: godot --headless --path . --script res://tests/test_rope_gap037.gd
# These are pure RefCounted components (no scene tree), so they can be exercised
# without gameplay input — verifies the new runtime code actually executes.
extends SceneTree

const VerletRopeScript = preload("res://scripts/verlet_rope.gd")
const WireConstraintScript = preload("res://scripts/wire_constraint.gd")

func _init() -> void:
	var fails := 0

	# --- VerletRope: endpoints pinned, points finite, correct count ---
	var rope: RefCounted = VerletRopeScript.new()
	rope.init(Vector2(0, 0), Vector2(0, 200), 12)
	if rope.points.size() != 12:
		fails += 1; printerr("FAIL verlet point count: ", rope.points.size())
	for _i in 60:
		rope.update(Vector2(0, 0), Vector2(50, 200), 200.0, 1.0 / 60.0)
	if rope.points[0] != Vector2(0, 0):
		fails += 1; printerr("FAIL verlet start not pinned: ", rope.points[0])
	if rope.points[11] != Vector2(50, 200):
		fails += 1; printerr("FAIL verlet end not pinned: ", rope.points[11])
	for p in rope.points:
		if not (is_finite(p.x) and is_finite(p.y)):
			fails += 1; printerr("FAIL verlet non-finite point: ", p)
			break

	# --- WireConstraint: slack passes through, taut clamps + cancels radial ---
	var wc: RefCounted = WireConstraintScript.new()
	wc.setup(Vector2(0, 0), 100.0)
	var slack: Dictionary = wc.constrain(Vector2(0, 50), Vector2(10, 0))
	if slack["pos"] != Vector2(0, 50):
		fails += 1; printerr("FAIL slack moved player: ", slack["pos"])
	var taut: Dictionary = wc.constrain(Vector2(0, 150), Vector2(0, 100))
	var d: float = (taut["pos"] as Vector2).distance_to(Vector2(0, 0))
	if absf(d - 100.0) > 0.5:
		fails += 1; printerr("FAIL taut not clamped to length: ", d)
	if (taut["vel"] as Vector2).y > 0.5:
		fails += 1; printerr("FAIL outward radial not removed: ", taut["vel"])

	# --- reel / auto_reel respect min_length ---
	wc.reel(50.0, 1.0)
	if wc.max_length > 100.0 or wc.max_length < wc.min_length - 0.01:
		fails += 1; printerr("FAIL reel out of range: ", wc.max_length)
	for _j in 100:
		wc.auto_reel(1.0)
	if absf(wc.max_length - wc.min_length) > 0.01:
		fails += 1; printerr("FAIL auto_reel not clamped to min: ", wc.max_length)

	if fails == 0:
		print("ROPE_TEST_PASS")
	else:
		print("ROPE_TEST_FAIL count=", fails)
	quit()
