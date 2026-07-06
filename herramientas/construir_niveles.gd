# =============================================================================
# Herramienta de un solo uso: construye los TileSets del juego a partir de
# assets/tilesets/tileset_01.png y PINTA los niveles como escenas estáticas
# (NivelPradera.tscn y NivelCueva.tscn). Tras ejecutarla, los mapas son
# TileMapLayers normales: se retocan con el pincel del editor.
#
# El TERRENO usa tiles nativos de 32 px (el atlas está dibujado en bloques
# de 32). La DECORACIÓN (arbustos/árboles) no está alineada a 32 en el atlas,
# así que usa una fuente de 16 px en una capa escalada x2.
#   godot --headless --path . --script res://herramientas/construir_niveles.gd
# =============================================================================
extends SceneTree

# ── Terreno: coordenadas en rejilla de 32 px ─────────────────────────────────
const HIERBA_A := Vector2i(21, 5)
const HIERBA_B := Vector2i(22, 5)
const HIERBA_C := Vector2i(21, 11)
const HIERBA_CLARA := Vector2i(1, 23)
const TIERRA := Vector2i(15, 5)
const TIERRA_B := Vector2i(17, 5)
const ARENA := Vector2i(0, 14)
const AGUA := Vector2i(30, 13)
const PIEDRA := Vector2i(17, 30)
const PIEDRA_GRIETA := Vector2i(16, 29)
const MURO_OSCURO := Vector2i(27, 5)
const MURO_OSCURO_B := Vector2i(28, 5)
const AGUA_OSCURA := Vector2i(19, 31)

const SOLIDOS: Array[Vector2i] = [AGUA, MURO_OSCURO, MURO_OSCURO_B, AGUA_OSCURA]

# ── Decoración: coordenadas en rejilla de 16 px, [coordenada, tamaño] ────────
const ARBUSTO_1 := [Vector2i(48, 25), Vector2i(3, 3)]
const ARBUSTO_2 := [Vector2i(51, 25), Vector2i(3, 3)]
const ARBOL := [Vector2i(59, 57), Vector2i(4, 5)]

var _rng := RandomNumberGenerator.new()
var _conjunto_terreno: TileSet
var _conjunto_decoracion: TileSet


func _initialize() -> void:
	_rng.seed = 12345
	var textura := load("res://assets/tilesets/tileset_01.png") as Texture2D
	if textura == null:
		push_error("No se encontró assets/tilesets/tileset_01.png importado.")
		quit(1)
		return
	_conjunto_terreno = _construir_tileset_terreno(textura)
	_conjunto_decoracion = _construir_tileset_decoracion(textura)
	_guardar_recurso(_conjunto_terreno, "res://niveles/tileset_juego.tres")
	_guardar_recurso(_conjunto_decoracion, "res://niveles/tileset_decoracion.tres")
	_construir_pradera()
	_construir_cueva()
	print("Niveles pintados y guardados.")
	quit(0)


# ═════════════════════════════════════════════════════════════ TILESETS ═════

func _construir_tileset_terreno(textura: Texture2D) -> TileSet:
	var conjunto := TileSet.new()
	conjunto.tile_size = Vector2i(32, 32)
	conjunto.add_physics_layer()
	conjunto.set_physics_layer_collision_layer(0, 1)
	var fuente := TileSetAtlasSource.new()
	fuente.texture = textura
	fuente.texture_region_size = Vector2i(32, 32)
	conjunto.add_source(fuente, 0)
	for coordenada in [
		HIERBA_A, HIERBA_B, HIERBA_C, HIERBA_CLARA, TIERRA, TIERRA_B,
		ARENA, AGUA, PIEDRA, PIEDRA_GRIETA, MURO_OSCURO, MURO_OSCURO_B, AGUA_OSCURA,
	]:
		fuente.create_tile(coordenada)
		if coordenada in SOLIDOS:
			var datos := fuente.get_tile_data(coordenada, 0)
			datos.set_collision_polygons_count(0, 1)
			datos.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16),
			]))
	return conjunto


