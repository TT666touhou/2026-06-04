## Player — Turn-based slingshot + needle controller.
## GAP-055/056: Rewrite for turn-based system.
## GAP-056b: Always-on preview, disconnect button, 1.0s turns, fixed swing sim.
extends CharacterBody2D

# ── Slingshot ──────────────────────────────────────────────────────────────────
@export var max_launch_speed: float = 1200.0  # px/s at full drag
@export var max_drag_pixels: float = 80.0     # drag distance for full power
@export var gravity: float = 980.0

# ── Wire grapple ──────────────────────────────────────────────────────────────
@export var rope_min_length: float = 24.0
@export var rope_snap_factor: float = 0.35
const REEL_STEP: float = 120.0  # px shortened per manual reel action

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

# Reel button rect (world coords) — set by _update_preview, read by input
var _reel_btn_rect: Rect2 = Rect2()

# Reel animation state
var _reel_animating: bool = false
var _reel_from: float = 0.0
var _reel_elapsed: float = 0.0

# Surface sticking (wall / ceiling / ledge)
var _stuck: bool = false
var _stuck_normal: Vector2 = Vector2.ZERO

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
	# Reel animation: smoothly shorten wire over one turn duration
	if _reel_animating:
		if _wire != null:
			_reel_elapsed += delta
			var t := clampf(_reel_elapsed / TURN_DURATION, 0.0, 1.0)
			_wire.length = lerpf(_reel_from, rope_min_length, t)
			if t >= 1.0:
				_reel_animating = false
				var anchor_pos: Vector2 = _wire_anchor.global_position if _wire_anchor != null else Vector2.ZERO
				_release_grapple()
				_try_stick_after_reel(anchor_pos)
		else:
			_reel_animating = false

	if _stuck:
		velocity = Vector2.ZERO
	else:
		_apply_gravity(delta)

	_apply_wire_pre(delta)
	move_and_slide()
	_apply_wire_post()

	# Auto-stick: Ronin style — any surface contact = grab; wire releases if active
	if not _reel_animating and not _stuck and not is_on_floor():
		if is_on_wall():
			if _wire != null:
				_release_grapple()
			_stick_to_surface(get_wall_normal())
		elif is_on_ceiling():
			if _wire != null:
				_release_grapple()
			_stick_to_surface(Vector2.DOWN)
		elif _wire == null:
			_check_ledge_snap()

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
			if _reel_btn_rect.has_area() and _reel_btn_rect.has_point(mouse_w):
				_do_reel()
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

func _do_reel() -> void:
	if _wire == null:
		return
	_reel_from = _wire.length
	_reel_elapsed = 0.0
	_reel_animating = true
	_unstick()
	TurnManager.commit()

func _on_turn_started() -> void:
	pass

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
	_unstick()
	_release_grapple()  # wire breaks when player chooses to move
	TurnManager.commit()

func _stick_to_surface(normal: Vector2) -> void:
	_stuck = true
	_stuck_normal = normal
	velocity = Vector2.ZERO

func _unstick() -> void:
	_stuck = false
	_stuck_normal = Vector2.ZERO

