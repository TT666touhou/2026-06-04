extends Node2D

const PLAYER_SCENES = [
	preload("res://scenes/player/player1.tscn"),
	preload("res://scenes/player/player2.tscn"),
	preload("res://scenes/player/player3.tscn"),
	preload("res://scenes/player/player4.tscn")
]

func _ready():
	var players_node = Node2D.new()
	players_node.name = "Players"
	add_child(players_node)

	var spawner = MultiplayerSpawner.new()
	spawner.name = "PlayerSpawner"
	spawner.spawn_path = NodePath("../Players")
	for s in PLAYER_SCENES:
		spawner.add_spawnable_scene(s.resource_path)
	add_child(spawner)

	if multiplayer.is_server():
		_spawn_players()

func _spawn_players():
	var spawn_pos = Vector2(0, -64)
	var players = NetworkManager.connected_players
	var i = 0
	
	if players.is_empty():
		_spawn_player(1, 1, spawn_pos)
		NetworkManager.alive_players[1] = true
		return
		
	for peer_id in players:
		var p_idx = i % 4
		_spawn_player(peer_id, p_idx + 1, spawn_pos + Vector2(i * 24, 0))
		NetworkManager.alive_players[peer_id] = true
		i += 1

func _spawn_player(peer_id: int, p_num: int, pos: Vector2):
	var p = PLAYER_SCENES[p_num - 1].instantiate()
	p.name = str(peer_id)
	p.position = pos
	p.set_multiplayer_authority(peer_id)
	$Players.add_child(p, true)

func _physics_process(delta):
	# Update Camera to follow furthest player (handled by SceneCamera separately if it can track group "Players")
	pass
