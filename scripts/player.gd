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
const NEEDLE_SPEED: float = 1600.0
const TURN_DURATION: float = 0.3
const NEEDLE_REACH: float = NEEDLE_SPEED * TURN_DURATION  # 480 px

# ── Internal state ─────────────────────────────────────────────────────────────
var _wire: WireConstraint = null
var _wire_anchor: Node2D = null
var _wire_projectile: Node = null

# Slingshot drag
var _sling_dragging: bool = false
var _sling_start: Vector2 = Vector2.ZERO

# Edge detection for DisplayServer raw polling
var _lmb_prev: bool = false
var _rmb_prev: bool = false

# Disconnect button rect (world coords) — set by _update_preview, read by input
var _disconnect_btn_rect: Rect2 = Rect2()
# When true, wire releases at next turn start (not immediately)
var _disconnect_queued: bool = false

@onready var needle_manager: Node = $NeedleManager
@onready var wire_renderer: Line2D = $WireRenderer
@onready var throw_origin: Marker2D = $AimPivot/ThrowOrigin
@onready var ghost_body: CharacterBody2D = $GhostBody

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
	set_process_unhandled_input(false)
	_lmb_prev = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_rmb_prev = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	TurnManager.turn_started.connect(_on_turn_started)

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_wire_pre(delta)
	move_and_slide()
	_apply_wire_post()
	_update_wire_renderer()

func _process(_delta: float) -> void:
	_update_aim_pivot()
	_poll_mouse()
	if TurnManager.is_frozen():
		_update_preview()
	else:
		aim_preview.clear_all()

func _poll_mouse() -> void:
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var mouse_w := get_global_mouse_position()

	if lmb and not _lmb_prev:
		if TurnManager.is_frozen():
			if _disconnect_btn_rect.has_area() and _disconnect_btn_rect.has_point(mouse_w):
				_disconnect_queued = not _disconnect_queued  # toggle: queue or cancel
			elif _is_on_player(mouse_w):
				_sling_dragging = true
				_sling_start = mouse_w
			else:
				_shoot_attack()
	elif not lmb and _lmb_prev:
		if _sling_dragging:
			_sling_dragging = false
			_launch_slingshot(mouse_w)

	if rmb and not _rmb_prev:
		if TurnManager.is_frozen():
			_start_grapple()

	_lmb_prev = lmb
	_rmb_prev = rmb

func _on_turn_started() -> void:
	if _disconnect_queued:
		_disconnect_queued = false
		_release_grapple()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kb := event as InputEventKey
		if kb.pressed and not kb.echo and kb.keycode == KEY_SPACE:
			if TurnManager.is_frozen():
				TurnManager.commit()


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
			var start_vel := sling_dir * speed
			# Pass wire params only if wire active AND disconnect not queued
			var wire_live := (_wire != null and _wire_anchor != null and is_instance_valid(_wire_anchor) and not _disconnect_queued)
			var w_anchor := _wire_anchor.global_position if wire_live else Vector2.ZERO
			var w_len := _wire.length if wire_live else 0.0
			var r1 := _simulate_arc_result(global_position, start_vel, 60, w_anchor, w_len)
			var arc: PackedVector2Array = r1["arc"]
			aim_preview.set_slingshot(arc, arc[-1] if arc.size() > 0 else global_position, true)
			aim_preview.clear_slingshot2()
	else:
		aim_preview.clear_slingshot()
		aim_preview.clear_slingshot2()

	# ── Layer 3: Wire pull arc + disconnect button (shown when wire active) ──
	if _wire != null and _wire_anchor != null and is_instance_valid(_wire_anchor):
		var anchor_pos := _wire_anchor.global_position
		var wire_len := _wire.length
		if _disconnect_queued:
			# Show free-fall arc (wire will release at turn start)
			var free_arc := _simulate_arc_result(global_position, velocity, 60)
			aim_preview.set_swing(free_arc["arc"])
		else:
			var wire_arc := _simulate_wire_pull(global_position, velocity, anchor_pos, wire_len, 60)
			aim_preview.set_swing(wire_arc)
		var btn_world := anchor_pos + Vector2(0, -28)
		_disconnect_btn_rect = Rect2(btn_world - Vector2(36, 14), Vector2(72, 28))
		aim_preview.set_disconnect_button(_disconnect_btn_rect, _disconnect_queued)
	else:
		aim_preview.clear_swing()
		_disconnect_btn_rect = Rect2()
		aim_preview.set_disconnect_button(Rect2(), false)

