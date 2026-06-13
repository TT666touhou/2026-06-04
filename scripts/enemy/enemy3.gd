extends CharacterBody2D

enum State { PATROL, TELEGRAPH, SHOOT, COOLDOWN }

@export var stats: EnemyStats
@export var attack_range: float = 160.0
@export var telegraph_duration: float = 0.4
@export var cooldown_duration: float = 1.6
@export var spawn_disabled: bool = false

@onready var appearance: TileMapLayer = $Appearance
@onready var wall_detector: RayCast2D = $WallDetector

var current_state: State = State.PATROL
var state_timer: float = 0.0
var direction: float = -1.0
var current_health: int = 10
var _is_dying: bool = false
@export var bullet_scene: PackedScene
@export var hit_vfx_scene: PackedScene
@export var death_vfx_scene: PackedScene

func _ready() -> void:
	if stats:
		current_health = stats.max_health
	
	# 如果沒有在屬性面板中指定，載入預設的子彈場景
	if not bullet_scene:
		bullet_scene = load("res://scenes/enemy/bullet.tscn")
		
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
	var players = get_tree().get_nodes_in_group("Players")
	var player = players[0] if players.size() > 0 else null
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

func _process_telegraph(_delta: float) -> void:
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
	var players = get_tree().get_nodes_in_group("Players")
	var player = players[0] if players.size() > 0 else null
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
	if _is_dying:
		return
	current_health -= damage
	print("Enemy3 took %d damage! HP: %d" % [damage, current_health])

	## 超白閃光 + 縮放震動
	appearance.modulate = Color(8.0, 8.0, 8.0, 1.0)
	var tw := create_tween()
	tw.tween_property(appearance, "modulate", Color(3.0, 0.2, 0.2, 1.0), 0.05)
	tw.tween_property(appearance, "modulate", Color.WHITE, 0.1)
	var st := create_tween()
	st.tween_property(self, "scale", Vector2(1.3, 0.7), 0.04)
	st.tween_property(self, "scale", Vector2(0.85, 1.2), 0.05)
	st.tween_property(self, "scale", Vector2.ONE, 0.07)
	_spawn_vfx(hit_vfx_scene)

	if current_health <= 0:
		die()

## 玩家近戰 Combo Knockback（純水平，多人遊戲安全）
func apply_knockback(impulse: Vector2) -> void:
	if _is_dying:
		return
	velocity += impulse

func die() -> void:
	if _is_dying:
		return
	_is_dying = true
	print("Enemy3 died!")
	set_physics_process(false)
	_spawn_vfx(death_vfx_scene)
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
