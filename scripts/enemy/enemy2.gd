extends CharacterBody2D

@export var stats: EnemyStats

@onready var appearance: Sprite2D = %Appearance
@onready var player_detector: Area2D = $PlayerDetector
@onready var raycast: RayCast2D = $RayCast2D
@onready var telegraph_line: Line2D = $TelegraphLine
@onready var laser_outer: Line2D = $LaserOuter
@onready var laser_inner: Line2D = $LaserInner

enum State { IDLE, NOTICE, FIRE }
var current_state: State = State.IDLE
var state_timer: float = 0.0

var current_health: int = 1
var target_player: Node2D = null

# 雷射設定
var max_laser_length: float = 300.0

func _ready() -> void:
	if stats:
		current_health = stats.max_health
	if player_detector:
		player_detector.body_entered.connect(_on_player_entered)
		player_detector.body_exited.connect(_on_player_exited)
		
	telegraph_line.visible = false
	laser_outer.visible = false
	laser_inner.visible = false
	
	# 設定 Raycast 的碰撞層 (只偵測玩家(Layer 2)與牆壁(Layer 1))
	raycast.collision_mask = 3

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.NOTICE:
			_notice_state(delta)
		State.FIRE:
			_fire_state(delta)

func _idle_state(delta: float) -> void:
	if target_player:
		current_state = State.NOTICE
		state_timer = 1.0 # 瞄準 1 秒
		telegraph_line.visible = true
		
		# 本體閃爍紅光警告
		var tween = create_tween()
		tween.set_loops(10)
		tween.tween_property(appearance, "modulate", Color("#E55C5C"), 0.05)
		tween.tween_property(appearance, "modulate", Color.WHITE, 0.05)

func _notice_state(delta: float) -> void:
	state_timer -= delta
	
	if target_player:
		# 瞄準玩家 (平滑轉向或直接對準)
		var aim_dir = (target_player.global_position - global_position).normalized()
		raycast.target_position = aim_dir * max_laser_length
		
		# 更新 Telegraph Line
		telegraph_line.points[0] = Vector2.ZERO
		raycast.force_raycast_update()
		if raycast.is_colliding():
			telegraph_line.points[1] = to_local(raycast.get_collision_point())
		else:
			telegraph_line.points[1] = raycast.target_position
			
	if state_timer <= 0:
		current_state = State.FIRE
		state_timer = 0.5 # 雷射持續 0.5 秒
		telegraph_line.visible = false
		laser_outer.visible = true
		laser_inner.visible = true
		
		# 鎖定發射方向，重置 appearance modulate
		appearance.modulate = Color.WHITE

func _fire_state(delta: float) -> void:
	state_timer -= delta
	
	# 更新雷射外觀長度
	laser_outer.points[0] = Vector2.ZERO
	laser_inner.points[0] = Vector2.ZERO
	
	raycast.force_raycast_update()
	var end_point = raycast.target_position
	if raycast.is_colliding():
		end_point = to_local(raycast.get_collision_point())
		
		# 傷害判定
		var collider = raycast.get_collider()
		if collider and collider.name.begins_with("Player"):
			if collider.has_method("take_damage"):
				collider.take_damage(1) # 雷射傷害
	
	laser_outer.points[1] = end_point
	laser_inner.points[1] = end_point
	
	if state_timer <= 0:
		laser_outer.visible = false
		laser_inner.visible = false
		current_state = State.IDLE
		# 發射完畢後會有短暫冷卻，這裡用 IDLE 狀態但如果不清空 target_player 就會立刻再次 NOTICE
		# 若要強制冷卻，可加個 Cooldown 狀態

func _on_player_entered(body: Node2D) -> void:
	if body.name.begins_with("Player"):
		target_player = body

func _on_player_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null
		if current_state == State.NOTICE:
			# 玩家逃離範圍，取消瞄準
			current_state = State.IDLE
			telegraph_line.visible = false
			appearance.modulate = Color.WHITE

func take_damage(damage: int) -> void:
	current_health -= damage
	print("Enemy2 took %d damage! Health remaining: %d" % [damage, current_health])
	
	var tween = create_tween()
	appearance.modulate = Color(10, 10, 10, 1) # 閃白
	tween.tween_property(appearance, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	print("Enemy2 died!")
	queue_free()
