class_name HurtboxComponent
extends Area2D
## Receives damage on behalf of the parent entity.
## Forwards damage to HealthComponent and applies knockback if present.

signal hurt(amount: float, source: Node)

var _health: HealthComponent = null

func _ready() -> void:
	_health = _find_health_component()

func _find_health_component() -> HealthComponent:
	for child in get_parent().get_children():
		if child is HealthComponent:
			return child
	return null

# ── Public API ────────────────────────────────────────────────
func receive_damage(amount: float, source: Node = null, knockback: float = 0.0) -> void:
	hurt.emit(amount, source)
	if _health:
		_health.take_damage(amount, source)
	if knockback > 0.0 and source:
		_apply_knockback(source, knockback)

# ── Internal ──────────────────────────────────────────────────
func _apply_knockback(source: Node, force: float) -> void:
	var parent := get_parent()
	if parent is CharacterBody2D:
		var dir = (parent.global_position - source.global_position).normalized()
		(parent as CharacterBody2D).velocity += dir * force
