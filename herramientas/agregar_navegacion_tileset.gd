# =============================================================================
# Herramienta: añade polígonos de navegación a niveles/tileset_juego.tres.
# Regla: todo tile SIN colisión física (hierba, tierra, arena, losa...) recibe
# un polígono de celda completa; los sólidos (agua, muros) quedan fuera, así
# la malla de navegación rodea los obstáculos del mapa automáticamente.
# Es idempotente: se puede re-ejecutar tras añadir tiles nuevos al TileSet.
#   godot --headless --path . --script res://herramientas/agregar_navegacion_tileset.gd
# =============================================================================
extends SceneTree

const RUTA_TILESET := "res://niveles/tileset_juego.tres"


func _initialize() -> void:
	var conjunto := load(RUTA_TILESET) as TileSet
	if conjunto == null:
		push_error("No se pudo cargar %s." % RUTA_TILESET)
		quit(1)
		return

	if conjunto.get_navigation_layers_count() == 0:
		conjunto.add_navigation_layer()

	# Polígono de celda completa (32x32 centrado), compartido por los tiles.
	var mitad := float(conjunto.tile_size.x) / 2.0
	var poligono := NavigationPolygon.new()
	poligono.vertices = PackedVector2Array([
		Vector2(-mitad, -mitad), Vector2(mitad, -mitad),
		Vector2(mitad, mitad), Vector2(-mitad, mitad),
	])
	poligono.add_polygon(PackedInt32Array([0, 1, 2, 3]))

	var caminables := 0
	var solidos := 0
	for indice_fuente in conjunto.get_source_count():
		var fuente := conjunto.get_source(conjunto.get_source_id(indice_fuente)) as TileSetAtlasSource
		if fuente == null:
			continue
		for indice_tile in fuente.get_tiles_count():
			var coordenada := fuente.get_tile_id(indice_tile)
			var datos := fuente.get_tile_data(coordenada, 0)
			var es_solido := conjunto.get_physics_layers_count() > 0 \
				and datos.get_collision_polygons_count(0) > 0
			if es_solido:
				solidos += 1
				datos.set_navigation_polygon(0, null)
			else:
				caminables += 1
				datos.set_navigation_polygon(0, poligono)

	var error := ResourceSaver.save(conjunto, RUTA_TILESET)
	if error != OK:
		push_error("No se pudo guardar el TileSet (error %d)." % error)
		quit(1)
		return
	print("Navegación añadida: %d tiles caminables, %d sólidos excluidos." % [caminables, solidos])
	quit(0)
