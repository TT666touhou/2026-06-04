extends Node2D
class_name RoomBase
## RoomBase -- Base script for all hand-crafted rooms.
##
## Responsibilities:
##   1. Expose get_spawn_point() -> Vector2 for portal transitions
##   2. Auto-notify GameWorld's MultiplayerCamera via CameraZone on _ready
##   3. [DEV TOOL] Auto-spawn debug player when scene is run directly (F6)
##
## ERR-001/007 safety: all scene-tree operations use call_deferred.
## ERR-006: This script must exist before any .tscn referencing it is created.

## Optional: human-readable room identifier used in debug output
@export var room_id: String = "room_xx"

# ── Internal refs ──────────────────────────────────────────────────────────
var _spawn_point: Marker2D = null
var _camera_zone = null  ## typed dynamically to avoid circular dependency

# ── Debug player scenes (only loaded in F6 standalone mode) ───────────────
const _DEBUG_PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const _DEBUG_BULLET_SCENE_PATH := "res://scenes/player/player_bullet.tscn"

func _ready() -> void:
	_spawn_point = get_node_or_null("SpawnPoint") as Marker2D
	## SpawnPoint 預警郏延至 _get_debug_spawn_info() 判斷：
	## 若有 Checkpoint 或 Portal SpawnMarker 就不需要 SpawnPoint
	## 此處不發出預警，_maybe_spawn_debug_player 內部已有 fallback 機制

	_camera_zone = get_node_or_null("CameraZone")

	## Apply camera zone after physics has settled (ERR-001 safety)
	call_deferred("_apply_camera_zone")
	print("[RoomBase] Ready: %s" % room_id)

	## DEV TOOL: auto-spawn debug player when this room is the root scene (F6)
	## ⚠️ ERR-001 safety: deferred so physics is settled before adding player
	call_deferred("_maybe_spawn_debug_player")

## Returns the world-space spawn position for this room.
## Falls back to the room's own global_position if SpawnPoint is missing.
func get_spawn_point() -> Vector2:
	if _spawn_point != null:
		return _spawn_point.global_position
	push_warning("[RoomBase] SpawnPoint missing, returning room origin.")
	return global_position

## Called deferred from _ready to avoid physics-flush issues (ERR-001).
func _apply_camera_zone() -> void:
	if _camera_zone == null:
		return
	## Walk up to find GameWorld, then locate MultiplayerCamera
	var game_world := get_tree().get_root().get_node_or_null("GameWorld")
	if game_world == null:
		return
	if game_world.has_method("apply_room_camera_zone"):
		game_world.apply_room_camera_zone(_camera_zone)

