## CameraController — Free pan/zoom during FROZEN, smooth follow during PLAYING.
## GAP-063: Scene-level camera replacing Player-child Camera2D.
extends Camera2D

const ZOOM_MIN    := 0.25
const ZOOM_MAX    := 3.0
const ZOOM_FACTOR := 1.12   # multiplier per scroll tick
const PAN_SPEED   := 600.0  # px/s keyboard pan (world units)
const FOLLOW_LERP := 7.0    # smooth follow coefficient

var _mid_drag        : bool    = false
var _drag_origin_scr : Vector2 = Vector2.ZERO  # screen pos at drag start
var _drag_origin_cam : Vector2 = Vector2.ZERO  # camera world pos at drag start
var _player          : Node2D  = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	make_current()

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D

	if TurnManager.is_frozen():
		# FROZEN: WASD keyboard pan
		var kdir := Vector2(
			float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		)
		if kdir.length_squared() > 0.0:
			global_position += kdir.normalized() * PAN_SPEED / zoom.x * delta
	else:
		# PLAYING: smooth follow player
		if _player:
			global_position = global_position.lerp(
				_player.global_position + Vector2(0, 60), FOLLOW_LERP * delta
			)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_toward_mouse(ZOOM_FACTOR)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_toward_mouse(1.0 / ZOOM_FACTOR)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_MIDDLE:
				_mid_drag = mb.pressed
				if mb.pressed:
					_drag_origin_scr = mb.position
					_drag_origin_cam = global_position

	elif event is InputEventMouseMotion and _mid_drag:
		var motion := event as InputEventMouseMotion
		global_position = _drag_origin_cam - (motion.position - _drag_origin_scr) / zoom.x

func _zoom_toward_mouse(factor: float) -> void:
	var old_z  := zoom.x
	var new_z  := clampf(old_z * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_z, old_z):
		return
	var vp_half   := get_viewport_rect().size * 0.5
	var mouse_vp  := get_viewport().get_mouse_position()
	# World point currently under the mouse
	var world_pt  := global_position + (mouse_vp - vp_half) / old_z
	zoom           = Vector2.ONE * new_z
	# Reposition so that same world point stays under mouse
	global_position = world_pt - (mouse_vp - vp_half) / new_z
