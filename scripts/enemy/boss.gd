extends CharacterBody2D
## Boss: The Warden（守護者）
## 三段 Phase，每段改變攻擊模式
## Phase 1（60~40 HP）：巡邏 + 衝刺
## Phase 2（40~20 HP）：衝刺加快 + 三向子彈
## Phase 3（20~0 HP）：狂暴：衝刺+子彈+地面震動

# ═══════════════════════════════════════════════════════════════
# EXPORT 參數
# ═══════════════════════════════════════════════════════════════
@export_group("Stats")
@export var max_health: int = 60
@export var contact_damage: int = 1
@export var bullet_damage: int = 1

@export_group("Phase 1")
@export var patrol_speed: float = 60.0
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.35
@export var dash_cooldown: float = 2.5

@export_group("Phase 2")
@export var p2_patrol_speed: float = 90.0
@export var p2_dash_speed: float = 400.0
@export var p2_dash_cooldown: float = 1.8
@export var bullet_cooldown: float = 1.5

@export_group("Phase 3")
@export var p3_dash_cooldown: float = 1.0
@export var p3_bullet_cooldown: float = 0.8
@export var shockwave_cooldown: float = 3.5

@export_group("Visuals")
@export var tile_id_normal: int = 8    ## mrmotext tileset 的 Boss 格子
@export var tile_id_rage: int = 9     ## 狂暴狀態

@onready var appearance: TileMapLayer = $Appearance
@onready var wall_detector: RayCast2D = $WallDetector
@onready var health_bar: Node = $HealthBar

# ═══════════════════════════════════════════════════════════════
# 狀態機
# ═══════════════════════════════════════════════════════════════
enum State { IDLE, PATROL, DASH, SHOOT, SHOCKWAVE, DEAD }
enum Phase { ONE, TWO, THREE }

var current_state: State = State.PATROL
var current_phase: Phase = Phase.ONE
var current_health: int = 60

var _direction: float = -1.0
var _state_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _bullet_timer: float = 0.0
var _shockwave_timer: float = 0.0
var _dash_direction: float = 0.0

signal phase_changed(new_phase: int)
signal boss_died
signal boss_health_changed(new_health: int, max_health: int)

# ═══════════════════════════════════════════════════════════════
# 子彈場景（動態建立）
# ═══════════════════════════════════════════════════════════════
var _bullet_scene: PackedScene = null

func _ready() -> void:
	current_health = max_health
	add_to_group("Enemies")
	boss_health_changed.emit(current_health, max_health)
	
	# 嘗試載入子彈場景
	var bullet_path := "res://scenes/enemy/BossBullet.tscn"
	if ResourceLoader.exists(bullet_path):
		_bullet_scene = load(bullet_path)
	
	# 設定碰撞：Boss 在 layer 4，偵測 player layer 2
	collision_layer = 4
	collision_mask = 1  # 只與地形碰撞（移動用）

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	_update_phase()
	_apply_gravity(delta)
	_update_timers(delta)
	
	match current_state:
		State.PATROL: _process_patrol(delta)
		State.DASH:   _process_dash(delta)
		State.SHOOT:  _process_shoot(delta)
		State.SHOCKWAVE: _process_shockwave(delta)
	
	move_and_slide()
	_check_contact_damage()

# ═══════════════════════════════════════════════════════════════
# Phase 更新
# ═══════════════════════════════════════════════════════════════
func _update_phase() -> void:
	var new_phase := current_phase
	if current_health > 40:
		new_phase = Phase.ONE
	elif current_health > 20:
		new_phase = Phase.TWO
	else:
		new_phase = Phase.THREE
	
	if new_phase != current_phase:
		current_phase = new_phase
		phase_changed.emit(int(current_phase))
		_on_phase_change()

func _on_phase_change() -> void:
	print("[Boss] Phase changed to: ", int(current_phase) + 1)
	# 閃白特效
	if appearance:
		var tween := create_tween()
		for _i in range(5):
			tween.tween_property(appearance, "modulate", Color(5.0, 5.0, 5.0, 1.0), 0.08)
			tween.tween_property(appearance, "modulate", Color.WHITE, 0.08)
		
		# Phase 3：改變顏色為紅色
		if current_phase == Phase.THREE:
			tween.tween_property(appearance, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.2)

