class_name AreaAttackAbility
extends AbilityBase
## Spawns an AoE at a fixed-radius circle offset in the given direction.
## power only controls how far from the player it lands; radius is always fixed.

@export var area_damage: float = 30.0
@export var max_offset: float = 120.0  ## Max distance from entity center
## AoE radius – always fixed regardless of throw distance. Read by AimIndicator.
@export var area_radius: float = 80.0
@export var area_scene: PackedScene = preload("res://abilities/area_attack/AreaEffect.tscn")

func _ready() -> void:
	super._ready()
	ability_name = "Area Attack"
	ability_type = "area_attack"

func _execute(direction: Vector2, power: float) -> void:
	var effect := area_scene.instantiate() as AreaEffect
	var offset := Vector2.ZERO
	if direction.length() > 0.1:
		offset = direction.normalized() * max_offset * clampf(power, 0.2, 1.0)
	owner_entity.get_tree().current_scene.add_child(effect)
	effect.global_position = owner_entity.global_position + offset
	effect.base_radius = area_radius  # Sync radius from ability config
	effect.setup(area_damage, owner_entity)
