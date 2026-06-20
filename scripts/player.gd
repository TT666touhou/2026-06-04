extends CharacterBody2D

const WIRE_SEGMENTS := 8
const SAG_WEIGHT := 20.0       # px of sag when player stands on wire
const SAG_SPEED_ON := 8.0      # lerp rate when sagging under weight
const SAG_SPEED_OFF := 3.0     # lerp rate when wire returns to straight
const DROP_THROUGH_TIME := 0.25
const PickupPromptScene = preload("res://scenes/ui/pickup_prompt_ui.tscn")
const VerletRopeScript = preload("res://scripts/verlet_rope.gd")

@export var move_speed: float = 240.0
@export var jump_velocity: float = 540.0
@export var gravity: float = 980.0
@export var wire_slack: float = 30.0
# Horizontal movement inertia (GAP-035)
@export var ground_accel: float = 2200.0   # accel toward target speed on ground
@export var ground_friction: float = 2600.0 # decel when no input on ground
@export var air_accel: float = 1400.0      # weaker control in air
@export var air_friction: float = 900.0    # keep more momentum in air
# Jump feel (GAP-035)
@export var coyote_time: float = 0.1       # jump grace after leaving ground
@export var jump_buffer_time: float = 0.1  # jump grace before landing
@export var jump_cut: float = 0.45         # upward velocity kept when jump released early
# Wire tether — pendulum swing + auto-reel (GAP-037)
@export var swing_accel: float = 500.0     # air-control accel while on the wire (px/s^2)
@export var swing_air_drag: float = 60.0   # gentle horizontal settle while swinging (px/s^2)
@export var auto_reel_speed: float = 110.0 # auto-pull toward the anchor on attach (px/s)
@export var min_rope_length: float = 24.0  # rope won't reel shorter than this
@export var reel_speed: float = 200.0      # extra reel while holding E (px/s)
@export var rope_segments: int = 12        # Verlet rope visual point count

var _wire: RefCounted = null
var _verlet: RefCounted = null      # Verlet rope visual for the active wire
var _wire_anchor: Node = null       # active pendulum anchor (swinging)
var _wire_projectile: Node = null
var _platform_a: Node = null        # platform endpoint A — independent of pendulum state
var _platform_b: Node = null        # platform endpoint B
var _platform_slack: float = 0.0
var _platform_renderer: Line2D = null
var _on_wire_platform: bool = false
var _drop_through_timer: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _pickup_ui: Node = null

@onready var needle_manager: Node = $NeedleManager
@onready var wire_renderer: Line2D = $WireRenderer
@onready var throw_origin: Marker2D = $AimPivot/ThrowOrigin

