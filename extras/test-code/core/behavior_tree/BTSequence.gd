class_name BTSequence
extends BTNode
## AND gate – runs children left to right.
## Returns FAILURE on the first failing child.
## Returns SUCCESS only when all children succeed.

func tick(actor: Node, blackboard: Dictionary) -> Status:
	for child in get_children():
		if not child is BTNode:
			continue
		var result: Status = child.tick(actor, blackboard)
		if result != Status.SUCCESS:
			return result
	return Status.SUCCESS
