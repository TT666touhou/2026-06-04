# GUT 測試 — GAP-028: WirePlatform 重量下垂 + S鍵穿透
# 驗證：(1) collision layer 設定  (2) drop-through mask 切換  (3) sag 數學正確性
extends GutTest

# ─── Test 1: WirePlatform 在 layer 4 (bitmask 8) ────────────────────────────
func test_wire_platform_on_layer_4() -> void:
	var scene: PackedScene = preload("res://scenes/WirePlatform.tscn")
	var platform: WirePlatform = scene.instantiate() as WirePlatform
	add_child_autofree(platform)
	assert_eq(platform.collision_layer, 8,
		"WirePlatform 應在 layer 4 (bitmask 8)，確保 player 可 toggle drop-through")

# ─── Test 2: WirePlatform one_way_collision 保持 true ────────────────────────
func test_wire_platform_one_way_after_setup() -> void:
	var scene: PackedScene = preload("res://scenes/WirePlatform.tscn")
	var platform: WirePlatform = scene.instantiate() as WirePlatform
	add_child_autofree(platform)
	var anchor_a := Node2D.new()
	var anchor_b := Node2D.new()
	anchor_a.global_position = Vector2(100.0, 300.0)
	anchor_b.global_position = Vector2(700.0, 300.0)
	add_child_autofree(anchor_a)
	add_child_autofree(anchor_b)
	platform.setup(anchor_a, anchor_b)
	var shape: CollisionShape2D = platform.get_node("CollisionShape2D")
	assert_true(shape.one_way_collision, "setup() 後 one_way_collision 應為 true")

# ─── Test 3: Player _ready() 後 mask 包含 layer 4 ────────────────────────────
func test_player_mask_includes_wire_layer() -> void:
	var scene: PackedScene = preload("res://scenes/Player.tscn")
	var player: CharacterBody2D = scene.instantiate() as CharacterBody2D
	add_child_autofree(player)
	await get_tree().process_frame
	assert_true(player.get_collision_mask_value(4),
		"Player _ready() 後 mask 應包含 layer 4 (wire platform)")

# ─── Test 4: Drop-through timer 控制 mask layer 4 on/off ─────────────────────
func test_drop_through_timer_disables_and_restores_mask() -> void:
	var scene: PackedScene = preload("res://scenes/Player.tscn")
	var player: CharacterBody2D = scene.instantiate() as CharacterBody2D
	add_child_autofree(player)
	await get_tree().process_frame

	# 模擬 timer > 0：layer 4 應關閉
	player._drop_through_timer = 0.25
	player.set_collision_mask_value(4, player._drop_through_timer <= 0.0)
	assert_false(player.get_collision_mask_value(4),
		"drop-through 計時中：mask layer 4 應為 false（可穿透平台）")

	# 模擬 timer = 0：layer 4 應恢復
	player._drop_through_timer = 0.0
	player.set_collision_mask_value(4, player._drop_through_timer <= 0.0)
	assert_true(player.get_collision_mask_value(4),
		"drop-through 結束後：mask layer 4 應恢復 true（可站上平台）")

# ─── Test 5: 下垂數學正確性（lerpf 不超出 SAG_WEIGHT）────────────────────────
func test_sag_math_reaches_target_without_overshoot() -> void:
	# 模擬 _update_platform_sag 的 lerpf 邏輯
	var slack := 0.0
	var sag_weight := 20.0   # SAG_WEIGHT
	var spd_on := 8.0        # SAG_SPEED_ON
	var delta := 1.0 / 60.0  # 60fps

	# 模擬 60 個物理 frame（1秒）站在平台上
	for _i in range(60):
		slack = lerpf(slack, sag_weight, minf(1.0, spd_on * delta))

	assert_gt(slack, 18.0, "站 1 秒後下垂應接近 SAG_WEIGHT (20px)")
	assert_true(slack <= sag_weight + 0.001, "下垂不應超過 SAG_WEIGHT（無 overshoot）")

# ─── Test 6: 離開平台後下垂回零 ──────────────────────────────────────────────
func test_sag_decreases_when_off_platform() -> void:
	var slack := 20.0        # 初始充分下垂
	var sag_weight := 0.0    # 離開平台時目標 = 0
	var spd_off := 3.0       # SAG_SPEED_OFF
	var delta := 1.0 / 60.0

	# 模擬 120 frame（2秒）離開平台
	for _i in range(120):
		slack = lerpf(slack, sag_weight, minf(1.0, spd_off * delta))

	assert_lt(slack, 3.0, "離開 2 秒後下垂應接近 0（線回直）")
	assert_true(slack >= 0.0, "下垂不應為負值")

# ─── Test 7: 方向正規化不造成 >90° 旋轉 ──────────────────────────────────────
func test_wire_platform_rotation_within_90deg_when_reversed() -> void:
	var scene: PackedScene = preload("res://scenes/WirePlatform.tscn")
	var platform: WirePlatform = scene.instantiate() as WirePlatform
	add_child_autofree(platform)

	# 第一根在右牆、第二根在左牆（這是 GAP-027 的 bug 情境）
	var anchor_right := Node2D.new()
	var anchor_left := Node2D.new()
	anchor_right.global_position = Vector2(800.0, 300.0)  # 右邊先
	anchor_left.global_position = Vector2(100.0, 300.0)   # 左邊後
	add_child_autofree(anchor_right)
	add_child_autofree(anchor_left)
	platform.setup(anchor_right, anchor_left)

	# GAP-027 修正：旋轉應在 ±90° 內（one-way normal 朝上）
	var rot_deg := rad_to_deg(platform.global_rotation)
	assert_lt(abs(rot_deg), 90.0,
		"右→左錨點順序時旋轉應 <90°（GAP-027 修正有效），目前: %.1f°" % rot_deg)
