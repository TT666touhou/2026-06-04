extends CharacterBody2D
## Player1 — 基礎橫向移動控制器
## 操控：A/D 或 ←/→ 移動；Space / W / ↑ 跳躍

# ── 移動參數 ──────────────────────────────────────────────────
const SPEED         := 200.0   ## 水平最大速度（px/s）
const JUMP_VELOCITY := -420.0  ## 跳躍初速（負 = 向上）
const GRAVITY       := 980.0   ## 重力加速度
const FRICTION      := 800.0   ## 地面制動加速度（停止時）

# ── 鏡頭前瞻參數 ──────────────────────────────────────────────
const LOOK_AHEAD_DIST  := 48.0 ## 前瞻最大偏移量（px）
const LOOK_AHEAD_SPEED := 5.0  ## 前瞻追蹤速度（lerp 係數）

@onready var _camera: Camera2D = $Camera2D

var _look_offset: float = 0.0
var _facing    : float = 1.0    ## 面向：+1 右、-1 左
var _jump_held : bool  = false   ## 模擬 just_pressed

# ── 物理更新 ──────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal(delta)
	_update_camera(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _handle_jump() -> void:
	var held := (
		Input.is_key_pressed(KEY_SPACE) or
		Input.is_key_pressed(KEY_W)     or
		Input.is_key_pressed(KEY_UP)
	)
	if held and not _jump_held and is_on_floor():
		velocity.y = JUMP_VELOCITY
	_jump_held = held

func _handle_horizontal(delta: float) -> void:
	var dir := float(
		int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) -
		int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	)
	if dir != 0.0:
		_facing    = sign(dir)
		velocity.x = dir * SPEED
	else:
		# 地面快速制動；空中緩慢減速
		var decel := FRICTION if is_on_floor() else FRICTION * 0.3
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

func _update_camera(delta: float) -> void:
	var target   := _facing * LOOK_AHEAD_DIST
	_look_offset  = lerp(_look_offset, target, delta * LOOK_AHEAD_SPEED)
	_camera.offset = Vector2(_look_offset, 0.0)
