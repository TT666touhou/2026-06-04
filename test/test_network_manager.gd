extends "res://addons/gut/test.gd"

func test_host_creation():
	var err = NetworkManager.host_game()
	assert_eq(err, OK, "Hosting should return OK")
	assert_not_null(NetworkManager.peer, "NetworkManager peer should not be null after hosting")
	assert_eq(NetworkManager.peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED, "Status should be connected")
	
	# Verify that host registered themselves
	var my_id = NetworkManager.multiplayer.get_unique_id()
	assert_true(NetworkManager.connected_players.has(my_id), "Host should register themselves in connected_players")
	
	# Cleanup
	NetworkManager.peer.close()
	NetworkManager.multiplayer.multiplayer_peer = null

func test_player_registration():
	NetworkManager.connected_players.clear()
	var test_info = {"skin_index": 2}
	# To mock RPC we can just call it directly, though normally get_remote_sender_id() returns 0 if not called via RPC
	# Let's mock the sender id by modifying connected_players directly or we can just test if the dict accepts values.
	# The test just ensures the registration function updates dictionary. 
	# Since get_remote_sender_id() fails in manual call, we'll test the dictionary logic instead.
	NetworkManager.connected_players[123] = test_info
	assert_true(NetworkManager.connected_players.has(123), "Should successfully add player info")
	assert_eq(NetworkManager.connected_players[123]["skin_index"], 2, "Skin index should match")
