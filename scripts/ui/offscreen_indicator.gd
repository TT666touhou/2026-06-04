extends CanvasLayer
## OffscreenIndicator — 畫面外玩家邊線指示器
## 對每個在畫面外的玩家，在螢幕邊線顯示一個透明箭頭圖示

const PLAYER_COLORS := [
	Color(0.4, 0.8, 1.0),
	Color(1.0, 0.5, 0.3),
	Color(0.4, 1.0, 0.5),
	Color(1.0, 0.9, 0.3),
]

# 每個玩家對應的指示器 Label（用作圖示）
var _indicators: Array[Label] = []
var _camera: Camera2D = null

func _ready() -> void:
	layer = 15  # 在 HUD 之上
	_build_indicators()

func _build_indicators() -> void:
	for i in range(4):
		var lbl := Label.new()
		lbl.text = "▶ P%d" % (i + 1)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = PLAYER_COLORS[i]
		lbl.modulate.a = 0.85
		lbl.visible = false
		
		var shadow := lbl.duplicate() as Label
		shadow.modulate = Color(0, 0, 0, 0.6)
		shadow.z_index = -1
		
		add_child(lbl)
		_indicators.append(lbl)

func _process(_delta: float) -> void:
	_update_camera()
	if _camera == null:
		return
	
	var players := get_tree().get_nodes_in_group("Players")
	var vp_size := get_viewport().get_visible_rect().size
	var margin := 20.0
	
	for i in range(min(players.size(), 4)):
		if i >= _indicators.size(): break
		var p := players[i] as Node2D
		if not is_instance_valid(p):
			_indicators[i].visible = false
			continue
		
		var screen_pos: Vector2 = _camera.unproject_position(p.global_position)
		var in_screen := Rect2(margin, margin + 28, vp_size.x - margin * 2, vp_size.y - margin * 2 - 28).has_point(screen_pos)
		
		if in_screen:
			_indicators[i].visible = false
		else:
			_indicators[i].visible = true
			# 計算邊線位置
			var clamped := _clamp_to_border(screen_pos, vp_size, margin)
			_indicators[i].global_position = clamped
			# 旋轉箭頭指向玩家方向
			var dir: Vector2 = (screen_pos - clamped).normalized()
			var angle: float = dir.angle()
			_indicators[i].rotation = angle

func _update_camera() -> void:
	if _camera != null and is_instance_valid(_camera):
		return
	# 找到當前的 Camera2D
	var cameras := get_tree().get_nodes_in_group("MainCamera")
	if not cameras.is_empty():
		_camera = cameras[0]
		return
	# fallback: 找任意 current Camera2D
	for node in get_tree().get_nodes_in_group("Players"):
		var cam := node.get_node_or_null("Camera2D")
		if cam:
			_camera = cam
			return

func _clamp_to_border(pos: Vector2, vp_size: Vector2, margin: float) -> Vector2:
	var center := vp_size * 0.5
	var dir := (pos - center)
	if dir.length() < 0.1:
		return center
	
	# 找到從中心到邊界的交點
	var norm := dir.normalized()
	var half_w := vp_size.x * 0.5 - margin
	var half_h := vp_size.y * 0.5 - margin - 14.0
	
	var t_x := half_w / maxf(abs(norm.x), 0.001)
	var t_y := half_h / maxf(abs(norm.y), 0.001)
	var t := minf(t_x, t_y)
	
	return center + norm * t
