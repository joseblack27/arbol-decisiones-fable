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
	var generador := _buscar_generador()
	if generador == null:
		return
	for nodo in _puntos_importantes():
		generador.despejar_alrededor(nodo.global_position, radio_despeje)


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
