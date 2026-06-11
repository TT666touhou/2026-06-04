extends GutTest

var network_manager = load("res://scripts/autoload/network_manager.gd").new()
var player_scene = load("res://scenes/player/player.tscn")

func before_each():
	add_child_autofree(network_manager)
	# Setup fake connected players
	network_manager.connected_players = {1: {"name": "P1"}, 2: {"name": "P2"}}
	network_manager.alive_players = {1: true, 2: true}

func test_notify_player_died():
	network_manager.notify_player_died(1)
	assert_false(network_manager.alive_players.has(1), "Player 1 should be removed from alive_players")
	assert_true(network_manager.alive_players.has(2), "Player 2 should still be alive")
	
	network_manager.notify_player_died(2)
	assert_false(network_manager.alive_players.has(2), "Player 2 should be removed from alive_players")
	# When alive_players is empty, show_game_over should be called
	# We can't directly mock show_game_over.rpc() here without complex setup, but we verify alive_players is empty.
	assert_eq(network_manager.alive_players.size(), 0, "No players should be alive")
