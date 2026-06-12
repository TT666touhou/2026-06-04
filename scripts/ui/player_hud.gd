extends Control
class_name PlayerHUD
## PlayerHUD — 玩家血條 HUD
## 掛在 game_world.tscn 的 CanvasLayer 下
## 自動搜尋 Players group 的玩家並顯示血條

@onready var heart_container: HBoxContainer = $HeartContainer

var heart_solid: AtlasTexture
var heart_empty: AtlasTexture
var _player: Node = null
var _search_timer: float = 0.0

func _ready() -> void:
	## 強制 CanvasLayer 所有子節點使用 Nearest 材質過濾（像素遊戲防模糊）
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	## 載入愛心圖案
	var atlas_path := "res://assets/tilesets/mrmotext/colored/color_T_10_fanqiehong.png"
	if ResourceLoader.exists(atlas_path):
		var atlas_tex := load(atlas_path)
		heart_solid = AtlasTexture.new()
		heart_solid.atlas = atlas_tex
		heart_solid.region = Rect2(24, 120, 8, 8)
		heart_solid.filter_clip = true  ## ⚠️ 防止 atlas 區域間像素滲透（防模糊關鍵）

		heart_empty = AtlasTexture.new()
		heart_empty.atlas = atlas_tex
		heart_empty.region = Rect2(32, 120, 8, 8)
		heart_empty.filter_clip = true  ## 同上

	## 等一幀讓玩家先生成
	call_deferred("_try_connect_player")

func _process(delta: float) -> void:
	## 若尚未連到玩家，每 0.5 秒重試一次
	if _player == null or not is_instance_valid(_player):
		_search_timer -= delta
		if _search_timer <= 0.0:
			_search_timer = 0.5
			_try_connect_player()

func _try_connect_player() -> void:
	## 從 Players group 取得本地玩家（p1_前綴）
	var players := get_tree().get_nodes_in_group("Players")
	if players.is_empty():
		return

	## 優先取有 player_prefix 的本地玩家；否則取第一個
	var target: Node = null
	for p: Node in players:
		if p.get("player_prefix") != null and not p.get("player_prefix").is_empty():
			target = p
			break
	if target == null:
		target = players[0]

	if target == _player:
		return  ## 已連接

	_player = target
	if target.has_signal("health_changed"):
		if not target.health_changed.is_connected(update_hearts):
			target.health_changed.connect(update_hearts)
	if target.get("current_health") != null:
		update_hearts(int(target.current_health))
	print("[PlayerHUD] 連接到玩家：", target.name)

func update_hearts(current_hp: int) -> void:
	## UI 修復（ERR-HUD-002）：
	## 心心 TextureRect 使用 EXPAND_IGNORE_SIZE + STRETCH_KEEP_ASPECT_CENTERED
	## 搭配固定 custom_minimum_size = 24x24，確保 8x8 atlas 等比放大不變形。
	## size_flags 設為 SHRINK_CENTER 防止 HBoxContainer 拉伸子節點。
	var heart_size := 24.0  ## 固定大小，不跟相機 zoom 連動

	var children := heart_container.get_children()
	var max_hp := 3
	if _player and _player.get("max_health") != null:
		max_hp = int(_player.get("max_health"))

	## 移除多餘的心心節點（max_hp 減少時）
	while children.size() > max_hp:
		var last := children.back()
		heart_container.remove_child(last)
		last.queue_free()
		children = heart_container.get_children()

	for i: int in range(max_hp):
		var rect: TextureRect
		if i < children.size():
			rect = children[i] as TextureRect
		else:
			rect = TextureRect.new()
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			## EXPAND_IGNORE_SIZE：讓 custom_minimum_size 控制大小，不讓 texture 決定佈局
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			## STRETCH_KEEP_ASPECT_CENTERED：等比縮放，不變形
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			## SHRINK_CENTER：防止 HBoxContainer 水平/垂直拉伸此節點
			rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rect.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
			heart_container.add_child(rect)

		## 鎖定尺寸：custom_minimum_size = 24x24，同時也鎖定 size
		## 雙重鎖定防止 Container 重新分配空間時變形
		rect.custom_minimum_size = Vector2(heart_size, heart_size)
		if heart_solid and heart_empty:
			rect.texture = heart_solid if i < current_hp else heart_empty
		else:
			## Fallback：沒有材質時用顏色方塊代替
			var fallback := ColorRect.new()
			fallback.custom_minimum_size = Vector2(heart_size, heart_size)
			fallback.color = Color(0.9, 0.1, 0.1) if i < current_hp else Color(0.3, 0.3, 0.3)
			if i >= children.size():
				heart_container.add_child(fallback)
