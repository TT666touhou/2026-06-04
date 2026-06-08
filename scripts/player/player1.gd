extends CharacterBody2D
## Player1 — 橫向移動控制器（含耐力系統、二段跳、蹬牆跳、翻滾）
## 操控：A/D 或 ←/→ 移動；Space / W / ↑ 跳躍；Shift 翻滾

# ═══════════════════════════════════════════════════════════════
# EXPORT 參數區塊（全部可在 Inspector 即時調整）
# ═══════════════════════════════════════════════════════════════

# ── 移動 ────────────────────────────────────────────────────────
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

# ── 跳躍手感 ────────────────────────────────────────────────────
@export_group("Jump Feel")
## Jump Buffer：提前按跳躍後的容錯時間（秒），落地時自動補觸發
@export_range(0.0, 0.3, 0.01) var jump_buffer_time: float = 0.15
## Coyote Time：踩空後仍可跳躍的寬限時間（秒）
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.12

# ── 耐力系統 ────────────────────────────────────────────────────
@export_group("Stamina")
## 最大耐力格數（float 表示，3.0 = 3 格全滿）
@export var max_stamina: float = 3.0
## 耐力恢復速度（格/秒），1.25 秒恢復 1 格
@export_range(0.1, 3.0, 0.05) var stamina_recovery: float = 0.8

# ── 二段跳 ──────────────────────────────────────────────────────
@export_group("Double Jump")
## 二段跳初速（負 = 向上，略低於普通跳）
@export var double_jump_velocity: float = -320.0
## 二段跳後重力縮放（短暫輕化感）
@export_range(0.5, 1.0, 0.05) var double_jump_gravity_scale: float = 0.8
## 重力縮放持續時間（秒）
@export_range(0.0, 0.5, 0.02) var double_jump_gravity_duration: float = 0.1

# ── 蹬牆跳 ──────────────────────────────────────────────────────
@export_group("Wall Jump")
## 蹬牆跳垂直速度（負 = 向上）
@export var wall_jump_vertical: float = -380.0
## 蹬牆跳水平速度（離牆方向）
@export var wall_jump_horizontal: float = 180.0
## 蹬牆跳後水平控制鎖定時間（秒），防止立即貼回牆
@export_range(0.0, 0.5, 0.02) var wall_jump_lock_time: float = 0.15

# ── 翻滾 ────────────────────────────────────────────────────────
@export_group("Roll")
## 翻滾速度（px/s，跟隨面向方向）
@export var roll_speed: float = 400.0
## 翻滾持續時間（秒）
@export_range(0.05, 0.5, 0.01) var roll_duration: float = 0.2
## 無敵幀時間（秒，翻滾中段，應 <= roll_duration）
@export_range(0.0, 0.5, 0.01) var roll_invincible_time: float = 0.12
## 翻滾後速度緩衝時間（秒）
@export_range(0.0, 0.3, 0.01) var roll_cooldown: float = 0.1

# ── 攝影機 ──────────────────────────────────────────────────────
@export_group("Camera")
## 縮放倍率（整數像素藝術請保持整數）
@export var cam_zoom: float = 4.0
## 攝影機垂直偏移（遊戲像素，負值=鏡頭上移，玩家視覺上偏下方）
## -40px 使玩家位於畫面約 72% 高度位置（標準平台遊戲慣例）
@export var cam_vertical_offset: float = -40.0
## 前瞻最大偏移（tile 單位，1 tile = 8 px）
@export var look_ahead_tiles: float = 2.0
## 前瞻追蹤速度（lerp 係數）
@export_range(1.0, 20.0, 0.5) var look_ahead_speed: float = 6.0
## 位置平滑開關
@export var position_smoothing: bool = true
## 位置平滑速度
@export_range(1.0, 30.0, 0.5) var smoothing_speed: float = 10.0
## 水平拖拽死區開關
@export var drag_horizontal: bool = true
## 拖拽左邊界
@export_range(0.0, 0.5, 0.05) var drag_left_margin: float = 0.35
## 拖拽右邊界
@export_range(0.0, 0.5, 0.05) var drag_right_margin: float = 0.35
## 下邊界標記節點：將任何 Node2D（建議用 Marker2D）拖入此欄位
## 攝影機的 limit_bottom = 該節點在世界中的 Y 座標
## 在場景中拖拉此節點即可即時調整邊界位置
## 留空則不設定下邊界（無限往下）
@export var camera_bottom_marker: NodePath = NodePath("")

# ═══════════════════════════════════════════════════════════════
# 節點引用
# ═══════════════════════════════════════════════════════════════
@onready var _camera    : Camera2D  = $Camera2D
@onready var _stamina_ui: Node2D    = $StaminaBar

# ═══════════════════════════════════════════════════════════════
# 內部狀態變數
# ═══════════════════════════════════════════════════════════════

# ── 通用 ──────────────────────────────────────────────────────
var _look_offset  : float = 0.0
var _facing       : float = 1.0
var _was_on_floor : bool  = false

