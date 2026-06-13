extends Control
## Run Complete Screen — 玩家通關後顯示

@onready var _restart_btn: Button = $RestartButton
@onready var _menu_btn: Button = $MenuButton

func _ready() -> void:
	_restart_btn.pressed.connect(_on_restart)
	_menu_btn.pressed.connect(_on_menu)

func _on_restart() -> void:
	get_tree().change_scene_to_file("res://scenes/level/game_world.tscn")

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
