extends CharacterBody2D

const WIRE_SEGMENTS := 8
const PLATFORM_TIGHTEN_SPEED := 320.0

@export var move_speed: float = 200.0
@export var jump_velocity: float = 501.0
@export var gravity: float = 980.0
@export var reel_speed: float = 150.0
@export var wire_slack: float = 30.0

var _wire: RefCounted = null
var _wire_anchor: Node = null       # active pendulum anchor (swinging)
var _wire_projectile: Node = null
var _platform_a: Node = null        # platform endpoint A — independent of pendulum state
var _platform_b: Node = null        # platform endpoint B
var _platform_slack: float = 0.0
var _platform_renderer: Line2D = null

@onready var needle_manager: Node = $NeedleManager
@onready var wire_renderer: Line2D = $WireRenderer
@onready var throw_origin: Marker2D = $AimPivot/ThrowOrigin

func _ready() -> void:
	needle_manager.wire_anchor_ready.connect(_on_wire_anchor_ready)
	needle_manager.needle_retrieved.connect(_on_needle_retrieved)
	needle_manager.wire_needle_launched.connect(_on_wire_needle_launched)
	needle_manager.platform_created.connect(_on_platform_created)
	wire_renderer.top_level = true
	wire_renderer.visible = false
	_platform_renderer = Line2D.new()
	_platform_renderer.top_level = true
	_platform_renderer.visible = false
	_platform_renderer.width = 1.5
	_platform_renderer.default_color = Color(0.95, 0.9, 0.55, 0.9)
	add_child(_platform_renderer)

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement()
	_apply_wire(delta)
	if _platform_b != null:
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
		# E key: directly retract position (rope winch, not spring)
		var to_anchor: Vector2 = _wire.anchor_pos - global_position
		var dist: float = to_anchor.length()
		if dist > _wire.max_length and dist > 0.0:
			position += (to_anchor / dist) * (dist - _wire.max_length)
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
	_platform_a = null
	_platform_b = null
	_platform_slack = 0.0
	wire_renderer.visible = false
	if _platform_renderer != null:
		_platform_renderer.visible = false

func _on_wire_needle_launched(proj: Node) -> void:
	_wire_projectile = proj

func _on_wire_anchor_ready(anchor: Node) -> void:
	_wire_projectile = null
	_wire = anchor.wire as RefCounted
	_wire_anchor = anchor
	_wire.setup(anchor.global_position, global_position.distance_to(anchor.global_position) + wire_slack)

func _on_needle_retrieved(anchor: Node) -> void:
	if anchor == _wire_anchor:
		_wire = null
		_wire_anchor = null
	if anchor == _platform_a or anchor == _platform_b:
		_platform_a = null
		_platform_b = null
		_platform_slack = 0.0
		if _platform_renderer != null:
			_platform_renderer.visible = false

func _on_platform_created(a1: Node, a2: Node) -> void:
	_wire = null
	_wire_anchor = null
	if _platform_a != a1 or _platform_b != a2:
		_platform_slack = 40.0
	_platform_a = a1
	_platform_b = a2

func _update_wire_renderer() -> void:
	# Platform renderer — independent of pendulum, always updated
	if _platform_a != null and is_instance_valid(_platform_a) \
			and _platform_b != null and is_instance_valid(_platform_b):
		_platform_renderer.visible = true
		_platform_renderer.default_color = Color(0.95, 0.9, 0.55, 0.9)
		_platform_renderer.width = 1.5
		_platform_renderer.clear_points()
		_draw_catenary_line(_platform_renderer, _platform_a.global_position, _platform_b.global_position, _platform_slack)
	else:
		if _platform_renderer != null:
			_platform_renderer.visible = false

	# Priority 1: Anchor exists + needle in flight → show anchor → flying needle
	if _wire_anchor != null and is_instance_valid(_wire_anchor) \
			and _wire_projectile != null and is_instance_valid(_wire_projectile):
		wire_renderer.default_color = Color(0.95, 0.9, 0.55, 0.75)
		wire_renderer.width = 1.5
		wire_renderer.visible = true
		wire_renderer.clear_points()
		wire_renderer.add_point(_wire_anchor.global_position)
		wire_renderer.add_point(_wire_projectile.global_position)
		return

	# Priority 2: Pendulum mode — yellow, brightens/thickens under tension
	if _wire != null and _wire_anchor != null and is_instance_valid(_wire_anchor):
		var dist := global_position.distance_to(_wire.anchor_pos)
		var slack := maxf(0.0, _wire.max_length - dist)
		var tension := clampf(1.0 - slack / _wire.max_length, 0.0, 1.0)
		wire_renderer.default_color = Color(0.95, 0.9, 0.55, 1.0).lerp(Color(1.0, 1.0, 0.8, 1.0), tension)
		wire_renderer.width = 1.5 + tension * 1.5
		wire_renderer.visible = true
		wire_renderer.clear_points()
		_draw_catenary_line(wire_renderer, global_position, _wire.anchor_pos, slack)
		return

	# Priority 3: In-flight only — dim, thin; no existing wire at all
	if _wire_projectile != null and is_instance_valid(_wire_projectile):
		wire_renderer.default_color = Color(0.95, 0.9, 0.55, 0.6)
		wire_renderer.width = 1.0
		wire_renderer.visible = true
		wire_renderer.clear_points()
		wire_renderer.add_point(global_position)
		wire_renderer.add_point(_wire_projectile.global_position)
		return
	_wire_projectile = null

	wire_renderer.visible = false

func _draw_catenary_line(renderer: Line2D, from: Vector2, to: Vector2, slack: float) -> void:
	var sag := minf(slack * 0.35, 60.0)
	var wire_vec := (to - from).normalized()
	var grav_dir := Vector2(0.0, 1.0)
	var perp := grav_dir - grav_dir.dot(wire_vec) * wire_vec
	var perp_len := perp.length()
	if perp_len < 0.01 or sag < 0.5:
		renderer.add_point(from)
		renderer.add_point(to)
		return
	perp = perp / perp_len
	for i in range(WIRE_SEGMENTS + 1):
		var t := float(i) / float(WIRE_SEGMENTS)
		var pt := from.lerp(to, t)
		pt += perp * sag * sin(PI * t)
		renderer.add_point(pt)

func _update_aim_pivot() -> void:
	var mouse_local := get_global_mouse_position() - global_position
	scale.x = -1.0 if mouse_local.x < 0.0 else 1.0

func get_wire_tension() -> float:
	return _wire.tension_ratio(global_position) if _wire != null else 0.0

func get_wire_length() -> float:
	return _wire.max_length if _wire != null else 0.0
