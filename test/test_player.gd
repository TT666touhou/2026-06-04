extends "res://addons/gut/test.gd"
## test_player.gd — 玩家腳本 GUT 測試
## 驗證：皮膚系統、顏色系統、群組、Multiplayer authority

var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
var player_inst: Node = null

func before_each() -> void:
	player_inst = player_scene.instantiate()
	player_inst.name = "1"
	# 離線模式：不建立 ENet peer，直接設定 authority（node name = "1"）

func after_each() -> void:
	if player_inst and is_instance_valid(player_inst):
		if player_inst.is_inside_tree():
			player_inst.queue_free()
		else:
			player_inst.free()
	player_inst = null

func test_player_in_players_group() -> void:
	## 玩家必須在 Players group，否則 DebugBridge 無法感知
	add_child_autofree(player_inst)
	await get_tree().process_frame
	assert_true(
		player_inst.is_in_group("Players"),
		"Player 必須加入 'Players' group（供 DebugBridge 追蹤）"
	)

func test_player_has_health_properties() -> void:
	## DebugBridge 需要讀取 current_health / max_health
	add_child_autofree(player_inst)
	await get_tree().process_frame
	assert_not_null(player_inst.get("current_health"), "Player 必須有 current_health 屬性")
	assert_not_null(player_inst.get("max_health"), "Player 必須有 max_health 屬性")

func test_set_skin() -> void:
	## 皮膚系統：set_skin 正確設定 _skin_index
	add_child_autofree(player_inst)
	await get_tree().process_frame
	player_inst.set_skin(2)
	assert_eq(player_inst._skin_index, 2, "set_skin(2) 應讓 _skin_index = 2")

func test_apply_player_color_p1() -> void:
	## 顏色系統：P1 = 暖橙色
	add_child_autofree(player_inst)
	await get_tree().process_frame
	player_inst.apply_player_color(0)
	var vp: Node2D = player_inst.get_node_or_null("VisualPivot")
	assert_not_null(vp, "Player 必須有 VisualPivot 節點")
	if vp:
		var expected_color := Color("#FF8C42")
		assert_almost_eq(vp.modulate.r, expected_color.r, 0.01, "P1 應為暖橙色 R")
		assert_almost_eq(vp.modulate.g, expected_color.g, 0.01, "P1 應為暖橙色 G")
		assert_almost_eq(vp.modulate.b, expected_color.b, 0.01, "P1 應為暖橙色 B")

func test_player_prefix_default() -> void:
	## 預設 player_prefix 為空字串（單機模式）
	assert_eq(player_inst.player_prefix, "", "預設 player_prefix 應為 \"\"")

func test_no_camera_in_player() -> void:
	## 多人相機由 MultiplayerCamera 管理，player 不應建立 Camera2D
	## (在離線/無 peer 模式下，player 內也不應有 Camera)
	add_child_autofree(player_inst)
	await get_tree().process_frame
	# 離線模式下 _is_authority() = true，但現在設計上 player 不建立 camera
	var has_cam := false
	for child in player_inst.get_children():
		if child is Camera2D:
			has_cam = true
			break
	# 注意：目前設計 player 不在 _ready 建立 camera
	# 如果未來設計改變，這個測試需要同步更新
	assert_false(has_cam, "Player 不應在 _ready 建立 Camera2D（由 MultiplayerCamera 負責）")
