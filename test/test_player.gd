extends "res://addons/gut/test.gd"
## test_player.gd — Player 單元測試
## 測試玩家生成、顏色、皮膚、輸入前綴設定

var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
var player_inst: Node = null

func before_each() -> void:
	player_inst = player_scene.instantiate()
	player_inst.name = "TestPlayer"

func after_each() -> void:
	if is_instance_valid(player_inst) and player_inst.is_inside_tree():
		player_inst.queue_free()
	elif is_instance_valid(player_inst):
		player_inst.free()
	player_inst = null

# ─────────────────────────────────────────────────────────────
# 基本生成測試
# ─────────────────────────────────────────────────────────────
func test_player_instantiates() -> void:
	assert_not_null(player_inst, "Player scene should instantiate successfully")

func test_player_has_correct_groups() -> void:
	add_child_autofree(player_inst)
	await get_tree().process_frame
	assert_true(player_inst.is_in_group("Players"), "Player should be in 'Players' group")

# ─────────────────────────────────────────────────────────────
# 皮膚與顏色
# ─────────────────────────────────────────────────────────────
func test_set_skin_updates_index() -> void:
	add_child_autofree(player_inst)
	await get_tree().process_frame
	player_inst.set_skin(2)
	assert_eq(player_inst._skin_index, 2, "Skin index should be tracked as 2")

func test_set_skin_updates_tilemap() -> void:
	add_child_autofree(player_inst)
	await get_tree().process_frame
	player_inst.set_skin(2)
	var appearance: TileMapLayer = player_inst.get_node_or_null("VisualPivot/Appearance")
	assert_not_null(appearance, "Appearance TileMapLayer should exist")
	var cell_coords: Vector2i = appearance.get_cell_atlas_coords(Vector2i(0, 0))
	assert_eq(cell_coords, Vector2i(28 + 2, 0), "Atlas coords should match skin index 2")

func test_apply_player_color_changes_modulate() -> void:
	add_child_autofree(player_inst)
	await get_tree().process_frame
	player_inst.apply_player_color(0)
	var visual: Node = player_inst.get_node_or_null("VisualPivot")
	assert_not_null(visual, "VisualPivot should exist")
	# P1 橙色
	var expected_color: Color = Color("#FF8C42")
	assert_almost_eq(visual.modulate.r, expected_color.r, 0.01, "P1 color R should match orange")

# ─────────────────────────────────────────────────────────────
# 輸入前綴
# ─────────────────────────────────────────────────────────────
func test_player_prefix_default_is_empty() -> void:
	add_child_autofree(player_inst)
	await get_tree().process_frame
	assert_eq(player_inst.player_prefix, "", "Default player prefix should be empty string")

func test_player_prefix_can_be_set() -> void:
	player_inst.player_prefix = "p2_"
	add_child_autofree(player_inst)
	await get_tree().process_frame
	assert_eq(player_inst.player_prefix, "p2_", "Player prefix should be settable")

# ─────────────────────────────────────────────────────────────
# 無 Camera2D（移除個人相機，改用多人相機）
# ─────────────────────────────────────────────────────────────
func test_no_individual_camera_in_offline_mode() -> void:
	## 離線模式下 player 不應有個人 Camera2D
	## 因為 MultiplayerCamera 在主場景統一處理
	add_child_autofree(player_inst)
	await get_tree().process_frame
	
	var has_cam: bool = false
	for child: Node in player_inst.get_children():
		if child is Camera2D:
			has_cam = true
			break
	assert_false(has_cam, "Player should NOT have individual Camera2D — MultiplayerCamera handles this")

# ─────────────────────────────────────────────────────────────
# 體力與受傷
# ─────────────────────────────────────────────────────────────
func test_player_has_stamina() -> void:
	add_child_autofree(player_inst)
	await get_tree().process_frame
	assert_true(player_inst.get("_stamina") != null, "Player should have _stamina variable")
	assert_true(player_inst._stamina > 0.0, "Stamina should be positive on spawn")
