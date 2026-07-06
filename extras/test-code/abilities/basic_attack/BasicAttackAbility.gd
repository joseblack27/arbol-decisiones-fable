class_name BasicAttackAbility
extends AbilityBase
## Instant melee swing in the player's current facing direction.
## Spawns a short-lived HitboxComponent at the entity's front.

@export var damage: float = 15.0
@export var knockback: float = 200.0
@export var hit_range: float = 48.0  ## Offset from entity center
@export var hit_radius: float = 30.0
@export var hit_duration: float = 0.15  ## Seconds the hitbox stays active

var _hit_scene: PackedScene = preload("res://abilities/basic_attack/BasicHit.tscn")

func _ready() -> void:
	super._ready()
	ability_name = "Basic Attack"
	ability_type = "basic_attack"

func _execute(direction: Vector2, _power: float) -> void:
	var hit := _hit_scene.instantiate() as Node2D
	var facing := direction if direction.length() > 0.1 else Vector2.RIGHT
	# add_child first so _ready() runs on 'hit' before setup() accesses its internals
	owner_entity.get_tree().current_scene.add_child(hit)
	hit.global_position = owner_entity.global_position + facing * hit_range
	hit.setup(damage, knockback, hit_radius, owner_entity, hit_duration)
