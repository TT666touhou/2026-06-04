extends Camera2D
## MultiplayerCamera — 多人動態縮放鏡頭
## 追蹤場景中所有「Players」群組的節點，
## 自動計算包含所有玩家的邊界框並調整縮放。
## 畫面外的玩家會每秒受傷並顯示邊線指示器。

# ═══════════════════════════════════════════════════════════════
# EXPORT 參數
# ═══════════════════════════════════════════════════════════════
@export_group("Zoom")
## 最小縮放倍率（玩家集中時）
@export_range(1, 6, 1) var min_zoom: int = 2
## 最大縮放倍率（玩家分散時）
@export_range(1, 6, 1) var max_zoom: int = 4
## 縮放速度（插值速度）
@export_range(0.5, 10.0, 0.5) var zoom_lerp_speed: float = 3.0
## 攝影機移動插值速度
@export_range(1.0, 20.0, 0.5) var follow_speed: float = 5.0

@export_group("Padding")
## 邊界框外的額外空白（世界像素）
@export var frame_padding: float = 40.0

@export_group("Limits")
## 上邊界 Marker2D 路徑
@export_node_path("Marker2D") var limit_top_path: NodePath
## 下邊界 Marker2D 路徑
@export_node_path("Marker2D") var limit_bottom_path: NodePath
## 左邊界 Marker2D 路徑
@export_node_path("Marker2D") var limit_left_path: NodePath
## 右邊界 Marker2D 路徑
@export_node_path("Marker2D") var limit_right_path: NodePath

@export_group("Offscreen Damage")
## 每秒對畫面外玩家造成的傷害
@export var offscreen_damage_per_second: float = 1.0
## 傷害計時間隔（秒）
@export var damage_interval: float = 1.0

# ═══════════════════════════════════════════════════════════════
# 內部節點引用
# ═══════════════════════════════════════════════════════════════
var _lim_top:    Marker2D
var _lim_bottom: Marker2D
var _lim_left:   Marker2D
var _lim_right:  Marker2D

# ═══════════════════════════════════════════════════════════════
# 內部狀態
# ═══════════════════════════════════════════════════════════════
var _damage_timer: float = 0.0
var _current_zoom: float = 4.0

# ═══════════════════════════════════════════════════════════════
# 初始化
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	make_current()
	position_smoothing_enabled = false
	drag_horizontal_enabled    = false
	drag_vertical_enabled      = false

	_lim_top    = get_node_or_null(limit_top_path)    as Marker2D
	_lim_bottom = get_node_or_null(limit_bottom_path) as Marker2D
	_lim_left   = get_node_or_null(limit_left_path)   as Marker2D
	_lim_right  = get_node_or_null(limit_right_path)  as Marker2D

	_apply_limits()
	_current_zoom = float(max_zoom)
	zoom = Vector2(_current_zoom, _current_zoom)

func _apply_limits() -> void:
	limit_left   = int(_lim_left.global_position.x)   if _lim_left   != null else -10_000_000
	limit_right  = int(_lim_right.global_position.x)  if _lim_right  != null else  10_000_000
	limit_top    = int(_lim_top.global_position.y)     if _lim_top    != null else -10_000_000
	limit_bottom = int(_lim_bottom.global_position.y)  if _lim_bottom != null else  10_000_000

