extends CharacterBody2D

const SPEED = 80.0
const DASH_SPEED = 300.0
const JUMP_VELOCITY = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

enum State { IDLE, WALK, JUMP, DASH }
var current_state = State.IDLE
var state_timer = 0.0
var direction = 1
var max_health = 100
var current_health = 100

@onready var hitbox: Area2D = $Hitbox

func _ready():
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		var sync = $MultiplayerSynchronizer
		var rep = SceneReplicationConfig.new()
		rep.add_property(NodePath(".:position"))
		rep.property_set_spawn(NodePath(".:position"), true)
		rep.property_set_replication_mode(NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		rep.add_property(NodePath(".:direction"))
		rep.property_set_spawn(NodePath(".:direction"), true)
		rep.property_set_replication_mode(NodePath(".:direction"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		rep.add_property(NodePath(".:current_health"))
		rep.property_set_spawn(NodePath(".:current_health"), true)
		rep.property_set_replication_mode(NodePath(".:current_health"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		sync.replication_config = rep
		
		hitbox.body_entered.connect(_on_hitbox_entered)
		
		# Change state periodically
		var t = Timer.new()
		t.wait_time = 2.0
		t.autostart = true
		t.timeout.connect(_on_state_timer)
		add_child(t)

func _is_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	# Flip visual based on direction
	for c in get_children():
		if c is Sprite2D:
			c.flip_h = direction < 0
			
	if not _is_authority():
		return

	if current_state == State.WALK:
		velocity.x = direction * SPEED
		if is_on_wall():
			direction *= -1
	elif current_state == State.DASH:
		velocity.x = direction * DASH_SPEED
		if is_on_wall():
			direction *= -1
			current_state = State.WALK
	elif current_state == State.JUMP:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if is_on_floor() and current_state == State.JUMP:
		current_state = State.IDLE

	move_and_slide()

func _on_state_timer():
	if not is_on_floor(): return
	var rand = randi() % 4
	if rand == 0:
		current_state = State.IDLE
	elif rand == 1:
		current_state = State.WALK
		direction = -1 if randf() > 0.5 else 1
	elif rand == 2:
		current_state = State.JUMP
		velocity.y = JUMP_VELOCITY
		direction = -1 if randf() > 0.5 else 1
	elif rand == 3:
		current_state = State.DASH
		direction = -1 if randf() > 0.5 else 1

func _on_hitbox_entered(body: Node2D):
	if body.is_in_group("Players"):
		if body.has_method("take_damage"):
			# Deal 1 damage
			body.take_damage(1)
			# Knockback calculation
			var dir = (body.global_position - global_position).normalized()
			dir.y = -0.5
			body.apply_bounce_impulse(dir * 300.0)

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int, hit_direction: int = 0):
	if not _is_authority():
		return
	current_health -= amount
	print("[Boss] Hit! HP: ", current_health)
	
	# Small knockback
	velocity.x = hit_direction * 150.0
	velocity.y = -100.0
	
	# Flash red
	_flash_red.rpc()
	
	if current_health <= 0:
		die.rpc()

@rpc("call_local", "reliable")
func _flash_red():
	modulate = Color.RED
	if has_node("HitParticles"):
		$HitParticles.restart()
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE

@rpc("call_local", "reliable")
func die():
	print("[Boss] Defeated!")
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	for c in get_children():
		if c is Sprite2D:
			c.hide()
			
	if has_node("HitParticles"):
		var p = $HitParticles
		p.amount = 50
		p.color = Color.RED
		p.scale_amount_max = 6.0
		p.restart()
		await get_tree().create_timer(1.0).timeout
		
	queue_free()
