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
	if _spawn_point == null:
		push_warning("[RoomBase] No SpawnPoint found in room: %s" % room_id)

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

	## Determine spawn position: use left portal's SpawnMarker if available,
	## otherwise fall back to a sensible default above floor level
	var spawn_pos := _get_debug_spawn_pos()
	add_child(player)
	player.global_position = spawn_pos

	## Add a simple Camera2D for the standalone session
	_add_debug_camera(player)

	print("[RoomBase] Debug player spawned at: %s" % str(spawn_pos))

## Find a good spawn position: prefers a portal SpawnMarker, falls back to
## a hardcoded offset inside the room bounds.
func _get_debug_spawn_pos() -> Vector2:
	## Try to find any SpawnMarker inside a RoomPortal
	for child in get_children():
		if child.get_class() == "Node2D" and child.name == "Portals":
			for portal in child.get_children():
				var marker := portal.get_node_or_null("SpawnMarker") as Marker2D
				if marker:
					## Offset slightly inward so player isn't inside portal hitbox
					return marker.global_position + Vector2(60, 0)
		## Also handle portals directly under root (not in Portals container)
		var marker := child.get_node_or_null("SpawnMarker") as Marker2D
		if marker:
			return marker.global_position + Vector2(60, 0)

	## Fall back: sensible position near the bottom-left of typical room layout
	return Vector2(80, -80)

## Add a simple Camera2D that follows the debug player.
## ⚠️ ERR-001 safety: camera added as child of player, not scene root.
func _add_debug_camera(player: Node) -> void:
	## Check if a Camera2D already exists in the scene
	for child in get_children():
		if child is Camera2D:
			return  ## Camera already present, skip

	var cam := Camera2D.new()
	cam.name = "DebugCamera"
	cam.make_current()
	## Smooth follow
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	## Zoom to match the game's pixel-art scale (3x)
	cam.zoom = Vector2(3.0, 3.0)
	player.add_child(cam)
	print("[RoomBase] Debug Camera2D added (zoom=3x, smooth follow)")
