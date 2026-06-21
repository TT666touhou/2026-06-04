class_name NeedleAnchor
extends Node2D

enum Type { ATTACK, WIRE }

var type: int = Type.ATTACK
var wire: RefCounted = null
var attached_body: PhysicsBody2D = null

# Offset from body origin captured on first physics frame after embedding
var _body_offset: Vector2 = Vector2.ZERO
var _offset_ready: bool = false

func _physics_process(_delta: float) -> void:
	if attached_body == null or not is_instance_valid(attached_body):
		return
	if not _offset_ready:
		_body_offset = global_position - attached_body.global_position
		_offset_ready = true
	global_position = attached_body.global_position + _body_offset
