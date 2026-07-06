class_name AbilityBase
extends Node
## Abstract base class for all abilities.
## Handles cooldown lifecycle and provides a uniform activation interface.
## Open/Closed: extend this class, never modify it to add ability-specific logic.

signal ability_activated(ability: AbilityBase)
signal cooldown_finished(ability: AbilityBase)

@export var ability_name: String = "Ability"
@export var ability_type: String = "base"  ## Used as identifier in EventBus signals
@export var cooldown_duration: float = 1.0

## Set automatically to the entity this ability belongs to.
var owner_entity: Node = null
var _cooldown_remaining: float = 0.0

func _ready() -> void:
	owner_entity = get_parent().get_parent()  # AbilityContainer → Entity

func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		if _cooldown_remaining <= 0.0:
			_cooldown_remaining = 0.0
			cooldown_finished.emit(self)
			EventBus.ability_cooldown_ended.emit(owner_entity, ability_type)

# ── Public API ────────────────────────────────────────────────
func can_use() -> bool:
	return _cooldown_remaining <= 0.0

func get_cooldown_ratio() -> float:
	if cooldown_duration <= 0.0:
		return 0.0
	return clampf(_cooldown_remaining / cooldown_duration, 0.0, 1.0)

func get_cooldown_remaining() -> float:
	return maxf(0.0, _cooldown_remaining)

## Call this to trigger the ability.
## direction – normalized vector (from joystick or facing dir).
## power     – 0..1 value for distance/range scaling.
func activate(direction: Vector2 = Vector2.ZERO, power: float = 1.0) -> void:
	if not can_use():
		return
	_execute(direction, power)
	_start_cooldown()
	ability_activated.emit(self)
	EventBus.ability_used.emit(owner_entity, ability_type)

# ── Internal – override in subclasses ─────────────────────────
func _execute(_direction: Vector2, _power: float) -> void:
	pass

func _start_cooldown() -> void:
	_cooldown_remaining = cooldown_duration
	EventBus.ability_cooldown_started.emit(owner_entity, ability_type, cooldown_duration)
