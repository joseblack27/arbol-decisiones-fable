class_name BTSelector
extends BTNode
## OR gate – runs children left to right.
## Returns SUCCESS on the first succeeding child.
## Returns FAILURE only when all children fail.

func tick(actor: Node, blackboard: Dictionary) -> Status:
	for child in get_children():
		if not child is BTNode:
			continue
		var result: Status = child.tick(actor, blackboard)
		if result != Status.FAILURE:
			return result
	return Status.FAILURE
