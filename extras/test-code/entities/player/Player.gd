class_name Player
extends CharacterBody2D
## Main player entity.
## Owns components (Health, Movement) and an AbilityContainer.
## Receives input via EventBus and stores it for states to consume.

# ── Cached components ─────────────────────────────────────────
var health: HealthComponent
var movement: MovementComponent
var hurtbox: HurtboxComponent

# ── Ability shortcuts (set in _ready via AbilityContainer) ────
var ability_basic: BasicAttackAbility
var ability_projectile: ProjectileAbility
var ability_area: AreaAttackAbility
var ability_charge: ChargeAbility

# ── Input state (written by EventBus listeners, read by states) ─
var input_movement_dir: Vector2 = Vector2.ZERO
var input_facing_dir: Vector2 = Vector2.RIGHT  ## Last non-zero movement direction

## Pending ability requests consumed by states
var pending_basic_attack: bool = false
var pending_charge: bool = false

func _ready() -> void:
	GameManager.register_player(self)
	_cache_components()
	_connect_input_signals()
	_connect_health_signals()

func _cache_components() -> void:
	health     = $HealthComponent
	movement   = $MovementComponent
	hurtbox    = $HurtboxComponent
	var ac     = $AbilityContainer
	ability_basic      = ac.get_node("BasicAttackAbility")
	ability_projectile = ac.get_node("ProjectileAbility")
	ability_area       = ac.get_node("AreaAttackAbility")
	ability_charge     = ac.get_node("ChargeAbility")

	# Give abilities reference to the charge component for the charge state
	ability_charge.charge_started.connect(_on_charge_started)

func _connect_input_signals() -> void:
	EventBus.movement_input_changed.connect(_on_movement_input)
	EventBus.ability_input_basic_attack.connect(_on_basic_attack_input)
	EventBus.ability_input_projectile.connect(_on_projectile_input)
	EventBus.ability_input_area_attack.connect(_on_area_attack_input)
	EventBus.ability_input_charge.connect(_on_charge_input)

func _connect_health_signals() -> void:
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)

# ── Input handlers ────────────────────────────────────────────
func _on_movement_input(dir: Vector2) -> void:
	input_movement_dir = dir
	if dir.length() > 0.1:
		input_facing_dir = dir.normalized()

func _on_basic_attack_input() -> void:
	pending_basic_attack = true

func _on_projectile_input(direction: Vector2, power: float) -> void:
	var dir := direction if direction.length() > 0.1 else input_facing_dir
	ability_projectile.activate(dir, power)

func _on_area_attack_input(direction: Vector2, power: float) -> void:
	# direction = Vector2.ZERO means "fire at self" — AreaAttackAbility handles it natively
	# (offset stays Vector2.ZERO), so do NOT fall back to input_facing_dir here.
	ability_area.activate(direction, power)

func _on_charge_input(direction: Vector2, power: float) -> void:
	var dir := direction if direction.length() > 0.1 else input_facing_dir
	ability_charge.activate(dir, power)

func _on_charge_started(_dir: Vector2, _speed: float, _dur: float) -> void:
	pending_charge = true

# ── Health callbacks ──────────────────────────────────────────
func _on_health_changed(current: float, max_hp: float) -> void:
	EventBus.player_health_changed.emit(current, max_hp)

func _on_died() -> void:
	EventBus.player_died.emit()
	set_process(false)
	set_physics_process(false)

# ── Draw (simple circle placeholder) ─────────────────────────
func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color(0.2, 0.6, 1.0))
	# Facing indicator
	draw_line(Vector2.ZERO, input_facing_dir * 22.0, Color(1, 1, 1), 3.0)
