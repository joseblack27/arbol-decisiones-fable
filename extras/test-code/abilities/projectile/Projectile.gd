class_name Projectile
extends Area2D
## Moving projectile that damages the first HurtboxComponent it enters.
## Speed is constant; power scales the max range.

@export var base_speed: float = 450.0
@export var base_range: float = 400.0
@export var damage: float = 20.0
@export var knockback_force: float = 100.0

var source_entity: Node = null
var _direction: Vector2 = Vector2.RIGHT
var _max_range: float = 400.0
var _distance_traveled: float = 0.0
var _already_hit: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func setup(dir: Vector2, power: float, dmg: float, source: Node) -> void:
	_direction = dir.normalized()
	_max_range = base_range * clampf(power, 0.2, 1.0)
	damage = dmg
	source_entity = source
	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	var step := _direction * base_speed * delta
	position += step
	_distance_traveled += step.length()
	if _distance_traveled >= _max_range:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _already_hit:
		return
	if not area is HurtboxComponent:
		return
	var hurtbox := area as HurtboxComponent
	if hurtbox.get_parent() == source_entity:
		return
	_already_hit = true
	hurtbox.receive_damage(damage, source_entity, knockback_force)
	EventBus.damage_dealt.emit(hurtbox.get_parent(), damage, source_entity)
	EventBus.ability_hit.emit("projectile", hurtbox.get_parent())
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color(0.9, 0.5, 0.1))
	draw_circle(Vector2(12.0, 0.0), 5.0, Color(1.0, 0.8, 0.3))
