# Headless test for GAP-041 simplified NeedleManager:
# attack-needle proximity auto-retrieve + release_wire safety.
# Run: godot --headless --path . --script res://tests/test_rope_gap041.gd
extends SceneTree

const NeedleManagerScript = preload("res://scripts/needle_manager.gd")
const NeedleAnchorScript = preload("res://scripts/needle_anchor.gd")

func _init() -> void:
	var fails := 0

	var nm: Node = NeedleManagerScript.new()
	if nm.max_needles != 5:
		fails += 1; printerr("FAIL max_needles != 5: ", nm.max_needles)

	# Two attack anchors: one within retrieve_radius(60), one far.
	var near_a: Node2D = NeedleAnchorScript.new()
	near_a.type = 0
	root.add_child(near_a)
	near_a.global_position = Vector2(100, 100)
	var far_a: Node2D = NeedleAnchorScript.new()
	far_a.type = 0
	root.add_child(far_a)
	far_a.global_position = Vector2(1000, 1000)
	nm._anchors = [near_a, far_a]

	var retrieved: Array = []
	nm.needle_retrieved.connect(func(a): retrieved.append(a))

	# player at (110,100): near (dist 10) auto-retrieved, far untouched
	nm.auto_retrieve_attack(Vector2(110, 100))
	if nm._anchors.size() != 1 or not (far_a in nm._anchors):
		fails += 1; printerr("FAIL near should be retrieved, far kept: ", nm._anchors.size())
	if retrieved.size() != 1 or retrieved[0] != near_a:
		fails += 1; printerr("FAIL wrong needle retrieved: ", retrieved)

	# release_wire with no active wire → no crash, no change
	nm.release_wire()
	if nm._anchors.size() != 1:
		fails += 1; printerr("FAIL release_wire altered attack anchors")

	if fails == 0:
		print("NM41_TEST_PASS")
	else:
		print("NM41_TEST_FAIL count=", fails)
	nm.free()
	quit()
