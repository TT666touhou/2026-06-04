extends CharacterBody2D

@export var stats: EnemyStats

@onready var appearance: TileMapLayer = %Appearance
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ledge_detector: RayCast2D = $LedgeDetector

# 取得重力
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var current_health: int = 1
var direction: float = -1.0 # 初始往左走

func _ready() -> void:
	if stats:
		current_health = stats.max_health

func _physics_process(delta: float) -> void:
	# 1. 處理重力
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# 2. 邊緣與牆壁偵測 (若在地面上才判定)
	if is_on_floor():
		wall_detector.force_raycast_update()
		ledge_detector.force_raycast_update()
		if wall_detector.is_colliding() or is_on_wall() or not ledge_detector.is_colliding():
			_turn_around()
			
	# 3. 水平移動
	var move_speed = stats.speed if stats else 50.0
	velocity.x = direction * move_speed
	
	move_and_slide()

func _turn_around() -> void:
	direction *= -1.0
	# 確保判定射線朝向與移動方向一致 (加長射線到 14，確保它能穿透邊界提早碰到牆壁)
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
