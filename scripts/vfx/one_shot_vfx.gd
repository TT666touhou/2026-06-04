extends Node2D
## 通用一次性 VFX 腳本
## 播完 AnimatedSprite2D 動畫後自動 queue_free
## 所有 VFX 場景（MeleeSlash, RangedMuzzle, EnemyHit, EnemyDeath）共用此腳本

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if _sprite == null:
		push_error("[OneShotVFX] 找不到 AnimatedSprite2D 子節點")
		queue_free()
		return
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play("default")

func _on_animation_finished() -> void:
	queue_free()
