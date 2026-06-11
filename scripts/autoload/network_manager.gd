extends Node

const PORT: int = 8910
const MAX_CLIENTS: int = 4

var peer: ENetMultiplayerPeer
var connected_players: Dictionary = {} # format: { peer_id: { "skin_index": 0 } }

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected
signal players_changed

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		printerr("Cannot host: ", error)
		return error
	multiplayer.multiplayer_peer = peer
	
	# Register host locally
	connected_players[multiplayer.get_unique_id()] = {"skin_index": 0}
	player_connected.emit(multiplayer.get_unique_id(), connected_players[multiplayer.get_unique_id()])
	players_changed.emit()
	return OK

func join_game(address: String):
	if address.is_empty():
		address = "127.0.0.1"
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error != OK:
		printerr("Cannot join: ", error)
		return error
	multiplayer.multiplayer_peer = peer
	return OK

func disconnect_game():
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	connected_players.clear()
	players_changed.emit()

func get_player_ids() -> Array:
	return connected_players.keys()

func _on_player_connected(_id):
	pass

func _on_player_disconnected(id):
	connected_players.erase(id)
	player_disconnected.emit(id)
	players_changed.emit()

func _on_connected_ok():
	var _peer_id = multiplayer.get_unique_id()
	rpc("register_player", {"skin_index": connected_players.size()})

func _on_connected_fail():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	connected_players.clear()
	server_disconnected.emit()
	players_changed.emit()

@rpc("any_peer", "call_local", "reliable")
func register_player(player_info: Dictionary):
	var new_player_id = multiplayer.get_remote_sender_id()
	connected_players[new_player_id] = player_info
	player_connected.emit(new_player_id, player_info)
	players_changed.emit()

	# If server, broadcast all known players to the new player
	if multiplayer.is_server():
		for id in connected_players:
			if id != new_player_id:
				rpc_id(new_player_id, "register_player_from_server", id, connected_players[id])

@rpc("authority", "call_remote", "reliable")
func register_player_from_server(id: int, player_info: Dictionary):
	connected_players[id] = player_info
	player_connected.emit(id, player_info)
	players_changed.emit()

@rpc("authority", "call_local", "reliable")
func start_game():
	get_tree().change_scene_to_file("res://scenes/test_level.tscn")

# ── 遊戲狀態追蹤 ──────────────────────────────────────────────────
var alive_players: Dictionary = {}

func reset_alive_players():
	alive_players = connected_players.duplicate()

@rpc("any_peer", "call_local", "reliable")
func notify_player_died(dead_peer_id: int):
	alive_players.erase(dead_peer_id)
	if alive_players.size() == 0:
		if multiplayer.is_server():
			rpc("show_game_over")

@rpc("authority", "call_local", "reliable")
func show_game_over():
	print("[NetworkManager] All players died. GAME OVER.")
	var go_scene = load("res://scenes/ui/game_over.tscn")
	if go_scene:
		var go_instance = go_scene.instantiate()
		get_tree().root.add_child(go_instance)