func _ready() -> void:
	needle_manager.wire_anchor_ready.connect(_on_wire_anchor_ready)
	needle_manager.needle_retrieved.connect(_on_needle_retrieved)
	needle_manager.wire_needle_launched.connect(_on_wire_needle_launched)
	needle_manager.platform_created.connect(_on_platform_created)
	set_collision_mask_value(4, true)  # wire platform lives on layer 4
	wire_renderer.top_level = true
	wire_renderer.visible = false
	_platform_renderer = Line2D.new()
	_platform_renderer.top_level = true
	_platform_renderer.visible = false
	_platform_renderer.width = 1.5
	_platform_renderer.default_color = Color(0.95, 0.9, 0.55, 0.9)
	add_child(_platform_renderer)
	_pickup_ui = PickupPromptScene.instantiate()
	_pickup_ui.top_level = true  # decouple from player's facing-flip (scale.x = -1)
	add_child(_pickup_ui)

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta)
	_apply_wire(delta)
	_update_jump(delta)
	_drop_through_timer = maxf(0.0, _drop_through_timer - delta)
	set_collision_mask_value(4, _drop_through_timer <= 0.0)
	move_and_slide()
	_update_platform_sag(delta)
	_update_wire_renderer()
	_update_aim_pivot()
	_update_pickup_prompts()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time   # buffered; executed in _update_jump
	if event.is_action_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut                   # variable jump height (short hop)
	if event.is_action_pressed("drop_through") and _on_wire_platform:
		_drop_through_timer = DROP_THROUGH_TIME
		velocity.y = maxf(velocity.y, 80.0)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_shoot_needle()
	if event.is_action_pressed("cut_wire"):
		_cut_wire()
	if event.is_action_pressed("retrieve_needle"):
		needle_manager.try_retrieve(global_position, _wire_anchor)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func _apply_movement(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if _wire != null:
		# On the wire: input is air-control accel that pumps the swing, preserving
		# momentum (GAP-034). Hard-setting velocity.x here would kill the swing.
		velocity.x += dir * swing_accel * delta
		velocity.x = move_toward(velocity.x, 0.0, swing_air_drag * delta)
	else:
		# Inertia-based horizontal movement (GAP-035): accelerate toward target,
		# decelerate with friction when no input; weaker control in the air.
		var target := dir * move_speed
		var rate: float
		if is_on_floor():
			rate = ground_accel if dir != 0.0 else ground_friction
		else:
			rate = air_accel if dir != 0.0 else air_friction
		velocity.x = move_toward(velocity.x, target, rate * delta)

func _update_jump(delta: float) -> void:
	# Coyote time + jump buffer (GAP-035). is_on_floor() reflects last move_and_slide.
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
	_wire.auto_reel(delta)                              # auto-pull toward anchor
	if Input.is_action_pressed("reel_wire"):
		_wire.reel(reel_speed, delta)                  # E: reel in faster
	var r: Dictionary = _wire.constrain(global_position, velocity)
	global_position = r["pos"]                         # clamp onto swing circle when taut
	velocity = r["vel"]                                # outward radial removed → pendulum

func _shoot_needle() -> void:
	var from := throw_origin.global_position if throw_origin else global_position
	var dir := (get_global_mouse_position() - from).normalized()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		needle_manager.shoot_wire_needle(from, dir)
	else:
		needle_manager.shoot_attack_needle(from, dir)

func _cut_wire() -> void:
	# Q only severs the active pendulum wire currently connecting the player.
	# A wire that has become a platform cannot be cut this way — use F to
	# retrieve one platform endpoint first (GAP-032). The needle stays embedded
	# and can be retrieved later by F.
	if _wire == null or _wire_anchor == null:
		return
	_wire = null
	_verlet = null
	_wire_anchor = null
	wire_renderer.visible = false

func _on_wire_needle_launched(proj: Node) -> void:
	_wire_projectile = proj

func _on_wire_anchor_ready(anchor: Node) -> void:
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
		_verlet = null
		_wire_anchor = null
	if anchor == _platform_a or anchor == _platform_b:
		_platform_a = null
		_platform_b = null
		_platform_slack = 0.0
		if _platform_renderer != null:
			_platform_renderer.visible = false

func _on_platform_created(a1: Node, a2: Node) -> void:
	_wire = null
	_verlet = null
	_wire_anchor = null
	if _platform_a != a1 or _platform_b != a2:
		_platform_slack = 30.0  # initial droop; settles via _update_platform_sag
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

	# Priority 2: Pendulum mode — Verlet rope (natural droop/straighten, no fake sag)
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

func _update_platform_sag(delta: float) -> void:
	# Detect if player is standing on the wire platform via slide collisions
	_on_wire_platform = false
	if _platform_a == null or _platform_b == null:
		return
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is WirePlatform:
			_on_wire_platform = true
			break
	# Lerp sag toward target: SAG_WEIGHT when bearing load, 0 when empty
	var target := SAG_WEIGHT if _on_wire_platform else 0.0
	var spd := SAG_SPEED_ON if _on_wire_platform else SAG_SPEED_OFF
	_platform_slack = lerpf(_platform_slack, target, minf(1.0, spd * delta))

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

func _update_pickup_prompts() -> void:
	if _pickup_ui == null:
		return
	var info: Dictionary = needle_manager.get_retrieve_info(global_position, _wire_anchor)
	_pickup_ui.update_prompts(info["candidates"], info["target"])

func get_wire_tension() -> float:
	return _wire.tension_ratio(global_position) if _wire != null else 0.0

func get_wire_length() -> float:
	return _wire.max_length if _wire != null else 0.0
