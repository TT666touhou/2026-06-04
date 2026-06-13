extends Area2D
class_name EnemyBullet

@export var speed: float = 120.0
@export var damage: int = 1
@export var lifetime: float = 5.0
var direction: Vector2 = Vector2.LEFT

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# 自動在設定的時間後銷毀，防止記憶體洩漏
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players") or body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	elif body is TileMapLayer: # 撞到牆壁/地面
		queue_free()
