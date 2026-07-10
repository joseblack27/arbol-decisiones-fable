# =============================================================================
# Herramienta: construye niveles/tileset_colisiones.tres a partir de
# assets/tilesets/colisiones.png. Cada silueta opaca del atlas (detectada por
# conectividad de píxeles) se convierte en un tile con un polígono de física
# que seduce la forma (envolvente convexa), en una rejilla de 8px.
#
# Además crea la ficha "Libre" (transparente, generada en memoria: no
# necesita archivo aparte) con polígono de NAVEGACIÓN de celda completa y
# SIN colisión física: es el suelo caminable de la capa Navegacion.
#
# Canales:
#   - Física:     collision_layer = 1 ("mundo", el mismo que usan agua/muros
#                 de tileset_juego), en las fichas-silueta. "Libre" no
#                 tiene física.
#   - Navegación: capa dedicada con máscara = 2 (ver MovimientoComponente),
#                 SOLO en la ficha "Libre". Las siluetas no llevan polígono
#                 de navegación: son el agujero en la malla.
#
# Reglas de la rejilla: los tiles se registran en unidades de 8px porque las
# siluetas del atlas no siempre caen en múltiplos de 16 (una mide 16x16 en
# x=168..183, que no es múltiplo de 16 pero sí de 8).
#   godot --headless --path . --script res://herramientas/construir_tileset_colisiones.gd
# =============================================================================
extends SceneTree

const RUTA_ATLAS := "res://assets/tilesets/colisiones.png"
const RUTA_SALIDA := "res://escenas/niveles/tileset_colisiones.tres"
const TAM_CELDA := 8
## Máscara de navegación dedicada a esta capa (ver MovimientoComponente.MASCARA_NAVEGACION).
const MASCARA_NAVEGACION := 2
## Capa física "mundo": la misma que usan agua y muros del terreno principal.
const CAPA_FISICA_MUNDO := 1


func _initialize() -> void:
	# Cargar como recurso importado (no load_from_file: evita el warning de
	# exportación y usa la textura tal como la vería el juego).
	var textura := load(RUTA_ATLAS) as Texture2D
	if textura == null:
		push_error("No se encontró %s importado." % RUTA_ATLAS)
		quit(1)
		return
	var imagen := textura.get_image()

	var conjunto := TileSet.new()
	conjunto.tile_size = Vector2i(TAM_CELDA, TAM_CELDA)
	conjunto.add_physics_layer()
	conjunto.set_physics_layer_collision_layer(0, CAPA_FISICA_MUNDO)
	conjunto.add_navigation_layer()
	conjunto.set_navigation_layer_layers(0, MASCARA_NAVEGACION)

	_crear_fuente_libre(conjunto)
	var siluetas := _crear_fuente_siluetas(conjunto, textura, imagen)

	var error := ResourceSaver.save(conjunto, RUTA_SALIDA)
	if error != OK:
		push_error("No se pudo guardar el TileSet (error %d)." % error)
		quit(1)
		return
	print("tileset_colisiones.tres generado: 1 ficha libre + %d siluetas." % siluetas)
	quit(0)


## Fuente 0: una única ficha transparente (imagen generada en memoria) que
## representa el suelo caminable. Al no tener archivo en disco, el .tres
## queda autocontenido.
func _crear_fuente_libre(conjunto: TileSet) -> void:
	var imagen_vacia := Image.create(TAM_CELDA, TAM_CELDA, false, Image.FORMAT_RGBA8)
	imagen_vacia.fill(Color(0, 0, 0, 0))
	var fuente := TileSetAtlasSource.new()
	fuente.texture = ImageTexture.create_from_image(imagen_vacia)
	fuente.texture_region_size = Vector2i(TAM_CELDA, TAM_CELDA)
	conjunto.add_source(fuente, 0)

	fuente.create_tile(Vector2i.ZERO)
	var datos := fuente.get_tile_data(Vector2i.ZERO, 0)
	var mitad := TAM_CELDA / 2.0
	var poligono := NavigationPolygon.new()
	poligono.vertices = PackedVector2Array([
		Vector2(-mitad, -mitad), Vector2(mitad, -mitad),
		Vector2(mitad, mitad), Vector2(-mitad, mitad),
	])
	poligono.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	datos.set_navigation_polygon(0, poligono)


