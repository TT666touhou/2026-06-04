extends Node
## GameWorld — 主遊戲場景控制器
## 負責：
##   1. 偵測啟動參數（--local-server / --local-client）
##   2. 自動建立 ENet 連線（本地多人）
##   3. 玩家生成與顏色分配
##   4. 連接 NetworkManager 事件

const PORT := 8910
const HOST := "127.0.0.1"

## 本地多人模式的輸入前綴（依玩家index分配）
## 對應 Project Settings > Input Map 中的 p1_/p2_/p3_/p4_ 動作
const INPUT_PREFIXES := ["", "p1_", "p2_", "p3_", "p4_"]

## 玩家場景路徑（由 MultiplayerSpawner 管理）
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

## 玩家子彈場景（注入到玩家的 bullet_scene 屬性）
const BULLET_SCENE := preload("res://scenes/player/player_bullet.tscn")

@onready var _spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var _players_root: Node2D = $Players
# _camera 由 MultiplayerCamera 場景節點自行 make_current()
# 此處不需持有參照

var _local_player_index: int = 1  ## 本機玩家編號（1=Server, 2-4=Client）

## Rogue-lite 房間生成器
@onready var _dungeon: Node = $DungeonGenerator

## 目前房間容器（存放當前已載入的房間場景）
var _current_room_node: Node = null

# ═══════════════════════════════════════════════════════════════
# 啟動流程
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	# 解析命令列參數
	var args := OS.get_cmdline_user_args()
	var is_server := "--local-server" in args
	var is_client := "--local-client" in args
	
	# 取得玩家 index（Client 傳入）
	var idx_pos := args.find("--player-index")
	if idx_pos >= 0 and idx_pos + 1 < args.size():
		_local_player_index = args[idx_pos + 1].to_int()
	elif is_server:
		_local_player_index = 1
	
	# 連接 NetworkManager 信號
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.player_connected.connect(_on_player_connected)
		nm.player_disconnected.connect(_on_player_disconnected)
	
	# 設定 MultiplayerSpawner
	if _spawner:
		_spawner.spawn_path = NodePath("../Players")  # 相對於 spawner 的路徑
	
	# 啟動連線
	if is_server:
		print("[GameWorld] 啟動為 Server（Player 1）")
		_start_as_server()
	elif is_client:
		print("[GameWorld] 啟動為 Client（Player %d）" % _local_player_index)
		_start_as_client()
	else:
		# 編輯器直接執行（單機測試）
		print("[GameWorld] 單機測試模式")
		_start_solo()

func _start_as_server() -> void:
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm:
		var err: int = nm.host_game()
		if err == OK:
			print("[GameWorld] Server 啟動成功，等待玩家連線...")
			_spawn_player(multiplayer.get_unique_id(), 0)
		else:
			push_error("[GameWorld] Server 啟動失敗：%d" % err)
	multiplayer.peer_connected.connect(_on_peer_connected_server)

func _start_as_client() -> void:
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm:
		var err: int = nm.join_game(HOST)
		if err != OK:
			push_error("[GameWorld] Client 連線失敗：%d" % err)

func _start_solo() -> void:
	## 單機測試：直接生成1個玩家，不需要網路
	## ⚠️ 閃爍/墜入虛空修復（ERR-SPAWN-001）：
	## 玩家必須先隱藏+停用物理，等房間載入完成再顯示。
	## 否則玩家會在虛空出現、受重力下墜、產生閃爍。
	var player := PLAYER_SCENE.instantiate()
	player.name = "SoloPlayer"
	player.player_prefix = "p1_"  ## 單機用 p1_ 前綴（Input Map 有定義 p1_attack/move 等）
	player.bullet_scene = BULLET_SCENE  ## 注入子彈場景
	player.visible = false              ## 隱藏直到房間載入完成
	player.set_physics_process(false)   ## 停用物理（不受重力影響）
	_players_root.add_child(player)
	player.global_position = Vector2(100, -200)  ## 放到畫面外，防止相機抖動
	player.apply_player_color(0)
	## 連接死亡信號
	if player.has_signal("died"):
		player.died.connect(_on_player_died.bind(player))
	print("[GameWorld] 單機玩家節點建立完成（隱藏中，等待房間載入）")

	## 啟動 Rogue-lite 生成（房間載入後會呼叫 _reset_player_positions 顯示玩家）
	if _dungeon:
		_dungeon.generate_run()
		var first_room: String = _dungeon.advance_room()
		if not first_room.is_empty():
			_load_room_scene(first_room)
			print("[GameWorld] 載入第一間房")
		else:
			## 無房間路徑：直接顯示玩家在預設位置
			_show_all_players()
	else:
		push_warning("[GameWorld] DungeonGenerator 節點不存在，跳過房間生成")
		_show_all_players()

