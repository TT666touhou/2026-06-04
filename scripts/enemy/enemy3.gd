extends CharacterBody2D

@export var stats: EnemyStats
@export var bullet_scene: PackedScene

@onready var appearance: Sprite2D = %Appearance
@onready var player_detector: Area2D = $PlayerDetector

enum State { IDLE, PURSUE, NOTICE, FIRE }
var current_state: State = State.IDLE
var state_timer: float = 0.0

var current_health: int = 1
var target_player: Node2D = null

# 距離控制
var min_distance: float = 60.0
var max_distance: float = 120.0
var move_speed: float = 40.0

func _ready() -> void:
	if stats:
		current_health = stats.max_health
	if player_detector:
		player_detector.body_entered.connect(_on_player_entered)
		player_detector.body_exited.connect(_on_player_exited)

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			move_and_slide()
		State.PURSUE:
			_pursue_state(delta)
			move_and_slide()
		State.NOTICE:
			_notice_state(delta)
			velocity = Vector2.ZERO
			move_and_slide()
		State.FIRE:
			_fire_state(delta)
			velocity = Vector2.ZERO
			move_and_slide()

func _pursue_state(delta: float) -> void:
	if not target_player:
		current_state = State.IDLE
		return
		
	var dist = global_position.distance_to(target_player.global_position)
	var dir = (target_player.global_position - global_position).normalized()
	
	if dist > max_distance:
		velocity = dir * move_speed
	elif dist < min_distance:
		velocity = -dir * move_speed
	else:
		velocity = Vector2.ZERO
		
	# 嘗試開火
	state_timer -= delta
	if state_timer <= 0:
		current_state = State.NOTICE
		state_timer = 0.5 # 閃爍警告0.5秒
		
		# 紅光閃爍
		var tween = create_tween()
		tween.set_loops(5)
		tween.tween_property(appearance, "modulate", Color("#E55C5C"), 0.05)
		tween.tween_property(appearance, "modulate", Color.WHITE, 0.05)

func _notice_state(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		current_state = State.FIRE
		appearance.modulate = Color.WHITE

func _fire_state(delta: float) -> void:
	if target_player and bullet_scene:
		var dir = (target_player.global_position - global_position).normalized()
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = dir
		get_tree().current_scene.add_child(bullet)
		
	current_state = State.PURSUE
	state_timer = 2.0 # 射擊冷卻2秒

func _on_player_entered(body: Node2D) -> void:
	if body.name.begins_with("Player"):
		target_player = body
		if current_state == State.IDLE:
			current_state = State.PURSUE
			state_timer = randf_range(1.0, 2.0)

func _on_player_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null
		current_state = State.IDLE
		appearance.modulate = Color.WHITE

func take_damage(damage: int) -> void:
	current_health -= damage
	print("Enemy3 took %d damage! Health remaining: %d" % [damage, current_health])
	
	var tween = create_tween()
	appearance.modulate = Color(10, 10, 10, 1) # 閃白
	tween.tween_property(appearance, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	queue_free()