# ═══════════════════════════════════════════════════════════════
# 計時器更新
# ═══════════════════════════════════════════════════════════════
func _update_timers(delta: float) -> void:
	_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)
	_bullet_timer = maxf(0.0, _bullet_timer - delta)
	_shockwave_timer = maxf(0.0, _shockwave_timer - delta)
	_state_timer = maxf(0.0, _state_timer - delta)

# ═══════════════════════════════════════════════════════════════
# 巡邏狀態
# ═══════════════════════════════════════════════════════════════
func _process_patrol(delta: float) -> void:
	var speed := _get_patrol_speed()
	velocity.x = _direction * speed
	
	# 牆壁偵測
	if wall_detector:
		wall_detector.force_raycast_update()
		if wall_detector.is_colliding() or is_on_wall():
			_turn_around()
	
	# 偵測玩家
	var player := _find_nearest_player()
	if player:
		var to_player := player.global_position - global_position
		_direction = sign(to_player.x) if to_player.x != 0 else _direction
		_update_detector()
		
		# 距離夠近就衝刺
		var dash_cd := _get_dash_cooldown()
		if _dash_cooldown_timer <= 0.0 and to_player.length() < 200.0:
			_start_dash(player)
		
		# Phase 2/3：射擊
		if current_phase != Phase.ONE and _bullet_timer <= 0.0:
			_change_state(State.SHOOT)
		
		# Phase 3：震波
		if current_phase == Phase.THREE and _shockwave_timer <= 0.0 and abs(to_player.x) < 120.0:
			_change_state(State.SHOCKWAVE)

func _get_patrol_speed() -> float:
	match current_phase:
		Phase.TWO: return p2_patrol_speed
		Phase.THREE: return p2_patrol_speed * 1.3
		_: return patrol_speed

func _get_dash_cooldown() -> float:
	match current_phase:
		Phase.TWO: return p2_dash_cooldown
		Phase.THREE: return p3_dash_cooldown
		_: return dash_cooldown

# ═══════════════════════════════════════════════════════════════
# 衝刺狀態
# ═══════════════════════════════════════════════════════════════
func _start_dash(player: Node2D) -> void:
	_dash_direction = sign(player.global_position.x - global_position.x)
	_dash_cooldown_timer = _get_dash_cooldown()
	_state_timer = dash_duration
	_change_state(State.DASH)
	
	# 衝刺閃白
	if appearance:
		var tween := create_tween()
		tween.tween_property(appearance, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.1)
		tween.tween_property(appearance, "modulate", Color.WHITE, 0.1)

func _process_dash(delta: float) -> void:
	var spd := p2_dash_speed if current_phase != Phase.ONE else dash_speed
	velocity.x = _dash_direction * spd
	
	if _state_timer <= 0.0 or is_on_wall():
		_change_state(State.PATROL)

