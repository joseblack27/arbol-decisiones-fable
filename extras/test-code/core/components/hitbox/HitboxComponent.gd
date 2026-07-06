class_name HitboxComponent
extends Area2D
## Deals damage to HurtboxComponents it overlaps.
## Attach to projectiles, melee swings, AoE effects, or any attack source.

@export var damage: float = 10.0
@export var knockback_force: float = 150.0
## If true, each target is only hit once per activation (good for projectiles).
@export var hit_once_per_target: bool = true

## Set to the entity that owns this hitbox so it can't damage itself.
var source_entity: Node = null

var _hit_targets: Array[Node] = []

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	# Hitboxes start disabled; owners enable them when attacking.
	monitoring = false

func activate() -> void:
	_hit_targets.clear()
	monitoring = true

func deactivate() -> void:
	monitoring = false

func reset() -> void:
	_hit_targets.clear()

func _on_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var hurtbox := area as HurtboxComponent
	var target := hurtbox.get_parent()
	if target == source_entity:
		return
	if hit_once_per_target and target in _hit_targets:
		return
	_hit_targets.append(target)
	hurtbox.receive_damage(damage, source_entity, knockback_force)
	EventBus.damage_dealt.emit(target, damage, source_entity)
