extends CharacterBody2D

const SPEED = 50.0
const JUMP_VELOCITY = -300.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var direction = 1
var timer = 0.0

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Basic AI: Jump occasionally
	timer += delta
	if timer > 2.0:
		timer = 0.0
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			direction *= -1 # turn around when jumping
			
	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