## Una fuente de atlas POR silueta (en vez de compartir una sola fuente):
## dos siluetas no conectadas por píxeles pueden tener cajas delimitadoras
## que se solapan en el atlas (ocurre con blob1 y blob8 de colisiones.png),
## y una fuente única no admite fichas cuyo rectángulo se pise. Con una
## fuente por silueta, cada una reserva su propio espacio de forma
## independiente; "margins" la ancla al recorte exacto de la textura.
func _crear_fuente_siluetas(conjunto: TileSet, textura: Texture2D, imagen: Image) -> int:
	var blobs := _detectar_siluetas(imagen)
	var id_fuente := 1
	for blob in blobs:
		var origen: Vector2i = blob["origen"]
		var tamano: Vector2i = blob["tamano"]
		var size_en_atlas := Vector2i(
			ceili(float(tamano.x) / TAM_CELDA), ceili(float(tamano.y) / TAM_CELDA)
		)

		var fuente := TileSetAtlasSource.new()
		fuente.texture = textura
		fuente.texture_region_size = Vector2i(TAM_CELDA, TAM_CELDA)
		fuente.margins = origen
		conjunto.add_source(fuente, id_fuente)
		id_fuente += 1

		fuente.create_tile(Vector2i.ZERO, size_en_atlas)
		var datos := fuente.get_tile_data(Vector2i.ZERO, 0)

		var centro := Vector2(origen) + Vector2(tamano) / 2.0
		var puntos_locales := PackedVector2Array()
		for punto: Vector2 in blob["envolvente"]:
			puntos_locales.append(punto - centro)
		datos.set_collision_polygons_count(0, 1)
		datos.set_collision_polygon_points(0, 0, puntos_locales)
	return blobs.size()


## Detecta regiones de píxeles opacos conectados (4-vecindad) y para cada una
## calcula su caja delimitadora y la envolvente convexa de sus píxeles.
func _detectar_siluetas(imagen: Image) -> Array[Dictionary]:
	var ancho := imagen.get_width()
	var alto := imagen.get_height()
	var visitado := {}
	var resultado: Array[Dictionary] = []

	for y in alto:
		for x in ancho:
			var clave := Vector2i(x, y)
			if visitado.has(clave) or imagen.get_pixel(x, y).a < 0.5:
				continue
			var pila: Array[Vector2i] = [clave]
			visitado[clave] = true
			var minimo := clave
			var maximo := clave
			var puntos: Array[Vector2] = []
			while not pila.is_empty():
				var p: Vector2i = pila.pop_back()
				minimo = Vector2i(mini(minimo.x, p.x), mini(minimo.y, p.y))
				maximo = Vector2i(maxi(maximo.x, p.x), maxi(maximo.y, p.y))
				# Cuatro esquinas del píxel: dan una envolvente fiel al borde real.
				puntos.append(Vector2(p.x, p.y))
				puntos.append(Vector2(p.x + 1, p.y))
				puntos.append(Vector2(p.x, p.y + 1))
				puntos.append(Vector2(p.x + 1, p.y + 1))
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var np: Vector2i = p + d
					if np.x < 0 or np.y < 0 or np.x >= ancho or np.y >= alto:
						continue
					if visitado.has(np) or imagen.get_pixel(np.x, np.y).a < 0.5:
						continue
					visitado[np] = true
					pila.append(np)
			var envolvente := Geometry2D.convex_hull(puntos)
			resultado.append({
				"origen": minimo,
				"tamano": maximo - minimo + Vector2i(1, 1),
				"envolvente": envolvente,
			})
	return resultado