# ═══════════════════════════════════════════════════════════════
# 玩家生成（Server 端）
# ═══════════════════════════════════════════════════════════════

## Server 端：新 peer 連線時生成其玩家
func _on_peer_connected_server(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	## 計算 skin_index（根據目前玩家數）
	var nm := get_node_or_null("/root/NetworkManager")
	var skin_idx := 0
	if nm and nm.get("connected_players") != null:
		skin_idx = nm.connected_players.size() - 1
	
	print("[GameWorld] 新玩家連線：peer_id=%d, skin=%d" % [peer_id, skin_idx])
	_spawn_player.rpc(peer_id, skin_idx)

@rpc("authority", "call_local", "reliable")
func _spawn_player(peer_id: int, skin_index: int) -> void:
	## 此函式在所有端執行（call_local），Server 和 Client 各自建立玩家節點
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)  ## 關鍵：name 必須是 peer_id 字串
	
	## 分配輸入前綴（只有本機玩家才有意義）
	if not multiplayer.has_multiplayer_peer() or peer_id == multiplayer.get_unique_id():
		player.player_prefix = INPUT_PREFIXES[_local_player_index] if _local_player_index < INPUT_PREFIXES.size() else ""
	
	_players_root.add_child(player)
	player.global_position = Vector2(80 + skin_index * 40, -50)  ## 分散生成位置
	player.apply_player_color(skin_index)
	## 連接死亡信號
	if player.has_signal("died"):
		player.died.connect(_on_player_died.bind(player))
	
	print("[GameWorld] 玩家節點已建立：name=%s, skin=%d, auth=%s" % [
		player.name, skin_index, str(player.is_multiplayer_authority())
	])

