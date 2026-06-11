extends CanvasLayer

func _ready():
	$Control/VBoxContainer/Button.pressed.connect(_on_retry_pressed)

func _on_retry_pressed():
	# 斷開連線並回到標題畫面
	NetworkManager.peer = null
	multiplayer.multiplayer_peer = null
	NetworkManager.connected_players.clear()
	NetworkManager.alive_players.clear()
	
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
	queue_free()
