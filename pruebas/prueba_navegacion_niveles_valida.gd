# =============================================================================
# Regresión (28 sep 2026): generar_capa_navegacion.gd y generar_nivel_
# hormiguero.gd pintaban la capa Navegacion con (0, (0, 0)) — en tileset_
# colisiones.tres la fuente 0 no existe y el tile (0, 0) es un triángulo de
# medio tile. Desde julio, Cueva, Mina, Nido de la Araña y Santuario no tenían
# NINGUNA malla (los mobs iban en línea recta contra las paredes), media
# Pradera tampoco, y el Hormiguero era una malla de triángulos unidos por las
# esquinas. Nada fallaba: sin malla, todo cae a la línea recta en silencio.
#
# Por cada nivel con capa Navegacion confirma:
#   1. Ninguna celda apunta a una fuente de tiles inexistente.
#   2. No hay triángulos (0, 0) sobre piso (terreno sin colisión).
#   3. Desde el punto de aparición hay ruta a todo lo que vive en "Enemigos".
# Si falla 1 o 2, correr herramientas/reparar_navegacion.gd.
#   godot --headless --path . --script res://pruebas/prueba_navegacion_niveles_valida.gd
# =============================================================================
extends SceneTree

const NIVELES := ["NivelCueva", "NivelHormiguero", "NivelMina", "NivelNidoArañaReina",
	"NivelPradera", "NivelSantuarioGuardian"]
const FICHA_TRIANGULO := Vector2i(0, 0)

var _f := 0
var _niveles := {}
var _exito := true


func _process(_delta: float) -> bool:
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
	print("PRUEBA NAVEGACION NIVELES VALIDA %s" % ("OK" if _exito else "FALLIDA"))
	quit(0 if _exito else 1)
	return true


func _revisar(nombre: String, nivel) -> void:
	var navegacion: TileMapLayer = nivel.get_node("Navegacion")
	var terreno: TileMapLayer = nivel.get_node("Terreno")
	var por_lado := terreno.tile_set.tile_size.x / navegacion.tile_set.tile_size.x
	var invalidas := 0
	var triangulos_sobre_piso := 0
	for celda in navegacion.get_used_cells():
		if not navegacion.tile_set.has_source(navegacion.get_cell_source_id(celda)):
			invalidas += 1
			continue
		if navegacion.get_cell_atlas_coords(celda) != FICHA_TRIANGULO:
			continue
		var celda_terreno := Vector2i(floori(float(celda.x) / por_lado), floori(float(celda.y) / por_lado))
		if not _es_solido(terreno, celda_terreno):
			triangulos_sobre_piso += 1

	var mapa: RID = nivel.mapa_navegacion()
	var origen: Vector2 = nivel.punto_aparicion().global_position
	var destinos := 0
	var sin_ruta := []
	for hijo in nivel.get_node("Enemigos").get_children():
		if not (hijo is Node2D):
			continue
		destinos += 1
		var ruta := NavigationServer2D.map_get_path(mapa, origen, (hijo as Node2D).global_position, true, 2)
		if ruta.size() < 2:
			sin_ruta.append(String(hijo.name))

	var ok := invalidas == 0 and triangulos_sobre_piso == 0 and sin_ruta.is_empty() and destinos > 0
	_exito = _exito and ok
	print("%s: celdas con fuente inexistente=%d, triángulos sobre piso=%d, rutas %d/%d %s (esperado true): %s" % [
		nombre, invalidas, triangulos_sobre_piso, destinos - sin_ruta.size(), destinos,
		("sin ruta: %s" % str(sin_ruta)) if not sin_ruta.is_empty() else "", ok])


func _es_solido(terreno: TileMapLayer, celda: Vector2i) -> bool:
	var fuente := terreno.tile_set.get_source(terreno.get_cell_source_id(celda)) as TileSetAtlasSource
	if fuente == null:
		return false
	var datos := fuente.get_tile_data(terreno.get_cell_atlas_coords(celda), 0)
	return datos != null and datos.get_collision_polygons_count(0) > 0
