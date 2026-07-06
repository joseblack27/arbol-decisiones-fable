extends Control
class_name JoystickDisparo
## Joystick direccional para disparar proyectiles.
##
## Uso:
##   - Presionar + arrastrar → previsualiza la dirección de disparo.
##   - Soltar con drag activo → lanza el proyectil en esa dirección.
##   - Soltar sin arrastrar (tap) → cancela.
##
## Señales emitidas via SeñalManager:
##   "disparo_apunte"   (direccion: Vector2, poder: float) — mientras se arrastra.
##   "disparo_lanzar"   (direccion: Vector2, poder: float) — al soltar con dirección.
##   "disparo_cancelar" ()                                 — al soltar sin dirección.
##
## Usa _input() global para que el rastreo de arrastre funcione fuera
## de los límites del control.

@export_group("Tamaños")
@export var radio_boton: float    = 36.0
## Radio máximo de arrastre del joystick.
@export var radio_joystick: float = 80.0

@export_group("Apariencia")
@export var texto: String         = "DISP"
@export var color_reposo: Color   = Color(0.2, 0.5, 1.0, 0.70)
@export var color_activo: Color   = Color(0.5, 0.8, 1.0, 0.90)
@export var color_dir: Color      = Color(1.0, 1.0, 0.4, 0.90)

# ── Estado interno ────────────────────────────────────────────────────────────
var _touch_index: int       = -1
var _drag_offset: Vector2   = Vector2.ZERO
var _activo: bool           = false
var _signal_id: String      = ""
var _ultima_pos_vp: Vector2 = Vector2.ZERO  # posición de viewport al soltar


func _get_centro() -> Vector2:
	return size / 2.0


func _ready() -> void:
	_signal_id = str(get_instance_id())
	# Registrar las tres señales que escuchará el jugador.
	SeñalManager.registrar("disparo_apunte",   _signal_id, {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	SeñalManager.registrar("disparo_lanzar",   _signal_id, {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	SeñalManager.registrar("disparo_cancelar", _signal_id, {})


# ── Input global — el drag funciona aunque salga del control ──────────────────

func _input(event: InputEvent) -> void:
	# ── Ratón (escritorio) ────────────────────────────────────────────────────
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_iniciar(0)
				get_viewport().set_input_as_handled()
		elif _touch_index == 0:
			_ultima_pos_vp = event.position
			_soltar()

	elif event is InputEventMouseMotion and _touch_index == 0:
		_drag_offset = (get_local_mouse_position() - _get_centro()).limit_length(radio_joystick)
		_emitir_apunte()
		queue_redraw()

	# ── Táctil ────────────────────────────────────────────────────────────────
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_iniciar(event.index)
				get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_ultima_pos_vp = event.position
			_soltar()

	elif event is InputEventScreenDrag and event.index == _touch_index:
		var local = event.position - get_global_rect().position - _get_centro()
		_drag_offset = local.limit_length(radio_joystick)
		_emitir_apunte()
		queue_redraw()


# ── Lógica interna ────────────────────────────────────────────────────────────

func _iniciar(indice: int) -> void:
	_touch_index = indice
	_activo      = true
	_drag_offset = Vector2.ZERO
	_emitir_apunte()
	queue_redraw()


func _soltar() -> void:
	if not _activo:
		return
	_activo      = false
	_touch_index = -1

	# Drag-to-cancel: si el dedo/ratón cayó dentro de la ZonaCancelacion
	if ZonaCancelacion.rect_activo != Rect2() \
			and ZonaCancelacion.rect_activo.has_point(_ultima_pos_vp):
		_drag_offset = Vector2.ZERO
		SeñalManager.emitir("disparo_cancelar", _signal_id, [])
		queue_redraw()
		return

	var direccion := _drag_offset.normalized() if _drag_offset.length() > 5.0 else Vector2.ZERO
	var poder     := _drag_offset.length() / radio_joystick

	if direccion != Vector2.ZERO:
		SeñalManager.emitir("disparo_lanzar", _signal_id, [direccion, poder])
	else:
		SeñalManager.emitir("disparo_cancelar", _signal_id, [])

	_drag_offset = Vector2.ZERO
	queue_redraw()


func _emitir_apunte() -> void:
	var direccion := _drag_offset.normalized() if _drag_offset.length() > 5.0 else Vector2.ZERO
	var poder     := _drag_offset.length() / radio_joystick
	SeñalManager.emitir("disparo_apunte", _signal_id, [direccion, poder])


# ── Dibujo ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var c     := _get_centro()
	var color := color_activo if _activo else color_reposo

	# Fondo circular del botón
	draw_circle(c, radio_boton, color)
	draw_arc(c, radio_boton, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0)

	# Indicador de dirección mientras se arrastra
	if _activo and _drag_offset.length() > 5.0:
		var tip := c + _drag_offset
		draw_line(c, tip, color_dir, 3.0)
		draw_circle(tip, 8.0, color_dir)

	# Etiqueta
	var fuente     := ThemeDB.fallback_font
	var tam_fuente := 18
	var tam_texto  := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_CENTER, -1, tam_fuente)
	draw_string(fuente, c - tam_texto / 2.0 + Vector2(0.0, tam_texto.y / 2.0),
		texto, HORIZONTAL_ALIGNMENT_CENTER, -1, tam_fuente, Color(1.0, 1.0, 1.0, 0.9))
