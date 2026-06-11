extends Node2D

@onready var world_layer: TileMapLayer = $WorldLayer
@onready var camera: Camera2D = $MultiplayerCamera
@onready var spawns_node: Node2D = $PlayerSpawns

# 100% Hollow Knight Style Map - solid boundaries everywhere.
# # = Solid Ground (mrmotext)
# . = Empty
# S = Player Spawn
# E = Enemy/Boss Spawn
const ASCII_MAP = [
	"########################################",
	"########################################",
	"##....................................##",
	"##....................................##",
	"##.........#####......................##",
	"##....................................##",
	"##....S...................####........##",
	"##..######............................##",
	"##...................######......E....##",
	"##.......#######......................##",
	"##...........................###......##",
	"##....................................##",
	"########################################",
	"########################################"
]

const TILE_SIZE = 8

func _ready():
	_generate_map_and_bounds()
	
	if multiplayer.is_server():
		# Spawn host immediately
		_spawn_player(multiplayer.get_unique_id(), 0)
		
		# Spawn connected clients
		for id in NetworkManager.connected_players.keys():
			if id != multiplayer.get_unique_id():
				_spawn_player(id, NetworkManager.connected_players[id].skin_index)
				
		# Listen for future players
		NetworkManager.player_connected.connect(_on_player_joined)

func _generate_map_and_bounds():
	var spawn_points = []
	var boss_scene = preload("res://scenes/enemy/boss.tscn")
	
	for y in range(ASCII_MAP.size()):
		var row = ASCII_MAP[y]
		for x in range(row.length()):
			var c = row[x]
			if c == '#':
				world_layer.set_cell(Vector2i(x, y), 0, Vector2i(14, 0))
			elif c == 'S':
				var p = Marker2D.new()
				p.position = Vector2(x * TILE_SIZE + TILE_SIZE/2.0, y * TILE_SIZE)
				spawns_node.add_child(p)
				spawn_points.append(p)
			elif c == 'E':
				if boss_scene:
					var b = boss_scene.instantiate()
					b.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
					add_child(b)
				
	# Calculate dynamic camera bounds based on map size
	var used_rect = world_layer.get_used_rect()
	if camera:
		camera.limit_left = used_rect.position.x * TILE_SIZE
		camera.limit_right = used_rect.end.x * TILE_SIZE
		camera.limit_top = used_rect.position.y * TILE_SIZE
		camera.limit_bottom = used_rect.end.y * TILE_SIZE

func _spawn_player(id: int, skin_idx: int):
	# Assign spawn points based on player index or randomly
	var spawns = spawns_node.get_children()
	var spawn_pos = Vector2.ZERO
	if spawns.size() > 0:
		spawn_pos = spawns[id % spawns.size()].position
		
	var player_scene_path = "res://scenes/player/player" + str((skin_idx % 4) + 1) + ".tscn"
	var p_scene = load(player_scene_path)
	if p_scene:
		var p_inst = p_scene.instantiate()
		p_inst.name = str(id)
		p_inst.global_position = spawn_pos
		$Players.add_child(p_inst)

func _on_player_joined(id: int, info: Dictionary):
	if multiplayer.is_server():
		_spawn_player(id, info.skin_index)
