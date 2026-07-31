# =============================================================================
# Prueba de la capa Navegacion dedicada:
#   1. Pinta una pared de fichas-silueta (colisiones.png) cruzando el camino
#      directo entre el lobo y un destino al otro lado.
#   2. Verifica que la ruta calculada por el agente RODEA la pared
#      (algún punto de la ruta se aleja de la línea recta) en vez de
#      atravesarla, y que aun así llega al destino.
#   godot --headless --path . --script res://pruebas/prueba_capa_navegacion.gd
#
# Igual que prueba_navegacion: el lobo lo pone la prueba y SpawnerMobs se apaga.
# Pescar el lobo que hubiera generado el spawner ataba la prueba a dos sorteos
# (qué tipo de mob toca y dónde cae), y ~1 de cada 10 corridas no generaba
# ninguno. Además, acá hay una espera que no es opcional: pintar la pared con
# set_cell() no la mete en la malla al instante — hay que esperar a que
# NavigationServer la re-sincronice, o la ruta se calcularía contra el mapa
# viejo (sin pared) y el desvío que busca la prueba no existiría.
# =============================================================================
extends SceneTree

const _ESCENA_LOBO := "res://escenas/enemigos/EnemigoLobo.tscn"

const _ORIGEN_LOBO := Vector2.ZERO
const _DESPLAZAMIENTO_DESTINO := Vector2(240, 0)
## A qué distancia (px) del lobo se levanta la pared, cruzada a su trayecto.
const _DISTANCIA_PARED := 120.0
## Cuántas celdas hacia arriba y hacia abajo se extiende la pared.
const _MEDIA_ALTURA_PARED := 6
const _TOLERANCIA_MALLA := 6.0

const _FISICAS_ESPERA_MALLA := 180
## Tope de físicas esperando a que la pared recién pintada entre en la malla.
const _FISICAS_ESPERA_PARED := 180
## Tope de físicas esperando a que el agente devuelva una ruta.
const _FISICAS_ESPERA_RUTA := 180

const _DISTANCIA_SONDA := 1_000_000.0

## Techo duro de fotogramas: pase lo que pase, esta prueba TERMINA. Los topes
## por fase cubren las esperas previstas, pero no un error de script que aborte
## _process() a mitad todos los fotogramas — ahí nunca se llegaría a quit() y
## el SceneTree seguiría girando para siempre (ver la nota larga en
## prueba_navegacion.gd, donde pasó de verdad).
const _FOTOGRAMAS_TOPE_DURO := 3000

var _fotogramas := 0
var _fisicas := 0
var _fisicas_de_fase := 0
var _lobo: CharacterBody2D
var _movimiento: Node
var _agente: NavigationAgent2D
var _navegacion: TileMapLayer
var _destino := Vector2.ZERO
var _centro_pared := Vector2.ZERO

enum Fase { ESPERANDO_MALLA, ESPERANDO_PARED, ESPERANDO_RUTA }
var _fase: Fase = Fase.ESPERANDO_MALLA


func _init() -> void:
	physics_frame.connect(func() -> void: _fisicas += 1)


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas > _FOTOGRAMAS_TOPE_DURO:
		return _fallar("la prueba no llegó a ningún veredicto en %d fotogramas "
			% _FOTOGRAMAS_TOPE_DURO + "(revisá los errores de script de arriba).")
	if _fotogramas == 1:
		_montar()
		return false
	match _fase:
		Fase.ESPERANDO_MALLA:
			return _esperar_malla()
		Fase.ESPERANDO_PARED:
			return _esperar_pared()
		Fase.ESPERANDO_RUTA:
			return _esperar_ruta()
	return false


