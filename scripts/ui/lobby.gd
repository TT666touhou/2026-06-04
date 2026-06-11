extends Control
## Lobby — 多人大廳
## 顯示已連線的玩家，Host 可以開始遊戲

const PLAYER_COLORS := [
	Color(0.4, 0.8, 1.0),
	Color(1.0, 0.5, 0.3),
	Color(0.4, 1.0, 0.5),
	Color(1.0, 0.9, 0.3),
]
const SKIN_NAMES := ["Blue Warrior", "Orange Knight", "Green Rogue", "Yellow Mage"]

@onready var player_list: VBoxContainer = $CenterContainer/VBox/PlayerList
@onready var start_btn: Button = $CenterContainer/VBox/StartButton
@onready var back_btn: Button = $CenterContainer/VBox/BackButton
@onready var status_label: Label = $CenterContainer/VBox/StatusLabel
@onready var room_code_label: Label = $CenterContainer/VBox/RoomCodeLabel

var _slot_nodes: Array[Control] = []
var _is_host: bool = false

func _ready() -> void:
	_is_host = multiplayer.is_server() or not multiplayer.has_multiplayer_peer()
	
	start_btn.pressed.connect(_on_start_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	# 只有 Host 可以開始遊戲
	start_btn.visible = _is_host
	
	# 建立 4 個玩家槽
	_build_player_slots()
	
	# 連接 NetworkManager 信號
	NetworkManager.player_connected.connect(_on_player_update)
	NetworkManager.player_disconnected.connect(_on_player_update)
	
	# 顯示目前玩家
	_refresh_player_list()
	
	# Room Code
	if _is_host:
		room_code_label.text = "HOSTING ON PORT %d" % NetworkManager.PORT
		status_label.text = "Waiting for players... (%d/4)" % NetworkManager.connected_players.size()
	else:
		room_code_label.text = "CONNECTED TO HOST"
		status_label.text = "Ready!"

func _build_player_slots() -> void:
	for c in player_list.get_children():
		c.queue_free()
	_slot_nodes.clear()
	
	for i in range(4):
		var slot := _build_slot(i)
		player_list.add_child(slot)
		_slot_nodes.append(slot)

func _build_slot(idx: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 40)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3)
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate.a = 0.4  # 灰色（空位）
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)
	
	# 顏色指示點
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.color = PLAYER_COLORS[idx]
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(dot)
	
	# P# 標籤
	var p_lbl := Label.new()
	p_lbl.text = "P%d" % (idx + 1)
	p_lbl.modulate = PLAYER_COLORS[idx]
	p_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(p_lbl)
	
	# 名稱標籤
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = "[ EMPTY ]"
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)
	
	# 狀態標籤
	var status := Label.new()
	status.name = "StatusLabel"
	status.text = "..."
	status.modulate = Color(0.5, 0.5, 0.5)
	status.add_theme_font_size_override("font_size", 10)
	hbox.add_child(status)
	
	return panel

func _refresh_player_list() -> void:
	# 重置所有槽
	for i in range(4):
		if i < _slot_nodes.size():
			_slot_nodes[i].modulate.a = 0.3
			var lbl = _slot_nodes[i].get_node_or_null("HBoxContainer/NameLabel")
			if lbl:
				lbl.text = "[ EMPTY ]"
			var st = _slot_nodes[i].get_node_or_null("HBoxContainer/StatusLabel")
			if st:
				st.text = "..."
	
	# 填入已連線的玩家
	var idx := 0
	for peer_id in NetworkManager.connected_players:
		if idx >= 4: break
		var info: Dictionary = NetworkManager.connected_players[peer_id]
		var skin_idx: int = info.get("skin_index", 0)
		
		_slot_nodes[idx].modulate.a = 1.0
		var style := _slot_nodes[idx].get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.border_color = PLAYER_COLORS[skin_idx % 4]
		
		var lbl = _slot_nodes[idx].get_node_or_null("HBoxContainer/NameLabel")
		if lbl:
			lbl.text = SKIN_NAMES[skin_idx % 4]
		var st = _slot_nodes[idx].get_node_or_null("HBoxContainer/StatusLabel")
		if st:
			st.text = "READY" if multiplayer.is_server() or peer_id == multiplayer.get_unique_id() else "WAITING"
			st.modulate = Color(0.4, 1.0, 0.5)
		
		idx += 1
	
	if _is_host:
		status_label.text = "Waiting for players... (%d/4)" % NetworkManager.connected_players.size()
		start_btn.disabled = NetworkManager.connected_players.size() < 1

func _on_player_update(_a=null, _b=null) -> void:
	_refresh_player_list()

func _on_start_pressed() -> void:
	# 開始遊戲：載入第一個房間
	NetworkManager.change_game_state("playing")
	get_tree().change_scene_to_file("res://scenes/levels/room_01_tutorial.tscn")

func _on_back_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	NetworkManager.connected_players.clear()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
