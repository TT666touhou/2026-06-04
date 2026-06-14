extends Node

const PORT: int = 8910
const MAX_CLIENTS: int = 4

var peer: ENetMultiplayerPeer
var connected_players: Dictionary = {} # format: { peer_id: {} }

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

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
	connected_players[multiplayer.get_unique_id()] = {}
	player_connected.emit(multiplayer.get_unique_id(), connected_players[multiplayer.get_unique_id()])
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

func _on_player_connected(_id):
	# Triggered when a peer connects. We will wait for them to register themselves via RPC.
	pass

func _on_player_disconnected(id):
	connected_players.erase(id)
	player_disconnected.emit(id)

func _on_connected_ok():
	# Connected to server successfully. Register self to all peers.
	var _peer_id = multiplayer.get_unique_id()
	rpc("register_player", {})

func _on_connected_fail():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	connected_players.clear()
	server_disconnected.emit()

@rpc("any_peer", "call_local", "reliable")
func register_player(player_info: Dictionary):
	var new_player_id = multiplayer.get_remote_sender_id()
	connected_players[new_player_id] = player_info
	player_connected.emit(new_player_id, player_info)
