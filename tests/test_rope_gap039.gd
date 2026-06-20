# Headless test for GAP-039: elastic reel fling physics + needle count.
# Run: godot --headless --path . --script res://tests/test_rope_gap039.gd
# Demonstrates the workflow's new verification priority (§F): assert physics
# numerically without gameplay input, instead of relying on run_project.
extends SceneTree

const WireConstraintScript = preload("res://scripts/wire_constraint.gd")
const NeedleManagerScript = preload("res://scripts/needle_manager.gd")

func _init() -> void:
	var fails := 0

	# --- needle count is 5 (export default) ---
	var nm: Node = NeedleManagerScript.new()  # not added to tree → _ready not run
	if nm.max_needles != 5:
		fails += 1; printerr("FAIL max_needles != 5: ", nm.max_needles)
	nm.free()

	# --- elastic pull: taut rope accelerates player TOWARD the anchor ---
	var wc: RefCounted = WireConstraintScript.new()
	wc.setup(Vector2(0, 0), 100.0)          # anchor at origin (above), rest length 100
	wc.stiffness = 40.0; wc.damping = 4.0; wc.max_accel = 5000.0
	var pull_vel: Vector2 = wc.apply(Vector2(0, 200), Vector2.ZERO, 1.0 / 60.0)  # player 200 below, stretched
	if pull_vel.y >= 0.0:                    # should gain upward (toward anchor) velocity
		fails += 1; printerr("FAIL elastic pull not toward anchor: ", pull_vel)

	# --- fling up: anchor above, fast auto-reel builds upward momentum ---
	var fc: RefCounted = WireConstraintScript.new()
	fc.setup(Vector2(0, 0), 200.0)
	fc.auto_reel_speed = 320.0; fc.stiffness = 40.0; fc.damping = 4.0; fc.max_accel = 5000.0
	var pos := Vector2(0, 200)               # player starts 200px below the anchor
	var vel := Vector2.ZERO
	for _i in 40:
		fc.auto_reel(1.0 / 60.0)
		vel = fc.apply(pos, vel, 1.0 / 60.0)
		pos += vel * (1.0 / 60.0)
	if vel.y >= 0.0:
		fails += 1; printerr("FAIL no upward fling velocity: ", vel)
	if pos.y >= 200.0:
		fails += 1; printerr("FAIL player not pulled upward: ", pos)

	# --- reel respects min_length ---
	for _j in 200:
		fc.auto_reel(1.0 / 60.0)
	if absf(fc.max_length - fc.min_length) > 0.01:
		fails += 1; printerr("FAIL reel not clamped to min: ", fc.max_length)

	if fails == 0:
		print("ROPE39_TEST_PASS")
	else:
		print("ROPE39_TEST_FAIL count=", fails)
	quit()
