class_name BasicHit
extends Node2D
## Short-lived area that deals melee damage.
## Auto-destructs after hit_duration.

var _hitbox: HitboxComponent
var _duration: float = 0.15
var _timer: float = 0.0

func _ready() -> void:
	_hitbox = $HitboxComponent

func setup(damage: float, knockback: float, radius: float, source: Node, duration: float) -> void:
	_duration = duration
	var shape := CircleShape2D.new()
	shape.radius = radius
	$HitboxComponent/CollisionShape2D.shape = shape
	_hitbox.damage = damage
	_hitbox.knockback_force = knockback
	_hitbox.source_entity = source
	_hitbox.activate()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _duration:
		queue_free()

func _draw() -> void:
	# Debug visual – white semi-transparent circle
	var shape := $HitboxComponent/CollisionShape2D.shape as CircleShape2D
	if shape:
		draw_circle(Vector2.ZERO, shape.radius, Color(1, 1, 1, 0.25))
