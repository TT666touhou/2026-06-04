extends CharacterBody2D
## Boss Enemy Script
## History:
## 2026-06-12 ERR-006 fix: created boss.gd (was missing, boss.tscn failed to load)
## 2026-06-12 ERR-009 fix: moved add_to_group into _ready() (was in class body)
## 2026-06-12 ERR-ENC fix: re-saved as UTF-8 without BOM (was in non-UTF-8 encoding)

enum State { PATROL, CHARGE, COOLDOWN, DEAD }

@export var stats: EnemyStats
@export var spawn_disabled: bool = false
@export var max_health: int    = 30
@export var move_speed: float  = 60.0
@export var charge_speed: float = 200.0
@export var attack_damage: int = 2
@export var detection_range: float = 200.0

var current_health: int = 30
var current_state: State = State.PATROL
var state_timer: float = 0.0
var direction: float = -1.0
var _charge_dir: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	add_to_group("Enemies")
	print("[Boss] Initialized")
	if stats:
		current_health = stats.max_health if stats.get("max_health") != null else max_health
	if spawn_disabled:
		disable_enemy()

func disable_enemy() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()

func enable_enemy() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	show()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	## Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	state_timer -= delta

	match current_state:
		State.PATROL:
			_process_patrol()
		State.CHARGE:
			_process_charge()
		State.COOLDOWN:
			_process_cooldown()

	move_and_slide()

func _process_patrol() -> void:
	velocity.x = direction * move_speed

	## Turn around on wall hit
	if is_on_wall():
		direction *= -1.0

	## Detect player -> switch to charge state
	var players := get_tree().get_nodes_in_group("Players")
	if players.size() > 0:
		var player: Node = players[0]
		var dist: float = global_position.distance_to(player.global_position)
		if dist < detection_range:
			_charge_dir = sign(player.global_position.x - global_position.x)
			_change_state(State.CHARGE)

func _process_charge() -> void:
	velocity.x = _charge_dir * charge_speed

	## Hit wall or timer expired -> cooldown
	if is_on_wall() or state_timer <= 0.0:
		_change_state(State.COOLDOWN)

func _process_cooldown() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0)
	if state_timer <= 0.0:
		_change_state(State.PATROL)

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.PATROL:
			state_timer = 0.0
		State.CHARGE:
			state_timer = 0.8
		State.COOLDOWN:
			state_timer = 1.5

func take_damage(damage: int) -> void:
	if current_state == State.DEAD:
		return
	current_health -= damage
	print("[Boss] Took %d damage, HP remaining: %d" % [damage, current_health])
	## Flash effect
	var tween := create_tween()
	modulate = Color(10, 10, 10, 1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	if current_health <= 0:
		call_deferred("die")

func die() -> void:
	current_state = State.DEAD
	print("[Boss] Boss defeated!")
	## Notify GameWorld (if exists)
	var gw := get_node_or_null("/root/GameWorld")
	if gw and gw.has_signal("boss_defeated"):
		gw.emit_signal("boss_defeated")
	queue_free()
