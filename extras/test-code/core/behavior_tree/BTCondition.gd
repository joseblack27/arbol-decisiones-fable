class_name BTCondition
extends BTLeaf
## Leaf node that evaluates a boolean condition.
## Override _check() in subclasses to implement the condition.

func tick(actor: Node, blackboard: Dictionary) -> Status:
	return Status.SUCCESS if _check(actor, blackboard) else Status.FAILURE

func _check(_actor: Node, _blackboard: Dictionary) -> bool:
	return false
