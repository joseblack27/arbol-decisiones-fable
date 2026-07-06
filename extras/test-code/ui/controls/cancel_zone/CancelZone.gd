class_name CancelZone
extends Control
## MODE 1 – Drag-to-cancel zone.
## Appears when an ability is being aimed. If the player releases the
## ability joystick while the finger/mouse is over this zone the ability
## is cancelled instead of fired.
##
## AbilityJoystick reads CancelZone.active_rect (static) on release to
## decide whether to cancel. No coupling beyond that static field.

## Viewport-space rect of this zone while visible. Reset to Rect2() when hidden.
static var active_rect: Rect2 = Rect2()

const RADIUS   := 38.0
const COLOR_BG := Color(0.8, 0.1, 0.1, 0.75)
const COLOR_X  := Color(1.0, 1.0, 1.0, 0.95)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	active_rect = Rect2()

func _process(_delta: float) -> void:
	if visible:
		# Keep the static rect up-to-date every frame (layout may shift).
		active_rect = get_global_rect()

func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, RADIUS, COLOR_BG)
	draw_arc(c, RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 2.0)
	# X mark
	var arm := RADIUS * 0.45
	draw_line(c + Vector2(-arm, -arm), c + Vector2(arm,  arm), COLOR_X, 4.0, true)
	draw_line(c + Vector2( arm, -arm), c + Vector2(-arm, arm), COLOR_X, 4.0, true)
	# Label
	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-16, 22), "CANCEL",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))
