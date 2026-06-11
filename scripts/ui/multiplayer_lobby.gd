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
	_update_slots()

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
		NetworkManager.start_game.rpc()

func _on_back_pressed():
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
