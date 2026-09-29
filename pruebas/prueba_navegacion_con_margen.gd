# =============================================================================
# La malla de los niveles deja MovimientoComponente.MARGEN_MALLA libres contra
# las paredes (ver NivelBase._hornear_malla_con_margen), en vez de llegar hasta
# el filo como la de la capa Navegacion pintada celda por celda.
#
# Confirma, en la Cueva y el Hormiguero (túneles angostos):
#   1. La capa Navegacion quedó con la navegación apagada y existe la región
#      horneada.
#   2. Ningún punto del borde de lo pintado (el lado de una celda caminable
#      que da a una celda sin navegación) está sobre la malla: el más cercano
#      queda a MARGEN_MALLA como mínimo.
#   3. El centro de cada celda caminable sigue cerca de la malla (a lo sumo
#      MARGEN_MALLA): achicar no se comió pasillos enteros.
#   godot --headless --path . --script res://pruebas/prueba_navegacion_con_margen.gd
# =============================================================================
extends SceneTree

const NIVELES := ["NivelCueva", "NivelHormiguero"]
const _VECINOS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
## Tolerancia del recorte de polígonos del horneado.
const _TOLERANCIA := 1.0

var _f := 0
var _niveles := {}
var _exito := true


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		for nombre in NIVELES:
			var nivel = (load("res://escenas/niveles/%s.tscn" % nombre) as PackedScene).instantiate()
			root.add_child(nivel)
			_niveles[nombre] = nivel
		return false
	if _f < 30:
		return false  # la malla de cada nivel tarda unos fotogramas en sincronizar.
	for nombre in NIVELES:
		_revisar(nombre, _niveles[nombre])
	print("PRUEBA NAVEGACION CON MARGEN %s" % ("OK" if _exito else "FALLIDA"))
	quit(0 if _exito else 1)
	return true


func _revisar(nombre: String, nivel) -> void:
	# Por nombre de archivo y no por class_name: compilar MovimientoComponente
	# junto con esta prueba lo haría antes de que existan los autoloads.
	var margen: float = (load("res://componentes/MovimientoComponente.gd") as GDScript) \
		.get_script_constant_map()["MARGEN_MALLA"]
	var capa: TileMapLayer = nivel.get_node("Navegacion")
	var region := nivel.get_node_or_null("NavegacionConMargen") as NavigationRegion2D
	var preparada := not capa.navigation_enabled and region != null
	_verificar("%s: capa apagada y región horneada" % nombre, preparada)
	if not preparada:
		return

	var mapa: RID = nivel.mapa_navegacion()
	var caminables := {}
	for celda in capa.get_used_cells():
		var datos := capa.get_cell_tile_data(celda)
		if datos != null and datos.get_navigation_polygon(0) != null:
			caminables[celda] = true

	var bordes := 0
	var peor_borde := INF
	var peor_centro := 0.0
	for celda: Vector2i in caminables:
		var centro := capa.to_global(capa.map_to_local(celda))
		peor_centro = maxf(peor_centro, centro.distance_to(NavigationServer2D.map_get_closest_point(mapa, centro)))
		for vecino in _VECINOS:
			if caminables.has(celda + vecino):
				continue
			var borde := (centro + capa.to_global(capa.map_to_local(celda + vecino))) / 2.0
			peor_borde = minf(peor_borde, borde.distance_to(NavigationServer2D.map_get_closest_point(mapa, borde)))
			bordes += 1
	_verificar("%s: %d bordes, el más cercano a la malla queda a %.1f px (esperado >= %.0f)" % [
		nombre, bordes, peor_borde, margen], bordes > 0 and peor_borde >= margen - _TOLERANCIA)
	_verificar("%s: el centro de celda más lejos de la malla está a %.1f px (esperado <= %.0f)" % [
		nombre, peor_centro, margen], peor_centro <= margen + _TOLERANCIA)


func _verificar(texto: String, ok: bool) -> void:
	_exito = _exito and ok
	print("%s: %s" % [texto, ok])
