class_name MovementComponent
extends Node
## Handles velocity and movement for a CharacterBody2D.
## Decoupled from input – set direction externally.

@export var max_speed: float = 200.0
@export var acceleration: float = 800.0

## Current movement direction (normalized). Set by the owner entity or states.
var direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var _overridden: bool = false

func _ready() -> void:
	assert(get_parent() is CharacterBody2D,
		"MovementComponent must be a child of CharacterBody2D")

# ── Public API ────────────────────────────────────────────────
func set_direction(dir: Vector2) -> void:
	direction = dir.normalized() if dir.length() > 0.1 else Vector2.ZERO

func process_movement(delta: float) -> void:
	var body := get_parent() as CharacterBody2D
	if _overridden:
		_overridden = false  # consume for this frame; caller must set again next frame
	elif direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)
	else:
		velocity = Vector2.ZERO
	body.velocity = velocity
	body.move_and_slide()

## Override velocity directly (e.g. for charge/knockback).
## Must be called every frame while the override is active.
func set_velocity_override(vel: Vector2) -> void:
	velocity = vel
	_overridden = vel != Vector2.ZERO

func is_moving() -> bool:
	return velocity.length() > 10.0

## Returns last non-zero movement direction; defaults to Vector2.RIGHT.
func get_facing_direction() -> Vector2:
	if velocity.length() > 10.0:
		return velocity.normalized()
	if direction.length() > 0.1:
		return direction.normalized()
	return Vector2.RIGHT
