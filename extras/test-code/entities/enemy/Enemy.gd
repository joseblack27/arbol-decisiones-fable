class_name Enemy
extends CharacterBody2D
## Basic enemy entity – static placeholder for ability testing.
## Components: HealthComponent, HurtboxComponent, DamageNumbers.

var health: HealthComponent

func _ready() -> void:
	health = $HealthComponent
	health.died.connect(_on_died)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 20.0, Color(0.85, 0.2, 0.2))
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color(1.0, 0.5, 0.5), 2.5)

func _on_died() -> void:
	queue_free()
