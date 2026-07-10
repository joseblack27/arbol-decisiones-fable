# =============================================================================
# Herramienta: construye niveles/tileset_mundo.tres a partir del atlas
# assets/tiles_mundo.png (generado por generar_tiles_png.gd + --import).
# Los tiles sólidos (agua y muros) reciben colisión completa en la capa 1.
#   godot --headless --path . --script res://herramientas/generar_tileset.gd
# =============================================================================
extends SceneTree

const CANTIDAD_TILES := 11
## Índices de tiles que bloquean el paso: agua, roca, agua de cueva, muro de cueva.
const SOLIDOS: Array[int] = [4, 5, 9, 10]


func _initialize() -> void:
	var textura := load("res://assets/tiles_mundo.png") as Texture2D
	if textura == null:
		push_error("Atlas no importado aún. Ejecuta generar_tiles_png.gd y luego --import.")
		quit(1)
		return

	var conjunto := TileSet.new()
	conjunto.tile_size = Vector2i(32, 32)
	conjunto.add_physics_layer()
	conjunto.set_physics_layer_collision_layer(0, 1)

	var fuente := TileSetAtlasSource.new()
	fuente.texture = textura
	fuente.texture_region_size = Vector2i(32, 32)
	# El origen debe pertenecer al TileSet ANTES de tocar colisiones:
	# los TileData heredan las capas físicas del conjunto.
	conjunto.add_source(fuente, 0)

	var cuadrado := PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16),
	])
	for indice in CANTIDAD_TILES:
		var coordenada := Vector2i(indice, 0)
		fuente.create_tile(coordenada)
		if indice in SOLIDOS:
			var datos := fuente.get_tile_data(coordenada, 0)
			datos.set_collision_polygons_count(0, 1)
			datos.set_collision_polygon_points(0, 0, cuadrado)

	DirAccess.make_dir_recursive_absolute("res://niveles")
	var error := ResourceSaver.save(conjunto, "res://escenas/niveles/tileset_mundo.tres")
	if error != OK:
		push_error("No se pudo guardar el TileSet (error %d)." % error)
		quit(1)
		return
	print("TileSet generado: res://escenas/niveles/tileset_mundo.tres")
	quit(0)