# ═══════════════════════════════════════════════════════════════
# 射擊狀態
# ═══════════════════════════════════════════════════════════════
func _process_shoot(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	if _state_timer <= 0.0:
		_fire_bullets()
		var cd := p3_bullet_cooldown if current_phase == Phase.THREE else bullet_cooldown
		_bullet_timer = cd
		_change_state(State.PATROL)

func _fire_bullets() -> void:
	var player := _find_nearest_player()
	var num_bullets := 5 if current_phase == Phase.THREE else 3
	
	for i in range(num_bullets):
		var angle := (float(i) / float(num_bullets - 1)) * PI - PI * 0.5
		if player:
			var base_angle := (player.global_position - global_position).angle()
			angle += base_angle
		_spawn_bullet(angle)

func _spawn_bullet(angle_rad: float) -> void:
	if _bullet_scene == null:
		# 沒有子彈場景時，用程式動態建立一個簡單的子彈
		var b := CharacterBody2D.new()
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 3.0
		col.shape = shape
		b.add_child(col)
		b.collision_layer = 8
		b.collision_mask = 2
		var script := GDScript.new()
		script.source_code = """
extends CharacterBody2D
var dir := Vector2.RIGHT
var spd := 200.0
var dmg := 1
func _physics_process(d):
	velocity = dir * spd
	move_and_slide()
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() and c.get_collider().has_method(\"take_damage\"):
			c.get_collider().take_damage(dmg)
			queue_free()
			return
		queue_free()
	if global_position.distance_to(get_parent().global_position if get_parent() else global_position) > 800:
		queue_free()
"""
		script.reload()
		b.set_script(script)
		b.set("dir", Vector2(cos(angle_rad), sin(angle_rad)))
		b.set("dmg", bullet_damage)
		b.global_position = global_position
		get_parent().add_child(b)
	else:
		var bullet := _bullet_scene.instantiate()
		bullet.global_position = global_position
		if bullet.has_method("set_direction"):
			bullet.set_direction(Vector2(cos(angle_rad), sin(angle_rad)))
		get_parent().add_child(bullet)

# ═══════════════════════════════════════════════════════════════
# 震波狀態（Phase 3 専用）
# ═══════════════════════════════════════════════════════════════
func _process_shockwave(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	if _state_timer <= 0.0:
		_do_shockwave()
		_shockwave_timer = shockwave_cooldown
		_change_state(State.PATROL)

func _do_shockwave() -> void:
	print("[Boss] SHOCKWAVE!")
	# 對附近所有玩家造成傷害
	for p in get_tree().get_nodes_in_group("Players"):
		if not is_instance_valid(p): continue
		var dist := global_position.distance_to(p.global_position)
		if dist < 150.0:
			if p.has_method("take_damage"):
				p.take_damage(2)
			# 擊退
			if p is CharacterBody2D:
				p.velocity = (p.global_position - global_position).normalized() * 400.0
	
	# 視覺效果：閃紅
	if appearance:
		var tween := create_tween()
		tween.tween_property(appearance, "modulate", Color(5.0, 1.0, 1.0, 1.0), 0.05)
		tween.tween_property(appearance, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.3)

# ═══════════════════════════════════════════════════════════════
# 接觸傷害
# ═══════════════════════════════════════════════════════════════
func _check_contact_damage() -> void:
	for p in get_tree().get_nodes_in_group("Players"):
		if not is_instance_valid(p): continue
		var dist := global_position.distance_to(p.global_position)
		if dist < 20.0 and p.has_method("take_damage"):
			p.take_damage(contact_damage)

# ═══════════════════════════════════════════════════════════════
# 受傷與死亡
# ═══════════════════════════════════════════════════════════════
func take_damage(amount: int) -> void:
	if current_state == State.DEAD: return
	current_health = clampi(current_health - amount, 0, max_health)
	boss_health_changed.emit(current_health, max_health)
	print("[Boss] HP: %d / %d" % [current_health, max_health])
	
	# 受傷閃白
	if appearance:
		var tween := create_tween()
		tween.tween_property(appearance, "modulate", Color(10.0, 10.0, 10.0, 1.0), 0.05)
		var base_color := Color(2.0, 0.5, 0.5, 1.0) if current_phase == Phase.THREE else Color.WHITE
		tween.tween_property(appearance, "modulate", base_color, 0.1)
	
	if current_health <= 0:
		_die()

func _die() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	print("[Boss] The Warden has been defeated!")
	boss_died.emit()
	
	# 死亡動畫
	var tween := create_tween()
	for _i in range(10):
		tween.tween_property(appearance, "modulate", Color(5.0, 5.0, 5.0, 1.0), 0.05)
		tween.tween_property(appearance, "modulate", Color.WHITE, 0.05)
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.5)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

# ═══════════════════════════════════════════════════════════════
# 輔助函式
# ═══════════════════════════════════════════════════════════════
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta

func _turn_around() -> void:
	_direction *= -1.0
	_update_detector()

func _update_detector() -> void:
	if wall_detector:
		wall_detector.target_position.x = 20.0 * _direction
	if appearance:
		appearance.scale.x = -_direction

func _find_nearest_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("Players")
	if players.is_empty(): return null
	var nearest: Node2D = null
	var min_dist := INF
	for p in players:
		if not is_instance_valid(p): continue
		var d := global_position.distance_to(p.global_position)
		if d < min_dist:
			min_dist = d
			nearest = p
	return nearest

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.SHOOT:
			_state_timer = 0.6  # 停頓 0.6s 後射擊
		State.SHOCKWAVE:
			_state_timer = 0.8  # 停頓 0.8s 後震波

