extends Camera2D
## SceneCamera — 場景級攝影機，掛在 Scene 下而非 Player 下
## 透過 @export 綁定 Player，並用 4 個 Marker2D 設定各方向的鏡頭邊界。
##
## 使用方式：
##   1. 在場景中新增 Camera2D 節點，將此腳本掛上。
##   2. 在 Inspector → Target 填入 Player 節點。
##   3. （選填）在 Inspector → Limits 各欄位拖入 Marker2D，
##      對應方向的邊界即會生效；留空則該方向無限。

# ═══════════════════════════════════════════════════════════════
# EXPORT 參數
# ═══════════════════════════════════════════════════════════════

@export_group("Target")
## 要追蹤的玩家節點（拖入 CharacterBody2D）
@export var player: CharacterBody2D

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
## 啟用位置平滑跟隨
@export var position_smoothing: bool = false
## 平滑速度（position_smoothing = true 時才有效）
@export_range(1.0, 30.0, 0.5) var smoothing_speed: float = 10.0
## 啟用水平拖拽死區
@export var drag_horizontal: bool = true
@export_range(0.0, 0.5, 0.05) var drag_margin_left: float = 0.35
@export_range(0.0, 0.5, 0.05) var drag_margin_right: float = 0.35

@export_group("Limits")
## 上邊界 Marker2D：攝影機不超過此節點的 Y 座標（留空 = 無限）
@export var limit_top_marker: Marker2D
## 下邊界 Marker2D：攝影機不超過此節點的 Y 座標（留空 = 無限）
@export var limit_bottom_marker: Marker2D
## 左邊界 Marker2D：攝影機不超過此節點的 X 座標（留空 = 無限）
@export var limit_left_marker: Marker2D
## 右邊界 Marker2D：攝影機不超過此節點的 X 座標（留空 = 無限）
@export var limit_right_marker: Marker2D

# ═══════════════════════════════════════════════════════════════
# 內部狀態
# ═══════════════════════════════════════════════════════════════
var _facing:      float = 1.0   # 1=右, -1=左
var _look_offset: float = 0.0   # 前瞻偏移（插值目標）

# ═══════════════════════════════════════════════════════════════
# 初始化
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	_apply_settings()
	_apply_limits()

func _apply_settings() -> void:
	zoom                       = Vector2(cam_zoom, cam_zoom)
	position_smoothing_enabled = position_smoothing
	position_smoothing_speed   = smoothing_speed
	drag_horizontal_enabled    = drag_horizontal
	drag_left_margin           = drag_margin_left
	drag_right_margin          = drag_margin_right

func _apply_limits() -> void:
	limit_left   = int(limit_left_marker.global_position.x)   if limit_left_marker   != null else -10_000_000
	limit_right  = int(limit_right_marker.global_position.x)  if limit_right_marker  != null else  10_000_000
	limit_top    = int(limit_top_marker.global_position.y)    if limit_top_marker    != null else -10_000_000
	limit_bottom = int(limit_bottom_marker.global_position.y) if limit_bottom_marker != null else  10_000_000

# ═══════════════════════════════════════════════════════════════
# 每幀更新：追蹤 Player + 前瞻偏移
# ═══════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if player == null:
		return

	# 更新朝向（根據 Player 的水平速度）
	if player.velocity.x > 0.1:
		_facing =  1.0
	elif player.velocity.x < -0.1:
		_facing = -1.0

	# 前瞻偏移插值
	var target_look := _facing * look_ahead_tiles * 8.0
	_look_offset     = lerp(_look_offset, target_look, delta * look_ahead_speed)

	# 全域位置追蹤 Player（Camera2D 不是 Player 的子節點）
	global_position = player.global_position
	offset          = Vector2(_look_offset, vertical_offset)
