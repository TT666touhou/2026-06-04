extends CharacterBody2D

@export var pull_speed: float = 240.0
@export var gravity: float = 980.0

var _pull_count: int = 0
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

	if _pull_count > 0 and _player != null and is_instance_valid(_player):
		var dx: float = _player.global_position.x - global_position.x
		velocity.x = sign(dx) * pull_speed if abs(dx) > 2.0 else 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, pull_speed * 4.0 * delta)

	move_and_slide()

# Called by NeedleManager when a needle embeds in this body.
func on_needle_embedded(n_type: int) -> void:
	if n_type == 0:  # ATTACK needle
		_pull_count += 1
		if _player == null or not is_instance_valid(_player):
			_init_player_ref()

# Called by NeedleManager when an embedded needle is removed.
func on_needle_removed(n_type: int) -> void:
	if n_type == 0:  # ATTACK needle
		_pull_count = max(0, _pull_count - 1)
