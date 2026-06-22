extends CharacterBody2D

# Movement / game feel (GAP-035)
@export var move_speed: float = 240.0
@export var jump_velocity: float = 540.0
@export var gravity: float = 980.0
@export var ground_accel: float = 2200.0
@export var ground_friction: float = 2600.0
@export var air_accel: float = 1400.0
@export var air_friction: float = 900.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var jump_cut: float = 0.45
# Wire grapple — hold right-click to grapple+reel, release to detach (GAP-041)
@export var rope_reel_speed: float = 180.0   # px/s rope shortens while held
@export var rope_min_length: float = 24.0    # shortest the rope can reel to
@export var rope_snap_factor: float = 0.12   # tiny inward bounce when rope snaps taut
@export var swing_accel: float = 150.0       # tangential air control during wire swing (GAP-054)

var _wire: WireConstraint = null
var _wire_anchor: Node = null
var _wire_projectile: Node = null
var _wire_held: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

@onready var needle_manager: Node = $NeedleManager
@onready var wire_renderer: Line2D = $WireRenderer
@onready var throw_origin: Marker2D = $AimPivot/ThrowOrigin

func _ready() -> void:
	add_to_group("player")
	needle_manager.wire_anchor_ready.connect(_on_wire_anchor_ready)
	needle_manager.needle_retrieved.connect(_on_needle_retrieved)
	needle_manager.wire_needle_launched.connect(_on_wire_needle_launched)
	wire_renderer.top_level = true
	wire_renderer.visible = false

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta)
	_update_jump(delta)
	_apply_wire_pre(delta)   # remove outward radial vel BEFORE slide
	move_and_slide()
	_apply_wire_post()       # hard-clamp position AFTER slide
	needle_manager.auto_retrieve_attack(global_position)
	_update_wire_renderer()
	_update_aim_pivot()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	if event.is_action_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_shoot_attack()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_start_grapple()
			else:
				_release_grapple()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func _apply_movement(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if _wire != null:
		# Tangential air control: push along the swing arc perpendicular to the rope (GAP-054)
		if dir != 0.0:
			var to_anchor := _wire.anchor_pos - global_position
			var dist := to_anchor.length()
			if dist > 0.001:
				var rope_dir := to_anchor / dist
				var tangent := Vector2(-rope_dir.y, rope_dir.x)
				velocity += tangent * dir * swing_accel * delta
		return
	var target := dir * move_speed
	var rate: float
	if is_on_floor():
		rate = ground_accel if dir != 0.0 else ground_friction
	else:
		rate = air_accel if dir != 0.0 else air_friction
	velocity.x = move_toward(velocity.x, target, rate * delta)

func _update_jump(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = -jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

# Pre-pass: sync anchor position, reel rope, remove outward radial velocity
func _apply_wire_pre(delta: float) -> void:
	if _wire == null:
		return
	if _wire_anchor != null and is_instance_valid(_wire_anchor):
		_wire.anchor_pos = _wire_anchor.global_position
	# Enemy hook: enemy moves toward player; player physics unchanged (GAP-047)
	var anchor_node := _wire_anchor as NeedleAnchor
	if anchor_node != null and anchor_node.attached_body != null \
			and not (anchor_node.attached_body is StaticBody2D):
		return
	_wire.reel(delta)
	velocity = _wire.pre_constrain(global_position, velocity)

# Post-pass: hard-clamp player onto rope circle after move_and_slide
func _apply_wire_post() -> void:
	if _wire == null:
		return
	var anchor_node := _wire_anchor as NeedleAnchor
	if anchor_node != null and anchor_node.attached_body != null \
			and not (anchor_node.attached_body is StaticBody2D):
		return
	var r := _wire.post_constrain(global_position, velocity)
	global_position = r["pos"] as Vector2
	velocity = r["vel"] as Vector2

func _shoot_attack() -> void:
	var from := throw_origin.global_position if throw_origin else global_position
	var dir := (get_global_mouse_position() - from).normalized()
	needle_manager.shoot_attack_needle(from, dir)

func _start_grapple() -> void:
	_wire_held = true
	if _wire != null or (_wire_projectile != null and is_instance_valid(_wire_projectile)):
		return
	var from := throw_origin.global_position if throw_origin else global_position
	var dir := (get_global_mouse_position() - from).normalized()
	needle_manager.shoot_wire_needle(from, dir)

func _release_grapple() -> void:
	_wire_held = false
	needle_manager.release_wire()
	_wire = null
	_wire_anchor = null
	_wire_projectile = null
	wire_renderer.visible = false

func _on_wire_needle_launched(proj: Node) -> void:
	_wire_projectile = proj

func _on_wire_anchor_ready(anchor: Node) -> void:
	if not _wire_held:
		needle_manager.release_wire()
		return
	_wire_projectile = null
	_wire = anchor.wire as WireConstraint
	_wire_anchor = anchor
	_wire.min_length = rope_min_length
	_wire.reel_speed = rope_reel_speed
	_wire.snap_factor = rope_snap_factor
	_wire.setup(anchor.global_position, global_position.distance_to(anchor.global_position))

func _on_needle_retrieved(anchor: Node) -> void:
	if anchor == _wire_anchor:
		_wire = null
		_wire_anchor = null
		wire_renderer.visible = false

func _update_wire_renderer() -> void:
	# Active wire — straight line (wire under tension; no Verlet droop)
	if _wire != null and _wire_anchor != null and is_instance_valid(_wire_anchor):
		var tension: float = _wire.tension_ratio(global_position)
		wire_renderer.default_color = Color(0.95, 0.9, 0.55, 1.0).lerp(Color(1.0, 1.0, 0.8, 1.0), tension)
		wire_renderer.width = 1.0 + tension * 2.0
		wire_renderer.visible = true
		wire_renderer.clear_points()
		wire_renderer.add_point(global_position)
		wire_renderer.add_point(_wire.anchor_pos)
		return
	# In-flight wire — straight line player → projectile
	if _wire_projectile != null and is_instance_valid(_wire_projectile):
		wire_renderer.default_color = Color(0.95, 0.9, 0.55, 0.6)
		wire_renderer.width = 1.0
		wire_renderer.visible = true
		wire_renderer.clear_points()
		wire_renderer.add_point(global_position)
		wire_renderer.add_point(_wire_projectile.global_position)
		return
	wire_renderer.visible = false

func _update_aim_pivot() -> void:
	var mouse_local := get_global_mouse_position() - global_position
	scale.x = -1.0 if mouse_local.x < 0.0 else 1.0

func get_wire_tension() -> float:
	return _wire.tension_ratio(global_position) if _wire != null else 0.0

func get_wire_length() -> float:
	return _wire.length if _wire != null else 0.0
