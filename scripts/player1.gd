extends CharacterBody2D

## Player 1 — 基本移動控制器
## 輸入：A/D 或方向鍵移動，Space 或 W 跳躍
## 鏡頭：Camera2D 帶死區 + 前瞻偏移

# ── 移動參數 ──────────────────────────────────────────
const SPEED: float = 200.0          ## 最高水平速度（px/s）
const JUMP_VELOCITY: float = -420.0 ## 跳躍初速（負值 = 向上）
const GRAVITY: float = 980.0        ## 重力加速度
const FRICTION_GROUND: float = 12.0 ## 地面摩擦倍數（越大越快停止）
const FRICTION_AIR: float = 3.0     ## 空中摩擦倍數

# ── 鏡頭前瞻參數 ──────────────────────────────────────
const LOOK_AHEAD_X: float = 80.0    ## 水平前瞻距離（px）
const LOOK_AHEAD_SPEED: float = 5.0 ## 前瞻插值速度

@onready var camera: Camera2D = $Camera2D

var _look_offset: Vector2 = Vector2.ZERO

# ──────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal(delta)
	move_and_slide()
	_update_look_ahead(delta)

# ── 重力 ──────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

# ── 跳躍 ──────────────────────────────────────────────
func _handle_jump() -> void:
	var jump: bool = (
		Input.is_key_pressed(KEY_SPACE) or
		Input.is_key_pressed(KEY_W)     or
		Input.is_key_pressed(KEY_UP)
	)
	if jump and is_on_floor():
		velocity.y = JUMP_VELOCITY

# ── 水平移動 ──────────────────────────────────────────
func _handle_horizontal(delta: float) -> void:
	var dir: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0

	if dir != 0.0:
		velocity.x = dir * SPEED
	else:
		# 有方向感的摩擦減速
		var friction: float = FRICTION_GROUND if is_on_floor() else FRICTION_AIR
		velocity.x = move_toward(velocity.x, 0.0, SPEED * friction * delta)

# ── 鏡頭前瞻 ─────────────────────────────────────────
## 角色往右走時鏡頭向右偏移，讓玩家看到更多前方空間
func _update_look_ahead(delta: float) -> void:
	var target: Vector2 = Vector2.ZERO
	if abs(velocity.x) > 10.0:
		target.x = sign(velocity.x) * LOOK_AHEAD_X
	_look_offset = _look_offset.lerp(target, LOOK_AHEAD_SPEED * delta)
	camera.offset = _look_offset
