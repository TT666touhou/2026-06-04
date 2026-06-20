# pure data node, no custom logic
class_name NeedleAnchor
extends Node2D

enum Type { ATTACK, WIRE }

var type: int = Type.ATTACK     # int not enum-name: avoids type annotation issues
var wire: RefCounted = null     # WireConstraint at runtime; untyped to avoid cross-script parse
var attached_body: PhysicsBody2D = null
