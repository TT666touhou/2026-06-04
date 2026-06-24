# Node2D + RayCast2D built-ins, minimal flight logic
class_name NeedleProjectile
extends Node2D

@export var flight_speed: float = 1600.0
@export var needle_size: Vector2 = Vector2(12.0, 2.0)
@export var max_travel: float = 2400.0   # safety: free a needle that never hits anything

enum NeedleType { ATTACK, WIRE }
var needle_type: NeedleType = NeedleType.ATTACK
var direction: Vector2 = Vector2.RIGHT
var _traveled: float = 0.0

signal embedded(hit_pos: Vector2, collider: Object)

@onready var _ray: RayCast2D = $RayCast2D
@onready var _visual: ColorRect = $Visual

func setup(dir: Vector2, n_type: NeedleType) -> void:
	direction = dir
	needle_type = n_type
	rotation = dir.angle()

func _ready() -> void:
	_visual.size = needle_size
	_visual.position = Vector2(-needle_size.x * 0.5, -needle_size.y * 0.5)
	_ray.enabled = true

func _physics_process(delta: float) -> void:
	var step := flight_speed * delta
	# target_position is LOCAL space; needle rotation = direction.angle(), so local-X == world direction
	_ray.target_position = Vector2(step * 1.2, 0)
	_ray.force_raycast_update()
	if _ray.is_colliding():
		embedded.emit(_ray.get_collision_point(), _ray.get_collider())
		queue_free()
		return
	global_position += direction * step
	# Safety net: free a needle that never hits anything. Culls by TRAVEL DISTANCE,
	# not screen/scene bounds. get_viewport_rect() returns the (possibly scaled)
	# viewport size — here 1152x648, not the 1280x720 world — so the previous
	# viewport-based bound culled needles INSIDE the arena before they reached the
	# walls (GAP-038). The enclosing walls catch real shots; this is only a fallback.
	_traveled += step
	if _traveled > max_travel:
		queue_free()
