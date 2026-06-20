# Headless test for GAP-040: NATURAL pendulum constraint + needle count.
# Run: godot --headless --path . --script res://tests/test_rope_gap040.gd
# Key assertion: the constraint NEVER injects velocity toward the anchor (GAP-039's
# spring did → unnatural "added momentum"). Replaces test_rope_gap039.gd.
extends SceneTree

const WireConstraintScript = preload("res://scripts/wire_constraint.gd")
const NeedleManagerScript = preload("res://scripts/needle_manager.gd")

func _init() -> void:
	var fails := 0

	# --- needle count is 5 ---
	var nm: Node = NeedleManagerScript.new()
	if nm.max_needles != 5:
		fails += 1; printerr("FAIL max_needles != 5: ", nm.max_needles)
	nm.free()

	var wc: RefCounted = WireConstraintScript.new()
	wc.setup(Vector2(0, 0), 100.0)   # anchor at origin, rope length 100

	# --- NATURAL: stationary player, taut → NO velocity injected (the spring would) ---
	var taut: Dictionary = wc.constrain(Vector2(0, 150), Vector2.ZERO)  # 150 below anchor
	if (taut["vel"] as Vector2).length() > 0.01:
		fails += 1; printerr("FAIL injected velocity (not natural): ", taut["vel"])
	var d: float = (taut["pos"] as Vector2).distance_to(Vector2(0, 0))
	if absf(d - 100.0) > 0.5:
		fails += 1; printerr("FAIL not clamped to length: ", d)

	# --- tangential (perpendicular) velocity preserved → natural swing ---
	var t2: Dictionary = wc.constrain(Vector2(0, 150), Vector2(50, 0))
	if absf((t2["vel"] as Vector2).x - 50.0) > 0.01:
		fails += 1; printerr("FAIL tangential not preserved: ", t2["vel"])

	# --- outward radial removed ---
	var t3: Dictionary = wc.constrain(Vector2(0, 150), Vector2(0, 100))
	if (t3["vel"] as Vector2).y > 0.5:
		fails += 1; printerr("FAIL outward radial not removed: ", t3["vel"])

	# --- slack passes through untouched ---
	var sl: Dictionary = wc.constrain(Vector2(0, 50), Vector2(10, 5))
	if sl["pos"] != Vector2(0, 50) or sl["vel"] != Vector2(10, 5):
		fails += 1; printerr("FAIL slack altered: ", sl)

	# --- reel clamps to min_length ---
	for _j in 200:
		wc.auto_reel(1.0 / 60.0)
	if absf(wc.max_length - wc.min_length) > 0.01:
		fails += 1; printerr("FAIL reel not clamped to min: ", wc.max_length)

	if fails == 0:
		print("ROPE40_TEST_PASS")
	else:
		print("ROPE40_TEST_FAIL count=", fails)
	quit()
