class_name AimIndicator
extends Node2D
## World-space aim preview rendered as child of Player.
## All range/radius values are read directly from the ability nodes,
## so changing an ability export automatically updates the indicator.

# ── Ability references (cached in _ready) ─────────────────────
var _proj_ab:   ProjectileAbility  = null
var _area_ab:   AreaAttackAbility  = null
var _charge_ab: ChargeAbility      = null
var _movement:  MovementComponent  = null

# ── Current aim state ─────────────────────────────────────────
var _active: bool    = false
var _type:   String  = ""
var _dir:    Vector2 = Vector2.ZERO
var _power:  float   = 0.0

func _ready() -> void:
	EventBus.ability_aim_updated.connect(_on_aim_updated)
	EventBus.ability_aim_cleared.connect(_on_aim_cleared)
	_cache_abilities()

func _cache_abilities() -> void:
	var player := get_parent()
	var ac     := player.get_node("AbilityContainer")
	_proj_ab   = ac.get_node("ProjectileAbility")  as ProjectileAbility
	_area_ab   = ac.get_node("AreaAttackAbility")   as AreaAttackAbility
	_charge_ab = ac.get_node("ChargeAbility")       as ChargeAbility
	_movement  = player.get_node("MovementComponent") as MovementComponent

# ── Helpers: read live ability values ─────────────────────────
func _proj_max_range() -> float:
	return _proj_ab.max_range if _proj_ab else 400.0

func _area_max_offset() -> float:
	return _area_ab.max_offset if _area_ab else 120.0

func _area_radius() -> float:
	return _area_ab.area_radius if _area_ab else 80.0

func _charge_distance() -> float:
	## distance = speed_multiplier × player_max_speed × charge_duration
	if _charge_ab and _movement:
		return _charge_ab.charge_speed_multiplier * _movement.max_speed * _charge_ab.charge_duration
	return 280.0

func _charge_half_w() -> float:
	return _charge_ab.preview_half_width if _charge_ab else 20.0

# ── Signal handlers ───────────────────────────────────────────
func _on_aim_updated(ability_type: String, direction: Vector2, power: float) -> void:
	_active = true
	_type   = ability_type
	_dir    = direction
	_power  = power
	queue_redraw()

func _on_aim_cleared() -> void:
	_active = false
	queue_redraw()

# ── Entry point ───────────────────────────────────────────────
func _draw() -> void:
	if not _active:
		return
	match _type:
		"projectile":  _draw_projectile()
		"area_attack": _draw_area()
		"charge":      _draw_charge()

# ── Projectile ────────────────────────────────────────────────
func _draw_projectile() -> void:
	var max_range := _proj_max_range()
	var c := Color(0.95, 0.55, 0.1, 1.0)

	# Max-range boundary ring
	draw_arc(Vector2.ZERO, max_range, 0.0, TAU, 64,
		Color(c.r, c.g, c.b, 0.18), 1.5)

	if _dir.length() < 0.05:
		return

	var end    := _dir * max_range
	var perp   := Vector2(-_dir.y, _dir.x)
	var hw     := 10.0  # half-width of projectile body

	# Rectangle path
	var corners := PackedVector2Array([
		perp * hw, end + perp * hw, end - perp * hw, -perp * hw
	])
	draw_colored_polygon(corners, Color(c.r, c.g, c.b, 0.18))
	draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]),
		Color(c.r, c.g, c.b, 0.75), 2.0)

	# Tip dot + arrowhead
	draw_circle(end, 9.0, c)
	draw_line(end, end - _dir * 18.0 + perp * 12.0, c, 2.5)
	draw_line(end, end - _dir * 18.0 - perp * 12.0, c, 2.5)
	draw_circle(Vector2.ZERO, 5.0, Color(c.r, c.g, c.b, 0.7))

# ── Area Attack ───────────────────────────────────────────────
func _draw_area() -> void:
	var max_offset := _area_max_offset()
	var radius     := _area_radius()
	var c := Color(0.85, 0.2, 0.85, 1.0)

	# Max-offset boundary ring
	draw_arc(Vector2.ZERO, max_offset, 0.0, TAU, 64,
		Color(c.r, c.g, c.b, 0.18), 1.5)

	if _dir.length() < 0.05:
		# Neutral: AOE circle at player
		draw_circle(Vector2.ZERO, radius, Color(c.r, c.g, c.b, 0.12))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, c, 2.5)
		return

	var offset := _dir * max_offset * clampf(_power, 0.15, 1.0)

	draw_dashed_line(Vector2.ZERO, offset, Color(c.r, c.g, c.b, 0.55), 2.0, 10.0)

	# Fixed-radius AoE circle at landing position
	draw_circle(offset, radius, Color(c.r, c.g, c.b, 0.15))
	draw_arc(offset, radius, 0.0, TAU, 48, c, 2.5)

	var cs := 9.0
	draw_line(offset - Vector2(cs, 0), offset + Vector2(cs, 0), c, 2.0)
	draw_line(offset - Vector2(0, cs), offset + Vector2(0, cs), c, 2.0)

# ── Charge ────────────────────────────────────────────────────
func _draw_charge() -> void:
	var distance := _charge_distance()
	var hw       := _charge_half_w()
	var c := Color(0.95, 0.72, 0.1, 1.0)

	# Max-distance boundary ring
	draw_arc(Vector2.ZERO, distance, 0.0, TAU, 64,
		Color(c.r, c.g, c.b, 0.18), 1.5)

	if _dir.length() < 0.05:
		return

	var end    := _dir * distance
	var perp   := Vector2(-_dir.y, _dir.x)

	# Rectangle path (player-body wide)
	var corners := PackedVector2Array([
		perp * hw, end + perp * hw, end - perp * hw, -perp * hw
	])
	draw_colored_polygon(corners, Color(c.r, c.g, c.b, 0.2))
	draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]),
		Color(c.r, c.g, c.b, 0.8), 2.5)

	# Arrowhead
	draw_line(end, end - _dir * 22.0 + perp * 15.0, c, 3.5)
	draw_line(end, end - _dir * 22.0 - perp * 15.0, c, 3.5)
	draw_line(end - _dir * 22.0 + perp * 15.0,
		end - _dir * 22.0 - perp * 15.0, c, 3.5)

	# Player hitbox ring at origin
	draw_arc(Vector2.ZERO, hw, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.6), 2.0)
