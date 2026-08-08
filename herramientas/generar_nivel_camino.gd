# =============================================================================
# generar_nivel_camino.gd — construye escenas/niveles/NivelCamino.tscn.
#
# El nivel es el CAMINO que comunica un pueblo (al oeste) con un castillo (al
# este): a propósito NO se ve ni el pueblo ni el castillo, sólo el tramo de
# camino entre ambos. El empedrado cruza el centro de lado a lado y todo lo
# demás es campo abierto con arboledas, para que haya sitio de sobra donde
# repartir mobs.
#
# Se genera por script y no a mano porque son ~48.000 celdas: pintarlas en el
# editor sería eterno y, sobre todo, irrepetible. Para cambiar el tamaño, el
# ancho del camino o la cantidad de mobs se tocan las constantes de acá y se
# vuelve a correr:
#   godot --headless --path . --script res://herramientas/generar_nivel_camino.gd
#
# Convenciones copiadas de NivelPradera.tscn (ver ahí):
#   • Terreno  — sólo visual (collision_enabled y navigation_enabled en false).
#   • Colision — invisible, navigation_enabled=false: sus tiles aportan SOLO
#                colisión (la maleza que encierra el nivel).
# El tile 4,2 de la fuente 8 de tileset_colisiones.tres es un cuadrado completo.
#
# La NAVEGACIÓN, en cambio, NO se hace con tiles acá: ver _crear_navegacion().
# =============================================================================
extends SceneTree

const RUTA_SALIDA := "res://escenas/niveles/NivelCamino.tscn"

const TILESET_JUEGO := "res://escenas/niveles/tileset_juego.tres"
const TILESET_COLISIONES := "res://escenas/niveles/tileset_colisiones.tres"
const ESCENA_PORTAL := "res://escenas/niveles/PortalNivel.tscn"
const ESCENA_DECORACION := "res://escenas/niveles/DecoracionOcluible.tscn"
const GUION_SPAWNER := "res://escenas/enemigos/SpawnerMobs.gd"

# ── Forma del nivel (en tiles de 32 px) ──────────────────────────────────────
const ANCHO := 220          # 7.040 px
const ALTO := 220           # 7.040 px — mapa cuadrado
const MITAD_X := ANCHO / 2
const MITAD_Y := ALTO / 2
## Última fila/columna transitable; más allá empieza la maleza sólida que
## encierra el mapa por los cuatro lados.
const BORDE_TRANSITABLE := 105
const GROSOR_MALEZA := 4
## Semiancho base del empedrado: queda entre 18 y 26 tiles (576-832 px) de
## camino con la ondulación. El mapa creció a 220x220 pero el camino conserva
## este ancho a pedido del usuario — cruza el centro y el resto es campo.
const SEMIANCHO_CAMINO := 11

## Máscara de la capa de navegación que usan los agentes de los mobs (ver
## MovimientoComponente.MASCARA_NAVEGACION). Si no coincide, los mobs ignoran
## la malla y caminan en línea recta.
const MASCARA_NAVEGACION := 2

# ── Paleta (coordenadas del atlas tileset_01.png) ────────────────────────────
# OJO al elegir tiles: muchos del atlas son BORDES con transparencia y, usados
# como relleno, dejan agujeros negros por los que se ve el vacío (pasó en la
# primera versión de este nivel). Todos los de acá están verificados como 100%
# opacos. El pasto es además el mismo que usa la Pradera, para que los dos
# niveles se vean del mismo juego.
const EMPEDRADO := [Vector2i(1, 16), Vector2i(2, 16), Vector2i(3, 16),
	Vector2i(1, 17), Vector2i(2, 17), Vector2i(3, 17)]
const TIERRA := [Vector2i(9, 22), Vector2i(10, 22), Vector2i(9, 23)]
const PASTO := [Vector2i(21, 5), Vector2i(22, 5), Vector2i(23, 5),
	Vector2i(21, 11), Vector2i(22, 11)]
const MALEZA := [Vector2i(10, 17), Vector2i(10, 18), Vector2i(25, 16)]

const FUENTE_COLISION := 8
const TILE_SOLIDO := Vector2i(4, 2)

# ── Población ────────────────────────────────────────────────────────────────
const COLUMNAS_SPAWNER := [-85, -51, -17, 17, 51, 85]
const FILAS_SPAWNER := [-70, 0, 70]
const MOBS_POR_SPAWNER := 5
const ARBOLEDAS := 42

var _rng := RandomNumberGenerator.new()


