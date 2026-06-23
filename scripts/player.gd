## Player — Turn-based slingshot + needle controller.
## GAP-055/056: Rewrite for turn-based system.
## GAP-056b: Always-on preview, disconnect button, 1.0s turns, fixed swing sim.
extends CharacterBody2D

# ── Slingshot ──────────────────────────────────────────────────────────────────
@export var max_launch_speed: float = 1200.0  # px/s at full drag
@export var max_drag_pixels: float = 80.0     # drag distance for full power
@export var gravity: float = 980.0

# ── Wire grapple ──────────────────────────────────────────────────────────────
@export var rope_reel_speed: float = 150.0    # px/s pulled toward anchor each turn
@export var rope_min_length: float = 24.0
@export var rope_snap_factor: float = 0.35

# ── Needle reach preview (must match NeedleProjectile.flight_speed × TURN_DURATION) ──
const NEEDLE_SPEED: float = 800.0
const TURN_DURATION: float = 1.0
const NEEDLE_REACH: float = NEEDLE_SPEED * TURN_DURATION  # 800 px

# ── Internal state ─────────────────────────────────────────────────────────────
var _wire: WireConstraint = null
var _wire_anchor: Node2D = null
var _wire_projectile: Node = null

# Slingshot drag
var _sling_dragging: bool = false
var _sling_start: Vector2 = Vector2.ZERO

# Disconnect button rect (world coords) — set by _update_preview, read by input
var _disconnect_btn_rect: Rect2 = Rect2()

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

func _process(_delta: float) -> void:
	_update_aim_pivot()  # always update facing — runs even when frozen
	# Safety: if LMB is physically up but drag state is stuck, reset it
	if _sling_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_sling_dragging = false
	if TurnManager.is_frozen():
		_update_preview()
	else:
		aim_preview.clear_all()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		if _sling_dragging:
			aim_preview.queue_redraw()
	elif event is InputEventKey:
		var kb := event as InputEventKey
		if kb.pressed and not kb.echo and kb.keycode == KEY_SPACE:
			if TurnManager.is_frozen():
				TurnManager.commit()

func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	var mouse_w := get_global_mouse_position()

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and TurnManager.is_frozen():
			# Disconnect button = free action
			if _disconnect_btn_rect.has_area() and _disconnect_btn_rect.has_point(mouse_w):
				_release_grapple()
				return
			if _is_on_player(mouse_w):
				_sling_dragging = true
				_sling_start = mouse_w
			else:
				_shoot_attack()
		elif not mb.pressed and _sling_dragging:
			_sling_dragging = false
			_launch_slingshot(mouse_w)

	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed and TurnManager.is_frozen():
			_start_grapple()

func _is_on_player(world_pos: Vector2) -> bool:
	# Circle radius 50px — generous hitbox so user can easily click the character
	return (world_pos - global_position).length_squared() <= 50.0 * 50.0

# ── Slingshot ──────────────────────────────────────────────────────────────────

func _launch_slingshot(release_pos: Vector2) -> void:
	if not TurnManager.is_frozen():
		return
	var drag := release_pos - global_position
	var sling_dist := drag.length()
	if sling_dist < 2.0:
		return
	var dir := drag.normalized()
	var speed := clampf(sling_dist / max_drag_pixels, 0.0, 1.0) * max_launch_speed
	velocity = dir * speed
	TurnManager.commit()

# ── Always-on preview — all layers drawn simultaneously ────────────────────────

