extends Control
## Game Over Screen
## 紅色警告風格，顯示每個玩家狀態

@onready var title_lbl: Label = $CenterContainer/VBox/TitleLabel
@onready var player_info: VBoxContainer = $CenterContainer/VBox/PlayerInfo
@onready var retry_btn: Button = $CenterContainer/VBox/RetryButton
@onready var title_btn: Button = $CenterContainer/VBox/TitleButton

const PLAYER_COLORS := [Color(0.4,0.8,1.0), Color(1.0,0.5,0.3), Color(0.4,1.0,0.5), Color(1.0,0.9,0.3)]

func _ready() -> void:
	retry_btn.pressed.connect(_on_retry)
	title_btn.pressed.connect(_on_to_title)
	
	# 進場動畫
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# 標題閃爍
	var flash := create_tween().set_loops(3)
	flash.tween_property(title_lbl, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.1)
	flash.tween_property(title_lbl, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.1)
	
	_populate_player_stats()

func _populate_player_stats() -> void:
	for c in player_info.get_children():
		c.queue_free()
	
	var idx := 0
	for peer_id in NetworkManager.connected_players:
		var info := NetworkManager.connected_players[peer_id]
		var is_dead: bool = info.get("is_dead", true)
		
		var lbl := Label.new()
		lbl.text = "P%d — %s" % [idx + 1, "FALLEN" if is_dead else "SURVIVED"]
		lbl.modulate = Color(0.5, 0.2, 0.2) if is_dead else PLAYER_COLORS[idx % 4]
		lbl.add_theme_font_size_override("font_size", 12)
		player_info.add_child(lbl)
		idx += 1
	
	if idx == 0:
		var lbl := Label.new()
		lbl.text = "All Warriors Have Fallen..."
		lbl.modulate = Color(0.7, 0.3, 0.3)
		player_info.add_child(lbl)

func _on_retry() -> void:
	# 重置死亡狀態
	for k in NetworkManager.connected_players:
		NetworkManager.connected_players[k].erase("is_dead")
	NetworkManager.change_game_state("playing")
	get_tree().change_scene_to_file("res://scenes/levels/room_01_tutorial.tscn")

func _on_to_title() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	NetworkManager.connected_players.clear()
	NetworkManager.change_game_state("lobby")
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