func _montar() -> void:
	var nivel := (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	var spawner := nivel.get_node_or_null("Enemigos/SpawnerMobs")
	if spawner != null:
		spawner.set("cantidad_inicial", 0)
		spawner.set("activo", false)
	root.add_child(nivel)
	current_scene = nivel
	_navegacion = nivel.get_node("Navegacion") as TileMapLayer


## true cuando la malla ya contesta consultas de posición de verdad: un punto
## absurdamente lejano devuelve el vértice transitable más cercano si está
## sincronizada, y el Vector2.ZERO de "no encontrado" si sigue a medio hornear.
func _malla_responde(mapa: RID) -> bool:
	if NavigationServer2D.map_get_regions(mapa).is_empty():
		return false
	return NavigationServer2D.map_get_closest_point(
		mapa, Vector2(_DISTANCIA_SONDA, _DISTANCIA_SONDA)
	) != Vector2.ZERO


func _fallar(motivo: String) -> bool:
	print("FALLO: %s" % motivo)
	print("PRUEBA CAPA NAVEGACION FALLIDA")
	quit(1)
	return true


func _esperar_malla() -> bool:
	# El mapa del NIVEL, no el del mundo (ver NivelBase._crear_mapa_navegacion).
	var mapa := _mapa_del_nivel()
	if not _malla_responde(mapa):
		if _fisicas < _FISICAS_ESPERA_MALLA:
			return false
		return _fallar("la malla no respondió consultas en %d físicas." % _FISICAS_ESPERA_MALLA)

	_destino = _ORIGEN_LOBO + _DESPLAZAMIENTO_DESTINO
	for descripcion: Array in [["origen", _ORIGEN_LOBO], ["destino", _destino]]:
		var punto: Vector2 = descripcion[1]
		if punto.distance_to(NavigationServer2D.map_get_closest_point(mapa, punto)) \
				> _TOLERANCIA_MALLA:
			return _fallar("el %s de la prueba (%s) no cae sobre la malla de la pradera."
				% [descripcion[0], punto])

	_pintar_pared()
	_fase = Fase.ESPERANDO_PARED
	_fisicas_de_fase = _fisicas
	return false


## Pared de fichas-silueta cruzando el eje X entre el lobo y su destino, unas
## celdas por encima y por debajo del origen (perpendicular al trayecto
## directo), para forzar un rodeo.
func _pintar_pared() -> void:
	var tam := _navegacion.tile_set.tile_size.x
	var origen_celda := _navegacion.local_to_map(_navegacion.to_local(_ORIGEN_LOBO))
	var x_pared := origen_celda.x + int(_DISTANCIA_PARED / tam)
	for dy in range(-_MEDIA_ALTURA_PARED, _MEDIA_ALTURA_PARED + 1):
		_navegacion.set_cell(Vector2i(x_pared, origen_celda.y + dy), 1, Vector2i.ZERO)
	_centro_pared = _navegacion.to_global(
		_navegacion.map_to_local(Vector2i(x_pared, origen_celda.y))
	)


## set_cell() no toca la malla en el acto: NavigationServer re-sincroniza la
## capa unas físicas después. Se espera a que el centro de la pared DEJE de ser
## transitable — preguntárselo a la malla es más honesto que contar fotogramas,
## que es justo lo que volvía intermitentes a estas pruebas.
func _esperar_pared() -> bool:
	var mapa := _mapa_del_nivel()
	var cercano := NavigationServer2D.map_get_closest_point(mapa, _centro_pared)
	if _centro_pared.distance_to(cercano) <= _TOLERANCIA_MALLA:
		if _fisicas - _fisicas_de_fase < _FISICAS_ESPERA_PARED:
			return false
		return _fallar(
			"la pared pintada no entró en la malla en %d físicas: su centro %s sigue siendo transitable."
			% [_FISICAS_ESPERA_PARED, _centro_pared]
		)

	_lobo = (load(_ESCENA_LOBO) as PackedScene).instantiate()
	current_scene.get_node("Enemigos").add_child(_lobo)
	_lobo.global_position = _ORIGEN_LOBO
	var ia := _lobo.get_node_or_null("ArbolComportamiento")
	if ia != null:
		ia.set("activo", false)
	_movimiento = _lobo.get_node("MovimientoComponente")
	_movimiento.comandar_destino(_destino)
	_agente = _movimiento.get("agente_navegacion") as NavigationAgent2D
	_fase = Fase.ESPERANDO_RUTA
	_fisicas_de_fase = _fisicas
	return false


func _esperar_ruta() -> bool:
	if _agente.get_current_navigation_path().is_empty():
		if _fisicas - _fisicas_de_fase < _FISICAS_ESPERA_RUTA:
			return false
		return _fallar("el agente no devolvió ninguna ruta en %d físicas." % _FISICAS_ESPERA_RUTA)
	return _informar()


func _informar() -> bool:
	var ruta := _agente.get_current_navigation_path()
	var desvio_maximo := 0.0
	for punto: Vector2 in ruta:
		var proyeccion := Geometry2D.get_closest_point_to_segment(
			punto, _ORIGEN_LOBO, _destino
		)
		desvio_maximo = maxf(desvio_maximo, punto.distance_to(proyeccion))
	print("Puntos de ruta: %d, desvío máximo respecto a la línea recta: %.0f px" % [
		ruta.size(), desvio_maximo,
	])
	var exito := ruta.size() >= 3 and desvio_maximo > 20.0
	print("PRUEBA CAPA NAVEGACION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true


## El mapa de navegación del nivel cargado. Cada nivel tiene el suyo desde que
## el servidor puede tener varios cargados a la vez, así que el del mundo
## (get_world_2d().navigation_map) ya no tiene ninguna región.
func _mapa_del_nivel() -> RID:
	# El nivel se cuelga directo de root en esta prueba (no hay contenedor
	# registrado en GestorNiveles), así que se lo busca ahí.
	for hijo in root.get_children():
		if hijo.has_method("mapa_navegacion"):
			return hijo.call("mapa_navegacion")
	return root.get_world_2d().navigation_map
