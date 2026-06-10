extends Control
class_name PlayerHUD

@onready var heart_container: HBoxContainer = $HeartContainer

var heart_solid: AtlasTexture
var heart_empty: AtlasTexture
var _player: Node2D = null

func _ready() -> void:
	# 載入愛心圖案 (番茄紅透明底色 source 26)
	heart_solid = AtlasTexture.new()
	heart_solid.atlas = load("res://assets/tilesets/mrmotext/colored/color_T_10_fanqiehong.png")
	heart_solid.region = Rect2(24, 120, 8, 8) # (3,15)
	
	heart_empty = AtlasTexture.new()
	heart_empty.atlas = load("res://assets/tilesets/mrmotext/colored/color_T_10_fanqiehong.png")
	heart_empty.region = Rect2(32, 120, 8, 8) # (4,15)
	
	_try_connect_player()

func _process(_delta: float) -> void:
	if _player == null:
		_try_connect_player()

func _try_connect_player() -> void:
	var player = get_tree().current_scene.find_child("Player1", true, false)
	if player:
		_player = player
		if not player.health_changed.is_connected(update_hearts):
			player.health_changed.connect(update_hearts)
		update_hearts(player.current_health)

func update_hearts(current_hp: int) -> void:
	# 獲取 Camera2D zoom 來動態計算顯示尺寸，確保與 Player 大小一致
	var cam_zoom: float = 3.0
	var camera = get_tree().current_scene.find_child("SceneCamera", true, false)
	if camera and "cam_zoom" in camera:
		cam_zoom = float(camera.cam_zoom)
	elif camera and camera is Camera2D:
		cam_zoom = camera.zoom.x
		
	# 計算尺寸：Player 是 16x16 像素，縮小/放大後在螢幕上的高度是 16 * cam_zoom
	# 愛心原始是 8x8，因此在 UI 空間中我們將大小設為 16 * cam_zoom 即可跟 player 尺寸一樣大！
	var heart_size := 16.0 * cam_zoom
	
	# 更新心形節點
	var children = heart_container.get_children()
	for i in range(3):
		var rect: TextureRect
		if i < children.size():
			rect = children[i] as TextureRect
		else:
			rect = TextureRect.new()
			# 使用 Nearest Filter 保持像素邊緣清晰
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			heart_container.add_child(rect)
			
		rect.custom_minimum_size = Vector2(heart_size, heart_size)
		rect.texture = heart_solid if i < current_hp else heart_empty
