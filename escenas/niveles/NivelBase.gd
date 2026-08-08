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
		_configurar_spawner_red()
	var generador := _buscar_generador()
	if generador == null:
		return
	for nodo in _puntos_importantes():
		generador.despejar_alrededor(nodo.global_position, radio_despeje)


## Mapa de navegación PROPIO de este nivel, en vez del compartido del mundo.
##
## Hace falta porque en el servidor conviven varios niveles a la vez, separados
## por 100.000 px (ver GestorNiveles). Con un único mapa compartido, los mobs
## de un nivel SIN malla propia —la Cueva no tiene— encontraban como "punto
## navegable más cercano" la malla del OTRO nivel, a 98.000 px, y sus agentes
## se iban caminando para allá en línea recta para siempre: detectaban al
## jugador pero jamás se le acercaban. Reportado: "los mobs de la cueva se
## quedaron quietos y solo reacciona la araña disparando de lejos" (la araña
## ataca a distancia, así que era la única que parecía viva).
##
## Con un mapa por nivel, un nivel sin malla simplemente no tiene rutas y sus
## mobs caen al respaldo de línea recta hacia el objetivo (ver
## MovimientoComponente._avanzar_hacia_destino), que es como se comportaban
## antes de que existieran varios niveles a la vez.
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


## UN solo MultiplayerSpawner para todo el contenedor "Enemigos": replica
## tanto los mobs de los generadores como las entidades que invoca un jugador
## (HabilidadInvocacion).
##
## Godot no admite dos spawners siguiendo al MISMO nodo: el segundo y
## siguientes fallan con "ERR_ALREADY_IN_USE" en cada alta. Antes cada
## SpawnerMobs creaba el suyo apuntando al mismo contenedor, y con los 18
## generadores del Camino eran ~1.500 líneas de error por sesión en la consola
## del servidor — que corre con un solo núcleo y ya sufrió antes por
## chaparrones de consola.
##
## Se crea ACÁ y no en SpawnerMobs a propósito: _ready() corre de hijos a
## padres, así que cuando le toca a un SpawnerMobs su contenedor todavía está
## "ocupado armando hijos" y add_child() sobre él falla. El nivel es el primer
## punto donde el árbol ya está quieto.
##
## Corre en TODOS los peers (no sólo el servidor): el spawner tiene que existir
## igual en los dos lados para que la réplica funcione.
func _configurar_spawner_red() -> void:
	var enemigos := get_node_or_null("Enemigos")
	if enemigos == null:
		return
	var spawner := MultiplayerSpawner.new()
	spawner.name = "SpawnerRed"
	# add_child() ANTES de spawn_path: la ruta se resuelve como NodePath
	# absoluto y necesita que el spawner ya esté dentro del árbol.
	enemigos.add_child(spawner)
	spawner.spawn_path = enemigos.get_path()
	spawner.add_spawnable_scene("res://escenas/enemigos/AliadoInvocado.tscn")
	for hijo in enemigos.get_children():
		if hijo.has_method("escenas_replicables"):
			for ruta in hijo.call("escenas_replicables"):
				spawner.add_spawnable_scene(ruta)


func punto_aparicion() -> Node2D:
	return get_node_or_null("PuntoAparicion")


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
