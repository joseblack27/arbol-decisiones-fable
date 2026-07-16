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
	# Un slot_N_apunte/cancelar/lanzar por CADA slot posible, no solo los
	# visibles a la vez en el HUD (ver PaginadorHabilidades: un botón físico
	# puede mostrar cualquier slot_index según la página activa).
	var total := _slot_habilidades.total_slots if _slot_habilidades else 10
	for i in total:
		SeñalManager.conectar("slot_%d_apunte" % i,   self, "_on_slot_%d_apunte" % i)
		SeñalManager.conectar("slot_%d_cancelar" % i, self, "_on_borrar")
		SeñalManager.conectar("slot_%d_lanzar" % i,   self, "_on_borrar_con_args")


# ── Handlers por slot ─────────────────────────────────────────────────────────

func _on_slot_0_apunte(dir: Vector2, poder: float) -> void: _set_apunte(0, dir, poder)
func _on_slot_1_apunte(dir: Vector2, poder: float) -> void: _set_apunte(1, dir, poder)
func _on_slot_2_apunte(dir: Vector2, poder: float) -> void: _set_apunte(2, dir, poder)
func _on_slot_3_apunte(dir: Vector2, poder: float) -> void: _set_apunte(3, dir, poder)
func _on_slot_4_apunte(dir: Vector2, poder: float) -> void: _set_apunte(4, dir, poder)
func _on_slot_5_apunte(dir: Vector2, poder: float) -> void: _set_apunte(5, dir, poder)
func _on_slot_6_apunte(dir: Vector2, poder: float) -> void: _set_apunte(6, dir, poder)
func _on_slot_7_apunte(dir: Vector2, poder: float) -> void: _set_apunte(7, dir, poder)
func _on_slot_8_apunte(dir: Vector2, poder: float) -> void: _set_apunte(8, dir, poder)
func _on_slot_9_apunte(dir: Vector2, poder: float) -> void: _set_apunte(9, dir, poder)


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
		"proyectil":         _draw_proyectil()
		"rafaga":            _draw_proyectil()  # mismo corredor recto: 5 tiros, una dirección
		"proyectil_abanico": _draw_proyectil_abanico()
		"area":              _draw_area_efecto()
		"carga":             _draw_carga()
		"muro":              _draw_muro()
		"parpadeo":          _draw_parpadeo()
		"lanzallamas":       _draw_lanzallamas()


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
	# Por propiedad y no casteando a HabilidadProyectil: la ráfaga
	# (HabilidadRafaga) comparte este dibujo y también expone alcance_maximo,
	# pero no hereda de esa clase.
	var alcance: float = _hab.get("alcance_maximo") \
		if _hab and ("alcance_maximo" in _hab) else 400.0

	_dibujar_rango(alcance)
	if _dir.length() < 0.05:
		return

	var fin  := _dir * alcance
	var perp := Vector2(-_dir.y, _dir.x)
	var hw   := 10.0

	# El corredor (esq) es la zona de golpe real del proyectil.
	var esq := PackedVector2Array([perp * hw, fin + perp * hw, fin - perp * hw, -perp * hw])
	_dibujar_area_golpe_poligono(esq)


## Mismo corredor que _draw_proyectil(), repetido una vez por cada dirección
## del abanico — así se ve de antemano hacia dónde va cada proyectil, no
## solo el rango total (círculo grande), antes de soltar el disparo.
func _draw_proyectil_abanico() -> void:
	var h             := _hab as HabilidadProyectilAbanico
	var alcance       := h.alcance_maximo       if h else 400.0
	var cantidad      := h.cantidad_proyectiles if h else 3
	var angulo_total  := deg_to_rad(h.angulo_total_grados) if h else deg_to_rad(30.0)

	_dibujar_rango(alcance)
	if _dir.length() < 0.05:
		return

	var hw := 10.0
	var paso := angulo_total / (cantidad - 1) if cantidad > 1 else 0.0
	var angulo_inicial := -angulo_total / 2.0
	for i in cantidad:
		var dir_i := _dir.rotated(angulo_inicial + paso * i)
		var fin   := dir_i * alcance
		var perp  := Vector2(-dir_i.y, dir_i.x)
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


## A diferencia de _draw_carga: el parpadeo no golpea nada en el camino, así
## que en vez de un corredor relleno se traza una LÍNEA fina hasta el punto
## de destino — mostraba solo el círculo de rango (grande, fijo) más el
## puntito de destino, y sin una línea que los conecte no queda claro que
## uno depende del otro (reportado: "no se entiende bien solo el círculo").
func _draw_parpadeo() -> void:
	var h         := _hab as HabilidadParpadeo
	var distancia := h.distancia_parpadeo if h else 200.0

	_dibujar_rango(distancia)
	if _dir.length() < 0.05:
		return

	var destino := _dir * distancia
	draw_line(Vector2.ZERO, destino, COLOR_AREA_GOLPE, 3.0)
	_dibujar_area_golpe_circulo(destino, 14.0)


## Cono real (mismo abanico que arma HabilidadLanzallamas._construir_forma_
## cono en código) — no un círculo genérico, para que el jugador vea desde
## antes exactamente qué ancho de chorro va a tocar.
func _draw_lanzallamas() -> void:
	var h        := _hab as HabilidadLanzallamas
	var alcance  := h.alcance_cono if h else 220.0
	var angulo   := h.angulo_cono_grados if h else 50.0

	_dibujar_rango(alcance)
	if _dir.length() < 0.05:
		return

	const SEGMENTOS := 8
	var mitad := deg_to_rad(angulo) / 2.0
	var puntos := PackedVector2Array([Vector2.ZERO])
	for i in (SEGMENTOS + 1):
		var ang := lerpf(-mitad, mitad, float(i) / float(SEGMENTOS))
		puntos.append(_dir.rotated(ang) * alcance)
	_dibujar_area_golpe_poligono(puntos)