## DEV TOOL: Spawn a debug player if this room is the F6 root scene.
## Detection: the scene tree root's first child is this RoomBase node,
## meaning no GameWorld/AutoLoad infrastructure is present.
## In normal game flow (via GameWorld), this function does nothing.
##
## F6 spawn 優先順序：
##   1. 找到房間內的 Checkpoint → 直接在 SpawnMarker 旁生成（無 Walk-in）
##   2. 找到 Portal 的 SpawnMarker → Walk-in 進場動畫
##   3. Fallback Vector2(80, -80) → Walk-in 從右方進入
func _maybe_spawn_debug_player() -> void:
	## Check: is this RoomBase the effective root scene?
	## In standalone F6 mode, get_tree().current_scene == self
	## In GameWorld mode, get_tree().current_scene is GameWorld, not us
	var current_scene := get_tree().current_scene
	if current_scene != self:
		return  ## Normal GameWorld mode — do nothing

	## Verify scene resources exist before loading
	if not ResourceLoader.exists(_DEBUG_PLAYER_SCENE_PATH):
		push_warning("[RoomBase] Debug player scene not found: %s" % _DEBUG_PLAYER_SCENE_PATH)
		return

	print("[RoomBase] F6 standalone mode detected — spawning debug player for: %s" % room_id)

	## Load scenes
	var player_packed := load(_DEBUG_PLAYER_SCENE_PATH) as PackedScene
	if player_packed == null:
		push_error("[RoomBase] Failed to load debug player scene")
		return

	var player := player_packed.instantiate()
	player.name = "DebugPlayer"
	player.add_to_group("Players")

	## Set input prefix (p1_ is always available in project input map)
	if player.get("player_prefix") != null:
		player.player_prefix = "p1_"

	## Inject bullet scene if available
	if ResourceLoader.exists(_DEBUG_BULLET_SCENE_PATH):
		var bullet_packed := load(_DEBUG_BULLET_SCENE_PATH) as PackedScene
		if bullet_packed and player.get("bullet_scene") != null:
			player.bullet_scene = bullet_packed

	## Apply color skin 0
	if player.has_method("apply_player_color"):
		player.apply_player_color(0)

	## 取得 spawn 資訊（Dictionary: pos, mode, direction）
	var spawn_info := _get_debug_spawn_info()
	add_child(player)

	if spawn_info["mode"] == "checkpoint":
		## Checkpoint spawn：直接出現在 SpawnMarker 旁（無 Walk-in）
		player.global_position = spawn_info["pos"]
		## 設定朝向為進場方向的相反（玩家面朝房間內部）
		var dir: Vector2 = spawn_info["direction"]
		if player.get("_facing") != null and dir.x != 0.0:
			player._facing = sign(dir.x)
		print("[RoomBase] Checkpoint spawn at: %s" % str(spawn_info["pos"]))
	else:
		## Walk-in spawn：計算邊界外起始位置，然後 Walk-in
		var dir: Vector2 = spawn_info["direction"]
		var target_pos: Vector2 = spawn_info["pos"]
		var walk_distance: float = 64.0
		var walk_duration: float = 0.5
		## 起始位置 = 目標位置 - 方向 * walk_distance（在邊界外）
		player.global_position = target_pos - dir * walk_distance
		if player.has_method("start_room_entry"):
			player.start_room_entry(dir, walk_distance, walk_duration)
		print("[RoomBase] Walk-in spawn, direction=%s, from=%s to=%s" % [
			str(dir), str(player.global_position), str(target_pos)])

	## Add a simple Camera2D for the standalone session
	_add_debug_camera(player)

## 回傳 F6 spawn 的完整資訊 Dictionary: {pos, mode, direction}
## mode: "checkpoint" | "portal" | "fallback"
func _get_debug_spawn_info() -> Dictionary:
	## 優先 1：找房間內的 Checkpoint（group: Checkpoints）
	for child: Node in get_children():
		## Checkpoint 可能直接是 child 或在容器中
		if child.is_in_group("Checkpoints"):
			var cp_pos: Vector2 = child.global_position
			var cp_dir: Vector2 = Vector2.RIGHT
			if child.has_method("get_spawn_position"):
				cp_pos = child.get_spawn_position()
			if child.has_method("get_entry_vector"):
				cp_dir = child.get_entry_vector()
			return {"pos": cp_pos, "mode": "checkpoint", "direction": cp_dir}
		## 也搜索子節點容器（如 CheckpointContainer）
		for grandchild: Node in child.get_children():
			if grandchild.is_in_group("Checkpoints"):
				var cp_pos: Vector2 = grandchild.global_position
				var cp_dir: Vector2 = Vector2.RIGHT
				if grandchild.has_method("get_spawn_position"):
					cp_pos = grandchild.get_spawn_position()
				if grandchild.has_method("get_entry_vector"):
					cp_dir = grandchild.get_entry_vector()
				return {"pos": cp_pos, "mode": "checkpoint", "direction": cp_dir}

	## 優先 2：找 Portal 的 SpawnMarker
	for child: Node in get_children():
		if child.get_class() == "Node2D" and child.name == "Portals":
			for portal: Node in child.get_children():
				var marker: Marker2D = portal.get_node_or_null("SpawnMarker") as Marker2D
				if marker:
					## Walk-in 方向：從 SpawnMarker 位置判斷（靠左側→從右方進入）
					var direction := _guess_portal_entry_direction(marker.global_position)
					return {"pos": marker.global_position, "mode": "portal", "direction": direction}
		## 也搜索直接在 root 下的 Portal SpawnMarker
		## ERR-A fix: 用 root_marker 避免與 inner scope 的 marker 同名（GDScript shadow 警告）
		var root_marker: Marker2D = child.get_node_or_null("SpawnMarker") as Marker2D
		if root_marker:
			var direction := _guess_portal_entry_direction(root_marker.global_position)
			return {"pos": root_marker.global_position, "mode": "portal", "direction": direction}

	## Fallback：預設位置右側進入
	return {"pos": Vector2(80, -80), "mode": "fallback", "direction": Vector2.RIGHT}

