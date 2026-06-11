extends SceneTree

func _init():
	print("Starting Scene Setup...")

	# 1. Setup boss_room.tscn by duplicating test_room_b.tscn
	var tb = load("res://scenes/test_room_b.tscn").instantiate()
	
	# Add Boss to boss_room
	var boss_scene = load("res://scenes/enemy/boss.tscn")
	var boss = boss_scene.instantiate()
	boss.position = Vector2(0, -64)
	tb.add_child(boss)
	boss.owner = tb

	var boss_pack = PackedScene.new()
	boss_pack.pack(tb)
	ResourceSaver.save(boss_pack, "res://scenes/level/boss_room.tscn")
	print("Saved boss_room.tscn")

	# 2. Add RoomTransition from test_room_a to test_room_b
	var ta = load("res://scenes/test_room_a.tscn").instantiate()
	var trans_scene = load("res://scenes/level/room_transition.tscn")
	if trans_scene:
		var trans_a = trans_scene.instantiate()
		trans_a.position = Vector2(150, -50)
		trans_a.target_room_path = "res://scenes/test_room_b.tscn"
		ta.add_child(trans_a)
		trans_a.owner = ta
		var pack_a = PackedScene.new()
		pack_a.pack(ta)
		ResourceSaver.save(pack_a, "res://scenes/test_room_a.tscn")
		print("Added transition to test_room_a")

	# 3. Add RoomTransition from test_room_b to boss_room
	tb = load("res://scenes/test_room_b.tscn").instantiate()
	if trans_scene:
		var trans_b = trans_scene.instantiate()
		trans_b.position = Vector2(150, -50)
		trans_b.target_room_path = "res://scenes/level/boss_room.tscn"
		tb.add_child(trans_b)
		trans_b.owner = tb
		var pack_b = PackedScene.new()
		pack_b.pack(tb)
		ResourceSaver.save(pack_b, "res://scenes/test_room_b.tscn")
		print("Added transition to test_room_b")

	print("Finished Scene Setup.")
	quit()
