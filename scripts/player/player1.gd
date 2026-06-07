extends CharacterBody2D
## Player1 — 基礎橫向移動控制器
## 操控：A/D 或 ←/→ 移動；Space / W / ↑ 跳躍
##
## 所有移動與鏡頭參數均可在 Inspector 中即時調整。

# ── 移動參數（Inspector 可調） ────────────────────────────────
@export_group("Movement")
## 水平最大速度（px/s）
@export var speed: float = 200.0
## 跳躍初速（負 = 向上）
@export var jump_velocity: float = -420.0
## 重力加速度（px/s²）
@export var gravity: float = 980.0
## 地面制動加速度
@export var friction: float = 800.0
## 空中水平摩擦倍率（0=無摩擦 1=與地面相同）
@export_range(0.0, 1.0, 0.05) var air_friction_factor: float = 0.3

# ── 鏡頭參數（Inspector 可調） ────────────────────────────────
@export_group("Camera")
## 縮放倍率（整數像素藝術請保持整數）
@export var cam_zoom: float = 4.0
## 前瞻最大偏移（tile 單位，1 tile = 8 px）
@export var look_ahead_tiles: float = 2.0
## 前瞻追蹤速度（lerp 係數，越大越快跟上）
@export_range(1.0, 20.0, 0.5) var look_ahead_speed: float = 6.0
## 位置平滑開關
@export var position_smoothing: bool = true
## 位置平滑速度
@export_range(1.0, 30.0, 0.5) var smoothing_speed: float = 10.0
## 水平拖拽死區開關（左右移動不立即移動鏡頭）
@export var drag_horizontal: bool = true
## 拖拽左邊界（0=最左 0.5=中間）
@export_range(0.0, 0.5, 0.05) var drag_left_margin: float = 0.35
## 拖拽右邊界（0=最右 0.5=中間）
@export_range(0.0, 0.5, 0.05) var drag_right_margin: float = 0.35

@onready var _camera: Camera2D = $Camera2D

var _look_offset: float = 0.0
var _facing    : float = 1.0
var _jump_held : bool  = false

# ── 初始化：將 Export 參數同步到 Camera2D ────────────────────
func _ready() -> void:
	_sync_camera_params()

## 手動呼叫可即時更新鏡頭設定（執行期調整也有效）
func _sync_camera_params() -> void:
	_camera.zoom                     = Vector2(cam_zoom, cam_zoom)
	_camera.position_smoothing_enabled = position_smoothing
	_camera.position_smoothing_speed   = smoothing_speed
	_camera.drag_horizontal_enabled    = drag_horizontal
	_camera.drag_left_margin           = drag_left_margin
	_camera.drag_right_margin          = drag_right_margin

# ── 物理更新 ──────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal(delta)
	_update_camera(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func _handle_jump() -> void:
	var held := (
		Input.is_key_pressed(KEY_SPACE) or
		Input.is_key_pressed(KEY_W)     or
		Input.is_key_pressed(KEY_UP)
	)
	if held and not _jump_held and is_on_floor():
		velocity.y = jump_velocity
	_jump_held = held

func _handle_horizontal(delta: float) -> void:
	var dir := float(
		int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) -
		int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	)
	if dir != 0.0:
		_facing    = sign(dir)
		velocity.x = dir * speed
	else:
		var decel := friction if is_on_floor() else friction * air_friction_factor
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

func _update_camera(delta: float) -> void:
	var look_ahead_px := look_ahead_tiles * 8.0   # 1 tile = 8 px
	var target        := _facing * look_ahead_px
	_look_offset       = lerp(_look_offset, target, delta * look_ahead_speed)
	_camera.offset     = Vector2(_look_offset, 0.0)
