extends Node2D
## PlayerDust — 落地煙塵特效
## 使用方式：instantiate() → 設定 global_position → add_child()
## 特效播完後自動 queue_free，不需外部管理。

@onready var _sprite: Sprite2D = $GroudFlash

func _ready() -> void:
	# ── 初始狀態：小而扁、半透明 ────────────────────────────────
	_sprite.scale    = Vector2(0.3, 0.1)
	_sprite.modulate = Color(1.0, 1.0, 1.0, 0.85)

	# ── Tween：同時執行擴張 + 淡出 ──────────────────────────────
	var tw := create_tween()
	tw.set_parallel(true)

	# 橫向快速擴開（Expo 緩出：爆發感）
	tw.tween_property(_sprite, "scale",
			Vector2(2.2, 0.45), 0.30)\
	  .set_ease(Tween.EASE_OUT)\
	  .set_trans(Tween.TRANS_EXPO)

	# 稍微延遲再開始淡出（讓形狀先完整出現）
	tw.tween_property(_sprite, "modulate:a",
			0.0, 0.25)\
	  .set_delay(0.06)

	# 所有 Tween 結束後自毀
	tw.finished.connect(queue_free)
