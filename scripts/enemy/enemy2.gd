extends CharacterBody2D

@export var stats: Resource

@onready var appearance: Node2D = %Appearance if has_node("%Appearance") else self
@onready var player_detector: RayCast2D = RayCast2D.new()

var StateMachineClass = preload("res://scripts/state_machine/state_machine.gd")
var PatrolStateClass = preload("res://scripts/enemy/enemy2/enemy2_patrol_state.gd")
var NoticeStateClass = preload("res://scripts/enemy/enemy2/enemy2_notice_state.gd")
var ShootStateClass = preload("res://scripts/enemy/enemy2/enemy2_shoot_state.gd")

var state_machine
var direction: float = -1.0
var current_health: int = 1

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	if stats and "max_health" in stats:
		current_health = stats.max_health
		
	player_detector.target_position = Vector2(-200, 0)
	player_detector.collision_mask = 2
	add_child(player_detector)
	
	state_machine = StateMachineClass.new()
	state_machine.name = "StateMachine"
	
	var patrol = PatrolStateClass.new()
	patrol.name = "PatrolState"
	state_machine.add_child(patrol)
	
	var notice = NoticeStateClass.new()
	notice.name = "NoticeState"
	state_machine.add_child(notice)
	
	var shoot = ShootStateClass.new()
	shoot.name = "ShootState"
	state_machine.add_child(shoot)
	
	state_machine.initial_state = patrol.get_path()
	add_child(state_machine)
	state_machine.init(self)

func _physics_process(_delta: float) -> void:
	pass

func turn_around() -> void:
	direction *= -1.0
	player_detector.target_position.x = 200.0 * direction
	if appearance and "scale" in appearance:
		appearance.scale.x = -direction

func take_damage(damage: int) -> void:
	current_health -= damage
	var tween = create_tween()
	if appearance and "modulate" in appearance:
		appearance.modulate = Color(10, 10, 10, 1)
		tween.tween_property(appearance, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	queue_free()
