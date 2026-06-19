# ponytail: rung=2+5 — CharacterBody2D (rung=2) + WireConstraint velocity projection (rung=5)
extends CharacterBody2D

@export var move_speed: float = 200.0
@export var jump_velocity: float = 501.0
@export var gravity: float = 980.0
@export var reel_speed: float = 100.0
@export var wire_slack: float = 10.0

var _wire: RefCounted = null   # WireConstraint at runtime
var _wire_anchor: Node = null  # NeedleAnchor at runtime

@onready var needle_manager: Node = $NeedleManager
@onready var wire_renderer: Line2D = $WireRenderer
@onready var throw_origin: Marker2D = $AimPivot/ThrowOrigin

func _ready() -> void:
	needle_manager.wire_anchor_ready.connect(_on_wire_anchor_ready)
	needle_manager.needle_retrieved.connect(_on_needle_retrieved)
	wire_renderer.visible = false

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement()
	_apply_wire(delta)
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
	wire_renderer.visible = false

func _on_wire_anchor_ready(anchor: Node) -> void:
	_wire = anchor.wire as RefCounted
	_wire_anchor = anchor
	_wire.setup(anchor.global_position, global_position.distance_to(anchor.global_position) + wire_slack)
	wire_renderer.visible = true

func _on_needle_retrieved(anchor: Node) -> void:
	if anchor == _wire_anchor:
		_cut_wire()

func _update_wire_renderer() -> void:
	if _wire == null or not wire_renderer.visible:
		return
	wire_renderer.clear_points()
	wire_renderer.add_point(Vector2.ZERO)
	wire_renderer.add_point(to_local(_wire.anchor_pos))

func _update_aim_pivot() -> void:
	var mouse_local := get_global_mouse_position() - global_position
	scale.x = -1.0 if mouse_local.x < 0.0 else 1.0

func get_wire_tension() -> float:
	return _wire.tension_ratio(global_position) if _wire != null else 0.0

func get_wire_length() -> float:
	return _wire.max_length if _wire != null else 0.0
