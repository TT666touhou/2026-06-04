extends CharacterBody2D

@export var knockback_force: float = 500.0
@export var ground_friction: float = 800.0
@export var gravity: float = 980.0
@export var wire_pull_speed: float = 200.0

var _player: Node = null
var _wire_pulling: bool = false

func _ready() -> void:
	add_to_group("training_dummy")
	call_deferred("_init_player_ref")

func _init_player_ref() -> void:
	var found := get_tree().get_nodes_in_group("player")
	_player = found[0] if found.size() > 0 else null

func _physics_process(delta: float) -> void:
	if _wire_pulling:
		if _player == null or not is_instance_valid(_player):
			_init_player_ref()
		if _player != null and is_instance_valid(_player):
			var pull_dir: Vector2 = (_player.global_position - global_position).normalized()
			velocity.x = pull_dir.x * wire_pull_speed
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
		if not _wire_pulling:
			velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	move_and_slide()

# Called by NeedleManager when a needle embeds in this body.
func on_needle_embedded(n_type: int) -> void:
	if n_type == 0:
		# Attack needle: one-shot knockback away from player
		if _player == null or not is_instance_valid(_player):
			_init_player_ref()
		var dir := Vector2.RIGHT
		if _player != null and is_instance_valid(_player):
			dir = (global_position - _player.global_position).normalized()
		velocity.x += dir.x * knockback_force
		if is_on_floor():
			velocity.y -= knockback_force * 0.35
	elif n_type == 1:
		# Wire needle: continuously pull toward player while wire is held (GAP-046)
		_wire_pulling = true

func on_needle_removed(n_type: int) -> void:
	if n_type == 1:
		_wire_pulling = false
