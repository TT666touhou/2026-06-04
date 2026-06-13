extends CanvasLayer
class_name ScreenFader
## ScreenFader — 全螢幕漸黑/漸亮效果
## 用於 RoomPortal 房間切換時的視覺過渡
## 
## 使用方式：
##   var fader := get_node("ScreenFader")
##   fader.faded_out.connect(_on_faded_out, CONNECT_ONE_SHOT)
##   fader.fade_out()
##   # 在 _on_faded_out() 中執行換場，然後呼叫 fader.fade_in()

signal faded_out   ## 漸黑完成（畫面全黑，可以換場了）
signal faded_in    ## 漸亮完成

@export var default_duration: float = 0.4  ## 預設過渡時間（秒）

@onready var _rect: ColorRect = $ColorRect

func _ready() -> void:
	## 確保 CanvasLayer 在最上層
	layer = 128
	## 初始透明
	_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_rect.modulate.a = 0.0
	print("[ScreenFader] 初始化完成，layer=", layer)

## 漸黑（透明 → 純黑），完成後發出 faded_out 信號
func fade_out(duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = default_duration
	_rect.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(faded_out.emit)
	print("[ScreenFader] 開始 Fade Out（%.2f 秒）" % duration)

## 漸亮（純黑 → 透明），完成後發出 faded_in 信號
func fade_in(duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = default_duration
	_rect.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(faded_in.emit)
	print("[ScreenFader] 開始 Fade In（%.2f 秒）" % duration)

## 立即設為全黑（不動畫）
func set_black() -> void:
	_rect.modulate.a = 1.0

## 立即設為透明（不動畫）
func set_clear() -> void:
	_rect.modulate.a = 0.0
