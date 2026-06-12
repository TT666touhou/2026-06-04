extends Node2D
## 內嵌於 Player 場景的近戰 VFX 節點
## 設計理念：在 Godot Editor 中直接拖放到正確位置，runtime 根據面向鏡像
##
## 使用方法：
##   1. 在 Player 場景中將此場景實例化為子節點
##   2. 在 Scene Editor 視窗中拖動節點到正確位置（以朝右為基準）
##   3. 程式碼呼叫 activate(_facing) 即可播放
##
## 注意：position.x 應設為正值（朝右方向）；
##       activate() 會自動根據 facing 鏡像到朝左方向

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

## 記錄在 Editor 中設定的朝右 x 偏移（確保為正值）
var _base_x: float = 0.0

func _ready() -> void:
	if _sprite == null:
		push_error("[EmbeddedMeleeVFX] 找不到 AnimatedSprite2D 子節點：", name)
		return
	## 記錄 Editor 設定的位置（x 強制正值 = 朝右基準）
	_base_x = absf(position.x)
	## 連接動畫結束訊號
	_sprite.animation_finished.connect(_on_animation_finished)
	## 初始狀態隱藏（等待攻擊觸發）
	visible = false

## 激活特效：根據 facing 決定方向
## facing: +1.0 = 朝右, -1.0 = 朝左
func activate(facing: float) -> void:
	## 根據 facing 鏡像 x 位置
	position.x = _base_x * facing
	## 鏡像圖像
	if _sprite:
		_sprite.flip_h = (facing < 0.0)
		## 重置並播放動畫
		_sprite.stop()
		_sprite.frame = 0
		_sprite.play("default")
	visible = true

func _on_animation_finished() -> void:
	## 播完後隱藏（節點繼續存在，下次攻擊可再次激活）
	visible = false