# ═══════════════════════════════════════════════════════════════
# 信號處理
# ═══════════════════════════════════════════════════════════════
func _on_player_connected(peer_id: int, _player_info: Dictionary) -> void:
	print("[GameWorld] NetworkManager: player_connected peer_id=%d" % peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	print("[GameWorld] NetworkManager: player_disconnected peer_id=%d" % peer_id)
	## 移除對應的玩家節點
	var player_node := _players_root.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
		print("[GameWorld] 玩家節點已移除：%d" % peer_id)

# ═══════════════════════════════════════════════════════════════
# Rogue-lite 房間控制
# ═══════════════════════════════════════════════════════════════

## 進入下一間房間（由 RoomTransition 節點觸發，或直接呼叫）
## ⚠️ 此函式必須由 call_deferred 呼叫（見 room_transition.gd）
func load_next_room() -> void:
	if not _dungeon:
		push_warning("[GameWorld] load_next_room: DungeonGenerator 不存在")
		return

	var next_path: String = _dungeon.advance_room()
	if next_path.is_empty():
		## Run 完成，顯示結算畫面
		print("[GameWorld] 所有房間已通過！Run 完成")
		## ⚠️ change_scene_to_file 必須 call_deferred，否則可能在 physics flush 中執行
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/run_complete.tscn")
		return

	_load_room_scene(next_path)

## 玩家死亡處理
func _on_player_died(player: Node) -> void:
	print("[GameWorld] 玩家 %s 死亡" % player.name)
	## 檢查是否所有玩家幹亡
	var alive_count := 0
	for p: Node in _players_root.get_children():
		if p.visible and p.is_physics_processing():
			alive_count += 1
	if alive_count <= 0:
		## 全部死亡 → Game Over
		print("[GameWorld] Game Over - 所有玩家死亡")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/game_over.tscn")
	else:
		## 尚有存活玩家，3秒後重生
		var t := get_tree().create_timer(3.0)
		t.timeout.connect(_respawn_player.bind(player))

## 重生玩家
func _respawn_player(player: Node) -> void:
	if not is_instance_valid(player):
		return
	player.visible = true
	player.set_physics_process(true)
	if player.has_method("take_damage"):
		pass  ## 重生不回血（可撴充）
	if player.get("current_health") != null:
		player.current_health = 1  ## 重生為 1 HP
	player.global_position = Vector2(100, -80)  ## 回到起始點（Y=-80 在地板上方）
	print("[GameWorld] 玩家 %s 重生" % player.name)

## 實際載入房間場景（加入為子節點而非切換主場景）
## ⚠️ 此函式必須透過 call_deferred 呼叫，不可在物理 callback 中直接執行
var _is_loading_room: bool = false  ## 防重入守衛（避免 body_entered 重複觸發）

func _load_room_scene(scene_path: String) -> void:
	## 防重入：若正在載入中則忽略重複呼叫（28次錯誤的根源）
	if _is_loading_room:
		print("[GameWorld] 忽略重複的 load_room_scene 呼叫（正在載入中）")
		return
	_is_loading_room = true

	if not ResourceLoader.exists(scene_path):
		push_warning("[GameWorld] 房間場景不存在：" + scene_path)
		_is_loading_room = false
		return

	## 移除舊房間（已在 deferred 上下文，可直接操作）
	if _current_room_node:
		_current_room_node.queue_free()
		_current_room_node = null

	## 載入新房間
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("[GameWorld] 無法載入場景：" + scene_path)
		_is_loading_room = false
		return

	_current_room_node = scene.instantiate()
	## ⚠️ ERR-001 修復（二次強化）：
	## instantiate() 本身是同步的，但加入場景樹後，節點的 _ready() 會立刻執行。
	## 若 _ready() 中有 Area2D.body_entered.connect() 等物理連結操作，
	## 而此時 Godot 仍在同一 deferred frame 處理 physics，就會爆出 "Can't change state while flushing"。
	## 解法：用 call_deferred 把所有後續操作（包含 add_child 之後的 cleanup/reset）延後到下一幀。
	call_deferred("_finish_room_load", scene_path)

func _finish_room_load(scene_path: String) -> void:
	## 確認節點仍有效（極少數情況下可能被 queue_free）
	if not is_instance_valid(_current_room_node):
		_is_loading_room = false
		return
	## 將房間加入場景樹，放在 Players 之前（確保房間層在下方）
	add_child(_current_room_node)
	move_child(_current_room_node, 0)

	## ─── 清除房間內硬編碼的 Player 和 Camera（避免衝突）───
	_cleanup_room_conflicts(_current_room_node)

	## 套用房間難度
	if _dungeon and _dungeon.has_method("get_current_room"):
		var room_def: Variant = _dungeon.get_current_room()
		if room_def and room_def.get("difficulty_bonus") != null:
			_apply_room_difficulty(roundi(float(room_def.get("difficulty_bonus"))))

	## 重設玩家位置到房間起始點
	_reset_player_positions()

	print("[GameWorld] 房間已載入：", scene_path)
	## 解除防重入鎖（稍微延後，讓本幀物理完全結算）
	call_deferred("_unlock_room_loading")

func _unlock_room_loading() -> void:
	_is_loading_room = false

## 清除房間內硬編碼的 Player 和 Camera 節點（避免與動態生成衝突）
func _cleanup_room_conflicts(room_node: Node) -> void:
	var nodes_to_remove: Array[Node] = []
	for child: Node in room_node.get_children():
		## 移除硬編碼的 Player（群組 "Players" 或 class CharacterBody2D named "Player"）
		if child.is_in_group("Players"):
			nodes_to_remove.append(child)
			print("[GameWorld] 清除房間內硬編碼 Player：", child.name)
		## 移除房間內的靜態相機（Camera2D 類型）
		elif child is Camera2D:
			nodes_to_remove.append(child)
			print("[GameWorld] 清除房間內硬編碼 Camera：", child.name)
	for n: Node in nodes_to_remove:
		n.queue_free()

## 重設所有玩家到生成位置（在房間載入後呼叫）
## ⚠️ 此函式同時負責「顯示」因閃爍修復而隱藏的玩家
func _reset_player_positions() -> void:
	var spawn_x := 80
	var players := _players_root.get_children()
	for i: int in range(players.size()):
		var p := players[i]
		p.global_position = Vector2(spawn_x + i * 50, -80)  ## Y=-80 讓玩家站在地板上方
		## 顯示並啟用物理（閃爍修復：此處才讓玩家可見）
		if not p.visible:
			p.visible = true
			p.set_physics_process(true)
			print("[GameWorld] 玩家 %s 顯示（房間就緒）" % p.name)

func _show_all_players() -> void:
	## 緊急顯示：無房間時直接顯示玩家
	for p in _players_root.get_children():
		p.visible = true
		p.set_physics_process(true)
		p.global_position = Vector2(100, -80)

## 套用房間難度（影響敵人數量）
func _apply_room_difficulty(bonus: int) -> void:
	if not _current_room_node:
		return
	## 啟用房間內被禁用的敵人（spawn_disabled 設為 false）
	var enemies := get_tree().get_nodes_in_group("Enemies")
	var enabled_count := 0
	for enemy: Node in enemies:
		if enabled_count < (5 + bonus * 2):  ## 基礎 5 隻 + 難度倍增
			if enemy.has_method("enable_enemy"):
				enemy.call_deferred("enable_enemy")
			enabled_count += 1
		else:
			break
	print("[GameWorld] 難度加成 %d  啟用敵人：%d 隻" % [bonus, enabled_count])

## Debug 資訊（供 DebugBridge 讀取）
func get_dungeon_debug_info() -> Dictionary:
	if not _dungeon:
		return {"status": "no_dungeon"}
	return _dungeon.get_debug_info()

# ═══════════════════════════════════════════════════════════════
# Portal 系統 — Hollow Knight 風格洞口換房間
# ═══════════════════════════════════════════════════════════════

## 等待進入的洞口 ID（用來在新房間定位玩家）
var _pending_entry_door_id: String = ""

## 由 RoomPortal._do_trigger() 呼叫（已在 call_deferred 環境）
## ⚠️ ERR-001/007 架構：此函式是三層 deferred 的第二層入口
func load_next_room_portal(
		from_door_id: String,
		target_door_id: String,
		target_path: String,
		fade_dur: float = 0.4) -> void:
	_pending_entry_door_id = target_door_id
	print("[GameWorld] Portal 觸發：from=%s → to=%s  path=%s" % [
		from_door_id, target_door_id,
		target_path if not target_path.is_empty() else "[DungeonGen]"
	])
	## 找 ScreenFader（作為 GameWorld 子節點）
	var fader := get_node_or_null("ScreenFader")
	if fader and fader.has_method("fade_out"):
		## 連接 faded_out 一次性信號（CONNECT_ONE_SHOT 自動斷開）
		fader.faded_out.connect(
			_on_faded_out_do_room_change.bind(target_path),
			CONNECT_ONE_SHOT
		)
		fader.fade_out(fade_dur)
	else:
		## 無 Fader 降級：直接換房間
		push_warning("[GameWorld] ScreenFader 不存在，使用降級模式（無 Fade）")
		call_deferred("_do_portal_room_change", target_path)

## Fade Out 完成後的 signal callback
## ⚠️ ERR-007：signal callback 本身可能在 physics flush 中，再次 call_deferred
func _on_faded_out_do_room_change(target_path: String) -> void:
	call_deferred("_do_portal_room_change", target_path)

## 實際決定換哪個房間（三層 deferred 的第三層入口）
func _do_portal_room_change(target_path: String) -> void:
	if target_path.is_empty():
		## DungeonGenerator 決定下一間
		if not _dungeon:
			push_warning("[GameWorld] _do_portal_room_change: DungeonGenerator 不存在")
			return
		var next: String = _dungeon.advance_room()
		if next.is_empty():
			print("[GameWorld] Portal: Run 完成！")
			get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/run_complete.tscn")
			return
		_load_room_scene_portal(next)
	else:
		_load_room_scene_portal(target_path)

## Portal 版本的房間載入（複用三層 deferred 架構，ERR-001/007）
func _load_room_scene_portal(scene_path: String) -> void:
	if _is_loading_room:
		print("[GameWorld] Portal: 忽略重複載入（正在載入中）")
		return
	_is_loading_room = true

	if not ResourceLoader.exists(scene_path):
		push_warning("[GameWorld] Portal 場景不存在：" + scene_path)
		_is_loading_room = false
		return

	## 移除舊房間
	if _current_room_node:
		_current_room_node.queue_free()
		_current_room_node = null

	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("[GameWorld] 無法載入 Portal 場景：" + scene_path)
		_is_loading_room = false
		return

	_current_room_node = scene.instantiate()
	## ⚠️ ERR-007：instantiate 後不立刻 add_child，延後到下一幀
	call_deferred("_finish_portal_room_load", scene_path)

## Portal 版本的房間完成載入（add_child 在此，完全遠離 physics flush）
func _finish_portal_room_load(scene_path: String) -> void:
	if not is_instance_valid(_current_room_node):
		_is_loading_room = false
		return
	add_child(_current_room_node)
	move_child(_current_room_node, 0)

	## 清除衝突節點
	_cleanup_room_conflicts(_current_room_node)

	## 套用難度
	if _dungeon and _dungeon.has_method("get_current_room"):
		var room_def: Variant = _dungeon.get_current_room()
		if room_def and room_def.get("difficulty_bonus") != null:
			_apply_room_difficulty(roundi(float(room_def.get("difficulty_bonus"))))

	## 定位玩家到指定 door_id 的 SpawnMarker
	_reset_player_at_door(_pending_entry_door_id)

	print("[GameWorld] Portal 房間載入完成：", scene_path, "  入口 door_id=", _pending_entry_door_id)

	## Apply CameraZone from new room (if it has one)
	call_deferred("_apply_room_camera_zone_deferred")

	## Fade In
	var fader := get_node_or_null("ScreenFader")
	if fader and fader.has_method("fade_in"):
		fader.fade_in()

	call_deferred("_unlock_room_loading")

## 依據 door_id 尋找目標房間的 RoomPortal（遞迴搜尋，支援 Portals 容器）
## 從其 SpawnMarker 定位玩家
func _reset_player_at_door(entry_door_id: String) -> void:
	var spawn_pos := Vector2(80.0, -80.0)  ## 後備預設位置

	if _current_room_node and not entry_door_id.is_empty():
		## 遞迴搜尋所有子節點（支援 Portals 容器結構）
		var portal := _find_portal_by_door_id(_current_room_node, entry_door_id)
		if portal != null:
			var marker := portal.get_node_or_null("SpawnMarker")
			if marker:
				spawn_pos = (marker as Node2D).global_position
				print("[GameWorld] 找到 SpawnMarker：door_id=%s pos=%s" % [entry_door_id, str(spawn_pos)])
			else:
				push_warning("[GameWorld] RoomPortal '%s' 沒有 SpawnMarker" % entry_door_id)
		else:
			push_warning("[GameWorld] 找不到 door_id='%s' 的 RoomPortal，使用預設位置" % entry_door_id)

	## Walk-in 方向：依 entry_door_id 決定方向向量（§10.11 規格）
	var walk_dir := Vector2.ZERO
	match entry_door_id:
		"left":   walk_dir = Vector2.RIGHT  ## 從左進 → 向右走
		"right":  walk_dir = Vector2.LEFT   ## 從右進 → 向左走
		"top":    walk_dir = Vector2.DOWN   ## 從頂部進 → 向下走
		"bottom": walk_dir = Vector2.UP     ## 從底部進 → 向上走

	## 放置並啟動所有玩家的 Walk-in 動畫
	var players := _players_root.get_children()
	for i: int in range(players.size()):
		var p := players[i]
		p.global_position = spawn_pos + Vector2(float(i) * 40.0, 0.0)
		## 顯示並啟用物理
		if not p.visible:
			p.visible = true
			p.set_physics_process(true)
		## Walk-in 動畫：呼叫 start_room_entry() 鎖定輸入並強制走入（ERR-SPAWN-001 安全）
		if walk_dir != Vector2.ZERO and p.has_method("start_room_entry"):
			p.start_room_entry(walk_dir, 48.0, 0.35)
			print("[GameWorld] 玩家 %s Walk-in 啟動：door_id=%s dir=%s" % [p.name, entry_door_id, str(walk_dir)])
		else:
			print("[GameWorld] 玩家 %s 出現（door_id=%s，無Walk-in）" % [p.name, entry_door_id])


## 遞迴搜尋房間內所有節點，找到指定 door_id 的 RoomPortal
func _find_portal_by_door_id(root: Node, door_id: String) -> RoomPortal:
	for child: Node in root.get_children():
		if child is RoomPortal:
			var portal := child as RoomPortal
			if portal.door_id == door_id:
				return portal
		## 搜尋子容器（如 Portals Node2D）
		var found: RoomPortal = _find_portal_by_door_id(child, door_id)
		if found != null:
			return found
	return null

## ── CameraZone 整合 ────────────────────────────────────────────────────────
## 公開方法：供 RoomBase._apply_camera_zone() 和 CameraZone._notify_camera() 呼叫
## ERR-001 safe: 呼叫者需確保已在 call_deferred 環境
func apply_room_camera_zone(zone: Area2D) -> void:
	var cam := get_node_or_null("MultiplayerCamera")
	if cam == null:
		## 嘗試找 Camera2D 型別的任意相機
		for child in get_children():
			if child is Camera2D:
				cam = child
				break
	if cam == null:
		push_warning("[GameWorld] apply_room_camera_zone: MultiplayerCamera not found")
		return
	if cam.has_method("set_limits_from_zone"):
		cam.set_limits_from_zone(zone)
	else:
		push_warning("[GameWorld] Camera has no set_limits_from_zone method")

## 延後版（在 _finish_portal_room_load 結尾呼叫，確保 room 節點已完全 ready）
func _apply_room_camera_zone_deferred() -> void:
	if _current_room_node == null:
		return
	var zone := _current_room_node.get_node_or_null("CameraZone")
	if zone == null:
		return  ## 舊房間（test_room）無 CameraZone，略過
	apply_room_camera_zone(zone as Area2D)
