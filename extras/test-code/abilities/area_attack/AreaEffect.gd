class_name AreaEffect
extends Area2D
## Temporary AoE that damages every HurtboxComponent inside on activation.
## power (0..1) scales the radius. Disappears after effect_duration.

@export var base_radius: float = 80.0
@export var damage: float = 30.0
@export var knockback_force: float = 80.0
@export var effect_duration: float = 0.4

var source_entity: Node = null
var _shape: CircleShape2D
var _timer: float = 0.0
var _activated: bool = false

func _ready() -> void:
	_shape = $CollisionShape2D.shape as CircleShape2D

## power is unused for radius – radius is always base_radius.
## The joystick power only controls the landing offset (handled by AreaAttackAbility).
func setup(dmg: float, source: Node) -> void:
	damage = dmg
	source_entity = source
	_shape.radius = base_radius
	call_deferred("_apply_damage")

func _apply_damage() -> void:
	_activated = true
	# Query the physics space directly — reliable regardless of frame timing.
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape            = _shape
	query.transform        = global_transform
	query.collision_mask   = 2       # hurtbox layer
	query.collide_with_areas   = true
	query.collide_with_bodies  = false
	var results := space.intersect_shape(query)
	for r in results:
		var collider = r.get("collider")
		if not collider is HurtboxComponent:
			continue
		if collider.get_parent() == source_entity:
			continue
		collider.receive_damage(damage, source_entity, knockback_force)
		EventBus.damage_dealt.emit(collider.get_parent(), damage, source_entity)
		EventBus.ability_hit.emit("area_attack", collider.get_parent())

func _process(delta: float) -> void:
	if not _activated:
		return
	_timer += delta
	if _timer >= effect_duration:
		queue_free()

func _draw() -> void:
	if _shape:
		draw_circle(Vector2.ZERO, _shape.radius, Color(0.8, 0.2, 0.8, 0.35))
		draw_arc(Vector2.ZERO, _shape.radius, 0.0, TAU, 32, Color(0.8, 0.2, 0.8, 0.9), 2.0)
