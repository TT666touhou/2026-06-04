extends CanvasLayer
## RoomBanner — 房間進入提示橫幅

@onready var label: Label = $BannerPanel/Label

func show_banner(room_name: String) -> void:
	label.text = room_name
	visible = true
	modulate.a = 0.0
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): visible = false)
