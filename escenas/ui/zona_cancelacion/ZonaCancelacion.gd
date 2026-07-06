extends Control
class_name ZonaCancelacion
## Zona de cancelación de habilidades (port de CancelZone).
## Aparece cuando el jugador está apuntando. Si el dedo/ratón se suelta
## sobre esta zona, la habilidad se cancela en lugar de dispararse.
##
## JoystickDisparo lee ZonaCancelacion.rect_activo (static) al soltar.
## No hay acoplamiento directo: el joystick solo lee el rect.

## Rect en espacio de viewport mientras la zona es visible. Rect2() cuando oculta.
static var rect_activo: Rect2 = Rect2()

const RADIO    := 38.0
const COLOR_BG := Color(0.80, 0.10, 0.10, 0.75)
const COLOR_X  := Color(1.00, 1.00, 1.00, 0.95)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# Slots 0-3 (UIHabilidad por slot)
	SeñalManager.conectar("slot_0_apunte",   self, "_on_apunte")
	SeñalManager.conectar("slot_0_cancelar", self, "_ocultar")
	SeñalManager.conectar("slot_0_lanzar",   self, "_on_lanzar")
	SeñalManager.conectar("slot_1_apunte",   self, "_on_apunte")
	SeñalManager.conectar("slot_1_cancelar", self, "_ocultar")
	SeñalManager.conectar("slot_1_lanzar",   self, "_on_lanzar")
	SeñalManager.conectar("slot_2_apunte",   self, "_on_apunte")
	SeñalManager.conectar("slot_2_cancelar", self, "_ocultar")
	SeñalManager.conectar("slot_2_lanzar",   self, "_on_lanzar")
	SeñalManager.conectar("slot_3_apunte",   self, "_on_apunte")
	SeñalManager.conectar("slot_3_cancelar", self, "_ocultar")
	SeñalManager.conectar("slot_3_lanzar",   self, "_on_lanzar")


func _on_apunte(_dir: Vector2, _poder: float) -> void:
	if not visible:
		visible = true
		queue_redraw()


func _ocultar() -> void:
	visible    = false
	rect_activo = Rect2()


func _on_lanzar(_dir: Vector2, _poder: float) -> void:
	_ocultar()


func _process(_delta: float) -> void:
	if visible:
		rect_activo = get_global_rect()


func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, RADIO, COLOR_BG)
	draw_arc(c, RADIO, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 2.0)
	# X
	var brazo := RADIO * 0.45
	draw_line(c + Vector2(-brazo, -brazo), c + Vector2( brazo,  brazo), COLOR_X, 4.0, true)
	draw_line(c + Vector2( brazo, -brazo), c + Vector2(-brazo,  brazo), COLOR_X, 4.0, true)
	# Etiqueta
	var fuente := ThemeDB.fallback_font
	draw_string(fuente, c + Vector2(-20, 26), "CANCELAR",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))
