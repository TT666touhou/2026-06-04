extends Control
## Title Screen — 完整重設計
## mrmotext 像素風，黑底白字
## 動畫：標題閃爍 + 選單 Tween 放大

@onready var host_btn: Button = $CenterContainer/VBox/HostButton
@onready var join_btn: Button = $CenterContainer/VBox/JoinButton
@onready var ip_row: HBoxContainer = $CenterContainer/VBox/IPRow
@onready var ip_input: LineEdit = $CenterContainer/VBox/IPRow/IPInput
@onready var quit_btn: Button = $CenterContainer/VBox/QuitButton
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel

var _title_tween: Tween = null

func _ready() -> void:
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	quit_btn.pressed.connect(func(): get_tree().quit())
	
	ip_row.hide()
	
	_setup_button_hover(host_btn)
	_setup_button_hover(join_btn)
	_setup_button_hover(quit_btn)
	
	_animate_title()

func _animate_title() -> void:
	if _title_tween:
		_title_tween.kill()
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(title_label, "modulate:a", 0.7, 0.8)
	_title_tween.tween_property(title_label, "modulate:a", 1.0, 0.8)

func _setup_button_hover(btn: Button) -> void:
	call_deferred("_deferred_setup_hover", btn)

func _deferred_setup_hover(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func():
		var t := create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.3)
	)
	btn.mouse_exited.connect(func():
		var t := create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.3)
	)

func _on_host_pressed() -> void:
	NetworkManager.host_game()
	# 切換到 Lobby
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")

func _on_join_pressed() -> void:
	if ip_row.visible:
		var ip := ip_input.text.strip_edges()
		if ip.is_empty():
			ip = "127.0.0.1"
		NetworkManager.join_game(ip)
		get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")
	else:
		ip_row.show()
		var t := create_tween().set_ease(Tween.EASE_OUT)
		t.tween_property(ip_row, "modulate:a", 1.0, 0.3).from(0.0)
