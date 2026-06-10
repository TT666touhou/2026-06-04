extends CharacterBody2D

@export var stats: EnemyStats
@export var detection_range: float = 120.0

@onready var appearance: TileMapLayer = %Appearance
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ledge_detector: RayCast2D = $LedgeDetector

# 取得重力
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var current_health: int = 1
var direction: float = -1.0 # 初始往左走
var is_alert: bool = false
var flash_timer: float = 0.0

func _ready() -> void:
	if stats:
		current_health = stats.max_health

func _physics_process(delta: float) -> void:
	# 處理重力
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# 正常巡邏邊緣與牆壁偵測
	if is_on_floor():
		wall_detector.force_raycast_update()
		ledge_detector.force_raycast_update()
		if wall_detector.is_colliding() or is_on_wall() or not ledge_detector.is_colliding():
			_turn_around()
			
	# 搜尋玩家並判斷加速條件
	var speed = stats.speed if stats else 50.0
	is_alert = false
	
	var player = get_tree().current_scene.find_child("Player1", true, false)
	if player:
		var to_player = player.global_position - global_position
		# 條件：同平面 (高度差小於 40)、距離夠近、且面向玩家的水平方向
		var is_same_platform = abs(to_player.y) < 40.0
		var in_range = to_player.length() < detection_range
		var is_facing_player = sign(to_player.x) == direction
		
		if is_same_platform and in_range and is_facing_player:
			# 射線阻擋檢測 (Mask 1 = 地形/牆壁)
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
			query.exclude = [get_rid(), player.get_rid()]
			var result = space_state.intersect_ray(query)
			
			if result.is_empty():
				# 無阻擋，加速 1.5 倍 (提高 0.5 倍速)
				is_alert = true
				speed *= 1.5

	# 閃爍特效更新
	if is_alert:
		flash_timer += delta
		var flash_freq := 0.07
		var is_red = fmod(flash_timer, flash_freq * 2.0) < flash_freq
		appearance.modulate = Color(2.0, 0.3, 0.3, 1.0) if is_red else Color.WHITE
	else:
		flash_timer = 0.0
		appearance.modulate = Color.WHITE

	# 水平移動
	velocity.x = direction * speed
	move_and_slide()
	
	# 偵測碰觸玩家並造成傷害
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and (collider.name == "Player1" or collider.has_method("take_damage")):
			collider.take_damage(1)

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
