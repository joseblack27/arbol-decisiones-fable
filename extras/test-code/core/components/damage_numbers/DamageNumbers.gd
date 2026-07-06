class_name DamageNumbers
extends Node
## Reusable component: spawns floating damage numbers on the parent entity.
## Add as a child of any entity that has a HealthComponent.
## Color can be customized via @export.

@export var color: Color = Color(1.0, 0.35, 0.35)  ## Default: red-orange

func _ready() -> void:
	EventBus.damage_received.connect(_on_damage_received)

func _on_damage_received(entity: Node, amount: float) -> void:
	if entity != get_parent():
		return
	var scene_root := get_tree().current_scene
	var world_pos  := (get_parent() as Node2D).global_position + Vector2(
		randf_range(-12.0, 12.0), -20.0
	)
	FloatingText.spawn(scene_root, world_pos, str(int(amount)), color)
