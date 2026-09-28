# =============================================================================
# Regresión (reportado en juego real, 27 sep 2026): "en la llamada de la reina
# no todas las hormigas atienden al llamado, y deben llegar al fondo de la
# cámara de la reina, no solo a la entrada". Con el Hormiguero real y la Reina
# en su lugar real, tres causas encadenadas:
#   1. AccionIrAPunto usaba MovimientoComponente.llego_al_destino(), que se da
#      por llegado a los 6s de intentarlo: las rutas por los túneles miden
#      1.600-12.000 px (14-100s de caminata), así que TODAS abandonaban a los
#      6s donde estuvieran. Ahora solo se rinde si deja de avanzar por la ruta.
#   2. Esquinas: la malla llega hasta el vértice de la pared y el cuerpo no
#      puede acercarse al punto de ruta más que su radio (8 obrera, 15
#      soldado), con path_desired_distance en 8: se quedaba empujando la
#      esquina. Ver MovimientoComponente._ajustar_distancia_punto_ruta.
#   3. Tramos a lo largo de una pared: la ruta baja por el filo de un bloque
#      sólido en (3104, 0..32). Ver MovimientoComponente._punto_ruta_con_holgura.
#
# Confirma:
#   A. Una obrera desde la sala 8 (ruta de ~1.600 px, ~14s) termina la llamada
#      JUNTO a la Reina — antes abandonaba a los 6s a ~880 px.
#   B. Una obrera justo antes del tramo pegado a la pared de (3104, 0) lo cruza
#      sin trabarse: a los 4s sigue en la llamada y avanzó por la ruta.
#   godot --headless --path . --script res://pruebas/prueba_llamada_reina_llega_por_tuneles.gd
# =============================================================================
extends SceneTree

const _ESCENA_OBRERA := "res://escenas/enemigos/EnemigoHormigaObrera.tscn"
const _POSICION_ANTES_DE_LA_PARED := Vector2(3088, -16)
const _TOPE_SEGUNDOS := 30.0

var _f := 0
var _t := 0.0
var _nivel
var _reina
var _desde_sala_8
var _antes_de_la_pared
var _ruta_inicial_b := 0.0
var _b_verificada := false
var _resultados: Dictionary = {}


func _process(delta: float) -> bool:
	_f += 1
	if _f == 1:
		_montar()
		return false
	if _f < 30:
		return false  # la malla del nivel tarda unos fotogramas en sincronizar.
	if _f == 30:
		_ruta_inicial_b = _largo_de_ruta(_antes_de_la_pared.global_position)
		_reina.get_node("Habilidades/HabilidadLlamadaAuxilio").activar(Vector2.ZERO, 1.0)
		return false

	_t += delta
	if not _b_verificada and _t >= 4.0:
		_b_verificada = true
		var sigue: bool = _en_llamada(_antes_de_la_pared)
		var ruta_ahora := _largo_de_ruta(_antes_de_la_pared.global_position)
		_anotar("B. cruza el tramo pegado a la pared sin trabarse (ruta %.0f -> %.0f px, sigue en la llamada=%s)" % [
			_ruta_inicial_b, ruta_ahora, sigue], sigue and _ruta_inicial_b - ruta_ahora > 250.0)

	if not _en_llamada(_desde_sala_8) and not _resultados.has("A"):
		var distancia: float = _desde_sala_8.global_position.distance_to(_reina.global_position)
		_anotar("A. desde la sala 8 termina la llamada junto a la Reina (a %.0f px, a los %.1fs)" % [
			distancia, _t], distancia <= 110.0)
		_resultados["A"] = true
	if _resultados.has("A") and _b_verificada:
		return _informar()
	if _t > _TOPE_SEGUNDOS:
		_anotar("A. desde la sala 8 terminó la llamada antes de %.0fs" % _TOPE_SEGUNDOS, false)
		return _informar()
	return false


func _montar() -> void:
	_nivel = (load("res://escenas/niveles/NivelHormiguero.tscn") as PackedScene).instantiate()
	root.add_child(_nivel)
	current_scene = _nivel
	var enemigos: Node = _nivel.get_node("Enemigos")
	_reina = enemigos.get_node("EnemigoReinaHormigas")
	_reina.get_node("ArbolComportamiento").process_mode = Node.PROCESS_MODE_DISABLED
	for hijo in enemigos.get_children():
		if "lista_mobs" in hijo:
			hijo.activo = false
	_desde_sala_8 = _crear_obrera(enemigos, enemigos.get_node("SpawnerMobs8").global_position)
	_antes_de_la_pared = _crear_obrera(enemigos, _POSICION_ANTES_DE_LA_PARED)


func _crear_obrera(enemigos: Node, posicion: Vector2) -> Node2D:
	var obrera = (load(_ESCENA_OBRERA) as PackedScene).instantiate()
	enemigos.add_child(obrera)
	obrera.global_position = posicion
	return obrera


func _en_llamada(hormiga) -> bool:
	return hormiga.get_node("ArbolComportamiento/MemoriaBT").obtener("en_llamada_auxilio", false)


func _largo_de_ruta(desde: Vector2) -> float:
	var ruta := NavigationServer2D.map_get_path(_nivel.mapa_navegacion(), desde, _reina.global_position, true, 2)
	var largo := 0.0
	for i in range(1, ruta.size()):
		largo += ruta[i - 1].distance_to(ruta[i])
	return largo


func _anotar(nombre: String, ok: bool) -> void:
	_resultados[nombre] = ok
	print("%s (esperado true): %s" % [nombre, ok])


func _informar() -> bool:
	var exito := true
	for clave in _resultados:
		if clave != "A":
			exito = exito and _resultados[clave]
	print("PRUEBA LLAMADA REINA LLEGA POR TUNELES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
