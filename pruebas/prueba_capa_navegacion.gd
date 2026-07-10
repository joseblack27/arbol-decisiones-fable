# =============================================================================
# Prueba de la capa Navegacion dedicada:
#   1. Pinta una pared de fichas-silueta (colisiones.png) cruzando el camino
#      directo entre el lobo y un destino al otro lado.
#   2. Verifica que la ruta calculada por el agente RODEA la pared
#      (algún punto de la ruta se aleja de la línea recta) en vez de
#      atravesarla, y que aun así llega al destino.
#   godot --headless --path . --script res://pruebas/prueba_capa_navegacion.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _lobo: CharacterBody2D
var _movimiento: Node
var _navegacion: TileMapLayer
var _destino := Vector2.ZERO


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		10:
			_destino = _lobo.global_position + Vector2(240, 0)
			_movimiento.comandar_destino(_destino)
		40:
			return _informar()
	return false


func _informar() -> bool:
	var agente: NavigationAgent2D = _movimiento.get("agente_navegacion")
	var ruta := agente.get_current_navigation_path()
	var desvio_maximo := 0.0
	var linea_inicio := _lobo.global_position
	for punto: Vector2 in ruta:
		var proyeccion := Geometry2D.get_closest_point_to_segment(
			punto, linea_inicio, _destino
		)
		desvio_maximo = maxf(desvio_maximo, punto.distance_to(proyeccion))
	print("Puntos de ruta: %d, desvío máximo respecto a la línea recta: %.0f px" % [
		ruta.size(), desvio_maximo,
	])
	var exito := ruta.size() >= 3 and desvio_maximo > 20.0
	print("PRUEBA CAPA NAVEGACION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true


func _montar() -> void:
	var nivel := (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	root.add_child(nivel)
	current_scene = nivel
	_lobo = nivel.get_node("Enemigos/EnemigoLobo")
	var ia := _lobo.get_node_or_null("ArbolComportamiento")
	if ia != null:
		ia.set("activo", false)
	_movimiento = _lobo.get_node("MovimientoComponente")

	_navegacion = nivel.get_node("Navegacion") as TileMapLayer
	# Pintar una pared de fichas-silueta cruzando el eje X entre el lobo y su
	# destino, unas celdas por encima y por debajo del origen (perpendicular
	# al trayecto directo), para forzar un rodeo.
	var tam := _navegacion.tile_set.tile_size.x
	var origen_celda := _navegacion.local_to_map(_navegacion.to_local(_lobo.global_position))
	var x_pared := origen_celda.x + int(120.0 / tam)
	for dy in range(-6, 7):
		_navegacion.set_cell(Vector2i(x_pared, origen_celda.y + dy), 1, Vector2i.ZERO)
