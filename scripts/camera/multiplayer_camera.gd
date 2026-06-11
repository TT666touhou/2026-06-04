extends Camera2D

@export var tracking_speed: float = 5.0
@export var damage_amount: int = 1
@export var bounce_impulse: Vector2 = Vector2(800, -200)

var furthest_x: float = 0.0

func _process(delta: float) -> void:
	# Only the authority (server/host) should process the camera damage logic to avoid duplicated damage,
	# but since Camera2D movement is local to each client, we'll let each client move their own camera.
	# To ensure consistency, we only process damage if we are the authority.
	var players = get_tree().get_nodes_in_group("Players")
	if players.is_empty():
		return
		
	# Find furthest X
	var max_x = -INF
	for player in players:
		# Ensure player is active
		if player.visible:
			if player.global_position.x > max_x:
				max_x = player.global_position.x
	
	if max_x != -INF:
		furthest_x = maxf(furthest_x, max_x)
		
	# Interpolate camera position
	global_position.x = lerp(global_position.x, furthest_x, tracking_speed * delta)
	
	# Only server processes damage to prevent multiple RPCs or sync issues
	if is_multiplayer_authority():
		var viewport_rect = get_viewport_rect()
		# The camera's left edge in global coordinates
		var camera_left_edge = global_position.x - (viewport_rect.size.x / 2) / zoom.x
		
		for player in players:
			if player.visible and player.global_position.x < camera_left_edge:
				if player.has_method("take_damage") and player.has_method("apply_bounce_impulse"):
					if player._i_frame_timer <= 0.0 and not player._is_rolling and not player.is_invincible:
						player.take_damage(damage_amount)
						player.apply_bounce_impulse(bounce_impulse)
