extends CharacterBody2D

@export var stats: EnemyStats
@export var detection_range: float = 120.0
@export var spawn_disabled: bool = false

@onready var appearance: TileMapLayer = %Appearance
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ledge_detector: RayCast2D = $LedgeDetector

# 取得重力
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var current_health: int = 1
var direction: float = -1.0 # 初始往左走
var is_alert: bool = false
var flash_timer: float = 0.0
var _is_dying: bool = false

## VFX scenes auto-loaded (no Inspector setup required)
const HIT_VFX_PATH: String = "res://scenes/VFX/EnemyHit.tscn"
const DEATH_VFX_PATH: String = "res://scenes/VFX/EnemyDeath.tscn"
var hit_vfx_scene: PackedScene
var death_vfx_scene: PackedScene

func _ready() -> void:
	## Auto-load VFX scenes
	hit_vfx_scene = load(HIT_VFX_PATH) as PackedScene
	death_vfx_scene = load(DEATH_VFX_PATH) as PackedScene

	if stats:
		current_health = stats.max_health
		
	if spawn_disabled:
		disable_enemy()

func disable_enemy() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()

func enable_enemy() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	show()

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
	
	var players = get_tree().get_nodes_in_group("Players")
	var player = players[0] if players.size() > 0 else null
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
	
	# 偵測碰觸玩家並造成傷害 (因為不物理碰撞，故使用距離判定)
	if player:
		var diff = player.global_position - global_position
		# 距離判定：水平小於 12 像素，且垂直高度差小於 14 像素
		if abs(diff.x) < 12.0 and abs(diff.y) < 14.0:
			player.take_damage(1)

func _turn_around() -> void:
	direction *= -1.0
	_update_detectors()

func _update_detectors() -> void:
	wall_detector.target_position.x = 14.0 * direction
	ledge_detector.position.x = 10.0 * direction
	appearance.scale.x = -direction

func take_damage(damage: int) -> void:
	if _is_dying:
		return
	current_health -= damage
	print("Enemy1 took %d damage! Health remaining: %d" % [damage, current_health])

	## 受擊視覺回饵：超白閃光 + 縮放震動
	appearance.modulate = Color(8.0, 8.0, 8.0, 1.0)
	var tw := create_tween()
	tw.tween_property(appearance, "modulate", Color(3.0, 0.2, 0.2, 1.0), 0.05)
	tw.tween_property(appearance, "modulate", Color.WHITE, 0.1)

	## 縮放震動（squash & stretch）
	var st := create_tween()
	st.tween_property(self, "scale", Vector2(1.3, 0.7), 0.04)
	st.tween_property(self, "scale", Vector2(0.85, 1.2), 0.05)
	st.tween_property(self, "scale", Vector2.ONE, 0.07)

	## 命中特效
	_spawn_vfx(hit_vfx_scene)

	if current_health <= 0:
		die()

func die() -> void:
	if _is_dying:
		return
	_is_dying = true
	print("Enemy1 died!")
	set_physics_process(false)
	_spawn_vfx(death_vfx_scene)

	## 死亡動畫：放大 + 淡出
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.08)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)

func _spawn_vfx(vfx_scene: PackedScene) -> void:
	if vfx_scene == null:
		return
	var vfx := vfx_scene.instantiate() as Node2D
	if vfx == null:
		return
	vfx.global_position = global_position + Vector2(0.0, -8.0)
	var parent := get_parent()
	if parent:
		parent.call_deferred("add_child", vfx)
