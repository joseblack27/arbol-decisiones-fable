extends Node2D
class_name IndicadorApunte
## Previsualización de trayectoria en espacio de mundo.
## Hijo del Jugador — dibuja en su espacio local, se mueve con él.
## Escucha señales de apunte por slot (slot_0..slot_3) y dibuja según
## el tipo de habilidad equipada en ese slot.

## Color unificado para toda previsualización de apuntado (rango, líneas,
## marcadores) — todas las habilidades usan el mismo tono rojizo.
@export var COLOR_APUNTE := Color(0.85, 0.15, 0.15, 1.0)
## Opacidad del relleno del círculo de rango (la zona grande de apuntado).
@export_range(0.0, 1.0) var opacidad_area_apunte := 0.08
## Color y grosor del borde del círculo de rango.
@export var color_borde_apunte := Color(0.85, 0.15, 0.15, 1.0)
@export var grosor_borde_apunte := 1.5

## La forma que representa DÓNDE pega de verdad la habilidad (el corredor
## del proyectil/carga, el círculo del área de efecto, el rectángulo del
## muro) se rellena siempre igual: rojo puro, bien visible.
@export var COLOR_AREA_GOLPE := Color(1.0, 0.0, 0.0, 0.8)
## Color y grosor del borde de la zona de golpe real.
@export var color_borde_golpe := Color(1.0, 0.0, 0.0, 1.0)
@export var grosor_borde_golpe := 2.0

var _slot_habilidades: SlotHabilidades = null

var _activo: bool      = false
var _tipo:   String    = ""
var _dir:    Vector2   = Vector2.ZERO
var _poder:  float     = 0.0
var _hab:    HabilidadBase = null


func _ready() -> void:
	call_deferred("_conectar")


func _conectar() -> void:
	# Hijo directo de Jugador (ver Jugador.tscn): usa el SlotHabilidades del
	# PROPIO padre, no "el primero del grupo" — con 2+ jugadores en el
	# árbol (red), ese primero podía ser el de otro jugador, dibujando la
	# previsualización de apuntado sobre el personaje equivocado.
	_slot_habilidades = get_parent().get_node_or_null("SlotHabilidades") as SlotHabilidades
	# El servidor dedicado no tiene UI que registre estas señales — solo
	# generan ruido ahí (ver mismo corte en Jugador._ready()).
	if Utils.en_red() and multiplayer.is_server():
		return
	# Señales de los 4 slots (UIHabilidad)
	SeñalManager.conectar("slot_0_apunte",    self, "_on_slot_0_apunte")
	SeñalManager.conectar("slot_0_cancelar",  self, "_on_borrar")
	SeñalManager.conectar("slot_0_lanzar",    self, "_on_borrar_con_args")
	SeñalManager.conectar("slot_1_apunte",    self, "_on_slot_1_apunte")
	SeñalManager.conectar("slot_1_cancelar",  self, "_on_borrar")
	SeñalManager.conectar("slot_1_lanzar",    self, "_on_borrar_con_args")
	SeñalManager.conectar("slot_2_apunte",    self, "_on_slot_2_apunte")
	SeñalManager.conectar("slot_2_cancelar",  self, "_on_borrar")
	SeñalManager.conectar("slot_2_lanzar",    self, "_on_borrar_con_args")
	SeñalManager.conectar("slot_3_apunte",    self, "_on_slot_3_apunte")
	SeñalManager.conectar("slot_3_cancelar",  self, "_on_borrar")
	SeñalManager.conectar("slot_3_lanzar",    self, "_on_borrar_con_args")


# ── Handlers por slot ─────────────────────────────────────────────────────────

func _on_slot_0_apunte(dir: Vector2, poder: float) -> void: _set_apunte(0, dir, poder)
func _on_slot_1_apunte(dir: Vector2, poder: float) -> void: _set_apunte(1, dir, poder)
func _on_slot_2_apunte(dir: Vector2, poder: float) -> void: _set_apunte(2, dir, poder)
func _on_slot_3_apunte(dir: Vector2, poder: float) -> void: _set_apunte(3, dir, poder)


func _set_apunte(slot: int, dir: Vector2, poder: float) -> void:
	# Las señales slot_N_apunte son un bus GLOBAL (SeñalManager): en red,
	# el IndicadorApunte de CADA jugador en pantalla las recibe, no solo el
	# del jugador propio — sin este corte, apuntar con tu habilidad
	# dibujaría la previsualización sobre todos los personajes a la vez
	# (mismo motivo que Jugador._joystick_movimiento/_activar_slot).
	var jugador := get_parent()
	if Utils.en_red() and "peer_id_dueño" in jugador and jugador.peer_id_dueño != multiplayer.get_unique_id():
		return
	_hab    = _slot_habilidades.obtener(slot) if _slot_habilidades else null
	_tipo   = _hab.tipo_habilidad if _hab else ""
	_activo = true
	_dir    = dir
	_poder  = poder
	queue_redraw()


