extends "res://addons/gut/test.gd"

var test_level_scene = preload("res://scenes/test_level.tscn")
var test_level = null

func before_each():
	# Mock command line arg for bots
	OS.set_environment("BOT_MODE", "1")
	test_level = test_level_scene.instantiate()
	get_tree().root.add_child(test_level)

func after_each():
	OS.set_environment("BOT_MODE", "")
	if test_level:
		test_level.queue_free()

func test_ai_can_traverse_level():
	# Wait for a brief moment for spawn and physics
	await get_tree().create_timer(1.0).timeout
	
	var players = test_level.get_node("Players").get_children()
	assert_gt(players.size(), 0, "Should have spawned at least one player in bot mode.")
	
	var p1 = players[0]
	assert_true(p1.get("bot_enabled"), "Bot mode should be enabled on the player.")
	
	# Initial position
	var start_x = p1.global_position.x
	
	# Let the AI run for some seconds
	await get_tree().create_timer(5.0).timeout
	
	var end_x = p1.global_position.x
	
	assert_gt(end_x, start_x + 100.0, "Player 1 AI should have moved right significantly.")
	assert_true(NetworkManager.alive_players.has(p1.name.to_int()), "Player 1 should still be alive.")
	
	# If we want a full 60s run we could await 60s, but that takes too long in unit tests.
	# The goal is that the bot moves forward and doesn't get stuck immediately.
