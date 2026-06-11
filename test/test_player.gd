extends GutTest

var player_scene = preload("res://scenes/player/player.tscn")
var player_inst = null

func before_each():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(8911)
	multiplayer.multiplayer_peer = peer
	
	player_inst = player_scene.instantiate()
	player_inst.name = "1" # Host ID is usually 1
	player_inst.set_multiplayer_authority(1)

func after_each():
	multiplayer.multiplayer_peer = null

func test_camera_authority():
	# If we are authority
	add_child_autofree(player_inst)
	# Wait one frame for _ready to trigger camera creation
	await get_tree().process_frame
	
	var has_cam = false
	for child in player_inst.get_children():
		if child is Camera2D:
			has_cam = true
			break
	assert_true(has_cam, "Authority should spawn Camera2D")
	
	# Create client player
	var client_player = player_scene.instantiate()
	client_player.set_multiplayer_authority(2) # not us
	add_child_autofree(client_player)
	await get_tree().process_frame
	
	has_cam = false
	for child in client_player.get_children():
		if child is Camera2D:
			has_cam = true
			break
	assert_false(has_cam, "Client should NOT spawn Camera2D")

func test_visual_setup():
	add_child_autofree(player_inst)
	await get_tree().process_frame
	
	player_inst.set_skin(2) # Player 3
	assert_eq(player_inst._skin_index, 2, "Skin index should be tracked")
	
	# Verify TileMapLayer has correct source ID and coords
	var appearance: TileMapLayer = player_inst.appearance
	var cell_coords = appearance.get_cell_atlas_coords(Vector2i(0, 0))
	assert_eq(cell_coords, Vector2i(28 + 2, 0), "Atlas coords should match player 3 index")
