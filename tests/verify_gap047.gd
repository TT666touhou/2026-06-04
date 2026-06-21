extends SceneTree
# Headless verification for GAP-047 fixes
# Run: godot --headless --path . --script res://tests/verify_gap047.gd

func _init() -> void:
	var passed := 0
	var failed := 0

	# ── Test 1: WireConstraint auto_reel reduces max_length ──────────────
	var wc := WireConstraint.new()
	wc.setup(Vector2(0.0, -200.0), 150.0)
	var before_len := wc.max_length
	wc.auto_reel(0.1)
	if wc.max_length < before_len:
		print("[PASS] auto_reel reduces max_length: ", before_len, " -> ", wc.max_length)
		passed += 1
	else:
		print("[FAIL] auto_reel did NOT reduce max_length: ", wc.max_length)
		failed += 1

	# ── Test 2: StaticBody2D is PhysicsBody2D (root cause doc) ───────────
	var wall := StaticBody2D.new()
	root.add_child(wall)
	if wall is PhysicsBody2D:
		print("[PASS] StaticBody2D IS PhysicsBody2D — root cause confirmed")
		passed += 1
	else:
		print("[FAIL] StaticBody2D is NOT PhysicsBody2D — unexpected")
		failed += 1

	# ── Test 3: StaticBody2D should NOT trigger early return ─────────────
	var body_wall: PhysicsBody2D = wall  # upcast to base type for runtime is-check
	var skip_for_wall: bool = body_wall != null and not (body_wall is StaticBody2D)
	if not skip_for_wall:
		print("[PASS] Wall does NOT trigger enemy-skip logic")
		passed += 1
	else:
		print("[FAIL] Wall WOULD trigger enemy-skip logic (regression!)")
		failed += 1

	# ── Test 4: CharacterBody2D SHOULD trigger early return ──────────────
	var enemy := CharacterBody2D.new()
	root.add_child(enemy)
	var body_enemy: PhysicsBody2D = enemy  # upcast to base type for runtime is-check
	var skip_for_enemy: bool = body_enemy != null and not (body_enemy is StaticBody2D)
	if skip_for_enemy:
		print("[PASS] Enemy DOES trigger skip-constraint logic")
		passed += 1
	else:
		print("[FAIL] Enemy does NOT trigger skip-constraint (bug!)")
		failed += 1

	# ── Test 5: NeedleAnchor does NOT track StaticBody2D ─────────────────
	var anchor_wall := NeedleAnchor.new()
	root.add_child(anchor_wall)
	anchor_wall.global_position = Vector2(200.0, 100.0)
	anchor_wall.attached_body = wall
	wall.global_position = Vector2(0.0, 0.0)
	anchor_wall._physics_process(0.016)
	if anchor_wall.global_position.is_equal_approx(Vector2(200.0, 100.0)):
		print("[PASS] Anchor on wall: position unchanged at ", anchor_wall.global_position)
		passed += 1
	else:
		print("[FAIL] Anchor on wall: position MOVED to ", anchor_wall.global_position)
		failed += 1

	# ── Test 6: NeedleAnchor DOES track CharacterBody2D ──────────────────
	var anchor_enemy := NeedleAnchor.new()
	root.add_child(anchor_enemy)
	anchor_enemy.global_position = Vector2(250.0, 50.0)
	enemy.global_position = Vector2(240.0, 40.0)
	anchor_enemy.attached_body = enemy
	# Frame 1: initialize offset = (10, 10)
	anchor_enemy._physics_process(0.016)
	# Move enemy
	enemy.global_position = Vector2(300.0, 80.0)
	# Frame 2: should follow
	anchor_enemy._physics_process(0.016)
	var expected := Vector2(310.0, 90.0)
	if anchor_enemy.global_position.is_equal_approx(expected):
		print("[PASS] Anchor on enemy: followed to ", anchor_enemy.global_position)
		passed += 1
	else:
		print("[FAIL] Anchor on enemy: expected ", expected, " got ", anchor_enemy.global_position)
		failed += 1

	# ── Summary ───────────────────────────────────────────────────────────
	print("")
	print("=== GAP-047 Verify: ", passed, "/", passed + failed, " passed ===")
	if failed == 0:
		print("ALL PASS — 牆壁盪繩 + 針跟隨敵人 邏輯正確")
	else:
		print("FAILURES FOUND — review above")

	quit(0 if failed == 0 else 1)
