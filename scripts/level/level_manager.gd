extends Node2D

const PLAYER_SCENES = [
	preload("res://scenes/player/player1.tscn"),
	preload("res://scenes/player/player2.tscn"),
	preload("res://scenes/player/player3.tscn"),
	preload("res://scenes/player/player4.tscn")
]

func _ready():
	if multiplayer.is_server():
		_spawn_players()
		
func _spawn_players():
	var spawn_pos = Vector2(0, -64)
	var connected_players = NetworkManager.connected_players
	var i = 0
	
	# If no players connected (e.g. testing directly from editor), just spawn P1
	if connected_players.is_empty():
		_spawn_player(1, 1, spawn_pos)
		return
		
	for peer_id in connected_players:
		# Use index 0 to 3 for the scene selection
		var player_index = i % 4
		_spawn_player(peer_id, player_index + 1, spawn_pos + Vector2(i * 24, 0))
		i += 1

func _spawn_player(peer_id: int, player_num: int, pos: Vector2):
	var player_scene = PLAYER_SCENES[player_num - 1]
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.position = pos
	player.set_multiplayer_authority(peer_id)
	add_child(player)
