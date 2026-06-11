extends Control

@onready var slots = [
	$VBoxContainer/HBoxPlayers/P1Slot,
	$VBoxContainer/HBoxPlayers/P2Slot,
	$VBoxContainer/HBoxPlayers/P3Slot,
	$VBoxContainer/HBoxPlayers/P4Slot
]
@onready var start_btn = $VBoxContainer/StartButton
@onready var back_btn = $VBoxContainer/BackButton

func _ready():
	start_btn.pressed.connect(_on_start_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	if not multiplayer.is_server():
		start_btn.hide() # Only host can start
	
	# Listen to network manager
	NetworkManager.players_changed.connect(_update_slots)
	# Apply flat modern minimalist style to buttons
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#436794") # VfxMix Dark Blue
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color("#6f81b3")
	
	for btn in [start_btn, back_btn]:
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", style)
		_setup_button_tween(btn)
		
	_update_slots()

func _setup_button_tween(btn: Button):
	btn.mouse_entered.connect(func(): _animate_button(btn, Vector2(1.05, 1.05)))
	btn.mouse_exited.connect(func(): _animate_button(btn, Vector2(1.0, 1.0)))

func _animate_button(btn: Button, target_scale: Vector2):
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", target_scale, 0.2)

func _update_slots():
	var active_ids = NetworkManager.get_player_ids()
	for i in range(4):
		var slot = slots[i]
		var lbl = slot.get_node("Label")
		if i < active_ids.size():
			slot.color = Color("#436794") # VfxMix dark blue active
			var id = active_ids[i]
			if id == 1:
				lbl.text = "P%d\nHost" % (i+1)
			else:
				lbl.text = "P%d\nClient" % (i+1)
		else:
			slot.color = Color("#2a425f") # Inactive
			lbl.text = "P%d\nWaiting..." % (i+1)

func _on_start_pressed():
	if multiplayer.is_server():
		# Go to test level with a synced random seed
		var rng_seed = randi()
		NetworkManager.rpc("start_game", rng_seed)

func _on_back_pressed():
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
