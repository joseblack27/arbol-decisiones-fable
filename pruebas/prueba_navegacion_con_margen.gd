# =============================================================================
# La malla de los niveles la hornea NivelBase (ver HorneadorNavegacion.gd) para
# que coincida con la física: deja MovimientoComponente.MARGEN_MALLA libres
# contra las paredes, resta la colisión de las otras capas y de las
# decoraciones, y descarta lo que quedó aislado.
#
# Confirma:
#   1. En los 7 niveles con malla, la capa/región original quedó apagada y
#      existe la región horneada.
#   2. Cueva y Hormiguero (túneles angostos): ningún punto del borde de lo
#      pintado queda a menos de MARGEN_MALLA de la malla.
#   3. Pradera: la Navegacion estaba pintada en todo el rectángulo, también del
#      otro lado de la cerca (capa Colision); ahí aparecían mobs a los que nadie
#      llega y el cazador se arrastraba contra la cerca. Esos puntos ya no están
#      sobre la malla.
#   4. Los StaticBody2D de Decoraciones (árboles, rocas, vetas) y los tiles de
#      Colision del Camino quedan fuera de la malla, con margen.
#   5. Las compuertas de la Mina (abren y cierran) NO se restan: su centro
#      sigue sobre la malla.
#   godot --headless --path . --script res://pruebas/prueba_navegacion_con_margen.gd
# =============================================================================
extends SceneTree

const NIVELES := ["NivelCueva", "NivelHormiguero", "NivelMina", "NivelNidoArañaReina",
	"NivelPradera", "NivelSantuarioGuardian", "NivelCamino"]
const _CON_BORDES := ["NivelCueva", "NivelHormiguero"]
const _VECINOS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
## Del otro lado de la cerca de la Pradera, donde los spawners llegaban a
## poner mobs (medido el 28 sep 2026).
const _AFUERA_DE_LA_PRADERA: Array[Vector2] = [Vector2(755, -691), Vector2(-611, 847),
	Vector2(-966, 545), Vector2(-504, -635)]
## Tolerancia del recorte de polígonos del horneado.
const _TOLERANCIA := 1.0

var _f := 0
var _niveles := {}
var _margen := 0.0
var _exito := true


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		# Por nombre de archivo y no por class_name: compilar MovimientoComponente
		# junto con esta prueba lo haría antes de que existan los autoloads.
		_margen = (load("res://componentes/MovimientoComponente.gd") as GDScript) \
			.get_script_constant_map()["MARGEN_MALLA"]
		for nombre in NIVELES:
			var nivel = (load("res://escenas/niveles/%s.tscn" % nombre) as PackedScene).instantiate()
			for hijo in nivel.get_node("Enemigos").get_children():
				if "lista_mobs" in hijo:
					hijo.cantidad_inicial = 0
			root.add_child(nivel)
			_niveles[nombre] = nivel
		return false
	if _f < 30:
		return false  # la malla de cada nivel tarda unos fotogramas en sincronizar.
	for nombre in NIVELES:
		_revisar_preparada(nombre, _niveles[nombre])
	for nombre in _CON_BORDES:
		_revisar_bordes(nombre, _niveles[nombre])
	_revisar_afuera_de_la_pradera()
	for nombre in ["NivelPradera", "NivelMina", "NivelCueva"]:
		_revisar_decoraciones(nombre, _niveles[nombre])
	_revisar_colision_del_camino()
	print("PRUEBA NAVEGACION CON MARGEN %s" % ("OK" if _exito else "FALLIDA"))
	quit(0 if _exito else 1)
	return true


func _revisar_preparada(nombre: String, nivel) -> void:
	var origen = nivel.get_node("Navegacion")
	var apagado: bool = (not origen.navigation_enabled) if origen is TileMapLayer else (not origen.enabled)
	var region := nivel.get_node_or_null("NavegacionConMargen") as NavigationRegion2D
	_verificar("%s: original apagado y región horneada" % nombre, apagado and region != null)