func _check_ledge_snap() -> void:
	if velocity.y < -50.0:
		return
	var space := get_world_2d().direct_space_state
	const HAND_Y := -12.0
	const REACH := 12.0
	for side in [-1.0, 1.0]:
		var hand := global_position + Vector2(side * 12.0, HAND_Y)
		var q := PhysicsRayQueryParameters2D.create(
			hand, hand + Vector2(side * REACH, 0.0), 1, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		# Confirm open space above hit point (= ledge corner, not mid-wall)
		var hit_pos: Vector2 = hit["position"]
		var above: Vector2 = hit_pos + Vector2(-side * 2.0, -2.0)
		var up_q := PhysicsRayQueryParameters2D.create(
			above, above + Vector2(0.0, -8.0), 1, [get_rid()])
		if space.intersect_ray(up_q).is_empty():
			global_position.y = hit_pos.y - HAND_Y
			velocity = Vector2.ZERO
			_stuck = true
			_stuck_normal = Vector2(-side, 0.0)
			break

func _try_stick_after_reel(anchor_pos: Vector2) -> void:
	if anchor_pos == Vector2.ZERO:
		return
	var dir: Vector2 = (anchor_pos - global_position)
	var dist := dir.length()
	if dist < 0.5:
		return
	dir = dir / dist
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
		global_position, anchor_pos + dir * 8.0, 1, [get_rid()])
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		_stick_to_surface(hit["normal"] as Vector2)

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
			# Wire breaks when player chooses to move — simulate without wire
			var r1 := _simulate_arc_result(global_position, start_vel, 60)
			var arc: PackedVector2Array = r1["arc"]
			aim_preview.set_slingshot(arc, arc[-1] if arc.size() > 0 else global_position, true)
			aim_preview.clear_slingshot2()
	else:
		aim_preview.clear_slingshot()
		aim_preview.clear_slingshot2()

	# ── Layer 3: Wire pull arc + reel button (shown when wire active) ──
	if _wire != null and _wire_anchor != null and is_instance_valid(_wire_anchor):
		var anchor_pos := _wire_anchor.global_position
		var wire_len := _wire.length
		var wire_arc := _simulate_wire_pull(global_position, velocity, anchor_pos, wire_len, 60)
		aim_preview.set_swing(wire_arc)
		var btn_world := anchor_pos + Vector2(0, -28)
		_reel_btn_rect = Rect2(btn_world - Vector2(36, 14), Vector2(72, 28))
		aim_preview.set_reel_button(_reel_btn_rect, false)
		aim_preview.clear_wire_range()
	else:
		aim_preview.clear_swing()
		_reel_btn_rect = Rect2()
		aim_preview.set_reel_button(Rect2(), false)
		# Show wire range circle with raycast toward mouse
		var dir := mouse_w - global_position
		if dir.length() > 4.0:
			var ray_dir := dir.normalized()
			var space := get_world_2d().direct_space_state
			var query := PhysicsRayQueryParameters2D.create(
				global_position, global_position + ray_dir * NEEDLE_REACH, 1, [get_rid()])
			var hit := space.intersect_ray(query)
			var hit_valid := not hit.is_empty()
			var hit_pos: Vector2 = hit["position"] if hit_valid else global_position + ray_dir * NEEDLE_REACH
			aim_preview.set_wire_range(global_position, NEEDLE_REACH, hit_pos, hit_valid)
		else:
			aim_preview.clear_wire_range()

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
		# Wire pre-constraint (no auto-reel — reel is manual)
		if wire_active:
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

func _apply_wire_pre(_delta: float) -> void:
	if _wire == null:
		return
	if _wire_anchor != null and is_instance_valid(_wire_anchor):
		_wire.anchor_pos = _wire_anchor.global_position
	var anchor_node := _wire_anchor as NeedleAnchor
	if anchor_node != null and anchor_node.attached_body != null \
			and not (anchor_node.attached_body is StaticBody2D):
		return
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
	var from := global_position
	var to_mouse := get_global_mouse_position() - from
	if to_mouse.length() < 4.0:
		return
	var dir := to_mouse.normalized()
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, from + dir * NEEDLE_REACH, 1, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return  # no surface in range — silent fail
	needle_manager.place_wire_anchor_instant(hit["position"], hit["collider"])
	TurnManager.commit()

func _release_grapple() -> void:
	needle_manager.release_wire()
	_wire = null
	_wire_anchor = null
	_wire_projectile = null
	wire_renderer.visible = false
	_reel_btn_rect = Rect2()
	aim_preview.set_reel_button(Rect2(), false)

func _on_wire_needle_launched(proj: Node) -> void:
	_wire_projectile = proj

func _on_wire_anchor_ready(anchor: Node) -> void:
	print("[PLAYER] Wire anchor ready at ", (anchor as Node2D).global_position)
	_wire_projectile = null
	_wire = anchor.wire as WireConstraint
	_wire_anchor = anchor as Node2D
	_wire.min_length = rope_min_length
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
