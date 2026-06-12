extends CanvasLayer
## DebugOverlay — F3 切換的全螢幕遊戲狀態顯示器
## Autoload 名稱：DebugOverlay
## 用途：讓開發者（和 AI）即時看到遊戲內部所有狀態
##
## 顯示內容：
##   - 所有玩家位置、速度、狀態機、HP、耐力
##   - 網路資訊（peer數、是否為server）
##   - FPS、物理FPS、節點數
##   - 碰撞框視覺化（獨立開關）
##
## 快捷鍵：
##   F3 — 切換 Debug Overlay
##   F4 — 切換碰撞框顯示
##   F5 — 強制立即寫出 debug_state.json

# ═══════════════════════════════════════════════════════════════
# 設定
# ═══════════════════════════════════════════════════════════════
const TOGGLE_KEY := KEY_F3
const HITBOX_TOGGLE_KEY := KEY_F4
const EXPORT_KEY := KEY_F5

## 更新頻率（秒），0 = 每幀
const UPDATE_INTERVAL: float = 0.05

var _overlay_visible: bool = false
var _show_hitboxes: bool = false
var _update_timer: float = 0.0

# ── UI 節點 ──────────────────────────────────────────────────────
var _panel: PanelContainer
var _label: RichTextLabel

# ═══════════════════════════════════════════════════════════════
# 初始化
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	layer = 100          # 確保在最上層
	_build_ui()
	hide()               # 預設隱藏
	set_process_input(true)
	print("[DebugOverlay] 已初始化。F3: 顯示/隱藏, F4: 碰撞框, F5: 寫出JSON")

func _build_ui() -> void:
	# 半透明黑底面板
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.custom_minimum_size = Vector2(440, 0)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.80)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)
	
	# 標題列
	var title := Label.new()
	title.text = "[ DEBUG OVERLAY — F3:關閉  F4:碰撞框  F5:寫JSON ]"
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	title.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# 主要狀態文字
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.custom_minimum_size = Vector2(420, 0)
	_label.add_theme_font_size_override("normal_font_size", 11)
	vbox.add_child(_label)

# ═══════════════════════════════════════════════════════════════
# 輸入處理
# ═══════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			TOGGLE_KEY:
				_overlay_visible = !_overlay_visible
				if _overlay_visible:
					show()
				else:
					hide()
			HITBOX_TOGGLE_KEY:
				_show_hitboxes = !_show_hitboxes
				_apply_hitbox_visibility()
			EXPORT_KEY:
				# DebugBridge 是 autoload，透過 root 安全取得
				var bridge := get_node_or_null("/root/DebugBridge")
				if bridge and bridge.has_method("force_export"):
					bridge.force_export()
				else:
					push_warning("[DebugOverlay] DebugBridge 未載入，無法寫出 JSON")

# ═══════════════════════════════════════════════════════════════
# 更新迴圈
# ═══════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if not _overlay_visible:
		return
	
	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = UPDATE_INTERVAL
	
	_refresh_display()