func _construir_tileset_decoracion(textura: Texture2D) -> TileSet:
	var conjunto := TileSet.new()
	conjunto.tile_size = Vector2i(16, 16)
	var fuente := TileSetAtlasSource.new()
	fuente.texture = textura
	fuente.texture_region_size = Vector2i(16, 16)
	conjunto.add_source(fuente, 0)
	for decorado in [ARBUSTO_1, ARBUSTO_2, ARBOL]:
		fuente.create_tile(decorado[0], decorado[1])
	return conjunto


func _guardar_recurso(recurso: Resource, ruta: String) -> void:
	var error := ResourceSaver.save(recurso, ruta)
	if error != OK:
		push_error("No se pudo guardar %s (error %d)." % [ruta, error])
		return
	# Con ruta propia, las escenas lo referencian como recurso EXTERNO
	# compartido (editable una sola vez) en vez de incrustar una copia.
	recurso.take_over_path(ruta)
	print("Guardado: %s" % ruta)


# ═════════════════════════════════════════════════════════════ PRADERA ═════

func _construir_pradera() -> void:
	var suelo := _capa_terreno()
	var decoracion := _capa_decoracion()

	# Isla de hierba rodeada de agua, con playa de arena en la orilla.
	var radio := Vector2(36.0, 21.0)
	for x in range(-42, 43):
		for y in range(-26, 27):
			var celda := Vector2i(x, y)
			var d := (Vector2(x, y) / radio).length()
			if d > 1.0:
				suelo.set_cell(celda, 0, AGUA)
			elif d > 0.9:
				suelo.set_cell(celda, 0, ARENA)
			else:
				suelo.set_cell(celda, 0, _hierba())

	# Camino de tierra de oeste (aparición) a este (portal).
	for x in range(-30, 36):
		for y in range(-1, 2):
			suelo.set_cell(Vector2i(x, y), 0, TIERRA if (x + y) % 2 == 0 else TIERRA_B)

	# Claros de hierba clara para variar.
	for centro in [Vector2i(-15, -12), Vector2i(12, 10), Vector2i(20, -10)]:
		_mancha(suelo, centro, 4, HIERBA_CLARA)

	# Arbustos y árboles repartidos (la capa de decoración va escalada x2,
	# así que sus celdas de 16 px coinciden con las de 32 px del terreno).
	for celda in [
		Vector2i(-20, -8), Vector2i(-5, 8), Vector2i(15, -14), Vector2i(25, 8),
	]:
		decoracion.set_cell(celda, 0, ARBUSTO_1[0] if _rng.randf() < 0.5 else ARBUSTO_2[0])
	for celda in [Vector2i(-28, -14), Vector2i(-10, -18), Vector2i(8, 12), Vector2i(28, -6)]:
		decoracion.set_cell(celda, 0, ARBOL[0])

	_guardar_nivel(
		"res://niveles/NivelPradera.tscn", "NivelPradera", "Pradera",
		[suelo, decoracion],
		Vector2(-800, 0),
		[
			["res://enemigos/EnemigoLobo.tscn", Vector2(500, 240)],
			["res://enemigos/EnemigoAraña.tscn", Vector2(100, -440)],
			["res://enemigos/EnemigoRaton.tscn", Vector2(-500, 400)],
			["res://enemigos/EnemigoRaton.tscn", Vector2(-200, -300)],
		],
		[["PortalACueva", Vector2(1080, 0), "res://niveles/NivelCueva.tscn", "→ Cueva"]],
	)


# ═════════════════════════════════════════════════════════════ CUEVA ════════