func _on_borrar() -> void:
	_activo = false
	queue_redraw()


func _on_borrar_con_args(_dir: Vector2, _poder: float) -> void:
	_activo = false
	queue_redraw()


# ── Dibujo ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not _activo:
		return
	match _tipo:
		"proyectil": _draw_proyectil()
		"area":      _draw_area_efecto()
		"carga":     _draw_carga()
		"muro":      _draw_muro()


## Dibuja el círculo grande de rango: relleno tenue + borde configurables.
func _dibujar_rango(radio: float) -> void:
	draw_circle(Vector2.ZERO, radio, Color(COLOR_APUNTE.r, COLOR_APUNTE.g, COLOR_APUNTE.b, opacidad_area_apunte))
	draw_arc(Vector2.ZERO, radio, 0.0, TAU, 64, color_borde_apunte, grosor_borde_apunte)


## Dibuja un polígono cerrado (la zona de golpe real) relleno + con borde.
func _dibujar_area_golpe_poligono(puntos: PackedVector2Array) -> void:
	draw_colored_polygon(puntos, COLOR_AREA_GOLPE)
	var cerrado := puntos.duplicate()
	cerrado.append(cerrado[0])
	draw_polyline(cerrado, color_borde_golpe, grosor_borde_golpe)


## Dibuja un círculo (la zona de golpe real) relleno + con borde.
func _dibujar_area_golpe_circulo(centro: Vector2, radio: float) -> void:
	draw_circle(centro, radio, COLOR_AREA_GOLPE)
	draw_arc(centro, radio, 0.0, TAU, 48, color_borde_golpe, grosor_borde_golpe)


func _draw_proyectil() -> void:
	var h       := _hab as HabilidadProyectil
	var alcance := h.alcance_maximo if h else 400.0

	_dibujar_rango(alcance)
	if _dir.length() < 0.05:
		return

	var fin  := _dir * alcance
	var perp := Vector2(-_dir.y, _dir.x)
	var hw   := 10.0

	# El corredor (esq) es la zona de golpe real del proyectil.
	var esq := PackedVector2Array([perp * hw, fin + perp * hw, fin - perp * hw, -perp * hw])
	_dibujar_area_golpe_poligono(esq)


func _draw_area_efecto() -> void:
	var h           := _hab as HabilidadAreaEfecto
	var desplaz_max := h.desplazamiento_maximo if h else 120.0
	var radio       := h.radio_area            if h else 80.0

	_dibujar_rango(desplaz_max)

	var offset := _dir * desplaz_max * _poder
	# El círculo en "offset" es la zona de golpe real del área de efecto.
	_dibujar_area_golpe_circulo(offset, radio)


## Igual que _draw_area_efecto (círculo de rango + zona de golpe en el punto
## de invocación), pero la zona es un rectángulo girado hacia _dir en vez de
## un círculo — mismo footprint que va a tener el muro real: ancho fijo
## (grosor de los pilares) por alto según cuántos pilares y qué tan
## separados estén.
func _draw_muro() -> void:
	var h       := _hab as HabilidadMuroJugador
	var alcance := h.alcance_maximo if h else 150.0

	_dibujar_rango(alcance)

	var offset := _dir * alcance * _poder

	var cantidad   := h.cantidad_pilares          if h else 3
	var separacion := h.distancia_entre_pilares   if h else 16.0
	var radio      := h.radio_pilar               if h else 8.0
	var ancho      := radio * 2.0
	var alto       := float(cantidad - 1) * separacion + radio * 2.0

	var giro := _dir.angle() if _dir.length() > 0.05 else 0.0
	var mitad_ancho := ancho / 2.0
	var mitad_alto  := alto / 2.0
	var esquinas_locales := PackedVector2Array([
		Vector2(-mitad_ancho, -mitad_alto), Vector2(mitad_ancho, -mitad_alto),
		Vector2(mitad_ancho, mitad_alto), Vector2(-mitad_ancho, mitad_alto),
	])
	var esquinas := PackedVector2Array()
	for esquina in esquinas_locales:
		esquinas.append(offset + esquina.rotated(giro))

	# El rectángulo (esquinas) es la zona de golpe real del muro.
	_dibujar_area_golpe_poligono(esquinas)


func _draw_carga() -> void:
	var h         := _hab as HabilidadCargaJugador
	var distancia := h.distancia_maxima_dash if h else 180.0

	_dibujar_rango(distancia)
	if _dir.length() < 0.05:
		return

	var fin  := _dir * distancia
	var perp := Vector2(-_dir.y, _dir.x)
	var hw   := 14.0

	# El corredor (esq) es la zona de golpe real del dash.
	var esq := PackedVector2Array([perp * hw, fin + perp * hw, fin - perp * hw, -perp * hw])
	_dibujar_area_golpe_poligono(esq)