func _revisar_bordes(nombre: String, nivel) -> void:
	var capa: TileMapLayer = nivel.get_node("Navegacion")
	var mapa: RID = nivel.mapa_navegacion()
	var caminables := {}
	for celda in capa.get_used_cells():
		var datos := capa.get_cell_tile_data(celda)
		if datos != null and datos.get_navigation_polygon(0) != null:
			caminables[celda] = true
	var bordes := 0
	var peor := INF
	for celda: Vector2i in caminables:
		var centro := capa.to_global(capa.map_to_local(celda))
		for vecino in _VECINOS:
			if caminables.has(celda + vecino):
				continue
			var borde := (centro + capa.to_global(capa.map_to_local(celda + vecino))) / 2.0
			peor = minf(peor, borde.distance_to(NavigationServer2D.map_get_closest_point(mapa, borde)))
			bordes += 1
	_verificar("%s: %d bordes, el más cercano a la malla queda a %.1f px (esperado >= %.0f)" % [
		nombre, bordes, peor, _margen], bordes > 0 and peor >= _margen - _TOLERANCIA)


func _revisar_afuera_de_la_pradera() -> void:
	var mapa: RID = _niveles["NivelPradera"].mapa_navegacion()
	var peor := INF
	for punto in _AFUERA_DE_LA_PRADERA:
		peor = minf(peor, punto.distance_to(NavigationServer2D.map_get_closest_point(mapa, punto)))
	_verificar("NivelPradera: del otro lado de la cerca, el punto más cercano a la malla queda a %.0f px (esperado > 50)" % peor,
		peor > 50.0)


func _revisar_decoraciones(nombre: String, nivel) -> void:
	var mapa: RID = nivel.mapa_navegacion()
	var fijos := 0
	var peor_fijo := INF
	var moviles := 0
	var peor_movil := 0.0
	for nodo in _descendientes(nivel.get_node("Decoraciones")):
		if not (nodo is StaticBody2D) or not ((nodo as StaticBody2D).collision_layer & 1):
			continue
		for hijo in nodo.get_children():
			if not (hijo is CollisionShape2D) or (hijo as CollisionShape2D).disabled:
				continue
			var centro: Vector2 = (hijo as Node2D).global_position
			var distancia := centro.distance_to(NavigationServer2D.map_get_closest_point(mapa, centro))
			if nodo.is_in_group(&"obstaculos_moviles"):
				moviles += 1
				peor_movil = maxf(peor_movil, distancia)
			else:
				fijos += 1
				peor_fijo = minf(peor_fijo, distancia)
	if fijos > 0:
		_verificar("%s: %d decoraciones sólidas, la más cercana a la malla a %.1f px (esperado >= %.0f)" % [
			nombre, fijos, peor_fijo, _margen], peor_fijo >= _margen - _TOLERANCIA)
	if moviles > 0:
		_verificar("%s: %d compuertas, la más lejos de la malla a %.1f px (esperado ~0: no se restan)" % [
			nombre, moviles, peor_movil], peor_movil <= _TOLERANCIA)


func _revisar_colision_del_camino() -> void:
	var nivel = _niveles["NivelCamino"]
	var capa: TileMapLayer = nivel.get_node("Colision")
	var mapa: RID = nivel.mapa_navegacion()
	var revisadas := 0
	var peor := INF
	for celda in capa.get_used_cells():
		var datos := capa.get_cell_tile_data(celda)
		if datos == null or datos.get_collision_polygons_count(0) == 0:
			continue
		var centro := capa.to_global(capa.map_to_local(celda))
		peor = minf(peor, centro.distance_to(NavigationServer2D.map_get_closest_point(mapa, centro)))
		revisadas += 1
	_verificar("NivelCamino: %d tiles de Colision, el centro más cercano a la malla a %.1f px (esperado >= %.0f)" % [
		revisadas, peor, _margen], revisadas > 0 and peor >= _margen - _TOLERANCIA)


func _descendientes(desde: Node) -> Array[Node]:
	var r: Array[Node] = []
	for hijo in desde.get_children():
		r.append(hijo)
		r.append_array(_descendientes(hijo))
	return r


func _verificar(texto: String, ok: bool) -> void:
	_exito = _exito and ok
	print("%s: %s" % [texto, ok])
