## Player — real-time WASD movement + wire grapple + needle combat.
## GAP-073: Turn-based system removed; Space = bullet time via TurnManager.
extends CharacterBody2D

# ── Movement ───────────────────────────────────────────────────────────────────
@export var walk_speed: float = 220.0
@export var jump_force: float = 550.0
@export var wall_climb_speed: float = 140.0
@export var gravity: float = 980.0

# ── Wire grapple ──────────────────────────────────────────────────────────────
@export var rope_min_length: float = 24.0
@export var rope_snap_factor: float = 0.35

# ── Needle reach (max range for both attack needle and wire grapple) ───────────
const NEEDLE_REACH: float = 480.0

# ── Reel animation ─────────────────────────────────────────────────────────────
const REEL_DURATION: float = 0.25   # seconds to fully reel in

# ── Internal state ─────────────────────────────────────────────────────────────
var _wire: WireConstraint = null
var _wire_anchor: Node2D = null
var _wire_projectile: Node = null

# Mouse edge detection
var _lmb_prev: bool = false
var _rmb_prev: bool = false

# Reel button rect (world coords)
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
	_lmb_prev = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_rmb_prev = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func _physics_process(delta: float) -> void:
	# Reel animation: smoothly shorten wire over REEL_DURATION
	if _reel_animating:
		if _wire != null:
			_reel_elapsed += delta
			var t := clampf(_reel_elapsed / REEL_DURATION, 0.0, 1.0)
			_wire.length = lerpf(_reel_from, rope_min_length, t)
			if t >= 1.0:
				_reel_animating = false
				var anchor_pos: Vector2 = _wire_anchor.global_position if _wire_anchor != null else Vector2.ZERO
				_release_grapple()
				_try_stick_after_reel(anchor_pos)
		else:
			_reel_animating = false

	_apply_movement(delta)
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

# ── Input ──────────────────────────────────────────────────────────────────────

func _poll_mouse() -> void:
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var mouse_w := get_global_mouse_position()

	if lmb and not _lmb_prev:
		if _reel_btn_rect.has_area() and _reel_btn_rect.has_point(mouse_w):
			_do_reel()
		else:
			_shoot_attack()

	if rmb and not _rmb_prev:
		_start_grapple()

	_lmb_prev = lmb
	_rmb_prev = rmb

func _unhandled_input(_event: InputEvent) -> void:
	pass

# ── Movement ───────────────────────────────────────────────────────────────────

func _apply_movement(delta: float) -> void:
	if _stuck:
		_apply_stuck_movement()
		return

	var h := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))

	if _wire != null:
		# Swinging on wire: gravity only, wire constraint handles position
		if not is_on_floor():
			velocity.y += gravity * delta
	else:
		# Free movement
		velocity.x = h * walk_speed
		if not is_on_floor():
			velocity.y += gravity * delta
		elif Input.is_key_pressed(KEY_W):
			velocity.y = -jump_force

func _apply_stuck_movement() -> void:
	var h := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var v := float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))  # positive = down

	if abs(_stuck_normal.x) > 0.5:
		# Vertical wall: W/S = climb up/down
		velocity.y = v * wall_climb_speed
		velocity.x = 0.0
		# Press away from wall = push off and fall
		if h * _stuck_normal.x > 0.3:
			_unstick()
			velocity.x = h * walk_speed
	elif _stuck_normal.y > 0.5:
		# Ceiling: A/D = crawl left/right
		velocity.x = h * wall_climb_speed
		velocity.y = 0.0
		# S = drop off ceiling
		if v > 0.3:
			_unstick()

# ── Reel ───────────────────────────────────────────────────────────────────────

func _do_reel() -> void:
	if _wire == null:
		return
	_reel_from = _wire.length
	_reel_elapsed = 0.0
	_reel_animating = true
	_unstick()

# ── Surface sticking ───────────────────────────────────────────────────────────

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

# ── Aim preview (shown during bullet time) ─────────────────────────────────────

func _update_preview() -> void:
	var mouse_w := get_global_mouse_position()

	# Layer 1: Needle aim trajectory
	var from := global_position
	var to_mouse := mouse_w - from
	if to_mouse.length() > 8.0:
		var needle_dir := to_mouse.normalized()
		var space := get_world_2d().direct_space_state
		var nq := PhysicsRayQueryParameters2D.create(
			from, from + needle_dir * NEEDLE_REACH, 0xFFFF, [get_rid()])
		var nhit := space.intersect_ray(nq)
		var reach: Vector2 = nhit["position"] if not nhit.is_empty() else from + needle_dir * NEEDLE_REACH
		aim_preview.set_needle(from, reach, mouse_w)
	else:
		aim_preview.clear_needle()

	# Layer 3: Wire swing arc + reel button (when wire active)
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
		# Wire range indicator toward mouse
		var dir := mouse_w - global_position
		if dir.length() > 4.0:
			var ray_dir := dir.normalized()
			var space := get_world_2d().direct_space_state
			var query := PhysicsRayQueryParameters2D.create(
				global_position, global_position + ray_dir * NEEDLE_REACH, 0xFFFF, [get_rid()])
			var hit := space.intersect_ray(query)
			var hit_valid := not hit.is_empty()
			var hit_pos: Vector2 = hit["position"] if hit_valid else global_position + ray_dir * NEEDLE_REACH
			aim_preview.set_wire_range(global_position, NEEDLE_REACH, hit_pos, hit_valid)
		else:
			aim_preview.clear_wire_range()

# ── Wire simulation (for aim preview swing arc) ────────────────────────────────

func _simulate_wire_pull(
	start_pos: Vector2, start_vel: Vector2,
	anchor_pos: Vector2, wire_len: float, steps: int
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var pos := start_pos
	var vel := start_vel
	var dt := 0.3 / steps
	pts.append(pos)
	for _i in range(steps):
		vel.y += gravity * dt
		var to_anchor := anchor_pos - pos
		var d := to_anchor.length()
		if d > wire_len and d > 0.001:
			var rope_dir := to_anchor / d
			var radial := vel.dot(rope_dir)
			if radial < 0.0:
				vel -= rope_dir * radial
		pos += vel * dt
		to_anchor = anchor_pos - pos
		d = to_anchor.length()
		if d > wire_len and d > 0.001:
			pos = anchor_pos - (to_anchor / d) * wire_len
		pts.append(pos)
	return pts

# ── Gravity ────────────────────────────────────────────────────────────────────

func _is_on_player(world_pos: Vector2) -> bool:
	return (world_pos - global_position).length_squared() <= 50.0 * 50.0

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
	var from := global_position
	var to_mouse := get_global_mouse_position() - from
	if to_mouse.length() < 4.0:
		return
	var dir := to_mouse.normalized()
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, from + dir * NEEDLE_REACH, 0xFFFF, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	needle_manager.place_attack_anchor_instant(hit["position"], hit["collider"])

func _start_grapple() -> void:
	if _wire != null or (_wire_projectile != null and is_instance_valid(_wire_projectile)):
		return
	var from := global_position
	var to_mouse := get_global_mouse_position() - from
	if to_mouse.length() < 4.0:
		return
	var dir := to_mouse.normalized()
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, from + dir * NEEDLE_REACH, 0xFFFF, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	needle_manager.place_wire_anchor_instant(hit["position"], hit["collider"])

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