func _process(_d: float) -> bool:
	_rng.seed = 20260731

	var raiz := Node2D.new()
	raiz.name = "NivelCamino"
	raiz.set_script(load("res://escenas/niveles/NivelBase.gd"))
	raiz.set("nombre_nivel", "Camino")
	raiz.y_sort_enabled = true

	var terreno := _crear_capa("Terreno", TILESET_JUEGO, raiz)
	terreno.z_index = -10
	terreno.y_sort_enabled = true
	terreno.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terreno.collision_enabled = false
	terreno.navigation_enabled = false

	var colision := _crear_capa("Colision", TILESET_COLISIONES, raiz)
	colision.visible = false
	colision.navigation_enabled = false

	_pintar(terreno, colision)
	_crear_navegacion(raiz)

	var decoraciones := Node2D.new()
	decoraciones.name = "Decoraciones"
	decoraciones.y_sort_enabled = true
	raiz.add_child(decoraciones)
	decoraciones.owner = raiz
	_plantar_arboles(decoraciones, raiz)

	# Aparición y portal, los dos en el extremo OESTE (el lado del pueblo).
	var aparicion := Marker2D.new()
	aparicion.name = "PuntoAparicion"
	aparicion.position = Vector2(_tile_a_px(-MITAD_X + 9), 0)
	raiz.add_child(aparicion)
	aparicion.owner = raiz

	var portal := (load(ESCENA_PORTAL) as PackedScene).instantiate()
	portal.name = "PortalAPradera"
	portal.position = Vector2(_tile_a_px(-MITAD_X + 5), 0)
	portal.set("ruta_nivel_destino", "res://escenas/niveles/NivelPradera.tscn")
	portal.set("etiqueta", "→ Pradera")
	raiz.add_child(portal)
	portal.owner = raiz

	var enemigos := Node2D.new()
	enemigos.name = "Enemigos"
	enemigos.y_sort_enabled = true
	raiz.add_child(enemigos)
	enemigos.owner = raiz
	_poblar(enemigos, raiz)

	var escena := PackedScene.new()
	if escena.pack(raiz) != OK:
		push_error("No se pudo empaquetar el nivel.")
		quit(1)
		return true
	if ResourceSaver.save(escena, RUTA_SALIDA) != OK:
		push_error("No se pudo guardar %s" % RUTA_SALIDA)
		quit(1)
		return true

	print("Guardado %s" % RUTA_SALIDA)
	print("  %d x %d tiles (%d x %d px)" % [ANCHO, ALTO, ANCHO * 32, ALTO * 32])
	print("  celdas: terreno=%d colision=%d" % [
		terreno.get_used_cells().size(), colision.get_used_cells().size()])
	print("  aparicion=%s portal=%s" % [aparicion.position, portal.position])
	quit(0)
	return true


func _crear_capa(nombre: String, ruta_tileset: String, raiz: Node) -> TileMapLayer:
	var capa := TileMapLayer.new()
	capa.name = nombre
	capa.tile_set = load(ruta_tileset)
	raiz.add_child(capa)
	capa.owner = raiz
	return capa


func _tile_a_px(tile: int) -> float:
	return tile * 32.0 + 16.0


## Semiancho del empedrado en la columna x: ondula suave para que el camino no
## sea un rectángulo perfecto y se lea como un camino de verdad.
func _semiancho_en(x: int) -> int:
	var onda := sin(x * 0.045) * 1.6 + sin(x * 0.011) * 1.2
	return SEMIANCHO_CAMINO + int(round(onda))


## true si esa celda queda fuera del anillo de maleza que encierra el mapa.
func _es_maleza(x: int, y: int) -> bool:
	return absi(y) > BORDE_TRANSITABLE or absi(x) > MITAD_X - GROSOR_MALEZA


func _pintar(terreno: TileMapLayer, colision: TileMapLayer) -> void:
	for ix in ANCHO:
		var x := ix - MITAD_X
		var semiancho := _semiancho_en(x)
		for iy in ALTO:
			var y := iy - MITAD_Y
			var celda := Vector2i(x, y)
			if _es_maleza(x, y):
				terreno.set_cell(celda, 0, _al_azar(MALEZA))
				colision.set_cell(celda, FUENTE_COLISION, TILE_SOLIDO)
				continue
			var distancia := absi(y)
			if distancia <= semiancho:
				terreno.set_cell(celda, 0, _al_azar(EMPEDRADO))
			elif distancia <= semiancho + 1:
				# Banquina de tierra: transición entre empedrado y pasto.
				terreno.set_cell(celda, 0, _al_azar(TIERRA))
			else:
				terreno.set_cell(celda, 0, _al_azar(PASTO))


