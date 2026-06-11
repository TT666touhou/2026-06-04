extends Node
## BossRoomManager — 監控 Boss 死亡並觸發勝利畫面
## 附加到 room_05_boss.tscn 的根節點上（由 base_level.gd 延伸而來）

var _base_level: Node = null

func _ready() -> void:
	# 等一幀讓場景完整初始化
	call_deferred("_connect_boss_signal")

func _connect_boss_signal() -> void:
	_base_level = get_parent()
	
	var boss := get_node_or_null("../Boss")
	if boss and boss.has_signal("boss_died"):
		boss.boss_died.connect(_on_boss_died)
		print("[BossRoomManager] Boss signal connected!")
		
		# 連接 Boss HP 到血量條
		var hp_bar := get_node_or_null("../BossHealthBar")
		if hp_bar and boss.has_signal("boss_health_changed"):
			boss.boss_health_changed.connect(func(cur, mx): hp_bar.value = cur)
	else:
		push_warning("[BossRoomManager] Boss node not found!")

func _on_boss_died() -> void:
	print("[BossRoomManager] Boss defeated! Triggering victory...")
	# 告知 base_level 觸發勝利
	if _base_level and _base_level.has_method("trigger_victory"):
		_base_level.trigger_victory()
	else:
		# Fallback
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/ui/victory.tscn")
