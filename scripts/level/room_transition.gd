extends Area2D
class_name RoomTransition

@export var target_room_path: String = ""

var _players_in_zone: Array[Node2D] = []

func _ready() -> void:
	# 確保只監聽 layer 2 (Player)
	collision_mask = 2
	collision_layer = 0
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("take_damage"): # 確認是玩家
		return
	if not body in _players_in_zone:
		_players_in_zone.append(body)
		_check_transition()

func _on_body_exited(body: Node2D) -> void:
	if body in _players_in_zone:
		_players_in_zone.erase(body)

func _check_transition() -> void:
	# 單機模式下直接處理，連線模式下由 Server 處理
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
		
	var network_manager = get_node_or_null("/root/NetworkManager")
	var connected_players = 1
	if network_manager != null and network_manager.connected_players.size() > 0:
		connected_players = network_manager.connected_players.size()
		
	# 所有註冊玩家都必須在區域內
	if _players_in_zone.size() >= connected_players:
		_trigger_transition()

func _trigger_transition() -> void:
	if target_room_path.is_empty():
		push_error("RoomTransition: target_room_path is empty")
		return
		
	if multiplayer.has_multiplayer_peer():
		_load_room.rpc(target_room_path)
	else:
		_load_room(target_room_path)

@rpc("authority", "call_local", "reliable")
func _load_room(path: String) -> void:
	get_tree().change_scene_to_file(path)
