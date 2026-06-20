# Node2D + RayCast2D built-ins, minimal flight logic
class_name NeedleProjectile
extends Node2D

@export var flight_speed: float = 1200.0
@export var needle_size: Vector2 = Vector2(12.0, 2.0)

enum NeedleType { ATTACK, WIRE }
var needle_type: NeedleType = NeedleType.ATTACK
var direction: Vector2 = Vector2.RIGHT

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
	# safety: free projectile if it escapes the play area (no wall to catch it).
	# Bounds are derived from the viewport so they track the scene size — a hardcoded
	# 960x540 bound (1024/604) freed every needle on spawn after the scene grew to
	# 1280x720 (GAP-036), since the player spawns below the old y=604 limit.
	var bounds := get_viewport_rect().size
	if global_position.x < -64.0 or global_position.x > bounds.x + 64.0 \
			or global_position.y < -64.0 or global_position.y > bounds.y + 64.0:
		queue_free()