## 根據 SpawnMarker 的 X 位置猜測入場方向
## 靠近左邊界 → 從右方（Vector2.RIGHT）進入
## 靠近右邊界 → 從左方（Vector2.LEFT）進入
func _guess_portal_entry_direction(marker_pos: Vector2) -> Vector2:
	## 用 CameraZone 的邊界判斷（若有）
	## ERR-030 fix: 顯式型別避免 Variant 推斷失敗
	var cam_zone: Node2D = get_node_or_null("CameraZone") as Node2D
	if cam_zone != null:
		var shape_node: CollisionShape2D = cam_zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node != null:
			var shape := shape_node.shape
			if shape is RectangleShape2D:
				var rect_center: Vector2 = cam_zone.global_position + shape_node.position
				## marker 在中心左側 → 從右方進入（Walk-in 向右）
				if marker_pos.x < rect_center.x:
					return Vector2.RIGHT
				else:
					return Vector2.LEFT
	## 無法判斷：預設從右方進入
	return Vector2.RIGHT

## Add a simple Camera2D that follows the debug player.
## ⚠️ ERR-001 safety: camera added as child of player, not scene root.
## ERR-CAMERA-F6 fix: Apply CameraZone limits so F6 behaviour matches F5/GameWorld.
func _add_debug_camera(player: Node) -> void:
	## Check if a Camera2D already exists in the scene
	for child in get_children():
		if child is Camera2D:
			return  ## Camera already present, skip

	var cam := Camera2D.new()
	cam.name = "DebugCamera"
	## Smooth follow
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	## ★ ERR-CAMERA-ZOOM 修復：F6 縮放必須與 F5 相同（ MultiplayerCamera.max_zoom = 4.0）
	## GDD §2.1： Camera2D zoom=4，等效 32px/tile 顯示
	cam.zoom = Vector2(4.0, 4.0)

	## ── ERR-CAMERA-F6 修復 ────────────────────────────────────────────────
	## F5 模式：GameWorld.MultiplayerCamera 透過 set_limits_from_zone(zone) 取得邊界。
	## F6 模式：我們必須直接讀取 CameraZone 的 Rect2 並設定 limit_*，
	##          否則鏡頭會在無限制的空間中自由漂移，看起來和 F5 完全不同。
	var zone_node: Node = get_node_or_null("CameraZone")
	if zone_node != null and zone_node.has_method("get_camera_limits"):
		var zone: CameraZone = zone_node as CameraZone
		if zone != null:
			var rect: Rect2 = zone.get_camera_limits()
			cam.limit_left   = int(rect.position.x)
			cam.limit_top    = int(rect.position.y)
			cam.limit_right  = int(rect.position.x + rect.size.x)
			cam.limit_bottom = int(rect.position.y + rect.size.y)
			print("[RoomBase] Debug camera limits applied from CameraZone: L=%d T=%d R=%d B=%d" % [
				cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])
		else:
			push_warning("[RoomBase] CameraZone node is not CameraZone class, limits not applied")
	else:
		push_warning("[RoomBase] No CameraZone found; F6 camera will have no boundary limits")

	## ERR-D fix: add_child 必須在 make_current() 之前，否則 !is_inside_tree() 止渡
	player.add_child(cam)
	cam.make_current()
	print("[RoomBase] Debug Camera2D added (zoom=4x 匹配 F5/MultiplayerCamera, smooth follow)")
