extends Area2D
class_name RoomTransition
## 房間過渡觸發器
## 當所有玩家都進入此區域時，呼叫 GameWorld.load_next_room()

@export var target_room_path: String = ""  ## 保留相容性，現在由 DungeonGenerator 決定目標

var _players_in_zone: Array[Node2D] = []

func _ready() -> void:
	## 確保只監聽 Layer 2 (Player)
	collision_mask = 2
	collision_layer = 0

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	## 確認是玩家（有 take_damage 方法）
	if not body.has_method("take_damage"):
		return
	if not body in _players_in_zone:
		_players_in_zone.append(body)
		_check_transition()

func _on_body_exited(body: Node2D) -> void:
	if body in _players_in_zone:
		_players_in_zone.erase(body)

func _check_transition() -> void:
	## 單機模式下直接處理，連線模式下由 Server 處理
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	## 取得已連線的玩家數量
	var network_manager := get_node_or_null("/root/NetworkManager")
	var connected_players := 1
	if network_manager != null and network_manager.get("connected_players") != null:
		connected_players = network_manager.connected_players.size()

	## 所有玩家都必須在區域內
	if _players_in_zone.size() >= connected_players:
		_trigger_transition()

func _trigger_transition() -> void:
	## 優先使用 GameWorld.load_next_room()（Rogue-lite 模式）
	var game_world := get_node_or_null("/root/GameWorld")
	if game_world == null:
		## 嘗試從場景樹根找 GameWorld
		game_world = get_tree().get_root().get_node_or_null("GameWorld")

	if game_world and game_world.has_method("load_next_room"):
		if multiplayer.has_multiplayer_peer():
			_trigger_rpc.rpc()
		else:
			game_world.load_next_room()
		return

	## 降級：使用舊的 target_room_path 邏輯
	if target_room_path.is_empty():
		push_warning("RoomTransition: target_room_path 為空且無 GameWorld，無法轉場")
		return

	if multiplayer.has_multiplayer_peer():
		_load_room.rpc(target_room_path)
	else:
		_load_room(target_room_path)

@rpc("authority", "call_local", "reliable")
func _trigger_rpc() -> void:
	## 所有端呼叫 GameWorld.load_next_room()
	var gw := get_tree().get_root().get_node_or_null("GameWorld")
	if gw and gw.has_method("load_next_room"):
		gw.load_next_room()

@rpc("authority", "call_local", "reliable")
func _load_room(path: String) -> void:
	get_tree().change_scene_to_file(path)
