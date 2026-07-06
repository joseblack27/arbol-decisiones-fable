class_name State
extends Node
## Abstract base class for all states.
## Subclasses override enter/exit/update/physics_update/get_transition.

## Set by StateMachine on registration – gives access to sibling states and actor.
var state_machine: StateMachine

# ── Lifecycle ─────────────────────────────────────────────────
func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

## Return the target state name to transition, or "" to remain in this state.
func get_transition() -> String:
	return ""
