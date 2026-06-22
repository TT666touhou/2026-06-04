## Player — Turn-based slingshot + needle controller.
## GAP-055: Complete rewrite for turn-based system.
## Movement: slingshot drag (replaces A/D + Space).
## Needles: left-click = attack, right-click = wire (gated by TurnManager.is_frozen()).
extends CharacterBody2D

# ── Slingshot ──────────────────────────────────────────────────────────────────
@export var max_launch_speed: float = 1200.0  # px/s at full drag (640px range at 45°)
@export var max_drag_pixels: float = 80.0     # screen pixels of drag = full power
@export var gravity: float = 980.0

# ── Wire grapple (retained from GAP-041/053/054) ──────────────────────────────
@export var rope_reel_speed: float = 350.0
@export var rope_min_length: float = 24.0
@export var rope_snap_factor: float = 0.35
@export var swing_accel: float = 150.0

# ── Needle preview reach per turn ──────────────────────────────────────────────
const NEEDLE_SPEED: float = 2400.0
const TURN_DURATION: float = 0.3
const NEEDLE_REACH: float = NEEDLE_SPEED * TURN_DURATION  # 720 px

# ── Internal state ─────────────────────────────────────────────────────────────
var _wire: WireConstraint = null
var _wire_anchor: Node = null
var _wire_projectile: Node = null
var _wire_held: bool = false

# Slingshot drag state
var _sling_dragging: bool = false
var _sling_start: Vector2 = Vector2.ZERO   # world pos where drag began

@onready var needle_manager: Node = $NeedleManager
@onready var wire_renderer: Line2D = $WireRenderer
@onready var throw_origin: Marker2D = $AimPivot/ThrowOrigin

var aim_preview: Node2D = null

func _ready() -> void:
	add_to_group("player")
	needle_manager.wire_anchor_ready.connect(_on_wire_anchor_ready)
	needle_manager.needle_retrieved.connect(_on_needle_retrieved)
	needle_manager.wire_needle_launched.connect(_on_wire_needle_launched)
	wire_renderer.top_level = true
	wire_renderer.visible = false
	# Create AimPreview dynamically to avoid UID issues with manually edited .tscn
	var preview_script := load("res://scripts/aim_preview.gd")
	aim_preview = Node2D.new()
	aim_preview.name = "AimPreview"
	aim_preview.top_level = true
	aim_preview.set_script(preview_script)
	add_child(aim_preview)

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_wire_pre(delta)
	move_and_slide()
	_apply_wire_post()
	_update_wire_renderer()
	_update_aim_pivot()

func _process(_delta: float) -> void:
	# Preview update runs during FROZEN (time_scale=0), process mode must be ALWAYS
	if TurnManager.is_frozen():
		_update_preview()
	else:
		aim_preview.clear()

## Input is handled in unhandled_input; this runs regardless of time_scale
## because InputEvent delivery ignores time_scale.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_handle_mouse_button(mb)
	elif event is InputEventMouseMotion:
		if _sling_dragging:
			aim_preview.queue_redraw()

func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var mouse_w := get_global_mouse_position()
			if _is_on_player(mouse_w):
				# Start slingshot drag (only in FROZEN)
				if TurnManager.is_frozen():
					_sling_dragging = true
					_sling_start = mouse_w
			else:
				# Attack needle click (only in FROZEN)
				if TurnManager.is_frozen() and not _sling_dragging:
					_shoot_attack()
		else:  # left button released
			if _sling_dragging:
				_sling_dragging = false
				_launch_slingshot(get_global_mouse_position())

	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed:
			_wire_held = true
			if TurnManager.is_frozen():
				_start_grapple()
		else:
			_wire_held = false
			_release_grapple()

## Check if world-space pos is within player collision rect
func _is_on_player(world_pos: Vector2) -> bool:
	var half := Vector2(16.0, 32.0)
	var local := world_pos - global_position
	return abs(local.x) <= half.x and abs(local.y) <= half.y

# ── Slingshot ──────────────────────────────────────────────────────────────────

func _launch_slingshot(release_pos: Vector2) -> void:
	if not TurnManager.is_frozen():
		return
	var drag := release_pos - _sling_start
	var dist := drag.length()
	if dist < 4.0:
		return  # ignore tiny taps
	var dir := drag.normalized()
	var speed := clampf(dist / max_drag_pixels, 0.0, 1.0) * max_launch_speed
	velocity = dir * speed
	TurnManager.commit()

# ── Aim preview ────────────────────────────────────────────────────────────────

func _update_preview() -> void:
	if _sling_dragging:
		var release := get_global_mouse_position()
		var drag := release - _sling_start
		var dist := drag.length()
		var dir := drag.normalized() if dist > 2.0 else Vector2.RIGHT
		var speed := clampf(dist / max_drag_pixels, 0.0, 1.0) * max_launch_speed
		var arc := _simulate_arc(global_position, dir * speed, 60)
		aim_preview.set_slingshot(arc)
	elif not _wire_held:
		var mouse_w := get_global_mouse_position()
		var from := throw_origin.global_position
		var to_mouse := mouse_w - from
		var dist := to_mouse.length()
		if dist > 8.0:
			var dir := to_mouse.normalized()
			var reach := from + dir * minf(dist, NEEDLE_REACH)
			aim_preview.set_needle(from, mouse_w, reach)
		else:
			aim_preview.clear()
	else:
		aim_preview.clear()

## Simulate a physics arc and return a list of points
func _simulate_arc(start_pos: Vector2, start_vel: Vector2, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var pos := start_pos
	var vel := start_vel
	var dt := TURN_DURATION / steps
	pts.append(pos)
	for _i in range(steps):
		vel.y += gravity * dt
		pos += vel * dt
		pts.append(pos)
	return pts

# ── Gravity ────────────────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

# ── Wire (retained from GAP-041/053/054) ───────────────────────────────────────

func _apply_wire_pre(delta: float) -> void:
	if _wire == null:
		return
	if _wire_anchor != null and is_instance_valid(_wire_anchor):
		_wire.anchor_pos = _wire_anchor.global_position
	var anchor_node := _wire_anchor as NeedleAnchor
	if anchor_node != null and anchor_node.attached_body != null \
			and not (anchor_node.attached_body is StaticBody2D):
		return
	_wire.reel(delta)
	velocity = _wire.pre_constrain(global_position, velocity)

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
	TurnManager.commit()

func _start_grapple() -> void:
	if _wire != null or (_wire_projectile != null and is_instance_valid(_wire_projectile)):
		return
	var from := throw_origin.global_position if throw_origin else global_position
	var dir := (get_global_mouse_position() - from).normalized()
	needle_manager.shoot_wire_needle(from, dir)
	TurnManager.commit()

func _release_grapple() -> void:
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
	if _wire != null and _wire_anchor != null and is_instance_valid(_wire_anchor):
		var tension: float = _wire.tension_ratio(global_position)
		wire_renderer.default_color = Color(0.95, 0.9, 0.55, 1.0).lerp(Color(1.0, 1.0, 0.8, 1.0), tension)
		wire_renderer.width = 1.0 + tension * 2.0
		wire_renderer.visible = true
		wire_renderer.clear_points()
		wire_renderer.add_point(global_position)
		wire_renderer.add_point(_wire.anchor_pos)
		return
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
