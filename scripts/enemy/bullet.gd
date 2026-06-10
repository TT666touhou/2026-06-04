extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 150.0
var damage: int = 1

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.name.begins_with("Player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	# 若撞到牆壁也銷毀，假設牆壁為 TileMapLayer
	elif body is TileMapLayer:
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
