class_name PlayerIdleState
extends State
## Player is standing still.
## Transitions to Move when joystick moves, or Attack when basic attack fires.

var _player: Player

func enter() -> void:
	_player = state_machine.actor as Player
	_player.movement.set_direction(Vector2.ZERO)

func physics_update(delta: float) -> void:
	_player.movement.process_movement(delta)
	queue_redraw_player()

func get_transition() -> String:
	if _player.pending_charge:
		_player.pending_charge = false
		return "ChargeState"
	if _player.pending_basic_attack:
		_player.pending_basic_attack = false
		return "AttackState"
	if _player.input_movement_dir.length() > 0.1:
		return "MoveState"
	return ""

func queue_redraw_player() -> void:
	_player.queue_redraw()
