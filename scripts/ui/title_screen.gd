extends Control

@onready var local_btn = $VBoxContainer/LocalButton
@onready var host_btn = $VBoxContainer/HostButton
@onready var join_btn = $VBoxContainer/HBoxContainer/JoinButton
@onready var ip_input = $VBoxContainer/HBoxContainer/IPInput

func _ready():
	local_btn.pressed.connect(_on_local_pressed)
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	
	_setup_button_tween(local_btn)
	_setup_button_tween(host_btn)
	_setup_button_tween(join_btn)
	
	# Apply flat modern minimalist style to buttons
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#436794") # VfxMix Dark Blue
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color("#6f81b3")
	
	for btn in [local_btn, host_btn, join_btn]:
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", style)

func _setup_button_tween(btn: Button):
	btn.mouse_entered.connect(func(): _animate_button(btn, Vector2(1.05, 1.05)))
	btn.mouse_exited.connect(func(): _animate_button(btn, Vector2(1.0, 1.0)))

func _animate_button(btn: Button, target_scale: Vector2):
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", target_scale, 0.2)

func _on_local_pressed():
	# Go to lobby, but don't start ENet. Just local multiplayer.
	get_tree().change_scene_to_file("res://scenes/ui/multiplayer_lobby.tscn")

func _on_host_pressed():
	NetworkManager.host_game()
	get_tree().change_scene_to_file("res://scenes/ui/multiplayer_lobby.tscn")

func _on_join_pressed():
	var ip = ip_input.text
	if ip.is_empty(): ip = "127.0.0.1"
	NetworkManager.join_game(ip)
	get_tree().change_scene_to_file("res://scenes/ui/multiplayer_lobby.tscn")
