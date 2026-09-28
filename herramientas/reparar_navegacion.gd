# =============================================================================
# reparar_navegacion.gd — arregla la capa "Navegacion" de cada nivel.
#
# generar_capa_navegacion.gd y generar_nivel_hormiguero.gd pintaban la ficha
# "Libre" como set_cell(celda, 0, (0, 0)): en tileset_colisiones.tres la
# fuente 0 no existe (solo la 8, desde el primer commit del 10 jul 2026), y en
# la fuente 8 el tile (0, 0) es un TRIÁNGULO de medio tile. Resultado (27-28
# sep 2026): Cueva, Mina, Nido de la Araña y Santuario sin NINGUNA malla (los
# mobs iban en línea recta contra las paredes), media Pradera sin malla, y el
# Hormiguero con una malla de triángulos unidos solo por las esquinas.
#
# Regla, la misma de los generadores: sobre terreno SIN colisión (piso), toda
# celda con fuente inexistente o con el triángulo (0, 0) pasa a la ficha
# completa (8, (4, 2)); sobre terreno con colisión, las de fuente inexistente
# se borran (nunca fueron malla) y los triángulos se dejan (pueden ser a
# propósito junto a una pared diagonal). La capa tiene collision_enabled =
# false, así que la colisión que trae (4, 2) no suma paredes.
#
# Toca SOLO la línea tile_map_data de la capa Navegacion de cada .tscn (no
# vuelve a guardar la escena entera). Idempotente.
#   godot --headless --path . --script res://herramientas/reparar_navegacion.gd
# =============================================================================
extends SceneTree

const NIVELES: Array[String] = [
	"res://escenas/niveles/NivelCueva.tscn",
	"res://escenas/niveles/NivelHormiguero.tscn",
	"res://escenas/niveles/NivelMina.tscn",
	"res://escenas/niveles/NivelNidoArañaReina.tscn",
	"res://escenas/niveles/NivelPradera.tscn",
	"res://escenas/niveles/NivelSantuarioGuardian.tscn",
]
const FUENTE := 8
const FICHA_COMPLETA := Vector2i(4, 2)
const FICHA_TRIANGULO := Vector2i(0, 0)


func _initialize() -> void:
	for ruta in NIVELES:
		_reparar(ruta)
	quit(0)


func _reparar(ruta: String) -> void:
	var nivel := (load(ruta) as PackedScene).instantiate()
	var navegacion := nivel.get_node("Navegacion") as TileMapLayer
	var terreno := nivel.get_node("Terreno") as TileMapLayer
	var por_lado := terreno.tile_set.tile_size.x / navegacion.tile_set.tile_size.x
	var completadas := 0
	var borradas := 0
	var triangulos_junto_a_pared := 0
	for celda in navegacion.get_used_cells():
		var invalida := not navegacion.tile_set.has_source(navegacion.get_cell_source_id(celda))
		var triangulo := not invalida and navegacion.get_cell_atlas_coords(celda) == FICHA_TRIANGULO
		if not (invalida or triangulo):
			continue
		var celda_terreno := Vector2i(floori(float(celda.x) / por_lado), floori(float(celda.y) / por_lado))
		if _es_solido(terreno, celda_terreno):
			if invalida:
				navegacion.erase_cell(celda)
				borradas += 1
			else:
				triangulos_junto_a_pared += 1
			continue
		navegacion.set_cell(celda, FUENTE, FICHA_COMPLETA)
		completadas += 1
	var datos_nuevos := Marshalls.raw_to_base64(navegacion.tile_map_data)
	nivel.free()
	if completadas == 0 and borradas == 0:
		print("%s: nada que reparar (triángulos junto a pared, sin tocar: %d)." % [ruta, triangulos_junto_a_pared])
		return

	var texto := FileAccess.get_file_as_string(ruta)
	var inicio_nodo := texto.find('[node name="Navegacion" type="TileMapLayer"')
	var marca := 'tile_map_data = PackedByteArray("'
	var inicio_datos := texto.find(marca, inicio_nodo) + marca.length()
	var fin_datos := texto.find('")', inicio_datos)
	var siguiente_nodo := texto.find("\n[", inicio_nodo + 1)
	if inicio_nodo == -1 or inicio_datos < marca.length() or (siguiente_nodo != -1 and inicio_datos > siguiente_nodo):
		push_error("%s: no se encontró tile_map_data de la capa Navegacion." % ruta)
		return
	texto = texto.substr(0, inicio_datos) + datos_nuevos + texto.substr(fin_datos)
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	archivo.store_string(texto)
	archivo.close()
	print("%s: %d celdas a ficha completa, %d referencias inválidas sobre pared borradas (triángulos junto a pared, sin tocar: %d)." % [
		ruta, completadas, borradas, triangulos_junto_a_pared])


func _es_solido(terreno: TileMapLayer, celda: Vector2i) -> bool:
	var fuente := terreno.tile_set.get_source(terreno.get_cell_source_id(celda)) as TileSetAtlasSource
	if fuente == null:
		return false
	var datos := fuente.get_tile_data(terreno.get_cell_atlas_coords(celda), 0)
	return datos != null and datos.get_collision_polygons_count(0) > 0
