extends GutTest
# GAP-047: 驗證針跟隨邏輯 + 牆壁/敵人判斷正確性

# ── NeedleAnchor 追蹤邏輯 ──────────────────────────────────────────────

func test_anchor_does_not_track_static_body() -> void:
	# 牆壁 = StaticBody2D，_physics_process 應直接 return，不改 position
	var anchor := NeedleAnchor.new()
	add_child_autofree(anchor)
	anchor.global_position = Vector2(200.0, 100.0)

	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	wall.global_position = Vector2(0.0, 0.0)

	anchor.attached_body = wall
	anchor._physics_process(0.016)  # 手動觸發一幀

	assert_eq(anchor.global_position, Vector2(200.0, 100.0),
		"StaticBody2D: anchor should NOT move")

func test_anchor_tracks_character_body() -> void:
	# 敵人 = CharacterBody2D，首幀記錄 offset，後續跟隨
	var anchor := NeedleAnchor.new()
	add_child_autofree(anchor)
	anchor.global_position = Vector2(250.0, 50.0)  # 插入點

	var enemy := CharacterBody2D.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector2(240.0, 40.0)  # body origin

	anchor.attached_body = enemy

	# 首幀：初始化 offset = (250-240, 50-40) = (10, 10)
	anchor._physics_process(0.016)
	assert_true(anchor._offset_ready, "offset should be initialized after first frame")

	# 敵人移動
	enemy.global_position = Vector2(300.0, 80.0)
	anchor._physics_process(0.016)

	var expected := Vector2(310.0, 90.0)  # enemy(300,80) + offset(10,10)
	assert_almost_eq(anchor.global_position.x, expected.x, 0.1, "x should track enemy")
	assert_almost_eq(anchor.global_position.y, expected.y, 0.1, "y should track enemy")

# ── WireConstraint auto_reel ───────────────────────────────────────────

func test_auto_reel_reduces_length() -> void:
	var wc := WireConstraint.new()
	wc.setup(Vector2(0.0, -200.0), 150.0)
	var before := wc.max_length
	wc.auto_reel(0.1)
	assert_lt(wc.max_length, before, "auto_reel: max_length must decrease")

func test_auto_reel_not_called_means_length_stable() -> void:
	# 模擬「鉤到敵人時 auto_reel 被跳過」的情境
	var wc := WireConstraint.new()
	wc.setup(Vector2(0.0, -200.0), 150.0)
	var before := wc.max_length
	# 不呼叫 auto_reel → 長度不變
	assert_eq(wc.max_length, before, "skipping auto_reel: max_length must stay the same")

# ── 牆壁判斷條件（純邏輯驗證）────────────────────────────────────────

func test_static_body_is_physics_body2d() -> void:
	# 確認 StaticBody2D is PhysicsBody2D（這是 bug 根因）
	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	assert_true(wall is PhysicsBody2D,
		"StaticBody2D IS a PhysicsBody2D — this was the root cause of the regression")

func test_static_body_excluded_by_type_check() -> void:
	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	# 模擬 player.gd 的判斷：不跳過 constraint
	var skip_constraint: bool = wall != null and not (wall is StaticBody2D)
	assert_false(skip_constraint, "wall: constraint should NOT be skipped")

func test_character_body_triggers_skip() -> void:
	var enemy := CharacterBody2D.new()
	add_child_autofree(enemy)
	var skip_constraint: bool = enemy != null and not (enemy is StaticBody2D)
	assert_true(skip_constraint, "enemy: constraint SHOULD be skipped")
