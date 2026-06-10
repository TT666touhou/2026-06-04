extends Node
class_name StateMachine

@export var initial_state: NodePath
var current_state: State

func init(actor: CharacterBody2D) -> void:
	for child in get_children():
		if child is State:
			child.state_machine = self
			child.actor = actor
	
	if initial_state:
		current_state = get_node(initial_state)
		current_state.enter()

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	if not has_node(target_state_name):
		return
	
	var target_state = get_node(target_state_name)
	if current_state:
		current_state.exit()
	
	current_state = target_state
	current_state.enter(msg)