func _update_preview() -> void:
	var mouse_w := get_global_mouse_position()
	var hover_player := _is_on_player(mouse_w)

	# ── Layer 1: Needle trajectory — HIDDEN when hovering player (slingshot mode) ─
	if not hover_player and not _sling_dragging:
		var from := global_position  # fire from player center
		var to_mouse := mouse_w - from
		var dist := to_mouse.length()
		if dist > 8.0:
			var needle_dir := to_mouse.normalized()
			var reach_dist := minf(dist, NEEDLE_REACH)
			var reach := from + needle_dir * reach_dist
			aim_preview.set_needle(from, reach, mouse_w)
		else:
			aim_preview.clear_needle()
	else:
		aim_preview.clear_needle()

	# ── Layer 1b: Player highlight — shown when hovering (slingshot mode ready) ─
	if hover_player and not _sling_dragging:
		aim_preview.set_player_hover(global_position, Vector2(16, 32))
	else:
		aim_preview.clear_player_hover()

	# ── Layer 2: Slingshot arc — ONLY during active left-drag from player body ─
	if _sling_dragging:
		var to_mouse_p := mouse_w - global_position
		if to_mouse_p.length() > 8.0:
			var sling_dir := to_mouse_p.normalized()
			var sling_dist := to_mouse_p.length()
			var speed := clampf(sling_dist / max_drag_pixels, 0.0, 1.0) * max_launch_speed
			var arc := _simulate_arc(global_position, sling_dir * speed, 80)
			aim_preview.set_slingshot(arc, arc[-1] if arc.size() > 0 else global_position, true)
	else:
		aim_preview.clear_slingshot()

	# ── Layer 3: Wire swing arc + disconnect button (shown when wire active) ──
	if _wire != null and _wire_anchor != null and is_instance_valid(_wire_anchor):
		var anchor_pos := _wire_anchor.global_position
		var wire_len := _wire.length
		# Use a small initial kick toward perpendicular if velocity is near zero
		# so the arc is visible even when player is stationary
		var sim_vel := velocity
		if sim_vel.length() < 10.0:
			# Tangential nudge so the arc is visible when player is nearly stationary
			var to_anchor := anchor_pos - global_position
			if to_anchor.length() > 1.0:
				var tangent := Vector2(-to_anchor.y, to_anchor.x).normalized()
				sim_vel = tangent * 100.0
		var swing_arc := _simulate_swing(global_position, sim_vel, anchor_pos, wire_len, 80)
		aim_preview.set_swing(swing_arc)
		# Disconnect button world position = above wire anchor
		var btn_world := anchor_pos + Vector2(0, -28)
		_disconnect_btn_rect = Rect2(btn_world - Vector2(28, 12), Vector2(56, 24))
		aim_preview.set_disconnect_button(_disconnect_btn_rect)
	else:
		aim_preview.clear_swing()
		_disconnect_btn_rect = Rect2()
		aim_preview.set_disconnect_button(Rect2())

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

func _simulate_swing(
	start_pos: Vector2, start_vel: Vector2,
	anchor_pos: Vector2, wire_len: float, steps: int
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var pos := start_pos
	var vel := start_vel
	var dt := TURN_DURATION / steps
	pts.append(pos)
	for _i in range(steps):
		vel.y += gravity * dt
		# Pre: cancel outward (away-from-anchor) radial velocity when taut
		var to_anchor := anchor_pos - pos
		var d := to_anchor.length()
		if d > 0.001:
			var rope_dir := to_anchor / d
			var radial := vel.dot(rope_dir)
			if d >= wire_len and radial < 0.0:
				vel -= rope_dir * radial  # cancel outward component
		pos += vel * dt
		# Post: hard-clamp to rope circle
		to_anchor = anchor_pos - pos
		d = to_anchor.length()
		if d > wire_len and d > 0.001:
			pos = anchor_pos - (to_anchor / d) * wire_len
		pts.append(pos)
	return pts

# ── Gravity ────────────────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

# ── Wire ───────────────────────────────────────────────────────────────────────

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
	_disconnect_btn_rect = Rect2()
	aim_preview.set_disconnect_button(Rect2())

func _on_wire_needle_launched(proj: Node) -> void:
	_wire_projectile = proj

func _on_wire_anchor_ready(anchor: Node) -> void:
	print("[PLAYER] Wire anchor ready at ", (anchor as Node2D).global_position)
	_wire_projectile = null
	_wire = anchor.wire as WireConstraint
	_wire_anchor = anchor as Node2D
	_wire.min_length = rope_min_length
	_wire.reel_speed = rope_reel_speed
	_wire.snap_factor = rope_snap_factor
	_wire.setup(anchor.global_position, global_position.distance_to(anchor.global_position))

func _on_needle_retrieved(anchor: Node) -> void:
	if (anchor as Node2D) == _wire_anchor:
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
