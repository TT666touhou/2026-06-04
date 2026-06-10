extends CharacterBody2D

enum State { PATROL, TELEGRAPH, CHARGE, COOLDOWN }

@export var stats: EnemyStats
@export var detection_range: float = 120.0
@export var charge_speed: float = 100.0
@export var telegraph_duration: float = 0.4
@export var cooldown_duration: float = 1.0

@onready var appearance: TileMapLayer = %Appearance
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ledge_detector: RayCast2D = $LedgeDetector

# 取得重力
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var current_state: State = State.PATROL
var state_timer: float = 0.0
var current_health: int = 1
var direction: float = -1.0 # 初始往左走

func _ready() -> void:
	if stats:
		current_health = stats.max_health

func _physics_process(delta: float) -> void:
	# 處理重力
	if not is_on_floor():
		velocity.y += gravity * delta
		
	state_timer -= delta
	
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.CHARGE:
			_process_charge(delta)
		State.COOLDOWN:
			_process_cooldown(delta)
			
	move_and_slide()
	
	# 偵測碰觸玩家並造成傷害
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and (collider.name == "Player1" or collider.has_method("take_damage")):
			collider.take_damage(1)

func _process_patrol(_delta: float) -> void:
	# 正常巡邏移動
	var speed = stats.speed if stats else 50.0
	velocity.x = direction * speed
	
	# 巡邏邊緣與牆壁偵測
	if is_on_floor():
		wall_detector.force_raycast_update()
		ledge_detector.force_raycast_update()
		if wall_detector.is_colliding() or is_on_wall() or not ledge_detector.is_colliding():
			_turn_around()
			
	# 搜尋玩家
	var player = get_tree().current_scene.find_child("Player1", true, false)
	if player:
		var to_player = player.global_position - global_position
		if to_player.length() < detection_range and abs(to_player.y) < 40.0:
			var target_dir = sign(to_player.x)
			if target_dir != 0.0 and target_dir != direction:
				direction = target_dir
				_update_detectors()
			_change_state(State.TELEGRAPH)

func _process_telegraph(_delta: float) -> void:
	velocity.x = 0.0
	
	# 紅光閃爍特效 (70ms 頻率)
	var flash_freq := 0.07
	var is_red = fmod(state_timer, flash_freq * 2.0) < flash_freq
	appearance.modulate = Color(2.0, 0.3, 0.3, 1.0) if is_red else Color.WHITE
	
	if state_timer <= 0.0:
		appearance.modulate = Color.WHITE
		_change_state(State.CHARGE)

func _process_charge(_delta: float) -> void:
	velocity.x = direction * charge_speed
	
	# 衝撞時忽略懸崖以追擊玩家，但碰到牆壁依然要回頭並進入冷卻
	if is_on_floor():
		wall_detector.force_raycast_update()
		if wall_detector.is_colliding() or is_on_wall():
			_turn_around()
			_change_state(State.COOLDOWN)

func _process_cooldown(_delta: float) -> void:
	# 撞牆/衝撞結束後冷卻慢速巡邏
	var speed = (stats.speed if stats else 50.0) * 0.6
	velocity.x = direction * speed
	
	if is_on_floor():
		wall_detector.force_raycast_update()
		ledge_detector.force_raycast_update()
		if wall_detector.is_colliding() or is_on_wall() or not ledge_detector.is_colliding():
			_turn_around()
			
	if state_timer <= 0.0:
		_change_state(State.PATROL)

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.PATROL:
			state_timer = 0.0
		State.TELEGRAPH:
			state_timer = telegraph_duration
		State.CHARGE:
			state_timer = 0.0
		State.COOLDOWN:
			state_timer = cooldown_duration
			appearance.modulate = Color.WHITE

func _turn_around() -> void:
	direction *= -1.0
	_update_detectors()

func _update_detectors() -> void:
	wall_detector.target_position.x = 14.0 * direction
	ledge_detector.position.x = 10.0 * direction
	appearance.scale.x = -direction



func take_damage(damage: int) -> void:
	current_health -= damage
	print("Enemy1 took %d damage! Health remaining: %d" % [damage, current_health])
	
	# 簡單受擊視覺回饋 (可選)
	var tween: Tween = create_tween()
	appearance.modulate = Color(10, 10, 10, 1) # 閃白
	tween.tween_property(appearance, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	print("Enemy1 died!")
	queue_free()
