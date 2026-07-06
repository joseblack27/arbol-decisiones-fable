class_name VirtualJoystick
extends Control
## Movement joystick. Uses _input() so drag works outside control bounds.

@export var joystick_radius: float = 70.0
@export var knob_radius: float = 28.0
@export var base_color: Color = Color(1, 1, 1, 0.15)
@export var knob_color: Color = Color(1, 1, 1, 0.45)
@export var dead_zone: float = 0.12

var _touch_index: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _output: Vector2 = Vector2.ZERO

func _get_center() -> Vector2:
	return size / 2.0

# ── Input ─────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_touch_index = 0
				_set_drag(get_local_mouse_position())
				get_viewport().set_input_as_handled()
		else:
			if _touch_index == 0:
				_release()

	elif event is InputEventMouseMotion and _touch_index == 0:
		_set_drag(get_local_mouse_position())

	elif event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_touch_index = event.index
				var local = event.position - get_global_rect().position
				_set_drag(local)
				get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_release()

	elif event is InputEventScreenDrag and event.index == _touch_index:
		var local = event.position - get_global_rect().position
		_set_drag(local)

# ── Logic ─────────────────────────────────────────────────────
func _set_drag(local_pos: Vector2) -> void:
	var delta := local_pos - _get_center()
	_drag_offset = delta.limit_length(joystick_radius)
	var magnitude := _drag_offset.length() / joystick_radius
	if magnitude > dead_zone:
		_output = _drag_offset.normalized() * ((magnitude - dead_zone) / (1.0 - dead_zone))
	else:
		_output = Vector2.ZERO
	EventBus.movement_input_changed.emit(_output)
	queue_redraw()

func _release() -> void:
	_touch_index = -1
	_drag_offset = Vector2.ZERO
	_output = Vector2.ZERO
	EventBus.movement_input_changed.emit(Vector2.ZERO)
	queue_redraw()

# ── Drawing ───────────────────────────────────────────────────
func _draw() -> void:
	var c := _get_center()
	draw_circle(c, joystick_radius, base_color)
	draw_arc(c, joystick_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.3), 2.0)
	draw_circle(c + _drag_offset, knob_radius, knob_color)
