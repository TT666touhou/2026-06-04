extends CharacterBody2D

enum State { PATROL, TELEGRAPH, SHOOT, COOLDOWN }

@export var stats: EnemyStats
@export var attack_range: float = 160.0
@export var telegraph_duration: float = 0.4
@export var cooldown_duration: float = 1.6

@onready var appearance: TileMapLayer = $Appearance
@onready var wall_detector: RayCast2D = $WallDetector

var current_state: State = State.PATROL
var state_timer: float = 0.0
var direction: float = -1.0
var current_health: int = 10
var bullet_scene: PackedScene

func _ready() -> void:
	if stats:
		current_health = stats.max_health
	
	# 載入子彈場景
	bullet_scene = load("res://scenes/enemy/bullet.tscn")

func _physics_process(delta: float) -> void:
	state_timer -= delta
	
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.SHOOT:
			_process_shoot()
		State.COOLDOWN:
			_process_cooldown(delta)

func _process_patrol(_delta: float) -> void:
	# 巡邏移動 (浮空，無重力)
	var speed = stats.speed if stats else 40.0
	velocity = Vector2(direction * speed, 0.0)
	
	# 牆壁偵測
	wall_detector.force_raycast_update()
	if wall_detector.is_colliding() or is_on_wall():
		_turn_around()
		
	move_and_slide()
	
	# 搜尋玩家以觸發攻擊
	var player = get_tree().current_scene.find_child("Player1", true, false)
	if player:
		var to_player = player.global_position - global_position
		# 射程與高度判定
		if to_player.length() < attack_range and abs(to_player.y) < 64.0:
			# 轉向玩家
			var target_dir = sign(to_player.x)
			if target_dir != 0.0 and target_dir != direction:
				direction = target_dir
				_update_detectors()
			
			_change_state(State.TELEGRAPH)

func _process_telegraph(delta: float) -> void:
	velocity = Vector2.ZERO
	
	# 紅光閃爍特效 (70ms 頻率)
	var flash_freq := 0.07
	var is_red = fmod(state_timer, flash_freq * 2.0) < flash_freq
	appearance.modulate = Color(2.0, 0.3, 0.3, 1.0) if is_red else Color.WHITE
	
	if state_timer <= 0.0:
		_change_state(State.SHOOT)

func _process_shoot() -> void:
	velocity = Vector2.ZERO
	appearance.modulate = Color.WHITE
	
	# 射出子彈
	var player = get_tree().current_scene.find_child("Player1", true, false)
	if player and bullet_scene:
		var bullet = bullet_scene.instantiate() as EnemyBullet
		bullet.global_position = global_position
		
		# 計算方向向量指向玩家中心
		var target_dir = (player.global_position - global_position).normalized()
		bullet.direction = target_dir
		
		get_tree().current_scene.add_child(bullet)
		print("Enemy3 fired a bullet at player!")
		
	_change_state(State.COOLDOWN)

func _process_cooldown(_delta: float) -> void:
	velocity = Vector2.ZERO
	if state_timer <= 0.0:
		_change_state(State.PATROL)

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.PATROL:
			state_timer = 0.0
		State.TELEGRAPH:
			state_timer = telegraph_duration
		State.SHOOT:
			state_timer = 0.0
		State.COOLDOWN:
			state_timer = cooldown_duration

func _turn_around() -> void:
	direction *= -1.0
	_update_detectors()

func _update_detectors() -> void:
	wall_detector.target_position.x = 14.0 * direction
	appearance.scale.x = -direction

func take_damage(damage: int) -> void:
	current_health -= damage
	print("Enemy3 took %d damage! HP: %d" % [damage, current_health])
	
	var tween: Tween = create_tween()
	appearance.modulate = Color(10, 10, 10, 1) # 閃白
	tween.tween_property(appearance, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	print("Enemy3 died!")
	queue_free()