# ── 跳躍手感 ────────────────────────────────────────────────────
var _prev_space  : bool  = false
var _prev_w      : bool  = false
var _prev_up     : bool  = false
var _jump_buffer : float = 0.0
var _coyote      : float = 0.0

# ── 耐力 ────────────────────────────────────────────────────────
var _stamina: float = 3.0   # 共用 float（0.0 ~ max_stamina）

# ── 二段跳 ──────────────────────────────────────────────────────
var _air_jump_used        : bool  = false   # 本次起跳是否已用過二段跳
var _dj_gravity_timer     : float = 0.0    # 二段跳後重力縮放倒數

# ── 蹬牆跳 ──────────────────────────────────────────────────────
var _wall_jump_lock       : float = 0.0    # > 0 = 水平控制鎖定中
var _wall_dir             : float = 0.0    # 牆面方向（-1 左牆 / +1 右牆）

# ── 翻滾 ────────────────────────────────────────────────────────
var _is_rolling       : bool  = false
var _roll_timer       : float = 0.0    # 翻滾剩餘時間倒數
var _roll_cooldown    : float = 0.0    # 翻滾後緩衝倒數
var _prev_shift       : bool  = false
## 目前是否處於無敵狀態（外部系統可讀取此屬性）
var is_invincible     : bool  = false

# ═══════════════════════════════════════════════════════════════
# 初始化
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	_sync_camera_params()
	_setup_camera_limit()
	_stamina = max_stamina

## 將 Export 參數同步到 Camera2D（可執行期呼叫以即時更新）
func _sync_camera_params() -> void:
	_camera.zoom                       = Vector2(cam_zoom, cam_zoom)
	_camera.position_smoothing_enabled = position_smoothing
	_camera.position_smoothing_speed   = smoothing_speed
	_camera.drag_horizontal_enabled    = drag_horizontal
	_camera.drag_left_margin           = drag_left_margin
	_camera.drag_right_margin          = drag_right_margin

## 根據 camera_bottom_marker 節點的 Y 座標設定攝影機下邊界
func _setup_camera_limit() -> void:
	_camera.limit_left   = -10000000
	_camera.limit_right  =  10000000
	_camera.limit_top    = -10000000

	if camera_bottom_marker.is_empty():
		_camera.limit_bottom = 10000000
		return

	var marker := get_node_or_null(camera_bottom_marker)
	if marker == null:
		_camera.limit_bottom = 10000000
		return

	# 直接使用節點的全域 Y 座標作為下邊界（世界像素單位）
	_camera.limit_bottom = int(marker.global_position.y)

# ═══════════════════════════════════════════════════════════════
# 物理更新主迴圈
# ═══════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_apply_gravity(delta)

	if _is_rolling:
		_tick_roll(delta)
	else:
		_handle_roll_input()
		_handle_jump()
		_handle_horizontal(delta)

	_update_camera(delta)
	_update_stamina_ui()
	move_and_slide()
	_post_move(delta)

## 落地後重置各種每跳狀態
func _post_move(_delta: float) -> void:
	if is_on_floor() and not _was_on_floor:
		_air_jump_used = false    # 落地重置二段跳
	_was_on_floor = is_on_floor()

# ═══════════════════════════════════════════════════════════════
# 各計時器倒數
# ═══════════════════════════════════════════════════════════════
func _tick_timers(delta: float) -> void:
	# Jump Buffer
	_jump_buffer = max(0.0, _jump_buffer - delta)

	# Coyote Time
	if _was_on_floor and not is_on_floor():
		_coyote = coyote_time
	elif is_on_floor():
		_coyote = 0.0
	else:
		_coyote = max(0.0, _coyote - delta)

	# 蹬牆跳控制鎖定
	_wall_jump_lock = max(0.0, _wall_jump_lock - delta)

	# 二段跳重力縮放
	_dj_gravity_timer = max(0.0, _dj_gravity_timer - delta)

	# 翻滾後緩衝
	_roll_cooldown = max(0.0, _roll_cooldown - delta)

	# 耐力恢復（每幀 +stamina_recovery * delta，上限 max_stamina）
	_stamina = min(_stamina + stamina_recovery * delta, max_stamina)

# ═══════════════════════════════════════════════════════════════
# 耐力工具函式
# ═══════════════════════════════════════════════════════════════
## 是否有足夠耐力（>= 1 格）
func has_stamina() -> bool:
	return _stamina >= 1.0

## 消耗 1 格耐力，並通知 UI 播放閃爍
func consume_stamina() -> void:
	var slot_before := floori(_stamina)   # 消耗前是第幾格滿
	_stamina = max(_stamina - 1.0, 0.0)
	var slot_after := floori(_stamina)    # 消耗後是第幾格滿
	# 通知消耗掉的那格閃爍
	var flash_slot := slot_after          # 消耗後最高滿格 = 剛變暗的那格
	if _stamina_ui != null and _stamina_ui.has_method("trigger_flash"):
		_stamina_ui.call("trigger_flash", flash_slot)

