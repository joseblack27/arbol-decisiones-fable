# =============================================================================
# Herramienta: añade a cada nivel una capa "Navegacion" (TileMapLayer con
# tileset_colisiones.tres) que sirve de única fuente de verdad para el
# pathfinding: los NavigationAgent2D (ver MovimientoComponente) solo leen la
# malla de esta capa (máscara de navegación 2), no la de Terreno.
#
# Se rellena por defecto con la ficha "Libre" (transparente, caminable) en
# toda celda donde Terreno sea transitable (misma regla que agua/muros:
# tiles con colisión física quedan fuera). Sobre esa base, PINTA A MANO en
# el editor las fichas de colisiones.png donde quieras un obstáculo (p. ej.
# bajo un árbol): eso abre un agujero en la malla Y añade colisión física,
# sin tocar el TileMapLayer de Terreno.
#
# Idempotente para la parte "Libre": puedes re-ejecutarla tras redibujar el
# Terreno; NO toca fichas ya pintadas a mano en Navegacion (solo añade
# "Libre" donde la celda está vacía).
#
# TAMBIÉN recorta: cualquier celda de Navegacion sin celda correspondiente
# en Terreno se borra — bug real reportado ("una araña está fuera del
# mapa"): Navegacion nació sobredimensionada en varios niveles (Pradera,
# Cueva, NidoArañaReina — hasta ~3.4x más ancha/3.2x más alta que el mapa
# real, probablemente copiada entre escenas alguna vez sin recortar), así
# que SpawnerMobs/MovimientoComponente daban por válida una franja
# "caminable" bien afuera del mapa visible. Este recorte corre SIEMPRE
# (no solo la primera vez que se crea la capa): a diferencia de agregar
# "Libre" (aditivo, seguro re-ejecutar), acá si Terreno se redibuja más
# chico después, las celdas viejas de Navegacion que quedaron huérfanas
# también deben desaparecer.
#   godot --headless --path . --script res://herramientas/generar_capa_navegacion.gd
# =============================================================================
extends SceneTree

const NIVELES: Array[String] = [
	"res://escenas/niveles/NivelPradera.tscn",
	"res://escenas/niveles/NivelCueva.tscn",
	"res://escenas/niveles/NivelNidoArañaReina.tscn",
]
const RUTA_TILESET_NAV := "res://escenas/niveles/tileset_colisiones.tres"


func _initialize() -> void:
	for ruta in NIVELES:
		_procesar(ruta)
	quit(0)


func _procesar(ruta: String) -> void:
	var nivel := (load(ruta) as PackedScene).instantiate()
	var terreno := nivel.get_node_or_null("Terreno") as TileMapLayer
	if terreno == null:
		push_error("%s: no tiene nodo Terreno." % ruta)
		nivel.free()
		return

	var navegacion := nivel.get_node_or_null("Navegacion") as TileMapLayer
	var era_nueva := navegacion == null
	if navegacion == null:
		navegacion = TileMapLayer.new()
		navegacion.name = "Navegacion"
		navegacion.tile_set = load(RUTA_TILESET_NAV)
		# Invisible en juego: es una capa lógica de colisión/navegación, no
		# arte. Cambia a 1.0 mientras ajustas la posición de los obstáculos.
		navegacion.modulate.a = 0.0
		nivel.add_child(navegacion)
		navegacion.owner = nivel
		nivel.move_child(navegacion, terreno.get_index() + 1)

	var tam_terreno := terreno.tile_set.tile_size
	var tam_nav := navegacion.tile_set.tile_size
	var celdas_por_lado := tam_terreno.x / tam_nav.x

	var pintadas := 0
	for celda in terreno.get_used_cells():
		if _es_solido(terreno, celda):
			continue
		var origen_nav := celda * celdas_por_lado
		for dx in celdas_por_lado:
			for dy in celdas_por_lado:
				var celda_nav := origen_nav + Vector2i(dx, dy)
				if navegacion.get_cell_source_id(celda_nav) != -1:
					continue  # Ya pintada a mano (obstáculo u otra cosa): no tocar.
				navegacion.set_cell(celda_nav, 0, Vector2i.ZERO)
				pintadas += 1

	var recortadas := _recortar_huerfanas(terreno, navegacion, celdas_por_lado)

	var empaquetada := PackedScene.new()
	var error := empaquetada.pack(nivel)
	if error == OK:
		error = ResourceSaver.save(empaquetada, ruta)
	if error != OK:
		push_error("No se pudo guardar %s (error %d)." % [ruta, error])
	else:
		print("%s: Navegacion %s, %d celdas 'Libre' añadidas, %d celdas huérfanas recortadas." % [
			ruta, "creada" if era_nueva else "actualizada", pintadas, recortadas,
		])
	nivel.free()


## Borra cualquier celda de Navegacion cuya celda de Terreno correspondiente
## (invirtiendo el mismo mapeo que arriba: celda_nav -> celda_terreno) NO
## esté entre las usadas de Terreno — sin importar si esa celda de
## Navegacion es "Libre" o una ficha de obstáculo pintada a mano, Navegacion
## nunca debería extenderse más allá de donde Terreno de verdad pintó algo.
## División con floori(): Vector2i "/" trunca hacia cero, no hacia abajo —
## con coordenadas negativas (habitual acá, el origen del mapa suele quedar
## a mitad de camino) truncar mal desplazaría el recorte una celda en el
## borde negativo.
func _recortar_huerfanas(terreno: TileMapLayer, navegacion: TileMapLayer, celdas_por_lado: int) -> int:
	var celdas_terreno := {}
	for celda in terreno.get_used_cells():
		celdas_terreno[celda] = true

	var recortadas := 0
	for celda_nav in navegacion.get_used_cells():
		var celda_terreno := Vector2i(
			floori(float(celda_nav.x) / celdas_por_lado),
			floori(float(celda_nav.y) / celdas_por_lado)
		)
		if not celdas_terreno.has(celda_terreno):
			navegacion.erase_cell(celda_nav)
			recortadas += 1
	return recortadas


func _es_solido(terreno: TileMapLayer, celda: Vector2i) -> bool:
	var fuente := terreno.tile_set.get_source(terreno.get_cell_source_id(celda)) as TileSetAtlasSource
	if fuente == null:
		return false
	var datos := fuente.get_tile_data(terreno.get_cell_atlas_coords(celda), 0)
	return datos != null and datos.get_collision_polygons_count(0) > 0
