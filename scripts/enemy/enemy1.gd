extends CharacterBody2D

@export var stats: EnemyStats

@onready var appearance: TileMapLayer = %Appearance
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ledge_detector: RayCast2D = $LedgeDetector
@onready var player_detector: Area2D = $PlayerDetector

# 取得重力
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

enum State { PATROL, NOTICE, CHARGE, REST }
var current_state: State = State.PATROL
var state_timer: float = 0.0

var current_health: int = 1
var direction: float = -1.0 # 初始往左走

func _ready() -> void:
	if stats:
		current_health = stats.max_health
	if player_detector:
		player_detector.body_entered.connect(_on_player_detected)

func _physics_process(delta: float) -> void:
	# 1. 處理重力
	if not is_on_floor():
		velocity.y += gravity * delta
		
	match current_state:
		State.PATROL:
			_patrol_state(delta)
		State.NOTICE:
			_notice_state(delta)
		State.CHARGE:
			_charge_state(delta)
		State.REST:
			_rest_state(delta)
			
	move_and_slide()

func _patrol_state(delta: float) -> void:
	if is_on_floor():
		wall_detector.force_raycast_update()
		ledge_detector.force_raycast_update()
		if wall_detector.is_colliding() or is_on_wall() or not ledge_detector.is_colliding():
			_turn_around()
			
	var move_speed = stats.speed if stats else 50.0
	velocity.x = direction * move_speed

func _notice_state(delta: float) -> void:
	velocity.x = 0
	state_timer -= delta
	if state_timer <= 0:
		current_state = State.CHARGE
		appearance.modulate = Color.WHITE

func _charge_state(delta: float) -> void:
	if is_on_floor():
		wall_detector.force_raycast_update()
		ledge_detector.force_raycast_update()
		if wall_detector.is_colliding() or is_on_wall() or not ledge_detector.is_colliding():
			current_state = State.REST
			state_timer = 1.5
			return
			
	var charge_speed = (stats.speed if stats else 50.0) * 2.5
	velocity.x = direction * charge_speed

func _rest_state(delta: float) -> void:
	velocity.x = 0
	state_timer -= delta
	if state_timer <= 0:
		current_state = State.PATROL
		_turn_around()

func _turn_around() -> void:
	direction *= -1.0
	# 確保判定射線朝向與移動方向一致 (加長射線到 14，確保它能穿透邊界提早碰到牆壁)
	wall_detector.target_position.x = 14.0 * direction
	ledge_detector.position.x = 10.0 * direction
	if player_detector:
		player_detector.scale.x = -direction
	appearance.scale.x = -direction # 假設原本向左(scale.x=1)，向右時(scale.x=-1)

func _on_player_detected(body: Node2D) -> void:
	if current_state == State.PATROL and body.name.begins_with("Player"):
		current_state = State.NOTICE
		state_timer = 0.5
		
		var tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(appearance, "modulate", Color("#E55C5C"), 0.1)
		tween.tween_property(appearance, "modulate", Color.WHITE, 0.1)

func take_damage(damage: int) -> void:
	current_health -= damage
	print("Enemy1 took %d damage! Health remaining: %d" % [damage, current_health])
	
	# 簡單受擊視覺回饋 (可選)
	var tween = create_tween()
	appearance.modulate = Color(10, 10, 10, 1) # 閃白
	tween.tween_property(appearance, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	print("Enemy1 died!")
	queue_free()
