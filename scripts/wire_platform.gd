class_name WirePlatform
extends StaticBody2D

@export var platform_height: float = 24.0  # min 24px to prevent tunneling at max player speed

var _anchor_a: Node2D = null
var _anchor_b: Node2D = null

@onready var _shape: CollisionShape2D = $CollisionShape2D

func setup(anchor_a: Node2D, anchor_b: Node2D) -> void:
	_anchor_a = anchor_a
	_anchor_b = anchor_b
	_shape.one_way_collision = true
	_shape.one_way_collision_margin = 8.0  # wider margin helps pass-through reliability
	var rect := RectangleShape2D.new()
	_shape.shape = rect
	_update_body()

func dissolve() -> void:
	queue_free()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_anchor_a) or not is_instance_valid(_anchor_b):
		queue_free()
		return
	_update_body()

func _update_body() -> void:
	var a := _anchor_a.global_position
	var b := _anchor_b.global_position
	var dist := a.distance_to(b)
	if dist < 1.0:
		return
	# Keep body un-rotated so one_way_collision direction stays world-up.
	# Rotate only the CollisionShape2D to align with the wire angle.
	global_position = (a + b) * 0.5
	global_rotation = 0.0
	(_shape.shape as RectangleShape2D).size = Vector2(dist, platform_height)
	_shape.rotation = a.angle_to_point(b)