# ═══════════════════════════════════════════════════════════════
# 重力
# ═══════════════════════════════════════════════════════════════
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g_scale := double_jump_gravity_scale if _dj_gravity_timer > 0.0 else 1.0
	velocity.y += gravity * g_scale * delta

# ═══════════════════════════════════════════════════════════════
# 翻滾
# ═══════════════════════════════════════════════════════════════
func _handle_roll_input() -> void:
	var cur_shift := Input.is_key_pressed(KEY_SHIFT)
	var just_shift := cur_shift and not _prev_shift
	_prev_shift = cur_shift

	if just_shift and has_stamina() and _roll_cooldown <= 0.0:
		_start_roll()

func _start_roll() -> void:
	consume_stamina()
	_is_rolling  = true
	_roll_timer  = roll_duration
	# 翻滾開始時立即進入無敵（在 roll 中段）
	# 實際無敵在 _tick_roll 中按時間計算

func _tick_roll(delta: float) -> void:
	_roll_timer = max(0.0, _roll_timer - delta)

	# 無敵幀：翻滾中段（剩餘時間在 roll_invincible_time 內）
	is_invincible = (_roll_timer <= roll_invincible_time)

	# 翻滾期間強制水平速度
	velocity.x = _facing * roll_speed

	if _roll_timer <= 0.0:
		# 翻滾結束
		_is_rolling  = false
		is_invincible = false
		_roll_cooldown = roll_cooldown
		# 翻滾後速度回到 speed（讓玩家不衝過頭）
		velocity.x = _facing * speed

# ═══════════════════════════════════════════════════════════════
# 跳躍（普通跳 + 二段跳 + 蹬牆跳）
# ═══════════════════════════════════════════════════════════════
func _handle_jump() -> void:
	var cur_space := Input.is_key_pressed(KEY_SPACE)
	var cur_w     := Input.is_key_pressed(KEY_W)
	var cur_up    := Input.is_key_pressed(KEY_UP)

	var just_pressed := (
		(cur_space and not _prev_space) or
		(cur_w     and not _prev_w)     or
		(cur_up    and not _prev_up)
	)

	if just_pressed:
		_jump_buffer = jump_buffer_time

	# ── 蹬牆跳（優先於普通跳）────────────────────────────────────
	var on_wall := is_on_wall() and not is_on_floor()
	if _jump_buffer > 0.0 and on_wall and has_stamina():
		# 計算牆面方向
		var wall_normal := get_wall_normal()
		_wall_dir = sign(wall_normal.x)   # 牆在左則 normal 向右(+1)，牆在右則 normal 向左(-1)
		velocity.y = wall_jump_vertical
		velocity.x = _wall_dir * wall_jump_horizontal
		_wall_jump_lock = wall_jump_lock_time
		_air_jump_used  = false           # 蹬牆跳重置二段跳次數
		consume_stamina()
		_jump_buffer = 0.0
		_prev_space  = cur_space
		_prev_w      = cur_w
		_prev_up     = cur_up
		return

	# ── 普通跳 / Coyote ────────────────────────────────────────
	var can_normal_jump := is_on_floor() or (_coyote > 0.0)
	if _jump_buffer > 0.0 and can_normal_jump:
		velocity.y   = jump_velocity
		_jump_buffer = 0.0
		_coyote      = 0.0
		_prev_space  = cur_space
		_prev_w      = cur_w
		_prev_up     = cur_up
		return

	# ── 二段跳（空中，且普通跳不成立）────────────────────────────
	if just_pressed and not is_on_floor() and not _air_jump_used and has_stamina():
		velocity.y         = double_jump_velocity
		_air_jump_used     = true
		_dj_gravity_timer  = double_jump_gravity_duration
		consume_stamina()
		_jump_buffer       = 0.0

	_prev_space = cur_space
	_prev_w     = cur_w
	_prev_up    = cur_up

# ═══════════════════════════════════════════════════════════════
# 水平移動
# ═══════════════════════════════════════════════════════════════
func _handle_horizontal(delta: float) -> void:
	# 蹬牆跳後鎖定水平控制
	if _wall_jump_lock > 0.0:
		return

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

# ═══════════════════════════════════════════════════════════════
# 攝影機更新
# ═══════════════════════════════════════════════════════════════
func _update_camera(delta: float) -> void:
	var look_ahead_px := look_ahead_tiles * 8.0
	var target        := _facing * look_ahead_px
	_look_offset       = lerp(_look_offset, target, delta * look_ahead_speed)
	# 同時套用前瞻偏移（X）和垂直偏移（Y，讓玩家在畫面偏下方）
	_camera.offset = Vector2(_look_offset, cam_vertical_offset)

# ═══════════════════════════════════════════════════════════════
# 耐力 UI 更新
# ═══════════════════════════════════════════════════════════════
func _update_stamina_ui() -> void:
	if _stamina_ui != null:
		_stamina_ui.stamina = _stamina
