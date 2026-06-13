extends Node2D
class_name RoomBase
## RoomBase -- Base script for all hand-crafted rooms.
##
## Responsibilities:
##   1. Expose get_spawn_point() -> Vector2 for portal transitions
##   2. Auto-notify GameWorld's MultiplayerCamera via CameraZone on _ready
##
## ERR-001/007 safety: all scene-tree operations use call_deferred.
## ERR-006: This script must exist before any .tscn referencing it is created.

## Optional: human-readable room identifier used in debug output
@export var room_id: String = "room_xx"

# ── Internal refs ──────────────────────────────────────────────────────────
var _spawn_point: Marker2D = null
var _camera_zone = null  ## typed dynamically to avoid circular dependency

func _ready() -> void:
	_spawn_point = get_node_or_null("SpawnPoint") as Marker2D
	if _spawn_point == null:
		push_warning("[RoomBase] No SpawnPoint found in room: %s" % room_id)

	_camera_zone = get_node_or_null("CameraZone")

	## Apply camera zone after physics has settled (ERR-001 safety)
	call_deferred("_apply_camera_zone")
	print("[RoomBase] Ready: %s" % room_id)

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
