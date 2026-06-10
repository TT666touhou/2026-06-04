extends CanvasLayer
class_name HUD

@onready var hearts_container: HBoxContainer = %HeartsContainer

var solid_heart_texture: AtlasTexture
var empty_heart_texture: AtlasTexture

func _ready() -> void:
	# 建立實心愛心 Texture (Tileset 座標 3, 15 => 24, 120)
	solid_heart_texture = AtlasTexture.new()
	solid_heart_texture.atlas = load("res://assets/tilesets/mrmotext/colored/color_T_10_fanqiehong.png")
	solid_heart_texture.region = Rect2(24, 120, 8, 8)
	
	# 建立空心愛心 Texture (Tileset 座標 4, 15 => 32, 120)
	empty_heart_texture = AtlasTexture.new()
	empty_heart_texture.atlas = load("res://assets/tilesets/mrmotext/colored/color_T_10_fanqiehong.png")
	empty_heart_texture.region = Rect2(32, 120, 8, 8)
	
	# 初始化建立 3 顆實心愛心
	for i in range(3):
		var rect = TextureRect.new()
		rect.texture = solid_heart_texture
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(8, 8)
		hearts_container.add_child(rect)

func update_health(current_health: int, max_health: int) -> void:
	# 確保 UI 愛心數量正確
	var children = hearts_container.get_children()
	for i in range(max_health):
		if i < children.size():
			if i < current_health:
				children[i].texture = solid_heart_texture
			else:
				children[i].texture = empty_heart_texture