func _construir_cueva() -> void:
	var suelo := _capa_terreno()

	# Caverna: suelo de losa en una elipse, rodeado de muro oscuro.
	var radio := Vector2(27.0, 17.0)
	for x in range(-32, 33):
		for y in range(-21, 22):
			var celda := Vector2i(x, y)
			var d := (Vector2(x, y) / radio).length()
			if d > 1.0:
				suelo.set_cell(celda, 0, MURO_OSCURO if (x + y) % 2 == 0 else MURO_OSCURO_B)
			else:
				suelo.set_cell(celda, 0, PIEDRA if _rng.randf() < 0.88 else PIEDRA_GRIETA)

	# Lago subterráneo.
	_mancha(suelo, Vector2i(8, 8), 5, AGUA_OSCURA)

	_guardar_nivel(
		"res://niveles/NivelCueva.tscn", "NivelCueva", "Cueva",
		[suelo],
		Vector2(680, 0),
		[
			["res://enemigos/EnemigoLobo.tscn", Vector2(-400, -240)],
			["res://enemigos/EnemigoLobo.tscn", Vector2(-360, 300)],
			["res://enemigos/EnemigoAraña.tscn", Vector2(120, -200)],
		],
		[["PortalAPradera", Vector2(-720, 0), "res://niveles/NivelPradera.tscn", "→ Pradera"]],
	)


# ═════════════════════════════════════════════════════════ CONSTRUCCIÓN ═════

func _capa_terreno() -> TileMapLayer:
	var capa := TileMapLayer.new()
	capa.name = "Terreno"
	capa.tile_set = _conjunto_terreno
	capa.z_index = -10
	capa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return capa


func _capa_decoracion() -> TileMapLayer:
	var capa := TileMapLayer.new()
	capa.name = "Decoracion"
	capa.tile_set = _conjunto_decoracion
	capa.z_index = -9
	# La decoración está en rejilla de 16 px en el atlas: se escala x2 para
	# que cada celda coincida con las celdas de 32 px del terreno.
	capa.scale = Vector2(2, 2)
	capa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return capa


func _hierba() -> Vector2i:
	var tirada := _rng.randf()
	if tirada < 0.5:
		return HIERBA_A
	return HIERBA_B if tirada < 0.85 else HIERBA_C


func _mancha(capa: TileMapLayer, centro: Vector2i, radio: int, coordenada: Vector2i) -> void:
	for dx in range(-radio, radio + 1):
		for dy in range(-radio, radio + 1):
			if Vector2(dx, dy).length() <= float(radio):
				capa.set_cell(centro + Vector2i(dx, dy), 0, coordenada)


func _guardar_nivel(
	ruta: String,
	nombre_nodo: String,
	nombre_nivel: String,
	capas: Array,
	posicion_aparicion: Vector2,
	enemigos: Array,
	portales: Array,
) -> void:
	var raiz := Node2D.new()
	raiz.name = nombre_nodo
	raiz.set_script(load("res://niveles/NivelBase.gd"))
	raiz.set("nombre_nivel", nombre_nivel)

	for capa in capas:
		raiz.add_child(capa)
		capa.owner = raiz

	var aparicion := Marker2D.new()
	aparicion.name = "PuntoAparicion"
	aparicion.position = posicion_aparicion
	raiz.add_child(aparicion)
	aparicion.owner = raiz

	var contenedor_enemigos := Node2D.new()
	contenedor_enemigos.name = "Enemigos"
	raiz.add_child(contenedor_enemigos)
	contenedor_enemigos.owner = raiz
	for datos in enemigos:
		var enemigo := (load(datos[0]) as PackedScene).instantiate()
		enemigo.position = datos[1]
		contenedor_enemigos.add_child(enemigo)
		enemigo.owner = raiz

	for datos in portales:
		var portal := (load("res://niveles/PortalNivel.tscn") as PackedScene).instantiate()
		portal.name = datos[0]
		portal.position = datos[1]
		portal.set("ruta_nivel_destino", datos[2])
		portal.set("etiqueta", datos[3])
		raiz.add_child(portal)
		portal.owner = raiz

	var empaquetada := PackedScene.new()
	var error := empaquetada.pack(raiz)
	if error == OK:
		error = ResourceSaver.save(empaquetada, ruta)
	if error != OK:
		push_error("No se pudo guardar %s (error %d)." % [ruta, error])
	else:
		print("Nivel guardado: %s" % ruta)
	raiz.free()
