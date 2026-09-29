class_name NivelBase
extends Node2D
## Contrato de todo nivel del juego. Un nivel aporta:
##   - Terreno (un TileMapLayer, pintado a mano o con GeneradorTerreno).
##   - PuntoAparicion (Marker2D): donde aparece el jugador al entrar.
##   - Enemigos (Node2D contenedor): los habitantes del nivel.
##   - Portales (PortalNivel): salidas hacia otros niveles.
##
## Crear un nivel nuevo = duplicar una escena de nivel y cambiar terreno,
## enemigos y portales. GestorNiveles no necesita saber nada más.

@export var nombre_nivel := "Nivel sin nombre"

## Radio (en tiles) que se despeja alrededor de puntos importantes para que
## nadie aparezca dentro de una roca o del agua.
@export var radio_despeje := 3


func _ready() -> void:
	_crear_mapa_navegacion()
	if Utils.en_red():
		_configurar_replicador_red()
	var generador := _buscar_generador()
	if generador == null:
		return
	for nodo in _puntos_importantes():
		generador.despejar_alrededor(nodo.global_position, radio_despeje)


## Mapa de navegación PROPIO de este nivel, en vez del compartido del mundo.
##
## En el servidor conviven varios niveles separados por 100.000 px (ver
## GestorNiveles). Con un mapa compartido, los mobs de un nivel sin malla
## propia tomaban como "punto navegable más cercano" la malla de OTRO nivel y
## se iban caminando para allá: detectaban al jugador pero nunca se le
## acercaban.
##
## Con un mapa por nivel, un nivel sin malla no tiene rutas y sus mobs caen al
## respaldo de línea recta hacia el objetivo (ver
## MovimientoComponente._avanzar_hacia_destino).
var _mapa_navegacion: RID

func _crear_mapa_navegacion() -> void:
	var por_defecto := get_world_2d().navigation_map
	_mapa_navegacion = NavigationServer2D.map_create()
	NavigationServer2D.map_set_cell_size(
		_mapa_navegacion, NavigationServer2D.map_get_cell_size(por_defecto))
	NavigationServer2D.map_set_active(_mapa_navegacion, true)
	for nodo in _descendientes():
		if nodo is TileMapLayer:
			(nodo as TileMapLayer).set_navigation_map(_mapa_navegacion)
		elif nodo is NavigationRegion2D:
			(nodo as NavigationRegion2D).set_navigation_map(_mapa_navegacion)
	var capa := get_node_or_null("Navegacion") as TileMapLayer
	if capa != null and capa.navigation_enabled:
		_preparar_malla_con_margen(capa)


# =============================================================================
# MALLA CON MARGEN: la capa Navegacion se pinta celda por celda, y la malla que
# arma el TileMapLayer llega hasta el filo de las paredes, así que las rutas
# las rozan. En vez de usarla tal cual, se hornea una malla a partir de las
# mismas celdas achicada en MovimientoComponente.MARGEN_MALLA (el radio típico
# de un mob): una ruta por el borde ya pasa separada de la pared.
#
# Se hornea una vez, en todos los peers, al cargar el nivel (de 7 a 60 ms
# según el nivel). La capa queda con la navegación apagada: su malla sin
# margen competiría con esta.
# =============================================================================
var _region_con_margen: NavigationRegion2D

func _preparar_malla_con_margen(capa: TileMapLayer) -> void:
	capa.navigation_enabled = false
	_region_con_margen = NavigationRegion2D.new()
	_region_con_margen.name = "NavegacionConMargen"
	if capa.tile_set != null and capa.tile_set.get_navigation_layers_count() > 0:
		_region_con_margen.navigation_layers = capa.tile_set.get_navigation_layer_layers(0)
	add_child(_region_con_margen)
	_region_con_margen.set_navigation_map(_mapa_navegacion)
	_hornear_malla_con_margen(capa)


## Si algo pinta la capa Navegacion en tiempo de ejecución (hoy solo pruebas),
## la malla no se entera sola: pintar celdas no emite "changed" en esta
## versión de Godot. Hay que pedirle que se vuelva a hornear.
func rehornear_navegacion() -> void:
	var capa := get_node_or_null("Navegacion") as TileMapLayer
	if capa != null and is_instance_valid(_region_con_margen):
		_hornear_malla_con_margen(capa)


## Cada celda aporta su polígono de navegación (el de la ficha, en general el
## cuadrado entero) como contorno transitable; el horneado los une y los achica
## en agent_radius.
func _hornear_malla_con_margen(capa: TileMapLayer) -> void:
	var fuente := NavigationMeshSourceGeometryData2D.new()
	for celda in capa.get_used_cells():
		var datos := capa.get_cell_tile_data(celda)
		if datos == null:
			continue
		var poligono := datos.get_navigation_polygon(0)
		if poligono == null:
			continue
		var centro := capa.map_to_local(celda)
		for contorno in _contornos_de(poligono):
			var puntos := PackedVector2Array()
			for p in contorno:
				puntos.append(_region_con_margen.to_local(capa.to_global(centro + p)))
			fuente.add_traversable_outline(puntos)
	var malla := NavigationPolygon.new()
	malla.agent_radius = MovimientoComponente.MARGEN_MALLA
	NavigationServer2D.bake_from_source_geometry_data(malla, fuente)
	_region_con_margen.navigation_polygon = malla


