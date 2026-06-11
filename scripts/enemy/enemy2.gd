extends CharacterBody2D

enum State { PATROL, TELEGRAPH, SHOOT, COOLDOWN }

@export var stats: EnemyStats
@export var attack_range: float = 160.0
@export var telegraph_duration: float = 2.5
@export var shoot_duration: float = 0.3
@export var cooldown_duration: float = 1.2
@export var spawn_disabled: bool = false

@onready var appearance: TileMapLayer = $Appearance
@onready var wall_detector: RayCast2D = $WallDetector
@onready var laser_raycast: RayCast2D = $LaserRaycast
@onready var warning_line: Line2D = $WarningLine
@onready var laser_outer: Line2D = $LaserOuter
@onready var laser_inner: Line2D = $LaserInner

const LASER_MAX_LENGTH: float = 2000.0

var current_state: State = State.PATROL
var state_timer: float = 0.0
var direction: float = -1.0
var current_health: int = 10
var target_laser_point: Vector2 = Vector2.ZERO
var damage_dealt_this_shot: bool = false

func _ready() -> void:
	if stats:
		current_health = stats.max_health
	
	# 初始化 Line2D 外型
	warning_line.visible = false
	laser_outer.visible = false
	laser_inner.visible = false
	
	# 將雷射檢測的 collision_mask 改為 1 (只與地形碰撞)，不阻擋視覺
	if laser_raycast:
		laser_raycast.collision_mask = 1
	
	# 設定雷射外觀為 Near White (中心) 與 Tomato Red (外圍)
	warning_line.default_color = Color(0.898, 0.361, 0.361, 0.6) # 半透明紅
	laser_outer.default_color = Color(0.898, 0.361, 0.361, 1.0) # 番茄紅
	laser_inner.default_color = Color(0.949, 0.976, 0.973, 1.0) # 近白
	
	if spawn_disabled:
		disable_enemy()

func disable_enemy() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()

func enable_enemy() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	show()

func _physics_process(delta: float) -> void:
	state_timer -= delta
	
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.SHOOT:
			_process_shoot(delta)
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
		# 雷射射程判定 (相同高度區間)
		if to_player.length() < attack_range and abs(to_player.y) < 64.0:
			# 轉向玩家
			var target_dir = sign(to_player.x)
			if target_dir != 0.0 and target_dir != direction:
				direction = target_dir
				_update_detectors()
			
			_change_state(State.TELEGRAPH)

func _get_laser_endpoint(target_pos: Vector2) -> Vector2:
	var dir_vec = (target_pos - global_position).normalized()
	laser_raycast.target_position = dir_vec * LASER_MAX_LENGTH
	laser_raycast.force_raycast_update()
	if laser_raycast.is_colliding():
		return laser_raycast.get_collision_point()
	return global_position + dir_vec * LASER_MAX_LENGTH

func _process_telegraph(_delta: float) -> void:
	velocity = Vector2.ZERO
	
	# 紅光閃爍特效 (70ms 頻率)
	var flash_freq := 0.07
	var is_red = fmod(state_timer, flash_freq * 2.0) < flash_freq
	appearance.modulate = Color(2.0, 0.3, 0.3, 1.0) if is_red else Color.WHITE
	
	# 更新紅色瞄準警告線
	var player = get_tree().current_scene.find_child("Player1", true, false)
	if player:
		# 發射前 1.5 秒就該停止追蹤。因此當 state_timer > 1.5 時，瞄準線跟隨玩家
		if state_timer > 1.5:
			target_laser_point = player.global_position
			
		var endpoint = _get_laser_endpoint(target_laser_point)
		var local_laser_pos = to_local(endpoint)
		warning_line.points = [Vector2.ZERO, local_laser_pos]
		warning_line.visible = true
	else:
		# 如果沒有玩家，若在追蹤期內則設為前方預設位置
		if state_timer > 1.5:
			target_laser_point = global_position + Vector2(direction * LASER_MAX_LENGTH, 0)
		var endpoint = _get_laser_endpoint(target_laser_point)
		var local_laser_pos = to_local(endpoint)
		warning_line.points = [Vector2.ZERO, local_laser_pos]
		
	if state_timer <= 0.0:
		_change_state(State.SHOOT)

func _process_shoot(_delta: float) -> void:
	velocity = Vector2.ZERO
	
	# 隱藏警告線，顯示雷射
	warning_line.visible = false
	laser_outer.visible = true
	laser_inner.visible = true
	appearance.modulate = Color.WHITE # 停止紅閃爍
	
	var endpoint = _get_laser_endpoint(target_laser_point)
	
	# 造成傷害 (只判定一次)
	if not damage_dealt_this_shot:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, endpoint, 3) # 檢測地形(1)與玩家(2)
		query.exclude = [get_rid()]
		var result = space_state.intersect_ray(query)
		if not result.is_empty():
			var collider = result.collider
			if collider and (collider.name == "Player1" or collider.has_method("take_damage")):
				collider.take_damage(1)
				damage_dealt_this_shot = true
				
	# 繪製雷射線條
	var local_endpoint = to_local(endpoint)
	laser_outer.points = [Vector2.ZERO, local_endpoint]
	laser_inner.points = [Vector2.ZERO, local_endpoint]
	
	if state_timer <= 0.0:
		_change_state(State.COOLDOWN)

func _process_cooldown(_delta: float) -> void:
	velocity = Vector2.ZERO
	laser_outer.visible = false
	laser_inner.visible = false
	
	if state_timer <= 0.0:
		_change_state(State.PATROL)

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.PATROL:
			state_timer = 0.0
		State.TELEGRAPH:
			state_timer = telegraph_duration
			warning_line.visible = true
			# 當進入預警狀態時，先立刻將 target_laser_point 設為當前玩家的位置
			var player = get_tree().current_scene.find_child("Player1", true, false)
			if player:
				target_laser_point = player.global_position
			else:
				target_laser_point = global_position + Vector2(direction * LASER_MAX_LENGTH, 0)
		State.SHOOT:
			state_timer = shoot_duration
			damage_dealt_this_shot = false
		State.COOLDOWN:
			state_timer = cooldown_duration
			appearance.modulate = Color.WHITE

func _turn_around() -> void:
	direction *= -1.0
	_update_detectors()

func _update_detectors() -> void:
	wall_detector.target_position.x = 14.0 * direction
	appearance.scale.x = -direction

func take_damage(damage: int) -> void:
	current_health -= damage
	print("Enemy2 took %d damage! HP: %d" % [damage, current_health])
	
	var tween: Tween = create_tween()
	appearance.modulate = Color(10, 10, 10, 1) # 閃白
	tween.tween_property(appearance, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	print("Enemy2 died!")
	queue_free()
