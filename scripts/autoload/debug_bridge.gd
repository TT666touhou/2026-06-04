extends Node
## DebugBridge — AI感知橋
## Autoload 名稱：DebugBridge
## 用途：每秒將遊戲完整狀態寫出到 user://debug_state.json
##       讓 AI 可以在不打開遊戲的情況下分析遊戲內部狀態
##
## AI 讀取方式：
##   路徑（Windows）：%APPDATA%\Godot\app_userdata\[專案名]\debug_state.json
##   或從 Godot 輸出的 user:// 路徑

const EXPORT_INTERVAL: float = 1.0   ## 每秒寫出一次
const OUTPUT_PATH := "user://debug_state.json"

var _timer: float = 0.0
var _enabled: bool = true  ## 可在 Inspector 或代碼關閉

func _ready() -> void:
	set_process(true)
	print("[DebugBridge] 啟動。輸出路徑：", ProjectSettings.globalize_path(OUTPUT_PATH))

func _process(delta: float) -> void:
	if not _enabled:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = EXPORT_INTERVAL
	_write_state()

## 強制立即寫出（按 F5 觸發）
func force_export() -> void:
	_timer = EXPORT_INTERVAL
	_write_state()
	print("[DebugBridge] 已強制寫出 JSON 狀態")

# ═══════════════════════════════════════════════════════════════
# 狀態收集與寫出
# ═══════════════════════════════════════════════════════════════
func _write_state() -> void:
	var state := _collect_state()
	var json_str := JSON.stringify(state, "\t")
	
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[DebugBridge] 無法開啟寫出檔案：" + OUTPUT_PATH)
		return
	file.store_string(json_str)
	file.close()

func _collect_state() -> Dictionary:
	var state: Dictionary = {}
	
	# ── 時間戳 ──────────────────────────────────────────────────
	state["timestamp"] = Time.get_unix_time_from_system()
	state["timestamp_str"] = Time.get_datetime_string_from_system()
	
	# ── 效能 ──────────────────────────────────────────────────────
	state["fps"] = Engine.get_frames_per_second()
	state["physics_fps"] = Engine.physics_ticks_per_second
	state["node_count"] = get_tree().get_node_count()
	
	# ── 網路資訊 ─────────────────────────────────────────────────
	var net: Dictionary = {}
	net["has_peer"] = multiplayer.has_multiplayer_peer()
	if multiplayer.has_multiplayer_peer():
		net["is_server"] = multiplayer.is_server()
		net["peer_id"] = multiplayer.get_unique_id()
		if has_node("/root/NetworkManager"):
			var nm := get_node("/root/NetworkManager")
			if nm.get("connected_players") != null:
				net["connected_count"] = nm.connected_players.size()
				net["connected_ids"] = nm.connected_players.keys()
	state["network"] = net
	
	# ── 玩家狀態 ─────────────────────────────────────────────────
	var players_data: Array = []
	var players := get_tree().get_nodes_in_group("Players")
	for player in players:
		var p: Dictionary = {}
		p["node_name"] = player.name
		
		if multiplayer.has_multiplayer_peer():
			p["peer_id"] = player.name.to_int()
			p["is_authority"] = player.is_multiplayer_authority()
		else:
			p["peer_id"] = -1
			p["is_authority"] = true
		
		# 位置與速度
		var pos: Vector2 = player.global_position
		var vel: Vector2 = Vector2.ZERO
		if player.get("velocity") != null:
			vel = player.velocity
		p["position"] = {"x": snappedf(pos.x, 0.1), "y": snappedf(pos.y, 0.1)}
		p["velocity"] = {"x": snappedf(vel.x, 0.1), "y": snappedf(vel.y, 0.1)}
		
		# 生命值
		p["hp"] = player.get("current_health") if player.get("current_health") != null else -1
		p["hp_max"] = player.get("max_health") if player.get("max_health") != null else -1
		p["stamina"] = snappedf(float(player.get("_stamina") if player.get("_stamina") != null else -1.0), 0.01)
		
		# 物理狀態
		if player.has_method("is_on_floor"):
			p["on_floor"] = player.is_on_floor()
			p["on_wall"] = player.is_on_wall()
		p["is_invincible"] = player.get("is_invincible") if player.get("is_invincible") != null else false
		p["is_rolling"] = player.get("_is_rolling") if player.get("_is_rolling") != null else false
		
		# 狀態機
		var sm := player.get_node_or_null("StateMachine")
		if sm:
			p["state_machine"] = str(sm.get("current_state")) if sm.get("current_state") != null else "unknown"
		
		players_data.append(p)
	state["players"] = players_data
	state["player_count"] = players_data.size()
	
	# ── 敵人狀態（摘要）──────────────────────────────────────────
	var enemies := get_tree().get_nodes_in_group("Enemies")
	var enemies_data: Array = []
	for enemy in enemies:
		var e: Dictionary = {}
		var epos: Vector2 = enemy.global_position
		e["node_name"] = enemy.name
		e["position"] = {"x": snappedf(epos.x, 0.1), "y": snappedf(epos.y, 0.1)}
		e["hp"] = enemy.get("current_health") if enemy.get("current_health") != null else -1
		var esm := enemy.get_node_or_null("StateMachine")
		if esm:
			e["state"] = str(esm.get("current_state")) if esm.get("current_state") != null else "unknown"
		enemies_data.append(e)
	state["enemies"] = enemies_data
	state["enemy_count"] = enemies_data.size()
	
	# ── 場景資訊 ─────────────────────────────────────────────────
	var scene := get_tree().current_scene
	state["current_scene"] = scene.name if scene else "null"
	
	return state
