extends Area2D
class_name CameraZone
## CameraZone -- Hollow-Knight-style camera boundary trigger.
##
## Place one (or more) of these inside a room. When the player enters,
## MultiplayerCamera smoothly tweens its limits to this zone's bounds.
##
## ERR-001: body_entered must NOT touch the scene tree.
##   All camera updates are deferred via call_deferred.

@export var zone_id: String = "default"

## Tracks whether a player is currently inside this zone
var _player_inside: bool = false

func _ready() -> void:
	## Only detect Players layer (layer 2, mask bit 1 = value 2)
	collision_layer = 0
	collision_mask  = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("[CameraZone] Ready: %s" % zone_id)

## Returns the world-space Rect2 matching this zone's CollisionShape2D.
## Used by MultiplayerCamera.set_limits_from_zone().
func get_camera_limits() -> Rect2:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		push_warning("[CameraZone] No CollisionShape2D child found in zone: %s" % zone_id)
		return Rect2(global_position, Vector2(320.0, 176.0))

	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		push_warning("[CameraZone] CollisionShape2D is not a RectangleShape2D in zone: %s" % zone_id)
		return Rect2(global_position, Vector2(320.0, 176.0))

	var center: Vector2 = global_position + shape_node.position
	var half: Vector2   = rect_shape.size / 2.0
	return Rect2(center - half, rect_shape.size)

## ERR-001: body_entered callback -- no scene-tree manipulation allowed here.
func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("take_damage"):
		return
	_player_inside = true
	## Defer camera update to escape physics-flush context
	call_deferred("_notify_camera")

func _on_body_exited(body: Node2D) -> void:
	if not body.has_method("take_damage"):
		return
	_player_inside = false

## Safe to call outside physics-flush (deferred from _on_body_entered).
func _notify_camera() -> void:
	var game_world := get_tree().get_root().get_node_or_null("GameWorld")
	if game_world == null:
		return
	if game_world.has_method("apply_room_camera_zone"):
		game_world.apply_room_camera_zone(self)
