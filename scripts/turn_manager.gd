## TurnManager — Autoload singleton
## Manages the turn cycle: FROZEN (time_scale=0) ↔ PLAYING (time_scale=1, 1.0s)
## GAP-055: Initial implementation for turn-based system
extends Node

enum State { FROZEN, PLAYING }

const TURN_DURATION: float = 0.3

var state: State = State.FROZEN
var _play_start_ms: int = 0

signal turn_started
signal turn_ended  # fired when 1.0s elapses and freeze resumes

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 0.0

func _process(_delta: float) -> void:
	if state == State.PLAYING:
		var elapsed_ms := Time.get_ticks_msec() - _play_start_ms
		if elapsed_ms >= int(TURN_DURATION * 1000.0):
			_end_turn()

## Call this when player confirms an action. Returns false if already playing.
func commit() -> bool:
	if state != State.FROZEN:
		return false
	state = State.PLAYING
	_play_start_ms = Time.get_ticks_msec()
	Engine.time_scale = 1.0
	print("[TM] TURN START — time_scale=1")
	turn_started.emit()
	return true

func is_frozen() -> bool:
	return state == State.FROZEN

func _end_turn() -> void:
	state = State.FROZEN
	Engine.time_scale = 0.0
	print("[TM] TURN END — time_scale=0 (freeze)")
	turn_ended.emit()
