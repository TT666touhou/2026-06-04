extends Node
## GameWorld — 主遊戲場景控制器
## 負責：
##   1. 偵測啟動參數（--local-server / --local-client）
##   2. 自動建立 ENet 連線（本地多人）
##   3. 玩家生成與顏色分配
##   4. 連接 NetworkManager 事件

const PORT := 8910
const HOST := "127.0.0.1"

## 本地多人模式的輸入前綴（依玩家index分配）
## 對應 Project Settings > Input Map 中的 p1_/p2_/p3_/p4_ 動作
const INPUT_PREFIXES := ["", "p1_", "p2_", "p3_", "p4_"]

## 玩家場景路徑（由 MultiplayerSpawner 管理）
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

## 玩家子彈場景（注入到玩家的 bullet_scene 屬性）
const BULLET_SCENE := preload("res://scenes/player/player_bullet.tscn")

@onready var _spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var _players_root: Node2D = $Players
# _camera 由 MultiplayerCamera 場景節點自行 make_current()
# 此處不需持有參照

var _local_player_index: int = 1  ## 本機玩家編號（1=Server, 2-4=Client）

## Rogue-lite 房間生成器
@onready var _dungeon: DungeonGenerator = $DungeonGenerator

## 目前房間容器（存放當前已載入的房間場景）
var _current_room_node: Node = null

# ═══════════════════════════════════════════════════════════════
# 啟動流程
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	# 解析命令列參數
	var args := OS.get_cmdline_user_args()
	var is_server := "--local-server" in args
	var is_client := "--local-client" in args
	
	# 取得玩家 index（Client 傳入）
	var idx_pos := args.find("--player-index")
	if idx_pos >= 0 and idx_pos + 1 < args.size():
		_local_player_index = args[idx_pos + 1].to_int()
	elif is_server:
		_local_player_index = 1
	
	# 連接 NetworkManager 信號
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.player_connected.connect(_on_player_connected)
		nm.player_disconnected.connect(_on_player_disconnected)
	
	# 設定 MultiplayerSpawner
	if _spawner:
		_spawner.spawn_path = NodePath("../Players")  # 相對於 spawner 的路徑
	
	# 啟動連線
	if is_server:
		print("[GameWorld] 啟動為 Server（Player 1）")
		_start_as_server()
	elif is_client:
		print("[GameWorld] 啟動為 Client（Player %d）" % _local_player_index)
		_start_as_client()
	else:
		# 編輯器直接執行（單機測試）
		print("[GameWorld] 單機測試模式")
		_start_solo()

func _start_as_server() -> void:
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm:
		var err: int = nm.host_game()
		if err == OK:
			print("[GameWorld] Server 啟動成功，等待玩家連線...")
			_spawn_player(multiplayer.get_unique_id(), 0)
		else:
			push_error("[GameWorld] Server 啟動失敗：%d" % err)
	multiplayer.peer_connected.connect(_on_peer_connected_server)

func _start_as_client() -> void:
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm:
		var err: int = nm.join_game(HOST)
		if err != OK:
			push_error("[GameWorld] Client 連線失敗：%d" % err)

func _start_solo() -> void:
	## 單機測試：直接生成1個玩家，不需要網路
	var player := PLAYER_SCENE.instantiate()
	player.name = "SoloPlayer"
	player.player_prefix = ""  # 使用預設輸入
	player.bullet_scene = BULLET_SCENE  ## 注入子彈場景
	_players_root.add_child(player)
	player.global_position = Vector2(100, -50)
	player.apply_player_color(0)
	print("[GameWorld] 單機玩家生成完成")

	## 啟動 Rogue-lite 生成
	if _dungeon:
		_dungeon.generate_run()
		var first_room := _dungeon.advance_room()
		if not first_room.is_empty():
			_load_room_scene(first_room)
			print("[GameWorld] 載入第一間房")
	else:
		push_warning("[GameWorld] DungeonGenerator 節點不存在，跳過房間生成")

# ═══════════════════════════════════════════════════════════════
# 玩家生成（Server 端）
# ═══════════════════════════════════════════════════════════════

