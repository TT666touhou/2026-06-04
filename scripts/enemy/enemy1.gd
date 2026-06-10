extends CharacterBody2D

@export var stats: EnemyStats
@export var detection_range: float = 120.0
@export var charge_speed: float = 100.0

@onready var appearance: TileMapLayer = %Appearance
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ledge_detector: RayCast2D = $LedgeDetector

# 取得重力
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var current_health: int = 1
var direction: float = -1.0 # 初始往左走
var is_charging: bool = false

func _ready() -> void:
	if stats:
		current_health = stats.max_health

func _physics_process(delta: float) -> void:
	# 1. 處理重力
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# 偵測玩家
	var player = get_tree().current_scene.find_child("Player1", true, false)
	is_charging = false
	if player:
		var to_player = player.global_position - global_position
		if to_player.length() < detection_range and abs(to_player.y) < 40.0:
			is_charging = true
			var target_dir = sign(to_player.x)
			if target_dir != 0.0 and target_dir != direction:
				direction = target_dir
				_update_detectors()

	# 2. 邊緣與牆壁偵測 (若在地面上才判定)
	if is_on_floor():
		wall_detector.force_raycast_update()
		ledge_detector.force_raycast_update()
		
		# 衝撞時忽略懸崖以追擊玩家，但碰到牆壁依然要回頭
		var should_turn := false
		if is_charging:
			should_turn = wall_detector.is_colliding() or is_on_wall()
		else:
			should_turn = wall_detector.is_colliding() or is_on_wall() or not ledge_detector.is_colliding()
			
		if should_turn:
			_turn_around()
			
	# 3. 水平移動
	var move_speed = charge_speed if is_charging else (stats.speed if stats else 50.0)
	velocity.x = direction * move_speed
	
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
	appearance.scale.x = -direction # 假設原本向左(scale.x=1)，向右時(scale.x=-1)


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
