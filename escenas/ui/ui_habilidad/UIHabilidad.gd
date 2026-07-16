extends Control
class_name UIHabilidad
## Control de habilidad unificado.
## Se adapta automáticamente a modo joystick (direccional) o modo botón (tap)
## según habilidad.requiere_direccion de la habilidad equipada en el slot.
##
## Solo hay que configurar tipo_habilidad en el Inspector para que coincida
## con el tipo_habilidad de la habilidad equipada.
##
## PRESENTACIÓN CON NODOS: el círculo del botón, el punto de dirección y los
## overlays son sprites/etiquetas hijos (ver UIHabilidad.tscn), no _draw().
## Única excepción: el "pastel" de recarga (PieCooldown, un arco progresivo).

@export_group("Habilidad")
## Índice del slot que controla este botón (0-3).
@export var slot_index: int = 0

@export_group("Tamaños")
@export var radio_boton: float    = 40.0
@export var radio_joystick: float = 80.0

@export_group("Apariencia")
@export var texto: String        = ""
@export var color_reposo: Color  = Color(0.60, 0.20, 0.80, 0.70)
@export var color_activo: Color  = Color(0.80, 0.50, 1.00, 0.90)
@export var color_dir: Color     = Color(1.00, 1.00, 0.40, 0.90)

# ── Nodos de presentación ─────────────────────────────────────────────────────
@onready var _base: Sprite2D = $Base
@onready var _linea_direccion: Line2D = $LineaDireccion
@onready var _punto_direccion: Sprite2D = $PuntoDireccion
@onready var _icono: Sprite2D = $Icono
@onready var _etiqueta_texto: Label = $EtiquetaTexto
@onready var _overlay_sin_energia: Sprite2D = $OverlaySinEnergia
@onready var _etiqueta_sin_energia: Label = $EtiquetaSinEnergia
@onready var _pie_cooldown: PieCooldown = $PieCooldown
@onready var _etiqueta_cooldown: Label = $EtiquetaCooldown

## Diámetro del punto que marca la dirección del apunte (antes círculo de r=8).
const DIAMETRO_PUNTO_DIRECCION := 16.0

# ── Modo ──────────────────────────────────────────────────────────────────────
## true = joystick con dirección, false = botón tap.
## Se determina desde habilidad.requiere_direccion al conectar el slot.
var _modo_joystick: bool = false

# ── Estado joystick ───────────────────────────────────────────────────────────
var _touch_index: int               = -1
var _drag_offset: Vector2           = Vector2.ZERO
var _press_local_from_center: Vector2 = Vector2.ZERO  # Press inicial relativo al centro del control
var _activo: bool                   = false
var _ultima_pos_vp: Vector2         = Vector2.ZERO

# ── Estado botón ──────────────────────────────────────────────────────────────
var _presionado: bool = false

# ── Señales ───────────────────────────────────────────────────────────────────
var _signal_id: String    = ""
var _sig_apunte: String   = ""
var _sig_lanzar: String   = ""
var _sig_cancelar: String = ""
var _sig_activar: String  = ""

# ── Cooldown ─────────────────────────────────────────────────────────────────
var _cd_ratio: float    = 0.0
var _cd_duracion: float = 0.0
var _cd_restante: float = 0.0

# ── Energía / slot ────────────────────────────────────────────────────────────
var _sin_energia: bool                 = false
var _slot_habilidades: SlotHabilidades = null


func _get_centro() -> Vector2:
	return size / 2.0


func _toque_en_boton(pos_global: Vector2) -> bool:
	var centro_global := get_global_rect().position + _get_centro()
	return pos_global.distance_to(centro_global) <= radio_boton


