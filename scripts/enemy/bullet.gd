extends CharacterBody2D

@export var speed: float = 200.0
@export var damage: int = 1
@export var direction: Vector2 = Vector2.LEFT

var lifetime: float = 3.0
var sprite: Sprite2D
var hitbox: Area2D

func _ready() -> void:
	sprite = Sprite2D.new()
	var tex = preload("res://assets/tilesets/mrmotext/colored/color_T_10_fanqiehong.png")
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(24, 120, 8, 8)
	sprite.texture = atlas
	add_child(sprite)
	
	hitbox = Area2D.new()
	hitbox.collision_mask = 2
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	shape.shape = rect
	hitbox.add_child(shape)
	add_child(hitbox)
	
	hitbox.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	velocity = direction * speed
	move_and_slide()
	
	lifetime -= delta
	if lifetime <= 0 or is_on_wall():
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player1" and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
