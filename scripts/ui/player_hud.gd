extends CanvasLayer
class_name PlayerHUD

@export var heart_texture: Texture2D = preload("res://assets/tilesets/mrmotext/colored/color_T_10_fanqiehong.png")
@export var solid_heart_region: Rect2 = Rect2(24, 120, 8, 8) # (3,15)
@export var empty_heart_region: Rect2 = Rect2(32, 120, 8, 8) # (4,15)
@export var ui_scale: float = 3.0 # Size to match player visually

var hearts: Array[TextureRect] = []

func _ready() -> void:
	var container = HBoxContainer.new()
	container.name = "HeartContainer"
	# Position top left
	container.position = Vector2(20, 20)
	container.scale = Vector2(ui_scale, ui_scale)
	add_child(container)
	
	# Initial setup (assume max 3 hearts)
	for i in range(3):
		var rect = TextureRect.new()
		var atlas = AtlasTexture.new()
		atlas.atlas = heart_texture
		atlas.region = solid_heart_region
		rect.texture = atlas
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(rect)
		hearts.append(rect)

func update_health(current: int, max_hp: int) -> void:
	# Ensure container size matches max_hp
	var container = $HeartContainer
	while hearts.size() < max_hp:
		var rect = TextureRect.new()
		var atlas = AtlasTexture.new()
		atlas.atlas = heart_texture
		rect.texture = atlas
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(rect)
		hearts.append(rect)
		
	while hearts.size() > max_hp:
		var rect = hearts.pop_back()
		rect.queue_free()
		
	for i in range(max_hp):
		var atlas = hearts[i].texture as AtlasTexture
		if i < current:
			atlas.region = solid_heart_region
		else:
			atlas.region = empty_heart_region
