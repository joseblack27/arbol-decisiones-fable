# =============================================================================
# generar_nivel_hormiguero.gd — construye escenas/niveles/NivelHormiguero.tscn.
#
# Colonia de hormigas: una cadena de 10 salas conectadas por túneles (serpentea
# en 2 filas), desde la entrada (sala 0, portal a Pradera) hasta la cámara de
# la Reina (sala 9). Topología de túnel/sala como la Mina (capa Navegacion por
# celda, BFS-verificable), no un campo abierto como Camino.
#
# Paleta reusada TAL CUAL de _construir_cueva() en construir_niveles.gd (ya
# verificada 100% opaca, mismo tileset_juego.tres compartido): PIEDRA/
# PIEDRA_GRIETA de piso, MURO_OSCURO/MURO_OSCURO_B de pared sólida.
#
# Esta corrida arma SOLO estructura (terreno+navegación+portal+aparición+
# contenedor Enemigos vacío) — spawners/activadores/reina se agregan en un
# paso aparte, después de verificar con verificar_navegacion_bfs.gd que la
# malla conecta de verdad.
#   godot --headless --path . --script res://herramientas/generar_nivel_hormiguero.gd
# =============================================================================
extends SceneTree

const RUTA_SALIDA := "res://escenas/niveles/NivelHormiguero.tscn"
const TILESET_JUEGO := "res://escenas/niveles/tileset_juego.tres"
const TILESET_NAV := "res://escenas/niveles/tileset_colisiones.tres"
const ESCENA_PORTAL := "res://escenas/niveles/PortalNivel.tscn"

# ── Paleta (verificada opaca en construir_niveles.gd/_construir_cueva) ───────
const PIEDRA := Vector2i(17, 30)
const PIEDRA_GRIETA := Vector2i(16, 29)
const MURO_OSCURO := Vector2i(27, 5)
const MURO_OSCURO_B := Vector2i(28, 5)

# ── Salas: centros en tiles de 32px, sala 0 = entrada, sala 9 = Reina ────────
# Serpentea en 2 filas de 5 para que el recorrido no sea una línea recta.
const CENTROS_SALA: Array[Vector2i] = [
	Vector2i(-100, -20), Vector2i(-50, -20), Vector2i(0, -20), Vector2i(50, -20), Vector2i(100, -20),
	Vector2i(100, 25), Vector2i(50, 25), Vector2i(0, 25), Vector2i(-50, 25), Vector2i(-100, 25),
]
const RADIO_SALA := Vector2(9.0, 7.0)
## Última sala más grande (cámara de la Reina): más espacio para moverse.
const RADIO_SALA_REINA := Vector2(13.0, 10.0)
const RADIO_TUNEL := 2.5
## Margen sólido alrededor de todo lo cavado, para que el mapa tenga borde.
const MARGEN_MURO := 6

var _rng := RandomNumberGenerator.new()
var _celdas_piso: Dictionary = {}


func _process(_d: float) -> bool:
	_rng.seed = 20260913

	var raiz := Node2D.new()
	raiz.name = "NivelHormiguero"
	raiz.set_script(load("res://escenas/niveles/NivelBase.gd"))
	raiz.set("nombre_nivel", "Hormiguero")
	raiz.y_sort_enabled = true

	var terreno := _crear_capa("Terreno", TILESET_JUEGO, raiz)
	# Sin esto el Terreno se dibuja al mismo z_index que jugador/mobs (0) --
	# con y_sort_enabled mezclando cada tile individual en ese mismo orden,
	# algunas celdas (sobre todo paredes) terminaban tapando sprites por
	# encima, y el indicador de apunte de las habilidades (que dibuja en el
	# mismo espacio) también quedaba tapado. Todos los demás niveles ya
	# tienen esto -- se me pasó acá. z_index bien negativo fuerza a la capa
	# ENTERA detrás de todo lo demás, sin importar el y_sort interno.
	terreno.z_index = -10
	terreno.y_sort_enabled = true
	terreno.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var navegacion := _crear_capa("Navegacion", TILESET_NAV, raiz)
	navegacion.modulate.a = 0.0

	_cavar_salas_y_tuneles()
	_pintar(terreno, navegacion)

	var limites := _limites_pintados()
	print("Hormiguero: %d celdas de piso, límites %s a %s (%d x %d tiles)." % [
		_celdas_piso.size(), limites[0], limites[1],
		limites[1].x - limites[0].x + 1, limites[1].y - limites[0].y + 1])

	var aparicion := Marker2D.new()
	aparicion.name = "PuntoAparicion"
	aparicion.position = _tile_a_px(CENTROS_SALA[0])
	raiz.add_child(aparicion)
	aparicion.owner = raiz

	var portal := (load(ESCENA_PORTAL) as PackedScene).instantiate()
	portal.name = "PortalAPradera"
	portal.position = _tile_a_px(CENTROS_SALA[0] + Vector2i(-4, 0))
	portal.set("ruta_nivel_destino", "res://escenas/niveles/NivelPradera.tscn")
	portal.set("etiqueta", "→ Pradera")
	raiz.add_child(portal)
	portal.owner = raiz

	var enemigos := Node2D.new()
	enemigos.name = "Enemigos"
	enemigos.y_sort_enabled = true
	raiz.add_child(enemigos)
	enemigos.owner = raiz

	var decoraciones := Node2D.new()
	decoraciones.name = "Decoraciones"
	decoraciones.y_sort_enabled = true
	raiz.add_child(decoraciones)
	decoraciones.owner = raiz

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
	print("  aparicion=%s (sala 0), reina=%s (sala 9)" % [
		aparicion.position, _tile_a_px(CENTROS_SALA[9])])
	quit(0)
	return true


