# needle state machine, ~110 lines
class_name NeedleManager
extends Node

const _NEEDLE_ATTACK := 0
const _NEEDLE_WIRE := 1
const _ANCHOR_ATTACK := 0
const _ANCHOR_WIRE := 1

const _WireConstraintScript = preload("res://scripts/wire_constraint.gd")

@export var max_needles: int = 3
@export var retrieve_radius: float = 60.0
@export var needle_proj_scene: PackedScene
@export var needle_anchor_scene: PackedScene
@export var wire_platform_scene: PackedScene

var _anchors: Array = []
var _in_flight: int = 0
var _current_platform: Node = null
var _platform_anchor_a: Node = null
var _platform_anchor_b: Node = null
var _needle_layer: Node = null
var _wire_layer: Node = null

signal wire_anchor_ready(anchor)
signal needle_retrieved(anchor)
signal wire_needle_launched(proj: Node)
signal platform_created(anchor1: Node, anchor2: Node)

func _ready() -> void:
	var root := get_tree().current_scene
	if root:
		_needle_layer = root.get_node_or_null("World/NeedleLayer")
		_wire_layer = root.get_node_or_null("WireLayer")

func shoot_attack_needle(from: Vector2, dir: Vector2) -> void:
	if _total_count() >= max_needles:
		return
	_spawn_projectile(from, dir, _NEEDLE_ATTACK)

func shoot_wire_needle(from: Vector2, dir: Vector2) -> void:
	if _total_count() >= max_needles:
		return
	_spawn_projectile(from, dir, _NEEDLE_WIRE)

func try_retrieve(player_pos: Vector2, connected_anchor: Node = null) -> void:
	var info := get_retrieve_info(player_pos, connected_anchor)
	var target: Node = info["target"]
	if target != null:
		_remove_anchor(target)

# Single source of truth for "what can F retrieve, and which one would it pick"
# (GAP-032 priority + GAP-033 UI share this). Returns:
#   { "candidates": Array[{anchor, label, priority}], "target": Node-or-null }
# Priority (lower first): 0 attack(no wire) < 1 wire/pendulum < 2 platform endpoint.
# All needles require proximity uniformly (GAP-034). connected_anchor only
# affects priority/label. Ties within a priority are broken by nearest.
func get_retrieve_info(player_pos: Vector2, connected_anchor: Node = null) -> Dictionary:
	var candidates: Array = []
	var target: Node = null
	var best_priority: int = 99
	var best_dist: float = INF
	for anchor in _anchors:
		if not is_instance_valid(anchor):
			continue
		var is_player_wire: bool = anchor == connected_anchor
		var is_platform: bool = anchor == _platform_anchor_a or anchor == _platform_anchor_b
		var dist: float = anchor.global_position.distance_to(player_pos)
		if dist > retrieve_radius:
			continue
		var prio: int = _retrieve_priority(anchor, is_platform)
		candidates.append({
			"anchor": anchor,
			"label": _retrieve_label(anchor, is_platform, is_player_wire),
			"priority": prio,
		})
		if prio < best_priority or (prio == best_priority and dist < best_dist):
			target = anchor
			best_priority = prio
			best_dist = dist
	return { "candidates": candidates, "target": target }

func _retrieve_priority(anchor: Node, is_platform: bool) -> int:
	# Lower retrieved first: attack(no wire) < wire/pendulum < platform endpoint
	if anchor.type == _ANCHOR_ATTACK:
		return 0
	if is_platform:
		return 2
	return 1

func _retrieve_label(anchor: Node, is_platform: bool, is_player_wire: bool) -> String:
	if anchor.type == _ANCHOR_ATTACK:
		return "[F] 攻擊針"
	if is_platform:
		return "[F] 平台針"
	if is_player_wire:
		return "[F] 擺錘針"
	return "[F] 鋼針"

func needle_count() -> int:
	return _total_count()

func get_wire_anchors() -> Array:
	return _anchors.filter(func(a) -> bool: return a.type == _ANCHOR_WIRE)

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
		wire_needle_launched.emit(proj)

func _on_embedded(hit_pos: Vector2, collider: Object, n_type: int) -> void:
	_in_flight = max(0, _in_flight - 1)
	if needle_anchor_scene == null or _needle_layer == null:
		return
	var anchor := needle_anchor_scene.instantiate()
	anchor.type = _ANCHOR_ATTACK if n_type == _NEEDLE_ATTACK else _ANCHOR_WIRE
	anchor.global_position = hit_pos
	if collider is PhysicsBody2D:
		anchor.attached_body = collider as PhysicsBody2D
	_needle_layer.add_child(anchor)
	_anchors.append(anchor)
	if anchor.type == _ANCHOR_WIRE:
		anchor.wire = _WireConstraintScript.new()
		wire_anchor_ready.emit(anchor)
		if get_wire_anchors().size() == 2:  # Only create platform on 2nd wire anchor; 3rd+ keeps old platform
			_try_create_platform()

func _try_create_platform() -> void:
	var wire_anchors := get_wire_anchors()
	if wire_anchors.size() < 2 or wire_platform_scene == null or _wire_layer == null:
		return
	var a1: Node = wire_anchors[0]
	var a2: Node = wire_anchors[1]
	if _current_platform != null:
		_current_platform.call("dissolve")
	var platform := wire_platform_scene.instantiate()
	_wire_layer.add_child(platform)
	platform.call("setup", a1, a2)
	_current_platform = platform
	_platform_anchor_a = a1
	_platform_anchor_b = a2
	platform_created.emit(a1, a2)

func _remove_anchor(anchor: Node) -> void:
	_anchors.erase(anchor)
	var platform_dissolved := false
	if _current_platform != null:
		if anchor == _platform_anchor_a or anchor == _platform_anchor_b:
			if is_instance_valid(_current_platform):
				_current_platform.call("dissolve")
			_current_platform = null
			_platform_anchor_a = null
			_platform_anchor_b = null
			platform_dissolved = true
	needle_retrieved.emit(anchor)
	# only transition to remaining anchor when platform dissolves,
	# not when retrieving the active pendulum anchor (GAP-029)
	if platform_dissolved:
		var remaining := get_wire_anchors()
		if remaining.size() > 0:
			wire_anchor_ready.emit(remaining[0])
	anchor.queue_free()
