extends Camera2D
## SceneCamera — 場景級攝影機，掛在 Scene 下而非 Player 下
## 透過 @export_node_path 綁定 Player，並用 4 個 Marker2D 設定各方向鏡頭邊界。
##
## 使用方式：
##   1. 在場景中選取 SceneCamera 節點。
##   2. Inspector → Target → Player Path：拖入 Player1 節點。
##   3. Inspector → Limits → 四個欄位分別拖入對應的 Marker2D 節點。

# ═══════════════════════════════════════════════════════════════
# EXPORT 參數
# ═══════════════════════════════════════════════════════════════

@export_group("Target")
## 要追蹤的玩家節點路徑（拖入 CharacterBody2D）
@export_node_path("CharacterBody2D") var player_path: NodePath

@export_group("Zoom")
## 攝影機縮放倍率（整數倍才清晰，建議 2/4/6/8）
@export_range(1, 8, 1) var cam_zoom: int = 4

@export_group("Follow")
## 前瞻偏移距離（tile 數，每 tile = 8px）
@export_range(0.0, 8.0, 0.5) var look_ahead_tiles: float = 2.0
## 前瞻追蹤插值速度
@export_range(1.0, 20.0, 0.5) var look_ahead_speed: float = 6.0
## 垂直偏移（負=讓玩家偏下方，正=偏上方）
@export var vertical_offset: float = -40.0

@export_group("Limits")
## 上邊界 Marker2D 路徑（留空 = 無限）
@export_node_path("Marker2D") var limit_top_path: NodePath
## 下邊界 Marker2D 路徑（留空 = 無限）
@export_node_path("Marker2D") var limit_bottom_path: NodePath
## 左邊界 Marker2D 路徑（留空 = 無限）
@export_node_path("Marker2D") var limit_left_path: NodePath
## 右邊界 Marker2D 路徑（留空 = 無限）
@export_node_path("Marker2D") var limit_right_path: NodePath

# ═══════════════════════════════════════════════════════════════
# 內部節點引用（_ready 時解析）
# ═══════════════════════════════════════════════════════════════
var _player:       CharacterBody2D
var _lim_top:      Marker2D
var _lim_bottom:   Marker2D
var _lim_left:     Marker2D
var _lim_right:    Marker2D

# ═══════════════════════════════════════════════════════════════
# 內部狀態
# ═══════════════════════════════════════════════════════════════
var _facing:      float = 1.0
var _look_offset: float = 0.0

# ═══════════════════════════════════════════════════════════════
# 初始化
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	make_current()

	# 解析 NodePath → 實際節點
	_player     = get_node_or_null(player_path)     as CharacterBody2D
	_lim_top    = get_node_or_null(limit_top_path)   as Marker2D
	_lim_bottom = get_node_or_null(limit_bottom_path) as Marker2D
	_lim_left   = get_node_or_null(limit_left_path)  as Marker2D
	_lim_right  = get_node_or_null(limit_right_path) as Marker2D

	# 套用縮放（唯一需要在 ready 設定的屬性）
	zoom = Vector2(cam_zoom, cam_zoom)

	# 關閉 Camera2D 內建 drag/smoothing（與手動 global_position 衝突）
	position_smoothing_enabled = false
	drag_horizontal_enabled    = false
	drag_vertical_enabled      = false

	# 套用鏡頭邊界
	_apply_limits()

func _apply_limits() -> void:
	limit_left   = int(_lim_left.global_position.x)   if _lim_left   != null else -10_000_000
	limit_right  = int(_lim_right.global_position.x)  if _lim_right  != null else  10_000_000
	limit_top    = int(_lim_top.global_position.y)     if _lim_top    != null else -10_000_000
	limit_bottom = int(_lim_bottom.global_position.y)  if _lim_bottom != null else  10_000_000

# ═══════════════════════════════════════════════════════════════
# 每幀更新：追蹤 Player + 前瞻偏移
# ═══════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if _player == null:
		return

	# 更新朝向
	if _player.velocity.x > 0.1:
		_facing =  1.0
	elif _player.velocity.x < -0.1:
		_facing = -1.0

	# 前瞻偏移插值
	var target_look := _facing * look_ahead_tiles * 8.0
	_look_offset     = lerp(_look_offset, target_look, delta * look_ahead_speed)

	# 追蹤 Player 位置
	global_position = _player.global_position
	offset          = Vector2(_look_offset, vertical_offset)