func _crear_capa(nombre: String, ruta_tileset: String, raiz: Node) -> TileMapLayer:
	var capa := TileMapLayer.new()
	capa.name = nombre
	capa.tile_set = load(ruta_tileset)
	raiz.add_child(capa)
	capa.owner = raiz
	return capa


func _tile_a_px(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * 32.0 + 16.0, tile.y * 32.0 + 16.0)


## Marca en _celdas_piso (Dictionary usado como set) cada celda cavada, sea
## de sala o de túnel — separado de _pintar() para poder calcular límites
## antes de pintar nada.
func _cavar_salas_y_tuneles() -> void:
	for i in CENTROS_SALA.size():
		var radio := RADIO_SALA_REINA if i == CENTROS_SALA.size() - 1 else RADIO_SALA
		_cavar_elipse(CENTROS_SALA[i], radio)
	for i in CENTROS_SALA.size() - 1:
		_cavar_tunel(CENTROS_SALA[i], CENTROS_SALA[i + 1])


func _cavar_elipse(centro: Vector2i, radio: Vector2) -> void:
	var rx := ceili(radio.x)
	var ry := ceili(radio.y)
	for dx in range(-rx, rx + 1):
		for dy in range(-ry, ry + 1):
			var d := Vector2(dx, dy) / radio
			if d.length() <= 1.0:
				_celdas_piso[centro + Vector2i(dx, dy)] = true


## Túnel recto entre dos centros de sala: capsula gruesa (un disco de
## RADIO_TUNEL en cada punto muestreado a lo largo del segmento) — alcanza
## para conectar sin necesitar pathfinding real, y el ancho fijo hace que
## nunca quede una costura de un tile pelado entre sala y túnel.
func _cavar_tunel(desde: Vector2i, hasta: Vector2i) -> void:
	var distancia := Vector2(hasta - desde).length()
	var pasos := maxi(1, ceili(distancia))
	for i in (pasos + 1):
		var t := float(i) / float(pasos)
		var centro := Vector2(desde).lerp(Vector2(hasta), t)
		var r := ceili(RADIO_TUNEL)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if Vector2(dx, dy).length() <= RADIO_TUNEL:
					_celdas_piso[Vector2i(round(centro.x) + dx, round(centro.y) + dy)] = true


func _limites_pintados() -> Array:
	var min_c := Vector2i(999999, 999999)
	var max_c := Vector2i(-999999, -999999)
	for celda in _celdas_piso:
		min_c = min_c.min(celda)
		max_c = max_c.max(celda)
	return [min_c, max_c]


## Piso donde se cavó, pared sólida en un margen alrededor (nunca "vacío":
## un TileMapLayer sin celda ahí no bloquea nada, así que sin pared real un
## jugador podría caminar fuera del área cavada sin que se note en el mapa).
func _pintar(terreno: TileMapLayer, navegacion: TileMapLayer) -> void:
	var limites := _limites_pintados()
	var min_c: Vector2i = limites[0] - Vector2i.ONE * MARGEN_MURO
	var max_c: Vector2i = limites[1] + Vector2i.ONE * MARGEN_MURO
	for x in range(min_c.x, max_c.x + 1):
		for y in range(min_c.y, max_c.y + 1):
			var celda := Vector2i(x, y)
			if _celdas_piso.has(celda):
				terreno.set_cell(celda, 0, PIEDRA if _rng.randf() < 0.85 else PIEDRA_GRIETA)
				navegacion.set_cell(celda, 0, Vector2i.ZERO)
			else:
				terreno.set_cell(celda, 0, MURO_OSCURO if (x + y) % 2 == 0 else MURO_OSCURO_B)
