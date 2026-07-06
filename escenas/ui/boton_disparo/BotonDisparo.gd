extends Control
class_name BotonDisparo
## Botón táctil que emite "boton_disparo" via SeñalManager al presionar.
## Sigue el mismo patrón que el Joystick: ComponenteToque maneja el input
## táctil y _gui_input cubre clics de ratón en escritorio.

@export var radio: float             = 40.0
@export var texto: String            = "DISP"
@export var color_reposo: Color      = Color(0.2, 0.5, 1.0, 0.75)
@export var color_presionado: Color  = Color(0.5, 0.8, 1.0, 0.95)

var _presionado: bool   = false
var _signal_id: String  = ""


func _ready() -> void:
	_signal_id = str(get_instance_id())
	# Registrar la señal global que escuchará el jugador.
	SeñalManager.registrar("boton_disparo", _signal_id, {})
	# Conectar a los eventos de toque que emite el ComponenteToque hijo.
	SeñalManager.conectar(str("touch_iniciado_",   get_instance_id()), self, "_on_touch_iniciado")
	SeñalManager.conectar(str("touch_finalizado_", get_instance_id()), self, "_on_touch_finalizado")


# ── Entrada táctil (via ComponenteToque) ─────────────────────────────────────

func _on_touch_iniciado(_index: int, _posicion: Vector2) -> void:
	_presionado = true
	SeñalManager.emitir("boton_disparo", _signal_id, [])
	queue_redraw()


func _on_touch_finalizado(_index: int, _posicion: Vector2) -> void:
	_presionado = false
	queue_redraw()


# ── Entrada de ratón (escritorio) ─────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_presionado = true
			SeñalManager.emitir("boton_disparo", _signal_id, [])
			queue_redraw()
		else:
			_presionado = false
			queue_redraw()


# ── Visual ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var centro := size / 2.0
	var color  := color_presionado if _presionado else color_reposo
	# Fondo circular
	draw_circle(centro, radio, color)
	# Borde
	draw_arc(centro, radio, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.4), 2.0)
	# Etiqueta centrada
	var fuente    := ThemeDB.fallback_font
	var tam_fuente := 14
	var tam_texto := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_CENTER, -1, tam_fuente)
	draw_string(fuente,
		centro - tam_texto / 2.0 + Vector2(0.0, tam_texto.y / 2.0),
		texto, HORIZONTAL_ALIGNMENT_CENTER, -1, tam_fuente, Color(1.0, 1.0, 1.0, 0.9))
