extends Node2D

const PLAYER_SCENES = [
	preload("res://scenes/player/player1.tscn"),
	preload("res://scenes/player/player2.tscn"),
	preload("res://scenes/player/player3.tscn"),
	preload("res://scenes/player/player4.tscn")
]

func _ready():
	# Players and Spawner are already in the scene, so we don't recreate them.
	_generate_level()
	if multiplayer.is_server():
		_spawn_players()

func _generate_level():
	var rng = RandomNumberGenerator.new()
	rng.seed = NetworkManager.current_level_seed

	# Simple linear modular map generator
	var blocks = [
		preload("res://scenes/modular_blocks/modular_block_1.tscn"),
		preload("res://scenes/modular_blocks/modular_block_3.tscn"),
		preload("res://scenes/modular_blocks/modular_block_4.tscn")
	]
	
	# Boss zone or End zone (we'll just use block_1 with a special flag or big enemy for now)
	var end_block = preload("res://scenes/modular_blocks/modular_block_1.tscn")
	var enemy1 = preload("res://scenes/enemy/Enemy1.tscn")
	var enemy2 = preload("res://scenes/enemy/Enemy2.tscn")
	var enemy3 = preload("res://scenes/enemy/Enemy3.tscn")
	
	var current_x = 0.0
	var map_length = 8
	var block_width = 160.0 # Approximate width of a modular block
	
	# Generate linear path
	for i in range(map_length):
		var b_scene = blocks[rng.randi() % blocks.size()]
		if i == map_length - 1:
			b_scene = end_block
			
		var b = b_scene.instantiate()
		b.position = Vector2(current_x, -56)
		add_child(b)
		
		# Spawn some enemies on the blocks (skip first block for safety)
		# Spawning locally on all peers ensures they appear since there's no MultiplayerSpawner for them right now.
		# They might desync in behavior, but they'll be physically present for testing.
		if i > 0:
			var e_scene = [enemy1, enemy2, enemy3][rng.randi() % 3]
			var e = e_scene.instantiate()
			# Put enemy slightly above the block
			e.position = Vector2(current_x + block_width / 2, -100)
			# Needs a spawner for enemies if we want them synced, 
			# but for now we just add them to the scene.
			add_child(e, true)
			
			if i == map_length - 1:
				# Boss!
				var boss = enemy3.instantiate()
				boss.position = Vector2(current_x + block_width, -150)
				boss.scale = Vector2(3, 3) # Big boss
				if boss.has_method("set_max_health"):
					boss.set_max_health(50)
				add_child(boss, true)

		current_x += block_width

func _spawn_players():
	var spawn_pos = Vector2(48, -64)
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
	
	if "--bot" in OS.get_cmdline_args() or OS.has_environment("BOT_MODE"):
		p.bot_enabled = true
		
	$Players.add_child(p, true)

func _physics_process(delta):
	# Update Camera to follow furthest player (handled by SceneCamera separately if it can track group "Players")
	pass
