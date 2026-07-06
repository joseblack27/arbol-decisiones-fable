class_name BehaviorTree
extends Node
## Root node that drives a behavior tree on a fixed tick rate.
## Attach as child of an AI entity and add BTSequence/BTSelector children.

@export var tick_rate: float = 0.1  ## Seconds between ticks

## Shared data bus between nodes. Populate in _ready or from outside.
var blackboard: Dictionary = {}

var _timer: float = 0.0
var _actor: Node

func _ready() -> void:
	_actor = get_parent()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= tick_rate:
		_timer = 0.0
		_tick()

func _tick() -> void:
	for child in get_children():
		if child is BTNode:
			child.tick(_actor, blackboard)
			break  # Only tick the single root composite node
