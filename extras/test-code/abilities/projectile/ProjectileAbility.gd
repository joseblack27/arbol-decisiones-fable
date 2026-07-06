class_name ProjectileAbility
extends AbilityBase
## Launches a projectile in the given direction.
## power (0..1) scales the projectile's max range.

@export var projectile_damage: float = 20.0
## Max travel distance. Forwarded to the Projectile instance and read by AimIndicator.
@export var max_range: float = 400.0
@export var projectile_scene: PackedScene = preload("res://abilities/projectile/Projectile.tscn")

func _ready() -> void:
	super._ready()
	ability_name = "Projectile"
	ability_type = "projectile"

func _execute(direction: Vector2, power: float) -> void:
	var proj := projectile_scene.instantiate() as Projectile
	owner_entity.get_tree().current_scene.add_child(proj)
	proj.global_position = owner_entity.global_position
	proj.base_range = max_range  # Sync so projectile matches the preview
	proj.setup(direction, power, projectile_damage, owner_entity)
