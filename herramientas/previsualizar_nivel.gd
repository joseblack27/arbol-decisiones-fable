# =============================================================================
# Herramienta: compone una imagen PNG de los niveles pintados (sin renderizador,
# copiando los tiles del atlas celda a celda) para revisarlos visualmente.
# Respeta la escala de cada capa (terreno 32 px nativo, decoración 16 px x2).
#   godot --headless --path . --script res://herramientas/previsualizar_nivel.gd
# =============================================================================
extends SceneTree


func _initialize() -> void:
	var atlas := Image.load_from_file("res://assets/tilesets/tileset_01.png")
	_previsualizar(atlas, "res://niveles/NivelPradera.tscn", "res://previsualizacion_pradera.png")
	_previsualizar(atlas, "res://niveles/NivelCueva.tscn", "res://previsualizacion_cueva.png")
	quit(0)


func _previsualizar(atlas: Image, ruta_nivel: String, ruta_salida: String) -> void:
	var nivel := (load(ruta_nivel) as PackedScene).instantiate()
	var capas: Array[TileMapLayer] = []
	for hijo in nivel.get_children():
		if hijo is TileMapLayer:
			capas.append(hijo)

	# Rectángulo usado total en píxeles de mundo.
	var minimo := Vector2(1e9, 1e9)
	var maximo := Vector2(-1e9, -1e9)
	for capa in capas:
		var paso := Vector2(capa.tile_set.tile_size) * capa.scale
		for celda in capa.get_used_cells():
			var origen := Vector2(celda) * paso
			minimo = minimo.min(origen)
			maximo = maximo.max(origen + paso)

	var tamano := Vector2i(maximo - minimo)
	var imagen := Image.create(tamano.x, tamano.y, false, Image.FORMAT_RGBA8)
	for capa in capas:
		var fuente := capa.tile_set.get_source(0) as TileSetAtlasSource
		var paso := Vector2(capa.tile_set.tile_size) * capa.scale
		var escala := int(capa.scale.x)
		for celda in capa.get_used_cells():
			var region := fuente.get_tile_texture_region(capa.get_cell_atlas_coords(celda), 0)
			var destino := Vector2i(Vector2(celda) * paso - minimo)
			if escala == 1:
				imagen.blend_rect(atlas, region, destino)
			else:
				var trozo := atlas.get_region(region)
				trozo.resize(region.size.x * escala, region.size.y * escala, Image.INTERPOLATE_NEAREST)
				imagen.blend_rect(trozo, Rect2i(Vector2i.ZERO, trozo.get_size()), destino)

	imagen.save_png(ruta_salida)
	print("Previsualización: %s (%dx%d)" % [ruta_salida, tamano.x, tamano.y])
	nivel.free()
