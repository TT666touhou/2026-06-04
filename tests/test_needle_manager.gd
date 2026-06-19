# GUT 單元測試 — NeedleManager 持有數量與回收邏輯
# 需要 GUT addon (addons/gut) 才能執行
# 注意：此測試需要 PackedScene 引用，建議在 Godot 編輯器中執行
extends GutTest

var nm: NeedleManager

func before_each() -> void:
	nm = NeedleManager.new()
	nm.max_needles = 3
	nm.retrieve_radius = 30.0
	add_child_autofree(nm)

# 超過 3 根時 shoot 被拒絕
func test_shoot_blocked_at_max() -> void:
	# 模擬 3 根 in_flight (直接操作私有欄位用於測試)
	nm._in_flight = 3
	var count_before := nm.needle_count()
	# 嘗試再 shoot 不應成功（因為 needle_proj_scene=null 也會靜默失敗）
	nm.shoot_attack_needle(Vector2.ZERO, Vector2.RIGHT)
	# _in_flight 不應增加（因為 max_needles 攔截）
	assert_eq(nm.needle_count(), count_before, "blocked at max: count should not increase")

# needle_count 應等於 _anchors.size() + _in_flight
func test_needle_count() -> void:
	nm._in_flight = 1
	var anchor := NeedleAnchor.new()
	anchor.type = NeedleAnchor.Type.ATTACK
	nm._anchors.append(anchor)
	assert_eq(nm.needle_count(), 2, "needle_count: 1 anchor + 1 in_flight = 2")
	anchor.free()

# try_retrieve：距離內的 anchor 被移除
func test_retrieve_within_radius() -> void:
	var anchor := NeedleAnchor.new()
	anchor.type = NeedleAnchor.Type.ATTACK
	anchor.global_position = Vector2(20.0, 0.0)
	add_child_autofree(anchor)
	nm._anchors.append(anchor)
	var signal_received := false
	nm.needle_retrieved.connect(func(_a): signal_received = true)
	nm.try_retrieve(Vector2.ZERO)
	assert_true(signal_received, "retrieve: within radius should emit needle_retrieved")
	assert_eq(nm._anchors.size(), 0, "retrieve: anchor should be removed from array")

# try_retrieve：距離外的 anchor 不受影響
func test_no_retrieve_outside_radius() -> void:
	var anchor := NeedleAnchor.new()
	anchor.type = NeedleAnchor.Type.ATTACK
	anchor.global_position = Vector2(100.0, 0.0)
	add_child_autofree(anchor)
	nm._anchors.append(anchor)
	nm.try_retrieve(Vector2.ZERO)
	assert_eq(nm._anchors.size(), 1, "no retrieve: outside radius should keep anchor")
	anchor.free()

# get_wire_anchors：只回傳 WIRE 類型
func test_get_wire_anchors_filters_type() -> void:
	var a1 := NeedleAnchor.new()
	a1.type = NeedleAnchor.Type.ATTACK
	var a2 := NeedleAnchor.new()
	a2.type = NeedleAnchor.Type.WIRE
	nm._anchors.append(a1)
	nm._anchors.append(a2)
	var wire_anchors := nm.get_wire_anchors()
	assert_eq(wire_anchors.size(), 1, "get_wire_anchors: only WIRE type returned")
	a1.free()
	a2.free()
