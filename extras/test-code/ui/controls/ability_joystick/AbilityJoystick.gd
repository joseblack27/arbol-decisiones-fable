class_name AbilityJoystick
extends Control
## Directional joystick for abilities (Projectile, AreaAttack, Charge).
## Press + drag to aim, release to fire.
## Uses _input() so drag tracking works even outside the control bounds.

enum AbilityType { PROJECTILE, AREA_ATTACK, CHARGE }

@export var ability_type: AbilityType = AbilityType.PROJECTILE
@export var button_radius: float = 36.0
@export var joystick_radius: float = 80.0
@export var label_text: String = "Q"

@export var idle_color: Color   = Color(0.2, 0.5, 1.0, 0.7)
@export var active_color: Color = Color(0.5, 0.8, 1.0, 0.9)
@export var dir_color: Color    = Color(1.0, 1.0, 0.4, 0.9)

var _touch_index: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _is_active: bool = false
var _cooldown_ratio: float = 0.0
var _last_release_vp_pos: Vector2 = Vector2.ZERO  # viewport-space release position

func _get_center() -> Vector2:
	return size / 2.0

func _ready() -> void:
	EventBus.ability_cooldown_started.connect(_on_cooldown_started)
	EventBus.ability_cooldown_ended.connect(_on_cooldown_ended)
	EventBus.ability_aim_cancelled.connect(_on_external_cancel)

# ── Cooldown ──────────────────────────────────────────────────
func _on_cooldown_started(_entity: Node, atype: String, duration: float) -> void:
	if atype == _get_ability_type_string():
		_cooldown_ratio = 1.0
		create_tween().tween_method(_set_cooldown_ratio, 1.0, 0.0, duration)

func _on_cooldown_ended(_entity: Node, atype: String) -> void:
	if atype == _get_ability_type_string():
		_cooldown_ratio = 0.0
		queue_redraw()

func _set_cooldown_ratio(v: float) -> void:
	_cooldown_ratio = v
	queue_redraw()

func _get_ability_type_string() -> String:
	match ability_type:
		AbilityType.PROJECTILE:  return "projectile"
		AbilityType.AREA_ATTACK: return "area_attack"
		AbilityType.CHARGE:      return "charge"
	return ""

# ── Input – handled globally so drag works outside bounds ─────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _touch_index == -1 and _cooldown_ratio <= 0.0:
				if get_global_rect().has_point(event.position):
					_touch_index = 0
					_is_active = true
					_drag_offset = Vector2.ZERO
					_emit_aim_preview()
					queue_redraw()
					get_viewport().set_input_as_handled()
		else:
			if _touch_index == 0:
				_last_release_vp_pos = event.position
				_release()

	elif event is InputEventMouseMotion and _touch_index == 0:
		_drag_offset = (get_local_mouse_position() - _get_center()).limit_length(joystick_radius)
		_emit_aim_preview()
		queue_redraw()

	elif event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and _cooldown_ratio <= 0.0:
				if get_global_rect().has_point(event.position):
					_touch_index = event.index
					_is_active = true
					_drag_offset = Vector2.ZERO
					_emit_aim_preview()
					queue_redraw()
					get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_last_release_vp_pos = event.position
			_release()

	elif event is InputEventScreenDrag and event.index == _touch_index:
		var local = event.position - get_global_rect().position
		_drag_offset = (local - _get_center()).limit_length(joystick_radius)
		_emit_aim_preview()
		queue_redraw()

func _release() -> void:
	if not _is_active:
		return
	_is_active = false
	_touch_index = -1

	# Mode 1: cancel if released inside the drag-to-cancel zone.
	if CancelZone.active_rect != Rect2() and CancelZone.active_rect.has_point(_last_release_vp_pos):
		_drag_offset = Vector2.ZERO
		EventBus.ability_aim_cleared.emit()
		queue_redraw()
		return

	var direction := _drag_offset.normalized() if _drag_offset.length() > 5.0 else Vector2.ZERO
	var power     := _drag_offset.length() / joystick_radius
	_emit_ability(direction, power)
	_drag_offset = Vector2.ZERO
	EventBus.ability_aim_cleared.emit()
	queue_redraw()

## Mode 2: external cancel (CancelButton pressed while this joystick was active).
func _on_external_cancel() -> void:
	if not _is_active:
		return
	_is_active = false
	_touch_index = -1
	_drag_offset = Vector2.ZERO
	EventBus.ability_aim_cleared.emit()
	queue_redraw()

func _emit_aim_preview() -> void:
	if _drag_offset.length() > 5.0:
		EventBus.ability_aim_updated.emit(
			_get_ability_type_string(),
			_drag_offset.normalized(),
			_drag_offset.length() / joystick_radius
		)
	else:
		# No drag yet – emit with zero direction so indicator shows a neutral ring
		EventBus.ability_aim_updated.emit(_get_ability_type_string(), Vector2.ZERO, 0.5)

func _emit_ability(direction: Vector2, power: float) -> void:
	match ability_type:
		AbilityType.PROJECTILE:
			EventBus.ability_input_projectile.emit(direction, power)
		AbilityType.AREA_ATTACK:
			EventBus.ability_input_area_attack.emit(direction, power)
		AbilityType.CHARGE:
			EventBus.ability_input_charge.emit(direction, power)

# ── Drawing ───────────────────────────────────────────────────
func _draw() -> void:
	var c := _get_center()
	var color := active_color if _is_active else idle_color

	draw_circle(c, button_radius, color)
	draw_arc(c, button_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0)

	if _cooldown_ratio > 0.0:
		draw_arc(c, button_radius - 4.0, -PI / 2.0,
			-PI / 2.0 + TAU * _cooldown_ratio, 48, Color(0, 0, 0, 0.6), 8.0)

	if _is_active and _drag_offset.length() > 5.0:
		var tip := c + _drag_offset
		draw_line(c, tip, dir_color, 3.0)
		draw_circle(tip, 8.0, dir_color)

	var font := ThemeDB.fallback_font
	var fsz  := 18
	var tsz  := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz)
	draw_string(font, c - tsz / 2.0 + Vector2(0, tsz.y / 2.0),
		label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz, Color(1, 1, 1, 0.9))
