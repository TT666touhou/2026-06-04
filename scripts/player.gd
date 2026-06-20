extends CharacterBody2D

const VerletRopeScript = preload("res://scripts/verlet_rope.gd")

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
# Wire grapple — hold right to grapple+reel, release to detach+recycle (GAP-041)
@export var wire_slack: float = 30.0
@export var swing_accel: float = 500.0     # air-control accel while on the wire
@export var swing_air_drag: float = 60.0   # gentle horizontal settle while swinging
@export var auto_reel_speed: float = 320.0 # auto-pull toward the anchor while held
@export var min_rope_length: float = 24.0
@export var rope_segments: int = 12        # Verlet rope visual point count

var _wire: RefCounted = null
var _verlet: RefCounted = null
var _wire_anchor: Node = null
var _wire_projectile: Node = null
var _wire_held: bool = false               # right mouse button currently held
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

@onready var needle_manager: Node = $NeedleManager
@onready var wire_renderer: Line2D = $WireRenderer
@onready var throw_origin: Marker2D = $AimPivot/ThrowOrigin

func _ready() -> void:
	needle_manager.wire_anchor_ready.connect(_on_wire_anchor_ready)
	needle_manager.needle_retrieved.connect(_on_needle_retrieved)
	needle_manager.wire_needle_launched.connect(_on_wire_needle_launched)
	wire_renderer.top_level = true
	wire_renderer.visible = false

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta)
	_apply_wire(delta)
	_update_jump(delta)
	move_and_slide()
	needle_manager.auto_retrieve_attack(global_position)  # left-needle proximity pickup
	_update_wire_renderer()
	_update_aim_pivot()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	if event.is_action_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut                  # variable jump height
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
		# On the wire: input is air-control accel that pumps the swing (preserves momentum)
		velocity.x += dir * swing_accel * delta
		velocity.x = move_toward(velocity.x, 0.0, swing_air_drag * delta)
	else:
		# Inertia-based horizontal movement (GAP-035)
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

func _apply_wire(delta: float) -> void:
	if _wire == null:
		return
	_wire.auto_reel(delta)                              # auto-pull toward anchor while held
	var r: Dictionary = _wire.constrain(global_position, velocity)
	# Apply the rope's position correction via move_and_collide (NOT a direct
	# global_position teleport, which bypassed collision and let the player pass
	# through platforms while being reeled toward a wall — GAP-042). move_and_collide
	# stops at walls/platforms, so the player gets blocked (卡住).
	var correction: Vector2 = (r["pos"] as Vector2) - global_position
	if correction != Vector2.ZERO:
		move_and_collide(correction)
	velocity = r["vel"]

func _shoot_attack() -> void:
	var from := throw_origin.global_position if throw_origin else global_position
	var dir := (get_global_mouse_position() - from).normalized()
	needle_manager.shoot_attack_needle(from, dir)

func _start_grapple() -> void:
	_wire_held = true
	if _wire != null or (_wire_projectile != null and is_instance_valid(_wire_projectile)):
		return                                         # already grappling / firing
	var from := throw_origin.global_position if throw_origin else global_position
	var dir := (get_global_mouse_position() - from).normalized()
	needle_manager.shoot_wire_needle(from, dir)

func _release_grapple() -> void:
	_wire_held = false
	needle_manager.release_wire()                      # cancel in-flight proj or recycle anchor
	_wire = null
	_wire_anchor = null
	_wire_projectile = null
	_verlet = null
	wire_renderer.visible = false

func _on_wire_needle_launched(proj: Node) -> void:
	_wire_projectile = proj

func _on_wire_anchor_ready(anchor: Node) -> void:
	if not _wire_held:
		needle_manager.release_wire()                  # released mid-flight → don't attach, recycle
		return
	_wire_projectile = null
	_wire = anchor.wire as RefCounted
	_wire_anchor = anchor
	_wire.min_length = min_rope_length
	_wire.auto_reel_speed = auto_reel_speed
	_wire.setup(anchor.global_position, global_position.distance_to(anchor.global_position) + wire_slack)
	_verlet = VerletRopeScript.new()
	_verlet.init(anchor.global_position, global_position, rope_segments)

func _on_needle_retrieved(anchor: Node) -> void:
	if anchor == _wire_anchor:
		_wire = null
		_wire_anchor = null
		_verlet = null
		wire_renderer.visible = false

func _update_wire_renderer() -> void:
	# Active wire — Verlet rope (natural droop/straighten)
	if _wire != null and _wire_anchor != null and is_instance_valid(_wire_anchor):
		var tension: float = _wire.tension_ratio(global_position)
		wire_renderer.default_color = Color(0.95, 0.9, 0.55, 1.0).lerp(Color(1.0, 1.0, 0.8, 1.0), tension)
		wire_renderer.width = 1.5 + tension * 1.5
		wire_renderer.visible = true
		if _verlet == null:
			_verlet = VerletRopeScript.new()
			_verlet.init(_wire.anchor_pos, global_position, rope_segments)
		_verlet.update(_wire.anchor_pos, global_position, _wire.max_length, get_physics_process_delta_time())
		wire_renderer.points = _verlet.points
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
	return _wire.max_length if _wire != null else 0.0
