class_name ChargeAbility
extends AbilityBase
## Sends the player dashing in the chosen direction dealing damage to anything in the path.
## Communicates via EventBus so the PlayerChargeState knows when to start/stop.

signal charge_started(direction: Vector2, speed_mult: float, duration: float)
signal charge_ended()

@export var charge_damage: float = 25.0
@export var charge_speed_multiplier: float = 4.0
@export var charge_duration: float = 0.35
@export var knockback_force: float = 300.0
## Half-width of the charge path rectangle in the aim preview (≈ player collision radius).
@export var preview_half_width: float = 20.0

var _charging: bool = false
var _charge_timer: float = 0.0
var _charge_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	super._ready()
	ability_name = "Charge"
	ability_type = "charge"

func _process(delta: float) -> void:
	super._process(delta)  # Cooldown tick
	if _charging:
		_charge_timer += delta
		if _charge_timer >= charge_duration:
			_end_charge()

func _execute(direction: Vector2, _power: float) -> void:
	_charge_direction = direction if direction.length() > 0.1 else Vector2.RIGHT
	_charging = true
	_charge_timer = 0.0
	charge_started.emit(_charge_direction, charge_speed_multiplier, charge_duration)

func _end_charge() -> void:
	_charging = false
	charge_ended.emit()

func is_charging() -> bool:
	return _charging

func get_charge_direction() -> Vector2:
	return _charge_direction

func get_charge_speed_multiplier() -> float:
	return charge_speed_multiplier
