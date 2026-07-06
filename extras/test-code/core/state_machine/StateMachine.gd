class_name StateMachine
extends Node
## Manages state transitions for an entity.
## Child nodes of type State are registered automatically.
## Usage: set initial_state in the Inspector, then call transition_to() from states.

@export var initial_state: String = ""

var current_state: State = null
var states: Dictionary = {}
## The entity this state machine controls (its parent node).
var actor: Node

func _ready() -> void:
	actor = get_parent()
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self

	# Defer so the parent entity's _ready() runs first and caches all components.
	if initial_state != "" and states.has(initial_state):
		call_deferred("_start_initial_state")

func _start_initial_state() -> void:
	if initial_state != "" and states.has(initial_state):
		current_state = states[initial_state]
		current_state.enter()

func _process(delta: float) -> void:
	if not current_state:
		return
	current_state.update(delta)
	var next := current_state.get_transition()
	if next != "":
		transition_to(next)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(state_name: String) -> void:
	if not states.has(state_name):
		push_error("StateMachine: unknown state '%s'" % state_name)
		return
	if current_state:
		current_state.exit()
	current_state = states[state_name]
	current_state.enter()

func get_current_state_name() -> String:
	return current_state.name if current_state else ""

func is_in_state(state_name: String) -> bool:
	return get_current_state_name() == state_name
