extends Control
## Victory Screen — 勝利畫面

@onready var title_lbl: Label = $CenterContainer/VBox/TitleLabel
@onready var time_lbl: Label = $CenterContainer/VBox/TimeLabel
@onready var player_info: VBoxContainer = $CenterContainer/VBox/PlayerInfo
@onready var title_btn: Button = $CenterContainer/VBox/TitleButton

const PLAYER_COLORS := [Color(0.4,0.8,1.0), Color(1.0,0.5,0.3), Color(0.4,1.0,0.5), Color(1.0,0.9,0.3)]

var _clear_time: float = 0.0

func _ready() -> void:
	title_btn.pressed.connect(_on_to_title)
	
	# 進場動畫
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var t := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.8)
	t.parallel().tween_property(self, "modulate:a", 1.0, 0.4)
	
	# 標題持續閃爍（金色）
	var flash := create_tween().set_loops()
	flash.tween_property(title_lbl, "modulate", Color(2.0, 2.0, 0.5, 1.0), 0.7)
	flash.tween_property(title_lbl, "modulate", Color(1.0, 1.0, 0.3, 1.0), 0.7)
	
	_populate_stats()

func _populate_stats() -> void:
	# 顯示通關時間
	var mins := int(_clear_time / 60.0)
	var secs := int(fmod(_clear_time, 60.0))
	time_lbl.text = "CLEAR TIME: %02d:%02d" % [mins, secs]
	
	# 顯示每個玩家狀態
	for c in player_info.get_children():
		c.queue_free()
	
	var idx := 0
	for peer_id in NetworkManager.connected_players:
		var info: Dictionary = NetworkManager.connected_players[peer_id]
		var survived: bool = not info.get("is_dead", false)
		
		var lbl := Label.new()
		lbl.text = "P%d — %s" % [idx + 1, "★ SURVIVED" if survived else "✗ FALLEN"]
		lbl.modulate = PLAYER_COLORS[idx % 4] if survived else Color(0.5, 0.5, 0.5)
		lbl.add_theme_font_size_override("font_size", 12)
		player_info.add_child(lbl)
		idx += 1

func set_clear_time(t: float) -> void:
	_clear_time = t
	if is_inside_tree():
		_populate_stats()

func _on_to_title() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	NetworkManager.connected_players.clear()
	NetworkManager.change_game_state("lobby")
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