func _refresh_display() -> void:
	var lines: Array[String] = []
	
	# ── 效能資訊 ─────────────────────────────────────────────────
	var fps: int = Engine.get_frames_per_second()
	var fps_color: String = "[color=#00ff88]" if fps >= 55 else ("[color=#ffcc00]" if fps >= 30 else "[color=#ff4444]")
	lines.append("%sFPS: %d[/color]  物理: %d Hz  節點: %d" % [
		fps_color, fps,
		Engine.physics_ticks_per_second,
		get_tree().get_node_count()
	])
	
	# ── 網路資訊 ─────────────────────────────────────────────────
	var net_info: String
	if not multiplayer.has_multiplayer_peer():
		net_info = "[color=#aaaaaa]網路：離線（單機模式）[/color]"
	else:
		var is_server: bool = multiplayer.is_server()
		var peer_id: int = multiplayer.get_unique_id()
		var role_str: String = "[color=#ff8844]SERVER[/color]" if is_server else "[color=#44aaff]CLIENT[/color]"
		net_info = "網路：%s  PeerID: %d" % [role_str, peer_id]
		var nm := get_node_or_null("/root/NetworkManager")
		if nm and nm.get("connected_players") != null:
			net_info += "  玩家數: [color=#00ff88]%d[/color]" % (nm.connected_players as Dictionary).size()
	lines.append(net_info)
	
	lines.append("[color=#555555]─────────────────────────────────────────[/color]")
	
	# ── 玩家狀態 ─────────────────────────────────────────────────
	var players: Array[Node] = get_tree().get_nodes_in_group("Players")
	if players.is_empty():
		lines.append("[color=#ff6666]⚠ 沒有玩家節點（group: Players）[/color]")
	else:
		var player_colors: Array[String] = ["#FF8C42", "#4CC9F0", "#5DA16E", "#9D5789"]
		var p_idx: int = 0
		for player: Node in players:
			var col: String = player_colors[p_idx % player_colors.size()]
			var pid_str: String
			if multiplayer.has_multiplayer_peer():
				pid_str = "ID:%s" % player.name
			else:
				pid_str = "P%d" % (p_idx + 1)
			
			var pos: Vector2 = player.get("global_position") if player.get("global_position") != null else Vector2.ZERO
			var vel: Vector2 = player.get("velocity") if player.get("velocity") != null else Vector2.ZERO
			var hp: int = player.get("current_health") if player.get("current_health") != null else -1
			var hp_max: int = player.get("max_health") if player.get("max_health") != null else -1
			var stamina: float = player.get("_stamina") if player.get("_stamina") != null else -1.0
			var is_auth: bool = true
			if multiplayer.has_multiplayer_peer() and player.has_method("is_multiplayer_authority"):
				is_auth = player.is_multiplayer_authority()
			
			var auth_str: String = "[color=#00ff88]✓AUTH[/color]" if is_auth else "[color=#aaaaaa]sync[/color]"
			var hp_str: String = "%d/%d" % [hp, hp_max] if hp >= 0 else "N/A"
			var sta_str: String = "%.1f" % stamina if stamina >= 0.0 else "N/A"
			
			lines.append("[color=%s]■ %s[/color] %s  pos(%.0f,%.0f)  vel(%.0f,%.0f)  HP:%s  ST:%s" % [
				col, pid_str, auth_str,
				pos.x, pos.y,
				vel.x, vel.y,
				hp_str, sta_str
			])
			
			# 狀態機
			var sm: Node = player.get_node_or_null("StateMachine")
			if sm and sm.get("current_state") != null:
				lines.append("    [color=#cccccc]狀態機: %s[/color]" % str(sm.get("current_state")))
			
			# 物理狀態標記
			if player.has_method("is_on_floor"):
				var flags: String = ""
				if player.is_on_floor(): flags += "[color=#88ff88]地面[/color] "
				if player.is_on_wall():  flags += "[color=#ffaa44]牆壁[/color] "
				var inv: Variant = player.get("is_invincible")
				if inv != null and inv: flags += "[color=#ff88ff]無敵[/color] "
				var roll: Variant = player.get("_is_rolling")
				if roll != null and roll: flags += "[color=#ffff44]翻滾[/color] "
				if not flags.is_empty():
					lines.append("    " + flags.strip_edges())
			
			p_idx += 1
	
	lines.append("[color=#555555]─────────────────────────────────────────[/color]")
	lines.append("[color=#777777]F4碰撞框:%s  F5強制寫JSON[/color]" % (
		"[color=#00ff88]ON[/color]" if _show_hitboxes else "[color=#ff4444]OFF[/color]"
	))
	
	_label.text = "\n".join(lines)

# ═══════════════════════════════════════════════════════════════
# 碰撞框視覺化
# ═══════════════════════════════════════════════════════════════
func _apply_hitbox_visibility() -> void:
	get_tree().debug_collisions_hint = _show_hitboxes
	print("[DebugOverlay] 碰撞框顯示: %s" % ("ON" if _show_hitboxes else "OFF"))
