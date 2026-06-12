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

@onready var _spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var _players_root: Node2D = $Players
## MultiplayerCamera 由場景節點持有，此處不需要對應的 onready

var _local_player_index: int = 1  ## 本機玩家編號（1=Server, 2-4=Client）

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
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		var err: Error = nm.host_game()
		if err == OK:
			print("[GameWorld] Server 啟動成功，等待玩家連線...")
			# Server 自己也是玩家1，立即生成
			_spawn_player(multiplayer.get_unique_id(), 0)
		else:
			push_error("[GameWorld] Server 啟動失敗：%d" % err)
	
	multiplayer.peer_connected.connect(_on_peer_connected_server)

func _start_as_client() -> void:
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		var err: Error = nm.join_game(HOST)
		if err != OK:
			push_error("[GameWorld] Client 連線失敗：%d" % err)

func _start_solo() -> void:
	## 單機測試：直接生成1個玩家，不需要網路
	var player := PLAYER_SCENE.instantiate()
	player.name = "SoloPlayer"
	player.player_prefix = ""  # 使用預設輸入
	_players_root.add_child(player)
	player.global_position = Vector2(100, -50)
	player.apply_player_color(0)
	print("[GameWorld] 單機玩家生成完成")

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
