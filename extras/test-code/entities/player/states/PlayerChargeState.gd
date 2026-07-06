class_name PlayerChargeState
extends State
## Player dashes forward while ChargeAbility is active.
## Uses a temporary HitboxComponent child for damaging enemies.

var _player: Player
var _charge: ChargeAbility
var _charge_direction: Vector2
var _charge_speed: float
var _charge_duration: float
var _elapsed: float = 0.0
var _hitbox: HitboxComponent

func enter() -> void:
	_player = state_machine.actor as Player
	_charge = _player.ability_charge
	_elapsed = 0.0

	_charge_direction = _charge.get_charge_direction()
	_charge_speed = _player.movement.max_speed * _charge.get_charge_speed_multiplier()
	_charge_duration = _charge.charge_duration

	_player.input_facing_dir = _charge_direction

	# Pass through enemy bodies (layer 1) during charge.
	_player.set_collision_mask_value(1, false)

	_hitbox = _build_hitbox()
	_player.add_child(_hitbox)
	_hitbox.source_entity = _player
	_hitbox.damage = _charge.charge_damage
	_hitbox.knockback_force = _charge.knockback_force
	_hitbox.activate()

func physics_update(delta: float) -> void:
	_elapsed += delta
	_player.movement.set_velocity_override(_charge_direction * _charge_speed)
	_player.movement.process_movement(delta)
	_player.queue_redraw()

func exit() -> void:
	if is_instance_valid(_hitbox):
		_hitbox.queue_free()
	_player.movement.set_velocity_override(Vector2.ZERO)
	# Restore normal collision.
	_player.set_collision_mask_value(1, true)

func get_transition() -> String:
	if _elapsed >= _charge_duration:
		return "MoveState" if _player.input_movement_dir.length() > 0.1 else "IdleState"
	return ""

func _build_hitbox() -> HitboxComponent:
	var hb := HitboxComponent.new()
	hb.name = "ChargeHitbox"
	hb.hit_once_per_target = true
	hb.collision_layer = 4  # hitbox layer
	hb.collision_mask  = 2  # hurtbox layer
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	var col := CollisionShape2D.new()
	col.shape = shape
	hb.add_child(col)
	return hb
