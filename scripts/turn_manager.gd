## BulletTimeManager (formerly TurnManager) — Space held = bullet time (time_scale=0.15).
## is_frozen() = bullet time active; used by player aim preview.
extends Node

const BULLET_TIME_SCALE: float = 0.15

var _bullet_time: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0

func _process(_delta: float) -> void:
	var want := Input.is_key_pressed(KEY_SPACE)
	if want != _bullet_time:
		_bullet_time = want
		Engine.time_scale = BULLET_TIME_SCALE if _bullet_time else 1.0

func is_frozen() -> bool:
	return _bullet_time
