class_name CancelButton
extends Control
## MODE 2 – Tap-to-cancel button.
## Appears on the left side when an ability is being aimed. The player
## taps it with the other thumb while holding the ability joystick to
## cancel without firing.
## Supports multi-touch: detects any new touch index, not just index 0.

const RADIUS   := 36.0
const COLOR_BG := Color(0.75, 0.08, 0.08, 0.82)
const COLOR_X  := Color(1.0,  1.0,  1.0,  0.95)

var _hovered: bool = false

func _ready() -> void:
	visible = false
	EventBus.ability_aim_updated.connect(_on_aim_updated)
	EventBus.ability_aim_cleared.connect(_hide)
	EventBus.ability_aim_cancelled.connect(_hide)

func _on_aim_updated(_type: String, _dir: Vector2, _power: float) -> void:
	if not visible:
		visible = true
		queue_redraw()

func _hide() -> void:
	visible = false
	_hovered = false
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = get_global_rect().has_point(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		pressed = get_global_rect().has_point(event.position)

	if pressed:
		EventBus.ability_aim_cancelled.emit()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var c := size / 2.0
	var col := COLOR_BG.lightened(0.15) if _hovered else COLOR_BG
	draw_circle(c, RADIUS, col)
	draw_arc(c, RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 2.0)
	var arm := RADIUS * 0.45
	draw_line(c + Vector2(-arm, -arm), c + Vector2(arm,  arm), COLOR_X, 4.0, true)
	draw_line(c + Vector2( arm, -arm), c + Vector2(-arm, arm), COLOR_X, 4.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-12, 22), "CANCEL",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))
