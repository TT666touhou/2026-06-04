extends CanvasLayer
## DebugOverlay — F3 切換的全螢幕遊戲狀態顯示器
## Autoload 名稱：DebugOverlay
## ─────────────────────────────────────────────────────────────
## 🔑 DEVELOPER NOTES:
##   - DebugBridge 為另一個 Autoload，這裡以 get_node 延遲取得
##     （不能直接用 DebugBridge，因為 autoload 載入順序不定）
##   - 所有動態類型一律加上顯式型別標注
##   - _net_label 已移除（功能合併到 _label）

const TOGGLE_KEY        := KEY_F3
const HITBOX_TOGGLE_KEY := KEY_F4
const EXPORT_KEY        := KEY_F5

const UPDATE_INTERVAL: float = 0.05

var _visible_debug: bool = false
var _show_hitboxes: bool = false
var _update_timer:  float = 0.0

var _panel: PanelContainer
var _label: RichTextLabel

# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	layer = 100
	_build_ui()
	hide()
	set_process_input(true)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.custom_minimum_size = Vector2(440, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.80)
	style.corner_radius_top_left    = 4
	style.corner_radius_top_right   = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	style.content_margin_top    = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "[ DEBUG OVERLAY  F3:關閉  F4:碰撞框  F5:寫出JSON ]"
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	title.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_label = RichTextLabel.new()
	_label.bbcode_enabled    = true
	_label.fit_content       = true
	_label.custom_minimum_size = Vector2(420, 0)
	_label.add_theme_font_size_override("normal_font_size", 11)
	vbox.add_child(_label)

# ═══════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var kev := event as InputEventKey
	if not kev.pressed or kev.echo:
		return
	match kev.keycode:
		TOGGLE_KEY:
			_visible_debug = !_visible_debug
			if _visible_debug:
				show()
			else:
				hide()
		HITBOX_TOGGLE_KEY:
			_show_hitboxes = !_show_hitboxes
			get_tree().debug_collisions_hint = _show_hitboxes
		EXPORT_KEY:
			# 延遲取得 DebugBridge（Autoload 一定存在，但載入順序問題）
			var bridge: Node = get_node_or_null("/root/DebugBridge")
			if bridge and bridge.has_method("force_export"):
				bridge.force_export()
			else:
				push_warning("[DebugOverlay] DebugBridge 未就緒，無法強制寫出")

# ═══════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if not _visible_debug:
		return
	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = UPDATE_INTERVAL
	_refresh_display()

func _refresh_display() -> void:
	var lines: PackedStringArray = PackedStringArray()

	# ── 效能 ──────────────────────────────────────────────────────
	var fps: int = roundi(Engine.get_frames_per_second())
	var fps_col: String
	if fps >= 55:
		fps_col = "#00ff88"
	elif fps >= 30:
		fps_col = "#ffcc00"
	else:
		fps_col = "#ff4444"

	lines.append("[color=%s]FPS: %d[/color]  物理: %d Hz  節點: %d" % [
		fps_col, fps,
		Engine.physics_ticks_per_second,
		get_tree().get_node_count()
	])

	# ── 網路資訊 ─────────────────────────────────────────────────
	var net_info: String = ""
	if not multiplayer.has_multiplayer_peer():
		net_info = "[color=#aaaaaa]網路：離線（單機）[/color]"
	else:
		var role_col: String = "#ff8844" if multiplayer.is_server() else "#44aaff"
		var role_str: String = "SERVER" if multiplayer.is_server() else "CLIENT"
		net_info = "網路：[color=%s]%s[/color]  PeerID: %d" % [
			role_col, role_str, multiplayer.get_unique_id()
		]
		var nm: Node = get_node_or_null("/root/NetworkManager")
		if nm != null:
			var cp: Variant = nm.get("connected_players")
			if cp is Dictionary:
				net_info += "  玩家數: [color=#00ff88]%d[/color]" % (cp as Dictionary).size()
	lines.append(net_info)

	lines.append("[color=#444444]──────────────────────────────────────────[/color]")

	# ── 玩家狀態 ─────────────────────────────────────────────────
	var players: Array = get_tree().get_nodes_in_group("Players")
	if players.is_empty():
		lines.append("[color=#ff6666]⚠ 無玩家節點（group: Players）[/color]")
	else:
		const P_COLORS: Array[String] = ["#FF8C42", "#4CC9F0", "#5DA16E", "#9D5789"]
		for p_idx: int in range(players.size()):
			var player: Node = players[p_idx]
			var col: String = P_COLORS[p_idx % P_COLORS.size()]

			var pid_str: String
			if multiplayer.has_multiplayer_peer():
				pid_str = "ID:%s" % player.name
			else:
				pid_str = "P%d" % (p_idx + 1)

			var pos: Vector2 = player.get("global_position") if player.get("global_position") != null else Vector2.ZERO
			var vel: Vector2 = player.get("velocity") if player.get("velocity") != null else Vector2.ZERO
			var hp:      Variant = player.get("current_health")
			var hp_max:  Variant = player.get("max_health")
			var stamina: Variant = player.get("_stamina")

			var hp_str:  String = "%d/%d" % [hp, hp_max] if hp != null and hp_max != null else "N/A"
			var sta_str: String = "%.1f" % float(stamina) if stamina != null else "N/A"

			var is_auth: bool = true
			if multiplayer.has_multiplayer_peer() and player.has_method("is_multiplayer_authority"):
				is_auth = player.is_multiplayer_authority()
			var auth_str: String = "[color=#00ff88]✓auth[/color]" if is_auth else "[color=#aaaaaa]sync[/color]"

			lines.append("[color=%s]■ %s[/color] %s  (%.0f,%.0f)  vel(%.0f,%.0f)  HP:%s  ST:%s" % [
				col, pid_str, auth_str,
				pos.x, pos.y, vel.x, vel.y,
				hp_str, sta_str
			])

			# 物理標記
			var flags: PackedStringArray = PackedStringArray()
			if player.has_method("is_on_floor") and player.is_on_floor():
				flags.append("[color=#88ff88]地[/color]")
			if player.has_method("is_on_wall") and player.is_on_wall():
				flags.append("[color=#ffaa44]牆[/color]")
			var inv: Variant = player.get("is_invincible")
			if inv != null and bool(inv):
				flags.append("[color=#ff88ff]無敵[/color]")
			if not flags.is_empty():
				lines.append("    " + " ".join(flags))

	lines.append("[color=#444444]──────────────────────────────────────────[/color]")
	lines.append("[color=#666666]F4: 碰撞框 %s  F5: 強制 JSON 輸出[/color]" % (
		"[color=#00ff88]ON[/color]" if _show_hitboxes else "[color=#ff4444]OFF[/color]"
	))

	_label.text = "\n".join(lines)
