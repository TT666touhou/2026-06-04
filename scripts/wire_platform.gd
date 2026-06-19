# ponytail: rung=5 — dynamic StaticBody2D between two anchors, ~50 lines
class_name WirePlatform
extends StaticBody2D

@export var platform_height: float = 4.0

var _anchor_a: Node2D = null   # NeedleAnchor at runtime
var _anchor_b: Node2D = null   # NeedleAnchor at runtime

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: ColorRect = $Visual

func setup(anchor_a: Node2D, anchor_b: Node2D) -> void:
	_anchor_a = anchor_a
	_anchor_b = anchor_b
	_shape.one_way_collision = true
	var rect := RectangleShape2D.new()
	_shape.shape = rect
	_update_shape()

func dissolve() -> void:
	queue_free()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_anchor_a) or not is_instance_valid(_anchor_b):
		queue_free()
		return
	_update_shape()

func _update_shape() -> void:
	var a := _anchor_a.global_position
	var b := _anchor_b.global_position
	var length := a.distance_to(b)
	if length < 1.0:
		return
	global_position = (a + b) * 0.5
	global_rotation = a.angle_to_point(b)
	(_shape.shape as RectangleShape2D).size = Vector2(length, platform_height)
	_visual.size = Vector2(length, platform_height)
	_visual.position = Vector2(-length * 0.5, -platform_height * 0.5)
