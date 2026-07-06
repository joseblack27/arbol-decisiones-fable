class_name HealthComponent
extends Node
## Manages health, damage reception, and death for any entity.
## Single Responsibility: only health logic here.

signal health_changed(current: float, max_hp: float)
signal died()

@export var max_health: float = 100.0
@export var is_invincible: bool = false

var current_health: float

func _ready() -> void:
	current_health = max_health

# ── Public API ────────────────────────────────────────────────
func take_damage(amount: float, source: Node = null) -> void:
	if is_invincible or current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	EventBus.damage_received.emit(get_parent(), amount)
	if current_health <= 0.0:
		_die()

func heal(amount: float) -> void:
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func is_alive() -> bool:
	return current_health > 0.0

func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return current_health / max_health

func set_max_health(new_max: float, also_heal: bool = false) -> void:
	max_health = new_max
	if also_heal:
		current_health = max_health
	health_changed.emit(current_health, max_health)

# ── Internal ──────────────────────────────────────────────────
func _die() -> void:
	died.emit()
	EventBus.entity_died.emit(get_parent())
