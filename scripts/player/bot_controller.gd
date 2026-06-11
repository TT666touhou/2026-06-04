extends Node
class_name BotController

@export var player: CharacterBody2D
@export var ray_length: float = 64.0
@export var gap_ray_length: float = 100.0

var _jump_release_timer: float = 0.0

func _ready():
	if not player:
		player = get_parent() as CharacterBody2D
		
func _physics_process(delta):
	if not player or not player.get("bot_enabled"):
		return
		
	# Check if player has the bot variables
	if not player.has_method("get") or not "bot_input_move_dir" in player:
		return
		
	var space_state = player.get_world_2d().direct_space_state
	var pos = player.global_position
	
	# Default: keep moving right
	player.bot_input_move_dir = 1.0
	
	# Release jump if we were holding it
	if _jump_release_timer > 0:
		_jump_release_timer -= delta
		player.bot_input_jump = false
	else:
		player.bot_input_jump = false
	
	player.bot_input_roll = false
	
	# 1. Wall Detection (Front)
	var wall_ray_start = pos + Vector2(0, -10)
	var wall_ray_end = wall_ray_start + Vector2(ray_length, 0)
	var wall_query = PhysicsRayQueryParameters2D.create(wall_ray_start, wall_ray_end, 1) # Mask 1 (world)
	var wall_result = space_state.intersect_ray(wall_query)
	
	# 2. Gap Detection (Floor in front)
	var gap_ray_start = pos + Vector2(24, 0)
	var gap_ray_end = gap_ray_start + Vector2(0, gap_ray_length)
	var gap_query = PhysicsRayQueryParameters2D.create(gap_ray_start, gap_ray_end, 1) # Mask 1
	var gap_result = space_state.intersect_ray(gap_query)
	
	var should_jump = false
	
	if wall_result:
		should_jump = true
		
	if not gap_result and player.is_on_floor():
		should_jump = true
		
	if should_jump and player.is_on_floor():
		player.bot_input_jump = true
		_jump_release_timer = 0.2 # Wait a bit before jumping again to prevent spam

	# AI could use double jump if falling and still gap ahead
	if not player.is_on_floor() and player.velocity.y > 0:
		var fall_gap_query = PhysicsRayQueryParameters2D.create(pos + Vector2(0, 0), pos + Vector2(0, gap_ray_length * 2), 1)
		var fall_gap_result = space_state.intersect_ray(fall_gap_query)
		if not fall_gap_result and player.get("_can_double_jump"):
			player.bot_input_jump = true
			_jump_release_timer = 0.2
