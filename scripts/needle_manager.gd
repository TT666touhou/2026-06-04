# needle state — simplified (GAP-041): attack needles + a single grapple wire.
# Platform mechanism, F-retrieve priority, and the retrieve UI were all removed.
class_name NeedleManager
extends Node

const _NEEDLE_ATTACK := 0
const _NEEDLE_WIRE := 1
const _ANCHOR_ATTACK := 0
const _ANCHOR_WIRE := 1

const _WireConstraintScript = preload("res://scripts/wire_constraint.gd")

@export var max_needles: int = 5
@export var retrieve_radius: float = 60.0
@export var needle_proj_scene: PackedScene
@export var needle_anchor_scene: PackedScene

var _anchors: Array = []
var _in_flight: int = 0
var _needle_layer: Node = null
var _wire_anchor: Node = null      # the single active grapple anchor (null when not grappling)
var _wire_proj: Node = null        # in-flight wire projectile (for release-cancel)

signal wire_anchor_ready(anchor)
signal needle_retrieved(anchor)
signal wire_needle_launched(proj: Node)

func _ready() -> void:
	var root := get_tree().current_scene
	if root:
		_needle_layer = root.get_node_or_null("World/NeedleLayer")

func shoot_attack_needle(from: Vector2, dir: Vector2) -> void:
	if _total_count() >= max_needles:
		return
	_spawn_projectile(from, dir, _NEEDLE_ATTACK)

func shoot_wire_needle(from: Vector2, dir: Vector2) -> void:
	if _total_count() >= max_needles:
		return
	_spawn_projectile(from, dir, _NEEDLE_WIRE)

func place_attack_anchor_instant(hit_pos: Vector2, collider: Object) -> void:
	if _total_count() >= max_needles or needle_anchor_scene == null or _needle_layer == null:
		return
	var anchor := needle_anchor_scene.instantiate()
	anchor.type = _ANCHOR_ATTACK
	anchor.global_position = hit_pos
	anchor.z_index = 1
	if collider is PhysicsBody2D:
		anchor.attached_body = collider as PhysicsBody2D
	_needle_layer.add_child(anchor)
	_anchors.append(anchor)
	if collider != null and collider.has_method("on_needle_embedded"):
		collider.on_needle_embedded(_NEEDLE_ATTACK)

func place_wire_anchor_instant(hit_pos: Vector2, collider: Object) -> void:
	if needle_anchor_scene == null or _needle_layer == null:
		return
	release_wire()
	var anchor := needle_anchor_scene.instantiate()
	anchor.type = _ANCHOR_WIRE
	anchor.global_position = hit_pos
	anchor.z_index = 1
	if collider is PhysicsBody2D:
		anchor.attached_body = collider as PhysicsBody2D
	_needle_layer.add_child(anchor)
	_anchors.append(anchor)
	anchor.wire = _WireConstraintScript.new()
	_wire_anchor = anchor
	wire_anchor_ready.emit(anchor)

func needle_count() -> int:
	return _total_count()

# Auto-retrieve attack needles within range of the player (no F key; GAP-041).
func auto_retrieve_attack(player_pos: Vector2) -> void:
	for anchor in _anchors.duplicate():
		if not is_instance_valid(anchor):
			continue
		if anchor.type == _ANCHOR_ATTACK and anchor.global_position.distance_to(player_pos) <= retrieve_radius:
			_remove_anchor(anchor)

# Release the grapple (right mouse released): cancel the in-flight wire projectile
# or recycle the embedded wire anchor. Idempotent.
func release_wire() -> void:
	if _wire_proj != null and is_instance_valid(_wire_proj):
		_wire_proj.queue_free()
		_in_flight = max(0, _in_flight - 1)
	_wire_proj = null
	if _wire_anchor != null and is_instance_valid(_wire_anchor):
		_remove_anchor(_wire_anchor)
	_wire_anchor = null

func _total_count() -> int:
	return _anchors.size() + _in_flight

func _spawn_projectile(from: Vector2, dir: Vector2, n_type: int) -> void:
	if needle_proj_scene == null or _needle_layer == null:
		return
	var proj := needle_proj_scene.instantiate()
	proj.global_position = from
	proj.call("setup", dir, n_type)
	proj.embedded.connect(_on_embedded.bind(n_type))
	_needle_layer.add_child(proj)
	_in_flight += 1
	if n_type == _NEEDLE_WIRE:
		_wire_proj = proj
		wire_needle_launched.emit(proj)

func _on_embedded(hit_pos: Vector2, collider: Object, n_type: int) -> void:
	_in_flight = max(0, _in_flight - 1)
	if needle_anchor_scene == null or _needle_layer == null:
		return
	var anchor := needle_anchor_scene.instantiate()
	anchor.type = _ANCHOR_ATTACK if n_type == _NEEDLE_ATTACK else _ANCHOR_WIRE
	anchor.global_position = hit_pos
	anchor.z_index = 1
	if collider is PhysicsBody2D:
		anchor.attached_body = collider as PhysicsBody2D
	_needle_layer.add_child(anchor)
	_anchors.append(anchor)
	if anchor.type == _ANCHOR_WIRE:
		anchor.wire = _WireConstraintScript.new()
		_wire_anchor = anchor
		_wire_proj = null
		wire_anchor_ready.emit(anchor)
	# Notify the hit body so it can react (e.g. TrainingDummy starts pulling).
	if collider != null and collider.has_method("on_needle_embedded"):
		collider.on_needle_embedded(n_type)

func _remove_anchor(anchor: Node) -> void:
	_anchors.erase(anchor)
	if anchor == _wire_anchor:
		_wire_anchor = null
	needle_retrieved.emit(anchor)
	# Notify the body the needle was removed from (e.g. TrainingDummy stops pulling).
	if anchor.attached_body != null and is_instance_valid(anchor.attached_body):
		if anchor.attached_body.has_method("on_needle_removed"):
			anchor.attached_body.on_needle_removed(anchor.type)
	anchor.queue_free()
