class_name BTNode
extends Node
## Base class for all Behavior Tree nodes.
## Subclasses implement tick() and return a Status.

enum Status {
	SUCCESS,
	FAILURE,
	RUNNING,
}

## Execute this node's logic.
## actor  – the entity being controlled.
## blackboard – shared dictionary for data passing between nodes.
func tick(_actor: Node, _blackboard: Dictionary) -> Status:
	return Status.FAILURE
