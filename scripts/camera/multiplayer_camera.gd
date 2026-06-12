extends Camera2D
## MultiplayerCamera — 追蹤所有玩家的動態相機
## 策略：計算所有玩家的包圍盒中心，動態縮放讓所有人都在畫面內
##
## 使用方式：
##   將此場景/腳本作為主場景的子節點，不需要設定 target
##   它自動從 group "Players" 尋找所有玩家

@export_group("Zoom")
## 最大縮放（玩家靠近時）
@export var max_zoom: float = 4.0
## 最小縮放（玩家分散時）
@export var min_zoom: float = 1.5
## 玩家間距多寬時開始縮小（像素）
@export var zoom_margin: float = 80.0

@export_group("Follow")
## 相機追蹤插值速度（越大越緊）
@export var follow_speed: float = 5.0
## 縮放插值速度
@export var zoom_speed: float = 3.0
## 垂直偏移（負=讓玩家偏畫面下方）
@export var vertical_offset: float = -20.0

@export_group("Limits")
@export_node_path("Marker2D") var limit_top_path: NodePath
@export_node_path("Marker2D") var limit_bottom_path: NodePath
@export_node_path("Marker2D") var limit_left_path: NodePath
@export_node_path("Marker2D") var limit_right_path: NodePath

# ── 內部狀態 ──────────────────────────────────────────────────────
var _target_pos: Vector2 = Vector2.ZERO
var _target_zoom: float = 4.0

func _ready() -> void:
	make_current()
	position_smoothing_enabled = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	
	_target_zoom = max_zoom
	zoom = Vector2(max_zoom, max_zoom)
	
	# 套用邊界
	var lim_top    := get_node_or_null(limit_top_path)    as Marker2D
	var lim_bottom := get_node_or_null(limit_bottom_path) as Marker2D
	var lim_left   := get_node_or_null(limit_left_path)   as Marker2D
	var lim_right  := get_node_or_null(limit_right_path)  as Marker2D
	
	## ⚠️ Camera2D.limit_* 屬性是 int。
	## 必須明確用 roundi() 轉換，避免 float→int narrowing conversion。
	## 三元運算符 (if/else) 的兩個分支型別必須完全一致，
	## 所以改用 if/else 區塊寫法，避免 "ternary not mutually compatible" 警告。
	if lim_top != null:
		limit_top = roundi(lim_top.global_position.y)
	else:
		limit_top = -10_000_000

	if lim_bottom != null:
		limit_bottom = roundi(lim_bottom.global_position.y)
	else:
		limit_bottom = 10_000_000

	if lim_left != null:
		limit_left = roundi(lim_left.global_position.x)
	else:
		limit_left = -10_000_000

	if lim_right != null:
		limit_right = roundi(lim_right.global_position.x)
	else:
		limit_right = 10_000_000


func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("Players")
	
	if players.is_empty():
		return
	
	# ── 計算所有玩家的包圍盒 ────────────────────────────────────
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var center := Vector2.ZERO
	
	for player in players:
		var pos: Vector2 = player.global_position
		min_x = minf(min_x, pos.x)
		max_x = maxf(max_x, pos.x)
		min_y = minf(min_y, pos.y)
		max_y = maxf(max_y, pos.y)
		center += pos
	
	center /= players.size()
	center.y += vertical_offset
	
	# ── 計算目標縮放 ────────────────────────────────────────────
	var spread_x := max_x - min_x + zoom_margin * 2.0
	var spread_y := max_y - min_y + zoom_margin * 2.0
	
	var vp := get_viewport().get_visible_rect().size
	var zoom_for_x := vp.x / maxf(spread_x, 1.0)
	var zoom_for_y := vp.y / maxf(spread_y, 1.0)
	
	_target_zoom = clampf(minf(zoom_for_x, zoom_for_y), min_zoom, max_zoom)
	_target_pos  = center
	
	# ── 平滑插值 ────────────────────────────────────────────────
	var new_zoom := lerpf(zoom.x, _target_zoom, zoom_speed * delta)
	zoom = Vector2(new_zoom, new_zoom)
	
	# ── 邊界約束 ────────────────────────────────────────────────
	var half_w := vp.x / (2.0 * zoom.x)
	var half_h := vp.y / (2.0 * zoom.y)
	
	var cx := clampf(_target_pos.x, float(limit_left) + half_w, float(limit_right) - half_w)
	var cy := clampf(_target_pos.y, float(limit_top) + half_h, float(limit_bottom) - half_h)
	
	global_position = global_position.lerp(Vector2(cx, cy), follow_speed * delta)
