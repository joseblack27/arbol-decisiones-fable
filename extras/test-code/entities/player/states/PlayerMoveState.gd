class_name PlayerMoveState
extends State
## Player is moving via the virtual joystick.

var _player: Player

func enter() -> void:
	_player = state_machine.actor as Player

func physics_update(delta: float) -> void:
	_player.movement.set_direction(_player.input_movement_dir)
	_player.movement.process_movement(delta)
	_player.queue_redraw()

func get_transition() -> String:
	if _player.pending_charge:
		_player.pending_charge = false
		return "ChargeState"
	if _player.pending_basic_attack:
		_player.pending_basic_attack = false
		return "AttackState"
	if _player.input_movement_dir.length() <= 0.1:
		return "IdleState"
	return ""
