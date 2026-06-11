extends GutTest

var cam_scene = load("res://scenes/test_room_b.tscn")
var cam_node = null
var player_scene = load("res://scenes/player/player.tscn")

func before_each():
	cam_node = cam_scene.instantiate()
	add_child_autofree(cam_node)
	# test_room_b already has one player. We add a second one to test max(x)
	var p2 = player_scene.instantiate()
	p2.position = Vector2(200, 0) # Far to the right
	cam_node.add_child(p2)

func test_dynamic_camera_tracking():
	await wait_physics_frames(2)
	# The camera is a child of cam_node named SceneCamera
	var camera = cam_node.get_node("SceneCamera")
	assert_not_null(camera)
	
	# The camera should be biased towards p2, but test_room_b has limits.
	# The right limit is 208, and with zoom 3, half width is ~100. max_x is around 100.
	# We just assert it moved right from the default (which would be near 0).
	assert_true(camera.global_position.x > 30, "Camera should track the rightmost player (clamped by limits)")
	
func test_boundary_penalty():
	# Move original player far to the left, outside the viewport
	var p1 = cam_node.get_node("Player")
	p1.position = Vector2(-2000, 0)
	
	await wait_physics_frames(10)
	# p1 should take damage and be teleported
	assert_true(p1.current_health < 3, "Player should take damage outside view")
	assert_true(p1.global_position.x > -1000, "Player should be teleported inside view bounds")