func _simulate_arc(start_pos: Vector2, start_vel: Vector2, steps: int) -> PackedVector2Array:
	return _simulate_arc_result(start_pos, start_vel, steps)["arc"]

func _simulate_arc_result(
	start_pos: Vector2, start_vel: Vector2, steps: int,
	wire_anchor := Vector2.ZERO, cur_wire_len := 0.0
) -> Dictionary:
	# Returns {arc: PackedVector2Array, end_vel: Vector2, hit: bool}
	# If cur_wire_len > 0, applies wire reel + rope constraint each step.
	var pts := PackedVector2Array()
	var pos := start_pos
	var vel := start_vel
	var dt := TURN_DURATION / steps
	var wire_active := cur_wire_len > 0.0
	var wlen := cur_wire_len
	var ghost_rid := ghost_body.get_rid()
	var params := PhysicsTestMotionParameters2D.new()
	params.exclude_bodies = [get_rid()]
	var result := PhysicsTestMotionResult2D.new()
	var hit := false
	pts.append(pos)
	for _i in range(steps):
		vel.y += gravity * dt
		# Wire reel + pre-constraint
		if wire_active:
			wlen = maxf(wlen - rope_reel_speed * dt, rope_min_length)
			var to_anchor := wire_anchor - pos
			var d := to_anchor.length()
			if d > wlen and d > 0.001:
				var dir := to_anchor / d
				var radial := vel.dot(dir)
				if radial < 0.0:
					vel -= dir * radial
		params.from = Transform2D(0, pos)
		params.motion = vel * dt
		if PhysicsServer2D.body_test_motion(ghost_rid, params, result):
			pos += result.get_travel()
			vel = vel.slide(result.get_collision_normal())
			hit = true
		else:
			pos += vel * dt
		# Wire post-constraint (hard clamp)
		if wire_active:
			var to_anchor := wire_anchor - pos
			var d := to_anchor.length()
			if d > wlen and d > 0.001:
				pos = wire_anchor - (to_anchor / d) * wlen
		pts.append(pos)
	return {"arc": pts, "end_vel": vel, "hit": hit}

func _simulate_wire_pull(
	start_pos: Vector2, start_vel: Vector2,
	anchor_pos: Vector2, wire_len: float, steps: int
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var pos := start_pos
	var vel := start_vel
	var dt := TURN_DURATION / steps
	var cur_len := wire_len
	pts.append(pos)
	for _i in range(steps):
		vel.y += gravity * dt
		cur_len = maxf(cur_len - rope_reel_speed * dt, rope_min_length)
		var to_anchor := anchor_pos - pos
		var d := to_anchor.length()
		if d > cur_len and d > 0.001:
			var rope_dir := to_anchor / d
			var radial := vel.dot(rope_dir)
			if radial < 0.0:
				vel -= rope_dir * radial
		pos += vel * dt
		to_anchor = anchor_pos - pos
		d = to_anchor.length()
		if d > cur_len and d > 0.001:
			pos = anchor_pos - (to_anchor / d) * cur_len
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
	_disconnect_queued = false
	needle_manager.release_wire()
	_wire = null
	_wire_anchor = null
	_wire_projectile = null
	wire_renderer.visible = false
	_disconnect_btn_rect = Rect2()
	aim_preview.set_disconnect_button(Rect2(), false)

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
