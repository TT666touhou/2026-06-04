extends CanvasLayer
## HUD — 遊戲中頂部血量顯示欄
## 顯示 1~4 個玩家各自的 HP 狀態條

const PLAYER_COLORS := [
	Color(0.4, 0.8, 1.0),   # P1 - 藍
	Color(1.0, 0.5, 0.3),   # P2 - 橘
	Color(0.4, 1.0, 0.5),   # P3 - 綠
	Color(1.0, 0.9, 0.3),   # P4 - 黃
]

var _player_slots: Array[Control] = []
var _hp_bars: Array[ProgressBar] = []
var _hp_labels: Array[Label] = []
var _player_refs: Array = []

@onready var top_bar: HBoxContainer = $TopBar

func _ready() -> void:
	_build_ui()
	# 延遲一幀後掃描場景中的玩家
	call_deferred("_scan_players")

func _build_ui() -> void:
	# 設定 CanvasLayer 層級
	layer = 10
	
	# 背景條
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.85)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 0.0
	bg.offset_bottom = 28
	add_child(bg)
	
	# Top Bar HBoxContainer
	var bar := HBoxContainer.new()
	bar.name = "TopBar"
	bar.anchor_right = 1.0
	bar.offset_top = 2
	bar.offset_bottom = 26
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	top_bar = bar
	
	# 建立 4 個玩家槽
	for i in range(4):
		var slot := _build_player_slot(i)
		bar.add_child(slot)
		_player_slots.append(slot)

func _build_player_slot(idx: int) -> Control:
	var slot := PanelContainer.new()
	slot.name = "PlayerSlot%d" % (idx + 1)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 邊框風格
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = PLAYER_COLORS[idx]
	slot.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	slot.add_child(hbox)
	
	# 玩家標籤
	var lbl := Label.new()
	lbl.text = "P%d" % (idx + 1)
	lbl.modulate = PLAYER_COLORS[idx]
	lbl.add_theme_font_size_override("font_size", 10)
	hbox.add_child(lbl)
	
	# HP 條
	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = 3
	hp_bar.value = 3
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.custom_minimum_size = Vector2(60, 12)
	hp_bar.show_percentage = false
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = PLAYER_COLORS[idx]
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	
	hbox.add_child(hp_bar)
	_hp_bars.append(hp_bar)
	
	# HP 數字
	var hp_lbl := Label.new()
	hp_lbl.text = "3"
	hp_lbl.add_theme_font_size_override("font_size", 10)
	hbox.add_child(hp_lbl)
	_hp_labels.append(hp_lbl)
	
	# 離線標示（預設灰色）
	slot.modulate.a = 0.3
	
	return slot

func _scan_players() -> void:
	_player_refs.clear()
	var players := get_tree().get_nodes_in_group("Players")
	for i in range(min(players.size(), 4)):
		var p := players[i]
		_player_refs.append(p)
		_player_slots[i].modulate.a = 1.0
		# 連接信號
		if p.has_signal("health_changed"):
			var idx := i
			p.health_changed.connect(func(hp): _on_player_hp_changed(idx, hp, p.max_health))
		if p.has_signal("player_died"):
			var idx := i
			p.player_died.connect(func(_node): _on_player_slot_died(idx))

func _on_player_hp_changed(slot_idx: int, new_hp: int, max_hp: int) -> void:
	if slot_idx >= _hp_bars.size(): return
	_hp_bars[slot_idx].max_value = max_hp
	_hp_bars[slot_idx].value = new_hp
	_hp_labels[slot_idx].text = str(new_hp)
	
	# 血量低時顏色變紅
	var color := PLAYER_COLORS[slot_idx]
	if new_hp == 1:
		color = Color(1.0, 0.3, 0.3)
	_hp_bars[slot_idx].get_theme_stylebox("fill").bg_color = color

func _on_player_slot_died(slot_idx: int) -> void:
	if slot_idx >= _player_slots.size(): return
	_hp_bars[slot_idx].value = 0
	_hp_labels[slot_idx].text = "X"
	_player_slots[slot_idx].modulate = Color(0.5, 0.2, 0.2, 0.8)

func update_boss_health(current: int, maximum: int) -> void:
	## 供 Boss 場景呼叫：更新 Boss 血量顯示
	pass  # Boss HP Bar 在場景中獨立顯示