## Los polígonos de las fichas pueden traer contornos o solo los polígonos ya
## horneados (vértices + índices); cualquiera de los dos sirve de contorno.
func _contornos_de(poligono: NavigationPolygon) -> Array[PackedVector2Array]:
	var contornos: Array[PackedVector2Array] = []
	for i in poligono.get_outline_count():
		contornos.append(poligono.get_outline(i))
	if not contornos.is_empty():
		return contornos
	var vertices := poligono.get_vertices()
	for i in poligono.get_polygon_count():
		var contorno := PackedVector2Array()
		for indice in poligono.get_polygon(i):
			contorno.append(vertices[indice])
		contornos.append(contorno)
	return contornos


## El mapa de navegación de este nivel. Todo lo que navegue DENTRO del nivel
## (agentes de los mobs, validación de puntos de aparición, contención dentro
## del mapa) tiene que usar este y no el del mundo.
func mapa_navegacion() -> RID:
	return _mapa_navegacion


func _exit_tree() -> void:
	if _mapa_navegacion.is_valid():
		NavigationServer2D.free_rid(_mapa_navegacion)
		_mapa_navegacion = RID()


func _descendientes(desde: Node = null) -> Array[Node]:
	var raiz: Node = desde if desde != null else self
	var resultado: Array[Node] = []
	for hijo in raiz.get_children():
		resultado.append(hijo)
		resultado.append_array(_descendientes(hijo))
	return resultado


## Corre en TODOS los peers: el replicador tiene que existir en la misma ruta
## en los dos lados para que sus RPCs lleguen. Hijo del nivel y no de
## "Enemigos" porque GestorNiveles apaga ese contenedor cuando el nivel queda
## sin jugadores.
func _configurar_replicador_red() -> void:
	var enemigos := get_node_or_null("Enemigos")
	if enemigos == null:
		return
	var replicador := ReplicadorEnemigos.new()
	replicador.name = "ReplicadorEnemigos"
	replicador.configurar(enemigos, self)
	add_child(replicador)


func punto_aparicion() -> Node2D:
	return get_node_or_null("PuntoAparicion")


## Contenedor de los mobs hostiles del nivel — ver GestorNiveles.
## _actualizar_actividad_niveles(), que lo apaga por separado del resto del
## nivel cuando no hay jugadores, aunque el nivel esté marcado "siempre
## activo" (Pradera/Ciudad/Mina, por los NPCs errantes).
func contenedor_enemigos() -> Node:
	return get_node_or_null("Enemigos")


## Rectángulo del mundo (coordenadas globales) que ocupa el Terreno del
## nivel, para que la cámara del jugador no muestre el vacío fuera del mapa.
## Rect2() vacío si el nivel no tiene Terreno (sin límite conocido).
func limites_camara() -> Rect2:
	var terreno := get_node_or_null("Terreno") as TileMapLayer
	if terreno == null:
		return Rect2()
	var usado := terreno.get_used_rect()
	if usado.size == Vector2i.ZERO:
		return Rect2()
	var mitad_tile := Vector2(terreno.tile_set.tile_size) / 2.0
	# map_to_local() da el CENTRO de la celda; restar medio tile lleva al
	# borde real de la rejilla (independiente de la escala de la capa,
	# porque to_global() aplica la transformación completa del nodo).
	var esquina_a := terreno.to_global(terreno.map_to_local(usado.position) - mitad_tile)
	var esquina_b := terreno.to_global(terreno.map_to_local(usado.position + usado.size) - mitad_tile)
	var minimo := esquina_a.min(esquina_b)
	var maximo := esquina_a.max(esquina_b)
	return Rect2(minimo, maximo - minimo)


## Puntos que deben quedar en suelo transitable: aparición, portales y enemigos.
func _puntos_importantes() -> Array[Node2D]:
	var puntos: Array[Node2D] = []
	var aparicion := punto_aparicion()
	if aparicion != null:
		puntos.append(aparicion)
	for portal in get_tree().get_nodes_in_group(&"portales_nivel"):
		if portal is Node2D and is_ancestor_of(portal):
			puntos.append(portal)
	var enemigos := get_node_or_null("Enemigos")
	if enemigos != null:
		for hijo in enemigos.get_children():
			if hijo is Node2D:
				puntos.append(hijo)
	return puntos


func _buscar_generador() -> GeneradorTerreno:
	for hijo in get_children():
		if hijo is GeneradorTerreno:
			return hijo
	return null
