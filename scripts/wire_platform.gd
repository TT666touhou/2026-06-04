class_name WirePlatform
extends StaticBody2D
# StaticBody2D + CollisionShape2D built-ins

@export var platform_height: float = 6.0

var _anchor_a: Node2D = null
var _anchor_b: Node2D = null

@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	set_collision_layer_value(1, false)  # not on default layer 1
	set_collision_layer_value(4, true)   # layer 4 — player can toggle for drop-through

func setup(anchor_a: Node2D, anchor_b: Node2D) -> void:
	_anchor_a = anchor_a
	_anchor_b = anchor_b
	_shape.one_way_collision = true
	_shape.one_way_collision_margin = 2.0
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
	global_position = (a + b) * 0.5
	# Normalize direction so X is always ≥ 0 → rotation stays within ±90°
	# This ensures the body's local -Y (one-way normal) always points world-up.
	# Without this, shooting right-wall first gives angle≈180°, flipping the
	# one-way direction to world-down and blocking the player from below. (GAP-027)
	var dir := b - a
	if dir.x < 0.0:
		dir = -dir
	global_rotation = dir.angle()
	(_shape.shape as RectangleShape2D).size = Vector2(dist, platform_height)
	_shape.rotation = 0.0
