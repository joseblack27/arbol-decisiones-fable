class_name AbilityButton
extends Control
## Simple tap button for Basic Attack.
## On press, emits EventBus.ability_input_basic_attack.

@export var button_radius: float = 36.0
@export var label_text: String = "ATK"
@export var idle_color: Color   = Color(1.0, 0.4, 0.2, 0.75)
@export var press_color: Color  = Color(1.0, 0.7, 0.5, 0.95)

var _pressed: bool = false
var _touch_index: int = -1
var _cooldown_ratio: float = 0.0

func _ready() -> void:
	EventBus.ability_cooldown_started.connect(_on_cooldown_started)
	EventBus.ability_cooldown_ended.connect(_on_cooldown_ended)

func _on_cooldown_started(_entity: Node, atype: String, duration: float) -> void:
	if atype == "basic_attack":
		_cooldown_ratio = 1.0
		var tween := create_tween()
		tween.tween_method(_set_cooldown_ratio, 1.0, 0.0, duration)

func _on_cooldown_ended(_entity: Node, atype: String) -> void:
	if atype == "basic_attack":
		_cooldown_ratio = 0.0
		queue_redraw()

func _set_cooldown_ratio(v: float) -> void:
	_cooldown_ratio = v
	queue_redraw()

# ── Input ─────────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and _cooldown_ratio <= 0.0:
			_touch_index = event.index
			_pressed = true
			EventBus.ability_input_basic_attack.emit()
			queue_redraw()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_pressed = false
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _cooldown_ratio <= 0.0:
			_pressed = true
			EventBus.ability_input_basic_attack.emit()
			queue_redraw()
		else:
			_pressed = false
			queue_redraw()

# ── Drawing ───────────────────────────────────────────────────
func _draw() -> void:
	var center := size / 2.0
	var color := press_color if _pressed else idle_color
	draw_circle(center, button_radius, color)
	draw_arc(center, button_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0)
	if _cooldown_ratio > 0.0:
		draw_arc(center, button_radius - 4.0, -PI / 2.0,
			-PI / 2.0 + TAU * _cooldown_ratio, 48, Color(0, 0, 0, 0.6), 8.0)
	var font := ThemeDB.fallback_font
	var font_size := 14
	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center - text_size / 2.0 + Vector2(0, text_size.y / 2.0),
		label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 0.95))