# ═══════════════════════════════════════════════════════════════
# 每幀更新
# ═══════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	var players := _get_alive_players()
	if players.is_empty():
		return

	# 1. 計算邊界框
	var bbox := _calc_bounding_box(players)

	# 2. 計算目標縮放
	var target_zoom := _calc_target_zoom(bbox)
	_current_zoom = lerp(_current_zoom, target_zoom, delta * zoom_lerp_speed)
	zoom = Vector2(_current_zoom, _current_zoom)

	# 3. 計算目標位置（邊界框中心）
	var target_pos := bbox.get_center()

	# 4. 套用鏡頭邊界 clamp
	var vp := get_viewport().get_visible_rect().size
	var half_w := vp.x / (2.0 * _current_zoom)
	var half_h := vp.y / (2.0 * _current_zoom)

	var min_x := float(limit_left)  + half_w
	var max_x := float(limit_right) - half_w
	var min_y := float(limit_top)   + half_h
	var max_y := float(limit_bottom) - half_h

	if min_x <= max_x:
		target_pos.x = clamp(target_pos.x, min_x, max_x)
	else:
		target_pos.x = (float(limit_left) + float(limit_right)) * 0.5
	if min_y <= max_y:
		target_pos.y = clamp(target_pos.y, min_y, max_y)
	else:
		target_pos.y = (float(limit_top) + float(limit_bottom)) * 0.5

	# 5. 移動鏡頭（平滑插值）
	global_position = lerp(global_position, target_pos, delta * follow_speed)
	offset = Vector2.ZERO

	# 6. 畫面外玩家傷害
	_damage_timer += delta
	if _damage_timer >= damage_interval:
		_damage_timer = 0.0
		_apply_offscreen_damage(players)

# ═══════════════════════════════════════════════════════════════
# 輔助函式
# ═══════════════════════════════════════════════════════════════
func _get_alive_players() -> Array[Node]:
	var result: Array[Node] = []
	for p in get_tree().get_nodes_in_group("Players"):
		if is_instance_valid(p) and p.visible:
			result.append(p)
	return result

func _calc_bounding_box(players: Array[Node]) -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for p in players:
		var pos: Vector2 = p.global_position
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x)
		max_pos.y = maxf(max_pos.y, pos.y)
	# 加入 padding
	min_pos -= Vector2(frame_padding, frame_padding)
	max_pos += Vector2(frame_padding, frame_padding)
	return Rect2(min_pos, max_pos - min_pos)

func _calc_target_zoom(bbox: Rect2) -> float:
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return float(max_zoom)
	# 計算需要的縮放以容納邊界框
	var zoom_for_w := vp.x / maxf(bbox.size.x, 1.0)
	var zoom_for_h := vp.y / maxf(bbox.size.y, 1.0)
	var required_zoom := minf(zoom_for_w, zoom_for_h)
	# clamp 到設定的範圍
	return clampf(required_zoom, float(min_zoom), float(max_zoom))

func _apply_offscreen_damage(players: Array[Node]) -> void:
	var _vp_rect := get_viewport_rect()  ## 預留，目前以手動計算取代
	# 轉換為世界座標的可見區域
	var cam_pos := global_position
	var vp_size := get_viewport().get_visible_rect().size
	var half_w := vp_size.x / (2.0 * _current_zoom)
	var half_h := vp_size.y / (2.0 * _current_zoom)
	var world_rect := Rect2(
		cam_pos.x - half_w,
		cam_pos.y - half_h,
		half_w * 2.0,
		half_h * 2.0
	)
	for p in players:
		if not is_instance_valid(p):
			continue
		var pos: Vector2 = p.global_position
		if not world_rect.has_point(pos):
			# 玩家在畫面外，造成傷害
			if p.has_method("take_damage"):
				p.take_damage(int(offscreen_damage_per_second))

## 取得玩家在螢幕上的位置（供 OffscreenIndicator 使用）
func get_player_screen_position(player: Node2D) -> Vector2:
	return get_viewport().get_canvas_transform() * player.global_position

## 取得目前世界可見區域
func get_world_visible_rect() -> Rect2:
	var cam_pos := global_position
	var vp_size := get_viewport().get_visible_rect().size
	var half_w := vp_size.x / (2.0 * _current_zoom)
	var half_h := vp_size.y / (2.0 * _current_zoom)
	return Rect2(cam_pos.x - half_w, cam_pos.y - half_h, half_w * 2.0, half_h * 2.0)
