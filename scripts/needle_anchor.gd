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
	# Only track moveable bodies (CharacterBody2D, RigidBody2D); walls are StaticBody2D and don't move
	if attached_body == null or not is_instance_valid(attached_body) or attached_body is StaticBody2D:
		return
	if not _offset_ready:
		_body_offset = global_position - attached_body.global_position
		_offset_ready = true
	global_position = attached_body.global_position + _body_offset