## Navegación con UNA sola región rectangular en vez de un tile por celda.
##
## La capa de tiles que usan los otros niveles crea una región de navegación
## POR CELDA: en la Pradera son 2.182 y se banca, pero acá el área transitable
## son ~44.000 celdas y otras tantas regiones que el NavigationServer tendría
## que sincronizar — carísimo, y el servidor corre con un solo núcleo. Como la
## zona caminable de este nivel es un rectángulo limpio (todo menos el anillo
## de maleza), alcanza con un polígono de cuatro vértices.
func _crear_navegacion(raiz: Node) -> void:
	var region := NavigationRegion2D.new()
	region.name = "Navegacion"
	region.navigation_layers = MASCARA_NAVEGACION

	# Un margen hacia adentro para que los agentes no rocen la maleza.
	var margen := 24.0
	var x0 := (-MITAD_X + GROSOR_MALEZA) * 32.0 + margen
	var x1 := (MITAD_X - GROSOR_MALEZA) * 32.0 - margen
	var y0 := -BORDE_TRANSITABLE * 32.0 + margen
	var y1 := (BORDE_TRANSITABLE + 1) * 32.0 - margen

	var poligono := NavigationPolygon.new()
	poligono.vertices = PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	poligono.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = poligono

	raiz.add_child(region)
	region.owner = raiz
	print("  navegacion: 1 region de %.0f x %.0f px" % [x1 - x0, y1 - y0])


func _al_azar(opciones: Array) -> Vector2i:
	return opciones[_rng.randi_range(0, opciones.size() - 1)]


## Arboledas repartidas por el campo, NUNCA sobre el empedrado ni sus
## banquinas: el camino queda despejado para pelear, que es para lo que se
## pidió ancho. Van en grupos y no sueltas de a una porque un campo enorme con
## árboles perfectamente esparcidos se ve artificial.
func _plantar_arboles(contenedor: Node2D, raiz: Node) -> void:
	var escena := load(ESCENA_DECORACION) as PackedScene
	var n := 0
	for _i in ARBOLEDAS:
		var cx := _rng.randi_range(-MITAD_X + GROSOR_MALEZA + 3, MITAD_X - GROSOR_MALEZA - 3)
		var cy := _rng.randi_range(-BORDE_TRANSITABLE + 3, BORDE_TRANSITABLE - 3)
		# Fuera del camino y su banquina, con un respiro de 3 tiles.
		if absi(cy) <= _semiancho_en(cx) + 4:
			continue
		for _j in _rng.randi_range(2, 6):
			var arbol := escena.instantiate()
			arbol.name = "Arbol%d" % n
			arbol.position = Vector2(
				_tile_a_px(cx) + _rng.randf_range(-140.0, 140.0),
				_tile_a_px(cy) + _rng.randf_range(-110.0, 110.0))
			arbol.scale = Vector2(1.6, 1.6)
			contenedor.add_child(arbol)
			arbol.owner = raiz
			n += 1
	print("  árboles: %d" % n)


## Generadores repartidos en rejilla por TODO el mapa (no sólo sobre el
## camino): con 220x220 el campo es la mayor parte del nivel y quedaría vacío.
## Temática de afueras de un castillo: esqueletos y lobos.
func _poblar(enemigos: Node2D, raiz: Node) -> void:
	var mobs: Array[PackedScene] = [
		load("res://escenas/enemigos/EnemigoCaballeroEsqueleto.tscn"),
		load("res://escenas/enemigos/EnemigoEsqueletoArquero.tscn"),
		load("res://escenas/enemigos/EnemigoLobo.tscn"),
		load("res://escenas/enemigos/EnemigoLoboFeroz.tscn"),
	]
	var n := 0
	for fila in FILAS_SPAWNER:
		for columna in COLUMNAS_SPAWNER:
			var spawner := Node2D.new()
			spawner.name = "SpawnerMobs%d" % n
			spawner.set_script(load(GUION_SPAWNER))
			spawner.position = Vector2(_tile_a_px(columna), _tile_a_px(fila))
			spawner.set("lista_mobs", mobs)
			spawner.set("maximo_mobs", MOBS_POR_SPAWNER)
			spawner.set("radio_spawn", 520.0)
			spawner.set("cantidad_inicial", MOBS_POR_SPAWNER)
			spawner.set("intervalo_spawn", 10.0)
			enemigos.add_child(spawner)
			spawner.owner = raiz
			n += 1
	print("  generadores: %d (hasta %d mobs a la vez)" % [n, n * MOBS_POR_SPAWNER])
