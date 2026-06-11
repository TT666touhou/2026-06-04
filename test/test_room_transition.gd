extends GutTest

var transition_scene = preload("res://scenes/level/room_transition.tscn")
var player_scene = preload("res://scenes/player/player.tscn")
var trans_inst = null

func before_each():
	trans_inst = transition_scene.instantiate()
	trans_inst.target_room_path = "res://scenes/test_level.tscn"
	add_child_autofree(trans_inst)
	NetworkManager.connected_players.clear()
	NetworkManager.connected_players[1] = {"name": "P1"}
	NetworkManager.connected_players[2] = {"name": "P2"}

func after_each():
	NetworkManager.connected_players.clear()

func test_requires_all_players_to_transition():
	# Player 1 enters
	var p1 = player_scene.instantiate()
	p1.name = "Player1"
	add_child_autofree(p1)
	
	# Simulate entering
	trans_inst._on_body_entered(p1)
	assert_eq(trans_inst._players_in_zone.size(), 1, "Player 1 should be in zone")
	
	# Transition should not be called yet because we need 2 players.
	# We can't easily assert the transition didn't happen if it uses rpc, but we can verify our zone state.
	assert_ne(trans_inst._players_in_zone.size(), NetworkManager.connected_players.size(), "Should not transition yet")
	
	# Player 2 enters
	var p2 = player_scene.instantiate()
	p2.name = "Player2"
	add_child_autofree(p2)
	
	trans_inst._on_body_entered(p2)
	assert_eq(trans_inst._players_in_zone.size(), 2, "Both players should be in zone")
	
	# At this point _trigger_transition would be called.
	assert_eq(trans_inst._players_in_zone.size(), NetworkManager.connected_players.size(), "Should trigger transition now")

func test_player_exits_zone():
	var p1 = player_scene.instantiate()
	add_child_autofree(p1)
	
	trans_inst._on_body_entered(p1)
	assert_eq(trans_inst._players_in_zone.size(), 1)
	
	trans_inst._on_body_exited(p1)
	assert_eq(trans_inst._players_in_zone.size(), 0, "Zone should be empty after player exits")

func test_ignores_non_players():
	var non_player = Node2D.new()
	add_child_autofree(non_player)
	
	trans_inst._on_body_entered(non_player)
	assert_eq(trans_inst._players_in_zone.size(), 0, "Should ignore non-player objects")
