extends CharacterBody2D
## Player1 — 基礎橫向移動控制器
## 操控：A/D 或 ←/→ 移動；Space / W / ↑ 跳躍（按住可連跳）
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

# ── 跳躍手感（Inspector 可調） ───────────────────────────────
@export_group("Jump Feel")
## Jump Buffer：提前按跳躍後的容錯時間（秒），落地時自動補觸發
## 建議值：0.10 ~ 0.20
@export_range(0.0, 0.3, 0.01) var jump_buffer_time: float = 0.15
## Coyote Time：踩空後仍可跳躍的寬限時間（秒）
## 建議值：0.08 ~ 0.15
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.12

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

# ── 跳躍手感計時器 ────────────────────────────────────────────
# 每個跳躍鍵分開追蹤（防止 W+Space 互干擾）
var _prev_space: bool  = false
var _prev_w    : bool  = false
var _prev_up   : bool  = false
# Jump Buffer：記住空中提前按下的跳躍輸入，倒數到 0 失效
var _jump_buffer: float = 0.0
# Coyote Time：離開地面後的寬限倒數
var _coyote    : float = 0.0
# 上一幀是否在地面（用來偵測「剛離開地面」的邊緣）
var _was_on_floor: bool = false

# ── 初始化：將 Export 參數同步到 Camera2D ────────────────────
func _ready() -> void:
	_sync_camera_params()

## 手動呼叫可即時更新鏡頭設定（執行期調整也有效）
func _sync_camera_params() -> void:
	_camera.zoom                      = Vector2(cam_zoom, cam_zoom)
	_camera.position_smoothing_enabled = position_smoothing
	_camera.position_smoothing_speed   = smoothing_speed
	_camera.drag_horizontal_enabled    = drag_horizontal
	_camera.drag_left_margin           = drag_left_margin
	_camera.drag_right_margin          = drag_right_margin

# ── 物理更新 ──────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_tick_jump_timers(delta)
	_handle_jump()
	_handle_horizontal(delta)
	_update_camera(delta)
	move_and_slide()
	_was_on_floor = is_on_floor()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

# ── 跳躍計時器（每幀更新 buffer 與 coyote） ───────────────────
func _tick_jump_timers(delta: float) -> void:
	var any_jump_held := (
		Input.is_key_pressed(KEY_SPACE) or
		Input.is_key_pressed(KEY_W)     or
		Input.is_key_pressed(KEY_UP)
	)

	# 連跳：剛落地且跳躍鍵仍按住 → 重新填滿 buffer，下一行邏輯立即觸發跳躍
	if not _was_on_floor and is_on_floor() and any_jump_held:
		_jump_buffer = jump_buffer_time

	# Coyote Time：剛離開地面那幀開始倒數
	if _was_on_floor and not is_on_floor():
		_coyote = coyote_time
	elif is_on_floor():
		_coyote = 0.0
	else:
		_coyote = max(0.0, _coyote - delta)

	# Jump Buffer：每幀倒數
	_jump_buffer = max(0.0, _jump_buffer - delta)

# ── 跳躍邏輯（Buffer + Coyote） ───────────────────────────────
func _handle_jump() -> void:
	var cur_space := Input.is_key_pressed(KEY_SPACE)
	var cur_w     := Input.is_key_pressed(KEY_W)
	var cur_up    := Input.is_key_pressed(KEY_UP)

	# 任一鍵剛按下 → 寫入 buffer（不管是否在地面）
	var just_pressed := (
		(cur_space and not _prev_space) or
		(cur_w     and not _prev_w)     or
		(cur_up    and not _prev_up)
	)
	if just_pressed:
		_jump_buffer = jump_buffer_time

	# 可跳條件：在地面 OR 在 coyote 寬限內
	var can_jump := is_on_floor() or (_coyote > 0.0)

	# Buffer 有效 + 可跳 → 執行跳躍，同時清空兩個計時器
	if _jump_buffer > 0.0 and can_jump:
		velocity.y   = jump_velocity
		_jump_buffer = 0.0
		_coyote      = 0.0    # 防止 coyote 重複觸發

	_prev_space = cur_space
	_prev_w     = cur_w
	_prev_up    = cur_up

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