## Server 端：新 peer 連線時生成其玩家
func _on_peer_connected_server(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	## 計算 skin_index（根據目前玩家數）
	var nm := get_node_or_null("/root/NetworkManager")
	var skin_idx := 0
	if nm and nm.get("connected_players") != null:
		skin_idx = nm.connected_players.size() - 1
	
	print("[GameWorld] 新玩家連線：peer_id=%d, skin=%d" % [peer_id, skin_idx])
	_spawn_player.rpc(peer_id, skin_idx)

@rpc("authority", "call_local", "reliable")
func _spawn_player(peer_id: int, skin_index: int) -> void:
	## 此函式在所有端執行（call_local），Server 和 Client 各自建立玩家節點
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)  ## 關鍵：name 必須是 peer_id 字串
	
	## 分配輸入前綴（只有本機玩家才有意義）
	if not multiplayer.has_multiplayer_peer() or peer_id == multiplayer.get_unique_id():
		player.player_prefix = INPUT_PREFIXES[_local_player_index] if _local_player_index < INPUT_PREFIXES.size() else ""
	
	_players_root.add_child(player)
	player.global_position = Vector2(80 + skin_index * 40, -50)  ## 分散生成位置
	player.apply_player_color(skin_index)
	
	print("[GameWorld] 玩家節點已建立：name=%s, skin=%d, auth=%s" % [
		player.name, skin_index, str(player.is_multiplayer_authority())
	])

# ═══════════════════════════════════════════════════════════════
# 信號處理
# ═══════════════════════════════════════════════════════════════
func _on_player_connected(peer_id: int, _player_info: Dictionary) -> void:
	print("[GameWorld] NetworkManager: player_connected peer_id=%d" % peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	print("[GameWorld] NetworkManager: player_disconnected peer_id=%d" % peer_id)
	## 移除對應的玩家節點
	var player_node := _players_root.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
		print("[GameWorld] 玩家節點已移除：%d" % peer_id)

# ═══════════════════════════════════════════════════════════════
# Rogue-lite 房間控制
# ═══════════════════════════════════════════════════════════════

## 進入下一間房間（由 RoomTransition 節點觸發，或直接呼叫）
func load_next_room() -> void:
	if not _dungeon:
		push_warning("[GameWorld] load_next_room: DungeonGenerator 不存在")
		return

	var next_path := _dungeon.advance_room()
	if next_path.is_empty():
		## Run 完成，回到主選單或顯示結算畫面
		print("[GameWorld] 所有房間已通過！Run 完成")
		## TODO Phase 3.3: 顯示結算畫面
		return

	_load_room_scene(next_path)

## 實際載入房間場景（加入為子節點而非切換主場景）
func _load_room_scene(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("[GameWorld] 房間場景不存在：" + scene_path)
		return

	## 移除舊房間
	if _current_room_node:
		_current_room_node.queue_free()
		_current_room_node = null

	## 載入新房間
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("[GameWorld] 無法載入場景：" + scene_path)
		return

	_current_room_node = scene.instantiate()
	## 將房間加入場景樹，放在 Players 之前（確保房間層在下方）
	add_child(_current_room_node)
	move_child(_current_room_node, 0)

	## 套用房間難度
	if _dungeon:
		var room_def := _dungeon.get_current_room()
		if room_def:
			_apply_room_difficulty(room_def.difficulty_bonus)

	print("[GameWorld] 房間已載入：", scene_path)

## 套用房間難度（影響敵人數量）
func _apply_room_difficulty(bonus: int) -> void:
	if not _current_room_node:
		return
	## 啟用房間內被禁用的敵人（spawn_disabled 設為 false）
	var enemies := get_tree().get_nodes_in_group("Enemies")
	var enabled_count := 0
	for enemy: Node in enemies:
		if enabled_count < (5 + bonus * 2):  ## 基礎 5 隻 + 難度倍增
			if enemy.has_method("enable_enemy"):
				enemy.call_deferred("enable_enemy")
			enabled_count += 1
		else:
			break
	print("[GameWorld] 難度加成 %d  啟用敵人：%d 隻" % [bonus, enabled_count])

## Debug 資訊（供 DebugBridge 讀取）
func get_dungeon_debug_info() -> Dictionary:
	if not _dungeon:
		return {"status": "no_dungeon"}
	return _dungeon.get_debug_info()
