# ponytail: rung=2+5 — CharacterBody2D (rung=2) + WireConstraint + catenary Line2D (rung=5)
extends CharacterBody2D

const WIRE_SEGMENTS := 8
const PLATFORM_TIGHTEN_SPEED := 320.0  # px/s — rate at which platform wire slack reduces

@export var move_speed: float = 200.0
@export var jump_velocity: float = 501.0
@export var gravity: float = 980.0
@export var reel_speed: float = 100.0
@export var wire_slack: float = 10.0

var _wire: RefCounted = null       # WireConstraint; null when not in pendulum mode
var _wire_anchor: Node = null      # anchor1 — valid in both pendulum and platform modes
var _wire_anchor2: Node = null     # anchor2 — valid only in platform mode
var _wire_projectile: Node = null  # in-flight wire needle; cleared on embed
var _platform_slack: float = 0.0   # extra slack in platform wire; decreases over time

@onready var needle_manager: Node = $NeedleManager
@onready var wire_renderer: Line2D = $WireRenderer
@onready var throw_origin: Marker2D = $AimPivot/ThrowOrigin

func _ready() -> void:
	needle_manager.wire_anchor_ready.connect(_on_wire_anchor_ready)
	needle_manager.needle_retrieved.connect(_on_needle_retrieved)
	needle_manager.wire_needle_launched.connect(_on_wire_needle_launched)
	needle_manager.platform_created.connect(_on_platform_created)
	wire_renderer.top_level = true  # world-space rendering, immune to Player scale flip
	wire_renderer.visible = false

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement()
	_apply_wire(delta)
	if _wire_anchor2 != null:
		_platform_slack = maxf(0.0, _platform_slack - PLATFORM_TIGHTEN_SPEED * delta)
	move_and_slide()
	_update_wire_renderer()
	_update_aim_pivot()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and is_on_floor():
		velocity.y = -jump_velocity
	if event.is_action_pressed("drop_through") and is_on_floor():
		position.y += 2.0
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_shoot_needle()
	if event.is_action_pressed("cut_wire"):
		_cut_wire()
	if event.is_action_pressed("retrieve_needle"):
		needle_manager.try_retrieve(global_position)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func _apply_movement() -> void:
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * move_speed

func _apply_wire(delta: float) -> void:
	if _wire == null:
		return
	if Input.is_action_pressed("reel_wire"):
		_wire.reel_in(reel_speed, delta)
	velocity = _wire.apply(global_position, velocity)

func _shoot_needle() -> void:
	var from := throw_origin.global_position if throw_origin else global_position
	var dir := (get_global_mouse_position() - from).normalized()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		needle_manager.shoot_wire_needle(from, dir)
	else:
		needle_manager.shoot_attack_needle(from, dir)

func _cut_wire() -> void:
	_wire = null
	_wire_anchor = null
	_wire_anchor2 = null
	_platform_slack = 0.0
	wire_renderer.visible = false

func _on_wire_needle_launched(proj: Node) -> void:
	_wire_projectile = proj

func _on_wire_anchor_ready(anchor: Node) -> void:
	_wire_projectile = null
	_wire = anchor.wire as RefCounted
	_wire_anchor = anchor
	_wire_anchor2 = null
	_platform_slack = 0.0
	_wire.setup(anchor.global_position, global_position.distance_to(anchor.global_position) + wire_slack)

func _on_needle_retrieved(anchor: Node) -> void:
	if anchor == _wire_anchor or anchor == _wire_anchor2:
		_cut_wire()

func _on_platform_created(a1: Node, a2: Node) -> void:
	_wire = null          # release pendulum constraint
	_wire_anchor = a1
	_wire_anchor2 = a2
	_platform_slack = 40.0  # start with slack; will physically contract to 0

func _update_wire_renderer() -> void:
	# In-flight: straight line from player to flying needle
	if _wire_projectile != null and is_instance_valid(_wire_projectile):
		wire_renderer.visible = true
		wire_renderer.clear_points()
		wire_renderer.add_point(global_position)
		wire_renderer.add_point(_wire_projectile.global_position)
		return
	_wire_projectile = null

	# Platform mode: catenary anchor1→anchor2, slack contracts to 0 (tightening effect)
	if _wire_anchor2 != null and is_instance_valid(_wire_anchor2) and is_instance_valid(_wire_anchor):
		wire_renderer.visible = true
		wire_renderer.clear_points()
		_draw_catenary(_wire_anchor.global_position, _wire_anchor2.global_position, _platform_slack)
		return

	# Pendulum mode: catenary player→anchor, sag grows with slack
	if _wire != null:
		var dist := global_position.distance_to(_wire.anchor_pos)
		var slack := maxf(0.0, _wire.max_length - dist)
		wire_renderer.visible = true
		wire_renderer.clear_points()
		_draw_catenary(global_position, _wire.anchor_pos, slack)
		return

	wire_renderer.visible = false

func _draw_catenary(from: Vector2, to: Vector2, slack: float) -> void:
	var sag := minf(slack * 0.35, 60.0)
	for i in range(WIRE_SEGMENTS + 1):
		var t := float(i) / float(WIRE_SEGMENTS)
		var pt := from.lerp(to, t)
		pt.y += sag * sin(PI * t)
		wire_renderer.add_point(pt)

func _update_aim_pivot() -> void:
	var mouse_local := get_global_mouse_position() - global_position
	scale.x = -1.0 if mouse_local.x < 0.0 else 1.0

func get_wire_tension() -> float:
	return _wire.tension_ratio(global_position) if _wire != null else 0.0

func get_wire_length() -> float:
	return _wire.max_length if _wire != null else 0.0