func _ready() -> void:
	_signal_id    = str(get_instance_id())
	_sig_apunte   = "slot_%d_apunte"   % slot_index
	_sig_lanzar   = "slot_%d_lanzar"   % slot_index
	_sig_cancelar = "slot_%d_cancelar" % slot_index
	_sig_activar  = "slot_%d_activar"  % slot_index

	# Registrar todas las señales posibles desde _ready() para que
	# IndicadorApunte (que conecta en su propio _ready()) las encuentre.
	SeñalManager.registrar(_sig_apunte,   _signal_id, {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	SeñalManager.registrar(_sig_lanzar,   _signal_id, {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	SeñalManager.registrar(_sig_cancelar, _signal_id, {})
	SeñalManager.registrar(_sig_activar,  _signal_id, {})

	BusEventos.recarga_iniciada.connect(_on_recarga_iniciada)
	BusEventos.recarga_terminada.connect(_on_recarga_terminada)
	BusEventos.energia_cambiada.connect(_on_energia_cambiada)

	resized.connect(_disponer_nodos)
	_linea_direccion.default_color = color_dir
	_punto_direccion.modulate = color_dir
	_disponer_nodos()
	_refrescar_visual()

	# Deferred: SlotHabilidades aún no está en el grupo cuando _ready() corre aquí.
	call_deferred("_conectar_slot")


# ── Slot ──────────────────────────────────────────────────────────────────────

## En red, el jugador propio recién existe cuando la conexión termina de
## resolverse (puede tardar varios fotogramas) — un solo intento diferido
## podía correr ANTES de que apareciera, dejando el botón sin habilidad
## para siempre. Reintenta hasta encontrarlo (o rendirse tras ~5s).
func _conectar_slot(intentos: int = 0) -> void:
	_slot_habilidades = Utils.slot_habilidades_local()
	if _slot_habilidades:
		_slot_habilidades.slot_cambiado.connect(_on_slot_cambiado)
		_actualizar_desde_habilidad()
		return
	if intentos > 300:
		return
	get_tree().create_timer(1.0 / 60.0).timeout.connect(_conectar_slot.bind(intentos + 1))


func _actualizar_desde_habilidad() -> void:
	var hab := _get_habilidad()
	if hab:
		_modo_joystick = hab.requiere_direccion
		texto = ""  # El icono reemplaza el texto
	else:
		_modo_joystick = false
		texto = ""
	_actualizar_icono()
	_refrescar_visual()


func _on_slot_cambiado(index: int, _hab: HabilidadBase) -> void:
	if index != slot_index:
		return
	_actualizar_desde_habilidad()
	_cd_ratio    = 0.0
	_cd_restante = 0.0
	_refrescar_visual()


func _get_habilidad() -> HabilidadBase:
	if _slot_habilidades:
		return _slot_habilidades.obtener(slot_index)
	return null


## Registra por adelantado las señales de otros slots que este botón físico
## va a representar más adelante (ver PaginadorHabilidades, que llama esto
## para TODAS las páginas apenas arranca) — sin esto, Jugador/IndicadorApunte
## (que escuchan los total_slots completos desde su propio _ready(), no solo
## la página visible) intentaban conectarse a señales que ningún botón había
## registrado todavía porque nadie había visitado esa página, y
## SeñalManager.conectar() falla EN SILENCIO si la señal no existe — sin
## este registro adelantado, cambiar de página y usar esas habilidades
## simplemente no hacía nada (nadie llegó a suscribirse a tiempo).
func registrar_indices_adicionales(indices: Array) -> void:
	for idx in indices:
		if idx == slot_index:
			continue
		var apunte   := "slot_%d_apunte"   % idx
		var lanzar   := "slot_%d_lanzar"   % idx
		var cancelar := "slot_%d_cancelar" % idx
		var activar  := "slot_%d_activar"  % idx
		if SeñalManager.registros.has(apunte):
			continue
		SeñalManager.registrar(apunte,   _signal_id, {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
		SeñalManager.registrar(lanzar,   _signal_id, {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
		SeñalManager.registrar(cancelar, _signal_id, {})
		SeñalManager.registrar(activar,  _signal_id, {})


## Reasigna este botón físico a otro slot_index — usado por
## PaginadorHabilidades al cambiar de página: los mismos 5 botones en
## pantalla pasan a representar los siguientes 5 slots. Desregistra las
## señales del slot viejo y registra (si hace falta) las del nuevo, para
## que Jugador/IndicadorApunte (que ya escuchan TODOS los slot_N posibles,
## ver sus _ready()) reciban las señales correctas sin tener que enterarse
## de que hubo un cambio de página.
func cambiar_slot(nuevo_index: int) -> void:
	if nuevo_index == slot_index:
		return
	# Soltar cualquier joystick/press a medio hacer del slot anterior — si
	# no, cambiar de página con el dedo todavía tocando el botón dejaría un
	# joystick fantasma apuntando a un slot que ya no se muestra.
	if _activo:
		_soltar_joystick()
	_presionado = false

	for sig in [_sig_apunte, _sig_lanzar, _sig_cancelar, _sig_activar]:
		if SeñalManager.registros.has(sig) and SeñalManager.registros[sig].suscriptores.has(self):
			SeñalManager.desconectar(sig, self)

	slot_index    = nuevo_index
	_sig_apunte   = "slot_%d_apunte"   % slot_index
	_sig_lanzar   = "slot_%d_lanzar"   % slot_index
	_sig_cancelar = "slot_%d_cancelar" % slot_index
	_sig_activar  = "slot_%d_activar"  % slot_index

	# registrar() protesta si el nombre ya existe (otra página anterior de
	# este mismo botón ya lo dejó registrado) — normal al volver a una
	# página ya visitada, no hace falta re-registrar.
	if not SeñalManager.registros.has(_sig_apunte):
		SeñalManager.registrar(_sig_apunte,   _signal_id, {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
		SeñalManager.registrar(_sig_lanzar,   _signal_id, {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
		SeñalManager.registrar(_sig_cancelar, _signal_id, {})
		SeñalManager.registrar(_sig_activar,  _signal_id, {})

	_cd_ratio    = 0.0
	_cd_restante = 0.0
	_actualizar_desde_habilidad()
	_actualizar_cooldown_visual()


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Ignorar input mientras el menú de equipamiento esté abierto.
	if get_tree().get_first_node_in_group("menu_abierto") != null:
		return
	# Mouse (escritorio)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _touch_index == -1 and _toque_en_boton(event.position):
				if _sin_energia:
					return
				if _modo_joystick:
					# Guardar la posición de press en espacio local relativo al centro
					_press_local_from_center = get_local_mouse_position() - _get_centro()
					_iniciar_joystick(0)
				else:
					_activar_boton()
				get_viewport().set_input_as_handled()
		else:
			if _modo_joystick and _touch_index == 0:
				_ultima_pos_vp = event.position
				_soltar_joystick()
			elif not _modo_joystick and _presionado:
				_presionado = false
				_refrescar_visual()

	elif event is InputEventMouseMotion and _modo_joystick and _touch_index == 0:
		var actual := get_local_mouse_position() - _get_centro()
		_drag_offset = (actual - _press_local_from_center).limit_length(radio_joystick)
		_emitir_apunte()
		_refrescar_visual()

	# Touch
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and _toque_en_boton(event.position):
				if _sin_energia:
					return
				if _modo_joystick:
					# Posición de press en espacio local relativo al centro
					_press_local_from_center = event.position - get_global_rect().position - _get_centro()
					_iniciar_joystick(event.index)
				else:
					_activar_boton()
				get_viewport().set_input_as_handled()
		else:
			if _modo_joystick and event.index == _touch_index:
				_ultima_pos_vp = event.position
				_soltar_joystick()
			elif not _modo_joystick and _presionado:
				_presionado = false
				_refrescar_visual()

	elif event is InputEventScreenDrag and _modo_joystick and event.index == _touch_index:
		var actual = event.position - get_global_rect().position - _get_centro()
		_drag_offset = (actual - _press_local_from_center).limit_length(radio_joystick)
		_emitir_apunte()
		_refrescar_visual()


# ── Lógica joystick ───────────────────────────────────────────────────────────

func _iniciar_joystick(indice: int) -> void:
	_touch_index = indice
	_activo      = true
	_drag_offset = Vector2.ZERO
	_emitir_apunte()
	_refrescar_visual()


func _soltar_joystick() -> void:
	if not _activo:
		return
	_activo      = false
	_touch_index = -1

	if ZonaCancelacion.rect_activo != Rect2() \
			and ZonaCancelacion.rect_activo.has_point(_ultima_pos_vp):
		_drag_offset = Vector2.ZERO
		SeñalManager.emitir(_sig_cancelar, _signal_id, [])
		_refrescar_visual()
		return

	var direccion := _drag_offset.normalized() if _drag_offset.length() > 5.0 else Vector2.ZERO
	var poder     := _drag_offset.length() / radio_joystick
	SeñalManager.emitir(_sig_lanzar, _signal_id, [direccion, poder])

	_drag_offset = Vector2.ZERO
	_refrescar_visual()


func _emitir_apunte() -> void:
	var direccion := _drag_offset.normalized() if _drag_offset.length() > 0.5 else Vector2.ZERO
	var poder     := _drag_offset.length() / radio_joystick
	SeñalManager.emitir(_sig_apunte, _signal_id, [direccion, poder])


# ── Lógica botón ─────────────────────────────────────────────────────────────

func _activar_boton() -> void:
	_presionado = true
	SeñalManager.emitir(_sig_activar, _signal_id, [])
	_refrescar_visual()


# ── Cooldown ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _cd_restante > 0.0:
		_cd_restante -= delta
		_cd_ratio = clampf(_cd_restante / _cd_duracion, 0.0, 1.0) if _cd_duracion > 0.0 else 0.0
		_actualizar_cooldown_visual()
	# apunte SOLO se emitía en el evento de arrastre (motion) — si el dedo se
	# queda quieto sosteniendo el joystick sin mover el punto, dejaba de
	# avisar. Habilidades de canal continuo (lanzallamas: "mientras
	# mantienes presionado") necesitan un tick por FOTOGRAMA para saber que
	# seguís con el dedo puesto, no solo cuando te movés. Barato: es un
	# Vector2 al bus de señales, y el resto de las habilidades (que solo
	# leen apunte para dibujar el indicador de puntería) ya lo manejan bien
	# sin importar la frecuencia.
	if _modo_joystick and _activo:
		_emitir_apunte()


func _on_recarga_iniciada(entidad: Node, slot_idx: int, duracion: float) -> void:
	if entidad == null or not entidad.is_in_group("jugadores"):
		return
	if slot_idx != slot_index:
		return
	_cd_duracion = duracion
	_cd_restante = duracion
	_cd_ratio    = 1.0
	_actualizar_cooldown_visual()


func _on_recarga_terminada(entidad: Node, slot_idx: int) -> void:
	if entidad == null or not entidad.is_in_group("jugadores"):
		return
	if slot_idx != slot_index:
		return
	_cd_ratio    = 0.0
	_cd_restante = 0.0
	_actualizar_cooldown_visual()


func _on_energia_cambiada(entidad: Node, nueva: float, _maxima: float) -> void:
	if entidad == null or not entidad.is_in_group("jugadores"):
		return
	var hab := _get_habilidad()
	var bloqueado := hab != null and nueva < hab.costo_energia
	if bloqueado != _sin_energia:
		_sin_energia = bloqueado
		_refrescar_visual()


# ── Presentación (nodos) ──────────────────────────────────────────────────────

## Coloca y escala los nodos según radio_boton y el tamaño del control.
func _disponer_nodos() -> void:
	var c := _get_centro()
	_base.position = c
	_escalar_sprite(_base, radio_boton * 2.0)
	_overlay_sin_energia.position = c
	_escalar_sprite(_overlay_sin_energia, radio_boton * 2.0)
	_icono.position = c
	_escalar_sprite(_punto_direccion, DIAMETRO_PUNTO_DIRECCION)
	_pie_cooldown.position = c
	_pie_cooldown.radio = radio_boton
	_centrar_etiqueta(_etiqueta_sin_energia, c)
	_centrar_etiqueta(_etiqueta_cooldown, c)


## Refleja el estado lógico en los nodos (antes era _draw()).
func _refrescar_visual() -> void:
	_base.self_modulate = color_activo if (_activo or _presionado) else color_reposo

	var mostrar_direccion := _modo_joystick and _activo and _drag_offset.length() > 5.0
	_linea_direccion.visible = mostrar_direccion
	_punto_direccion.visible = mostrar_direccion
	if mostrar_direccion:
		var c := _get_centro()
		_linea_direccion.points = PackedVector2Array([c, c + _drag_offset])
		_punto_direccion.position = c + _drag_offset

	_overlay_sin_energia.visible = _sin_energia
	_etiqueta_sin_energia.visible = _sin_energia

	_etiqueta_texto.visible = texto != "" and _icono.texture == null
	if _etiqueta_texto.visible:
		_etiqueta_texto.text = texto
		_centrar_etiqueta(_etiqueta_texto, _get_centro())


func _actualizar_icono() -> void:
	var datos := _slot_habilidades.obtener_datos(slot_index) if _slot_habilidades else null
	if datos and datos.icono:
		_icono.texture = datos.icono
		_icono.modulate = Color(1, 1, 1, 0.9)
		_escalar_sprite(_icono, radio_boton * 1.2)
	else:
		_icono.texture = null


func _actualizar_cooldown_visual() -> void:
	_pie_cooldown.ratio = _cd_ratio
	_etiqueta_cooldown.visible = _cd_ratio > 0.0
	if _etiqueta_cooldown.visible:
		_etiqueta_cooldown.text = "%.1fs" % _cd_restante
		# Centrado real (antes quedaba pegado al borde inferior del botón,
		# desalineado del ícono) — mismo helper que ya centra el resto de
		# las etiquetas de este control.
		_centrar_etiqueta(_etiqueta_cooldown, _get_centro())


## Escala un sprite para que su textura ocupe el diámetro indicado.
func _escalar_sprite(sprite: Sprite2D, diametro: float) -> void:
	if sprite.texture == null:
		return
	var tamano := sprite.texture.get_size()
	if tamano.x > 0.0:
		sprite.scale = Vector2.ONE * (diametro / tamano.x)


func _centrar_etiqueta(etiqueta: Label, centro: Vector2) -> void:
	etiqueta.reset_size()
	etiqueta.position = centro - etiqueta.size / 2.0
