extends CharacterBody2D

@export var knockback_force: float = 500.0
@export var ground_friction: float = 800.0
@export var gravity: float = 980.0

var _player: Node = null

func _ready() -> void:
	add_to_group("training_dummy")
	call_deferred("_init_player_ref")

func _init_player_ref() -> void:
	var found := get_tree().get_nodes_in_group("player")
	_player = found[0] if found.size() > 0 else null

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	move_and_slide()

# Called by NeedleManager when a needle embeds in this body.
# Attack needle (n_type=0) applies a one-shot knockback impulse away from the player.
func on_needle_embedded(n_type: int) -> void:
	if n_type != 0:
		return
	if _player == null or not is_instance_valid(_player):
		_init_player_ref()
	var dir := Vector2.RIGHT
	if _player != null and is_instance_valid(_player):
		dir = (global_position - _player.global_position).normalized()
	velocity.x += dir.x * knockback_force
	if is_on_floor():
		velocity.y -= knockback_force * 0.35
