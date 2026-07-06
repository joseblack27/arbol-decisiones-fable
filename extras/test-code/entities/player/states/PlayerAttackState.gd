class_name PlayerAttackState
extends State
## Brief lock while the basic attack fires.
## Returns to Idle/Move after attack_lock_duration.

@export var attack_lock_duration: float = 0.25

var _player: Player
var _timer: float = 0.0

func enter() -> void:
	_player = state_machine.actor as Player
	_timer = 0.0
	# Trigger the actual ability
	_player.ability_basic.activate(_player.input_facing_dir, 1.0)
	_player.movement.set_direction(Vector2.ZERO)

func physics_update(delta: float) -> void:
	_player.movement.process_movement(delta)
	_player.queue_redraw()

func update(delta: float) -> void:
	_timer += delta

func get_transition() -> String:
	if _timer >= attack_lock_duration:
		return "MoveState" if _player.input_movement_dir.length() > 0.1 else "IdleState"
	return ""
