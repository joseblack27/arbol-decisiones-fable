extends Node2D
class_name IndicadorApunte
## Previsualización de trayectoria en espacio de mundo.
## Hijo del Jugador — dibuja en su espacio local, se mueve con él.
## Escucha señales de apunte por slot (slot_0..slot_3) y dibuja según
## el tipo de habilidad equipada en ese slot.

var _slot_habilidades: SlotHabilidades = null

var _activo: bool      = false
var _tipo:   String    = ""
var _dir:    Vector2   = Vector2.ZERO
var _poder:  float     = 0.0
var _hab:    HabilidadBase = null


func _ready() -> void:
	call_deferred("_conectar")


func _conectar() -> void:
	_slot_habilidades = get_tree().get_first_node_in_group("slot_habilidades") as SlotHabilidades
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


func _draw_proyectil() -> void:
	var h       := _hab as HabilidadProyectil
	var alcance := h.alcance_maximo if h else 400.0
	var c       := Color(0.95, 0.55, 0.10, 1.0)

	draw_arc(Vector2.ZERO, alcance, 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.18), 1.5)
	if _dir.length() < 0.05:
		return

	var fin  := _dir * alcance
	var perp := Vector2(-_dir.y, _dir.x)
	var hw   := 10.0

	var esq := PackedVector2Array([perp * hw, fin + perp * hw, fin - perp * hw, -perp * hw])
	draw_colored_polygon(esq, Color(c.r, c.g, c.b, 0.18))
	draw_polyline(PackedVector2Array([esq[0], esq[1], esq[2], esq[3], esq[0]]),
		Color(c.r, c.g, c.b, 0.75), 2.0)
	draw_circle(fin, 9.0, c)
	draw_line(fin, fin - _dir * 18.0 + perp * 12.0, c, 2.5)
	draw_line(fin, fin - _dir * 18.0 - perp * 12.0, c, 2.5)
	draw_circle(Vector2.ZERO, 5.0, Color(c.r, c.g, c.b, 0.70))


func _draw_area_efecto() -> void:
	var h           := _hab as HabilidadAreaEfecto
	var desplaz_max := h.desplazamiento_maximo if h else 120.0
	var radio       := h.radio_area            if h else 80.0
	var c           := Color(0.85, 0.20, 0.85, 1.0)

	draw_arc(Vector2.ZERO, desplaz_max, 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.18), 1.5)

	var offset := _dir * desplaz_max * _poder
	draw_dashed_line(Vector2.ZERO, offset, Color(c.r, c.g, c.b, 0.55), 2.0, 10.0)
	draw_circle(offset, radio, Color(c.r, c.g, c.b, 0.15))
	draw_arc(offset, radio, 0.0, TAU, 48, c, 2.5)
	var cs := 9.0
	draw_line(offset - Vector2(cs, 0), offset + Vector2(cs, 0), c, 2.0)
	draw_line(offset - Vector2(0, cs), offset + Vector2(0, cs), c, 2.0)


## Igual que _draw_area_efecto (círculo de rango + marca en el punto de
## invocación), pero la marca es un rectángulo girado hacia _dir en vez de
## un círculo — mismo footprint que va a tener el muro real: ancho fijo
## (grosor de los pilares) por alto según cuántos pilares y qué tan
## separados estén.
func _draw_muro() -> void:
	var h       := _hab as HabilidadMuroJugador
	var alcance := h.alcance_maximo if h else 150.0
	var c       := Color(0.55, 0.50, 0.40, 1.0)

	draw_arc(Vector2.ZERO, alcance, 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.18), 1.5)

	var offset := _dir * alcance * _poder
	draw_dashed_line(Vector2.ZERO, offset, Color(c.r, c.g, c.b, 0.55), 2.0, 10.0)

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

	draw_colored_polygon(esquinas, Color(c.r, c.g, c.b, 0.25))
	esquinas.append(esquinas[0])
	draw_polyline(esquinas, Color(c.r, c.g, c.b, 0.80), 2.0)
	draw_circle(Vector2.ZERO, 5.0, Color(c.r, c.g, c.b, 0.70))


func _draw_carga() -> void:
	var h         := _hab as HabilidadCargaJugador
	var distancia := h.distancia_maxima_dash if h else 180.0
	var c         := Color(0.20, 0.80, 1.00, 1.0)

	draw_arc(Vector2.ZERO, distancia, 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.18), 1.5)
	if _dir.length() < 0.05:
		return

	var fin  := _dir * distancia
	var perp := Vector2(-_dir.y, _dir.x)
	var hw   := 14.0

	var esq := PackedVector2Array([perp * hw, fin + perp * hw, fin - perp * hw, -perp * hw])
	draw_colored_polygon(esq, Color(c.r, c.g, c.b, 0.15))
	draw_polyline(PackedVector2Array([esq[0], esq[1], esq[2], esq[3], esq[0]]),
		Color(c.r, c.g, c.b, 0.70), 2.0)
	draw_circle(fin, 10.0, c)
	draw_line(fin, fin - _dir * 20.0 + perp * 13.0, c, 2.5)
	draw_line(fin, fin - _dir * 20.0 - perp * 13.0, c, 2.5)
	draw_circle(Vector2.ZERO, 5.0, Color(c.r, c.g, c.b, 0.70))
